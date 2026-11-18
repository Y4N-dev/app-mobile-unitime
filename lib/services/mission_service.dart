// lib/services/mission_service.dart
//
// MISSÕES DIÁRIAS, RESGATE DE XP, SEQUÊNCIA DE DIAS E RESUMO DA SEMANA.
//
// Este serviço só LÊ dados que o app já guarda (curtidas com data,
// comentários, compras, avaliações e vídeos publicados) e GRAVA apenas o
// XP resgatado. Nenhuma regra de créditos é executada aqui. Os níveis são
// SIMBÓLICOS: missões dão só XP, nunca créditos.
//
// Regras:
//  - 4 missões por dia, iguais para todos no mesmo dia (variam pelo dia da
//    semana). A quarta é "postar vídeo" na quarta e no sábado; nos outros
//    dias é "avaliar um vídeo".
//  - O resgate só vale NO MESMO DIA: quem esquece, perde aquele XP.
//  - Sequência de dias = dias seguidos com pelo menos uma missão resgatada.
//
// FUTURO: com o banco online, só a origem dos dados (MockDatabase) muda.

import '../data/mock_database.dart';
import '../models/video_model.dart';
import '../models/xp_entry_model.dart';
import 'progression_service.dart';

// =======================================================================
// REGRAS (valores em um lugar só)
// =======================================================================

class MissionRules {
  MissionRules._();

  // XP de cada missão (um dia comum rende 45 XP; dia de postagem, 65)
  static const int likeXp = 10;
  static const int commentXp = 10;
  static const int unlockXp = 15;
  static const int rateXp = 10;
  static const int postXp = 30;

  /// Duração mínima do vídeo da missão "postar".
  static const int postMinMinutes = 3;

  /// A corrente só aparece "quebrada" para sequências de pelo menos 2 dias.
  static const int minBrokenStreak = 2;
}

/// Tipos de missão. O nome (kind.name) é o código gravado no XP resgatado.
enum MissionKind { like, comment, unlock, rate, post }

// =======================================================================
// RESULTADOS (o que a tela recebe pronto)
// =======================================================================

/// Situação de uma missão do dia.
class MissionStatus {
  final MissionKind kind;
  final String title;
  final String description;
  final int xp;
  final int target; // meta (já ajustada ao que o aluno tem disponível)
  final int progress; // quanto já foi feito (nunca passa da meta)
  final bool claimed; // XP já resgatado hoje

  /// Motivo da missão estar indisponível hoje (nulo = disponível).
  final String? unavailableReason;

  /// A meta foi reduzida porque o aluno tem menos vídeos disponíveis.
  final bool adjusted;

  const MissionStatus({
    required this.kind,
    required this.title,
    required this.description,
    required this.xp,
    required this.target,
    required this.progress,
    required this.claimed,
    this.unavailableReason,
    this.adjusted = false,
  });

  String get id => kind.name;
  bool get completed => progress >= target;
  bool get unavailable => unavailableReason != null && !completed;

  /// Pronta para o botão "Resgatar".
  bool get canClaim => completed && !claimed;

  /// Progresso de 0.0 a 1.0 (para a barra).
  double get fraction =>
      target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0).toDouble();
}

/// As missões de um dia.
class DailyMissions {
  final DateTime day;
  final List<MissionStatus> missions;

  const DailyMissions({required this.day, required this.missions});

  /// XP que ainda é possível ganhar hoje (ignora as indisponíveis).
  int get possibleXp {
    var total = 0;
    for (final m in missions) {
      if (!m.unavailable) total += m.xp;
    }
    return total;
  }

  /// XP já resgatado hoje.
  int get claimedXp {
    var total = 0;
    for (final m in missions) {
      if (m.claimed) total += m.xp;
    }
    return total;
  }

  /// XP de missões completas esperando o botão "Resgatar".
  int get claimableXp {
    var total = 0;
    for (final m in missions) {
      if (m.canClaim) total += m.xp;
    }
    return total;
  }
}

/// Resultado do resgate de uma missão.
class ClaimResult {
  final bool success;
  final String message;
  final int xp;
  final int levelBefore;
  final int levelAfter;

  /// Faixa de medalha nova, se o resgate fez o aluno trocar de faixa.
  final MedalTier? newTier;

  const ClaimResult({
    required this.success,
    required this.message,
    this.xp = 0,
    this.levelBefore = 0,
    this.levelAfter = 0,
    this.newTier,
  });

  factory ClaimResult.fail(String message) =>
      ClaimResult(success: false, message: message);

  bool get leveledUp => success && levelAfter > levelBefore;
}

/// Estados da corrente da sequência de dias.
enum StreakState {
  none, // sem sequência (corrente inteira, número 0)
  active, // sequência viva (corrente inteira, número preto)
  broken, // quebrada (corrente quebrada, número perdido em vermelho)
}

class StreakInfo {
  final StreakState state;
  final int count;
  final bool claimedToday;

  const StreakInfo({
    required this.state,
    required this.count,
    required this.claimedToday,
  });
}

/// Um dia do resumo da semana.
class WeekDayInfo {
  final DateTime date;
  final bool claimed;
  final bool isToday;
  final bool isFuture;

  const WeekDayInfo({
    required this.date,
    required this.claimed,
    required this.isToday,
    required this.isFuture,
  });
}

/// Resumo da semana (segunda a domingo). Puramente simbólico.
class WeekSummary {
  final List<WeekDayInfo> days;
  const WeekSummary(this.days);

  int get claimedCount => days.where((d) => d.claimed).length;
}

// =======================================================================
// SERVIÇO
// =======================================================================

class _Def {
  final MissionKind kind;
  final String title;
  final int xp;
  final int baseTarget;
  final int minMinutes;

  const _Def(this.kind, this.title, this.xp, this.baseTarget, this.minMinutes);
}

class MissionService {
  MissionService._();
  static final MissionService instance = MissionService._();

  MockDatabase get _db => MockDatabase.instance;

  // =====================================================================
  // NÍVEL
  // =====================================================================

  /// Nível e progresso do aluno (calculado a partir do XP resgatado).
  LevelInfo levelInfo(String rgm) =>
      ProgressionService.infoFor(_db.totalXp(rgm));

  // =====================================================================
  // MISSÕES DO DIA
  // =====================================================================

  /// Missões de hoje, com o progresso calculado sobre os dados do app.
  DailyMissions todaysMissions(String rgm, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final dayKey = XpEntryModel.dayKeyOf(today);

    // Vídeos de outros alunos que este aluno já desbloqueou (os únicos em
    // que dá para curtir, comentar e avaliar).
    final accessible = _db.getUnlockedVideos(rgm);

    final list = <MissionStatus>[];
    for (final def in _definitionsFor(today)) {
      list.add(_buildStatus(def, rgm, today, dayKey, accessible.length));
    }
    return DailyMissions(day: today, missions: list);
  }

  /// As 4 missões do dia da semana (ver tabela de variação).
  List<_Def> _definitionsFor(DateTime day) {
    final wd = day.weekday;
    final likeTarget = (wd == DateTime.tuesday ||
            wd == DateTime.thursday ||
            wd == DateTime.saturday)
        ? 3
        : 2;
    final commentTarget =
        (wd == DateTime.thursday || wd == DateTime.sunday) ? 2 : 1;
    final unlockMinutes =
        (wd == DateTime.tuesday || wd == DateTime.thursday) ? 2 : 1;
    final isPostDay = wd == DateTime.wednesday || wd == DateTime.saturday;

    return [
      _Def(MissionKind.like, 'Curtir vídeos', MissionRules.likeXp, likeTarget,
          1),
      _Def(MissionKind.comment, 'Comentar', MissionRules.commentXp,
          commentTarget, 1),
      _Def(MissionKind.unlock, 'Desbloquear um vídeo', MissionRules.unlockXp, 1,
          unlockMinutes),
      isPostDay
          ? const _Def(MissionKind.post, 'Postar um vídeo', MissionRules.postXp,
              1, MissionRules.postMinMinutes)
          : const _Def(
              MissionKind.rate, 'Avaliar um vídeo', MissionRules.rateXp, 1, 1),
    ];
  }

  MissionStatus _buildStatus(
    _Def def,
    String rgm,
    DateTime today,
    String dayKey,
    int accessibleCount,
  ) {
    var target = def.baseTarget;
    var adjusted = false;
    String? unavailable;
    int progress;

    switch (def.kind) {
      case MissionKind.like:
        progress = _likesToday(rgm, today);
        break;
      case MissionKind.comment:
        progress = _commentsToday(rgm, today);
        break;
      case MissionKind.unlock:
        progress = _unlocksToday(rgm, today, def.minMinutes);
        break;
      case MissionKind.rate:
        progress = _ratingsToday(rgm, today);
        break;
      case MissionKind.post:
        progress = _postsToday(rgm, today, def.minMinutes);
        break;
    }

    // Curtir, comentar e avaliar exigem vídeos desbloqueados: a meta se
    // ajusta ao que o aluno tem disponível.
    if (def.kind == MissionKind.like ||
        def.kind == MissionKind.comment ||
        def.kind == MissionKind.rate) {
      if (accessibleCount == 0) {
        unavailable = 'Desbloqueie um vídeo para poder participar.';
      } else if (target > accessibleCount) {
        target = accessibleCount;
        adjusted = true;
      }
    }

    // Desbloquear: precisa existir um vídeo novo ao alcance do saldo.
    if (def.kind == MissionKind.unlock && progress < target) {
      unavailable = _unlockUnavailableReason(rgm, def.minMinutes);
    }

    final shownProgress = progress > target ? target : progress;
    return MissionStatus(
      kind: def.kind,
      title: def.title,
      description: _describe(def, target),
      xp: def.xp,
      target: target,
      progress: shownProgress,
      claimed: _db.hasClaimed(rgm, def.kind.name, dayKey),
      unavailableReason: unavailable,
      adjusted: adjusted,
    );
  }

  String _describe(_Def def, int target) {
    switch (def.kind) {
      case MissionKind.like:
        return 'Curta $target '
            '${target == 1 ? 'vídeo diferente' : 'vídeos diferentes'} '
            'de outros alunos.';
      case MissionKind.comment:
        return 'Comente em $target '
            '${target == 1 ? 'vídeo' : 'vídeos diferentes'} '
            'de outros alunos.';
      case MissionKind.unlock:
        return def.minMinutes <= 1
            ? 'Desbloqueie 1 vídeo novo.'
            : 'Desbloqueie 1 vídeo novo de no mínimo ${def.minMinutes} min.';
      case MissionKind.rate:
        return 'Avalie 1 vídeo que você desbloqueou.';
      case MissionKind.post:
        return 'Publique 1 vídeo de no mínimo ${def.minMinutes} min.';
    }
  }

  // ---------- Progresso de cada missão (dados que o app já guarda) ----------

  /// Vídeos DIFERENTES de outros alunos curtidos hoje.
  int _likesToday(String rgm, DateTime today) {
    final ids = <String>{};
    for (final id in _db.likedVideoIdsOn(rgm, today)) {
      final video = _db.getVideoById(id);
      if (video != null && !video.isOwnedBy(rgm)) ids.add(id);
    }
    return ids.length;
  }

  /// Vídeos DIFERENTES de outros alunos comentados hoje.
  int _commentsToday(String rgm, DateTime today) {
    var count = 0;
    for (final video in _db.allVideos) {
      if (video.isOwnedBy(rgm)) continue;
      final commented = _db
          .getComments(video.id)
          .any((c) => c.authorRgm == rgm && _sameDay(c.createdAt, today));
      if (commented) count++;
    }
    return count;
  }

  /// Vídeos novos desbloqueados hoje com pelo menos [minMinutes] minutos.
  /// (Minutos = valor pago ÷ 10; só vale se o vídeo ainda existe.)
  int _unlocksToday(String rgm, DateTime today, int minMinutes) {
    final ids = <String>{};
    for (final t in _db.getTransactionsByUser(rgm)) {
      if (!t.isUnlockPurchase || !_sameDay(t.createdAt, today)) continue;
      final id = t.videoId;
      if (id == null || _db.getVideoById(id) == null) continue;
      final minutes = t.amount ~/ VideoModel.creditsPerMinute;
      if (minutes >= minMinutes) ids.add(id);
    }
    return ids.length;
  }

  /// Vídeos de outros alunos avaliados hoje.
  int _ratingsToday(String rgm, DateTime today) {
    var count = 0;
    for (final video in _db.allVideos) {
      if (video.isOwnedBy(rgm)) continue;
      final rating = _db.getRatingBy(rgm, video.id);
      if (rating != null && _sameDay(rating.createdAt, today)) count++;
    }
    return count;
  }

  /// Vídeos publicados hoje com pelo menos [minMinutes] minutos.
  int _postsToday(String rgm, DateTime today, int minMinutes) {
    var count = 0;
    for (final video in _db.getVideosByAuthor(rgm)) {
      if (_sameDay(video.createdAt, today) &&
          video.durationSeconds >= minMinutes * 60) {
        count++;
      }
    }
    return count;
  }

  /// Por que a missão de desbloquear está indisponível (ou null se dá).
  String? _unlockUnavailableReason(String rgm, int minMinutes) {
    final balance = _db.getUserByRgm(rgm)?.credits ?? 0;
    final eligible = _db.allVideos.where((v) =>
        !v.isOwnedBy(rgm) &&
        !_db.hasUnlocked(rgm, v.id) &&
        v.billableMinutes >= minMinutes);

    if (eligible.isEmpty) return 'Não há vídeos novos disponíveis hoje.';
    final affordable = eligible.any((v) => v.creditCost <= balance);
    if (!affordable)
      return 'Saldo insuficiente para desbloquear um vídeo novo.';
    return null;
  }

  // =====================================================================
  // RESGATE (só vale no MESMO dia da missão)
  // =====================================================================

  ClaimResult claim(String rgm, MissionKind kind, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = _dateOnly(current);
    final dayKey = XpEntryModel.dayKeyOf(today);

    // Só existem missões de HOJE: dias passados não podem ser resgatados.
    MissionStatus? mission;
    for (final m in todaysMissions(rgm, now: current).missions) {
      if (m.kind == kind) mission = m;
    }
    if (mission == null) {
      return ClaimResult.fail('Missão não encontrada para hoje.');
    }
    if (mission.claimed) {
      return ClaimResult.fail('Você já resgatou esta missão hoje.');
    }
    if (!mission.completed) {
      return ClaimResult.fail('Complete a missão para resgatar o XP.');
    }

    final before = ProgressionService.infoFor(_db.totalXp(rgm));
    final saved = _db.addXpEntry(XpEntryModel(
      id: _db.nextXpId(),
      userRgm: rgm,
      missionId: kind.name,
      dayKey: dayKey,
      xp: mission.xp,
      createdAt: current,
    ));
    if (!saved) {
      return ClaimResult.fail('Você já resgatou esta missão hoje.');
    }
    final after = ProgressionService.infoFor(_db.totalXp(rgm));

    MedalTier? newTier;
    if (after.tier != before.tier) newTier = after.tier;

    var message = '+${mission.xp} XP resgatados!';
    if (after.level > before.level) {
      message = 'Você chegou ao nível ${after.level}! (+${mission.xp} XP)';
    }

    return ClaimResult(
      success: true,
      message: message,
      xp: mission.xp,
      levelBefore: before.level,
      levelAfter: after.level,
      newTier: newTier,
    );
  }

  // =====================================================================
  // SEQUÊNCIA DE DIAS
  // =====================================================================

  /// Estados da corrente:
  ///  - resgatou hoje, ou ontem: ATIVA (corrente inteira, número preto);
  ///  - passou um dia inteiro sem resgatar: QUEBRADA durante o dia seguinte
  ///    (corrente quebrada, número perdido em vermelho), mesmo que o aluno
  ///    resgate algo nesse dia; a nova sequência aparece só no dia seguinte;
  ///  - depois disso: sem sequência (corrente inteira, número 0).
  StreakInfo streak(String rgm, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final days = _claimedDays(rgm);
    final claimedToday = days.contains(today);

    // Último dia com resgate ANTES de hoje.
    DateTime? lastBefore;
    for (final d in days) {
      if (d.isBefore(today) && (lastBefore == null || d.isAfter(lastBefore))) {
        lastBefore = d;
      }
    }

    if (lastBefore != null) {
      final gap = _daysBetween(lastBefore, today);
      final run = _runEndingAt(days, lastBefore);

      // Hoje é o dia seguinte ao primeiro dia perdido: corrente quebrada.
      if (gap == 2 && run >= MissionRules.minBrokenStreak) {
        return StreakInfo(
          state: StreakState.broken,
          count: run,
          claimedToday: claimedToday,
        );
      }

      // Resgatou ontem: a sequência está viva (hoje ainda dá para manter).
      if (gap == 1) {
        return StreakInfo(
          state: StreakState.active,
          count: claimedToday ? run + 1 : run,
          claimedToday: claimedToday,
        );
      }
    }

    if (claimedToday) {
      return const StreakInfo(
          state: StreakState.active, count: 1, claimedToday: true);
    }
    return const StreakInfo(
        state: StreakState.none, count: 0, claimedToday: false);
  }

  // =====================================================================
  // RESUMO DA SEMANA (segunda a domingo, puramente simbólico)
  // =====================================================================

  WeekSummary weekSummary(String rgm, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final claimedDays = _claimedDays(rgm);
    final monday =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));

    final days = <WeekDayInfo>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(monday.year, monday.month, monday.day + i);
      days.add(WeekDayInfo(
        date: date,
        claimed: claimedDays.contains(date),
        isToday: date == today,
        isFuture: date.isAfter(today),
      ));
    }
    return WeekSummary(days);
  }

  // =====================================================================
  // AUXILIARES DE DATA
  // =====================================================================

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Dias entre duas datas (já sem hora), sem sofrer com horário de verão.
  static int _daysBetween(DateTime a, DateTime b) {
    return DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
  }

  /// Dias (sem hora) em que o aluno resgatou alguma missão.
  Set<DateTime> _claimedDays(String rgm) {
    final result = <DateTime>{};
    for (final key in _db.claimedDayKeys(rgm)) {
      final day = XpEntryModel.dayFromKey(key);
      if (day != null) result.add(_dateOnly(day));
    }
    return result;
  }

  /// Tamanho da sequência de dias seguidos que termina em [end].
  int _runEndingAt(Set<DateTime> days, DateTime end) {
    var run = 1;
    var cursor = end;
    while (true) {
      final previous = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!days.contains(previous)) break;
      run++;
      cursor = previous;
    }
    return run;
  }
}

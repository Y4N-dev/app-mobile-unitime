// lib/services/metrics_service.dart
//
// Todos os CÁLCULOS da aba Métricas, fora da tela. A tela só desenha o
// resultado destas funções. Este serviço apenas LÊ dados (extrato, saldo e
// vídeos): nenhuma regra de créditos é executada aqui (isso é papel do
// credit_service.dart).
//
// FUTURO: quando o banco de dados online existir, só a origem dos dados
// (MockDatabase) muda; estes cálculos e a tela continuam iguais.

import '../data/mock_database.dart';
import '../models/credit_transaction_model.dart';
import '../models/video_model.dart';

// =======================================================================
// FILTROS
// =======================================================================

/// Período do resumo, do balanço de minutos e do extrato.
enum MetricsPeriod {
  all('Tudo', null),
  last30Days('30 dias', 30),
  last7Days('7 dias', 7);

  final String label;
  final int? days; // nulo = sem limite de data
  const MetricsPeriod(this.label, this.days);
}

/// Filtro do extrato.
enum StatementFilter {
  all('Todos'),
  income('Ganhos'),
  expense('Gastos');

  final String label;
  const StatementFilter(this.label);
}

// =======================================================================
// RESULTADOS (o que a tela recebe pronto)
// =======================================================================

/// Resumo de créditos de um período, dividido por origem.
class CreditSummary {
  // Ganhos
  final int bootstrap; // fundo inicial
  final int videoEarnings; // ganhos com os seus vídeos
  final int refunds; // estornos recebidos (vídeos excluídos por autores)

  // Gastos
  final int unlockSpend; // desbloqueios
  final int editFees; // edições (créditos que saem de circulação)
  final int penalties; // penalidades por exclusão

  const CreditSummary({
    required this.bootstrap,
    required this.videoEarnings,
    required this.refunds,
    required this.unlockSpend,
    required this.editFees,
    required this.penalties,
  });

  int get totalIncome => bootstrap + videoEarnings + refunds;
  int get totalExpense => unlockSpend + editFees + penalties;

  /// Ganhos menos gastos (pode ser negativo no período).
  int get net => totalIncome - totalExpense;

  /// Minutos APRENDIDOS: gasto em desbloqueios, descontados os estornos
  /// (vídeos excluídos não contam). Nunca fica abaixo de 0.
  int get learnedMinutes {
    final value = unlockSpend - refunds;
    return value <= 0 ? 0 : value ~/ VideoModel.creditsPerMinute;
  }

  /// Minutos ENSINADOS: ganho com os seus vídeos, descontadas as
  /// penalidades. Nunca fica abaixo de 0.
  int get taughtMinutes {
    final value = videoEarnings - penalties;
    return value <= 0 ? 0 : value ~/ VideoModel.creditsPerMinute;
  }

  /// Proporção (0 a 1) de uma parte sobre o total. Útil para as barras.
  static double share(int part, int total) =>
      total <= 0 ? 0 : (part / total).clamp(0.0, 1.0).toDouble();
}

/// Estimativas de uso do saldo atual.
class UsageEstimates {
  final int balance;

  /// Quantos minutos de vídeo o saldo compra (saldo ÷ 10).
  final int minutesAffordable;

  /// Vídeos que não são seus e que você ainda não desbloqueou.
  final int availableVideos;

  /// Desses, quantos cabem no saldo atual.
  final int affordableVideos;

  final int? cheapestCost; // nulo se não há vídeos disponíveis
  final int? mostExpensiveCost;

  const UsageEstimates({
    required this.balance,
    required this.minutesAffordable,
    required this.availableVideos,
    required this.affordableVideos,
    this.cheapestCost,
    this.mostExpensiveCost,
  });

  /// Quanto falta para desbloquear o vídeo mais caro (0 se já dá).
  int? get missingForMostExpensive {
    final cost = mostExpensiveCost;
    if (cost == null) return null;
    final diff = cost - balance;
    return diff > 0 ? diff : 0;
  }
}

/// Um item do histórico de vídeos desbloqueados (atalho de consumo).
class UnlockedEntry {
  final VideoModel video;
  final int paid; // créditos pagos no desbloqueio
  final DateTime date;

  const UnlockedEntry({
    required this.video,
    required this.paid,
    required this.date,
  });
}

/// Rendimento de um vídeo do autor, em créditos.
class VideoEarning {
  final VideoModel video;

  /// Total de créditos que o vídeo já rendeu ao autor.
  final int earned;

  /// Quantos alunos compraram o vídeo.
  final int buyers;

  /// Se o autor EXCLUIR o vídeo: total devolvido aos compradores (100%).
  final int refundOnDelete;

  /// Se o autor EXCLUIR o vídeo: créditos que ele perderia (100% do que
  /// ganhou, limitado ao saldo atual por causa do piso de 0).
  final int penaltyOnDelete;

  const VideoEarning({
    required this.video,
    required this.earned,
    required this.buyers,
    required this.refundOnDelete,
    required this.penaltyOnDelete,
  });

  /// Soma do rendimento de uma lista de vídeos.
  static int total(List<VideoEarning> list) =>
      list.fold<int>(0, (sum, item) => sum + item.earned);
}

// =======================================================================
// SERVIÇO
// =======================================================================

class MetricsService {
  MetricsService._();
  static final MetricsService instance = MetricsService._();

  MockDatabase get _db => MockDatabase.instance;

  /// Extrato do aluno (mais recentes primeiro) dentro do período.
  List<CreditTransactionModel> _inPeriod(String rgm, MetricsPeriod period) {
    final all = _db.getTransactionsByUser(rgm);
    final days = period.days;
    if (days == null) return all;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return all.where((t) => !t.createdAt.isBefore(cutoff)).toList();
  }

  // ---------- Resumo e balanço de minutos (respeitam o período) ----------
  CreditSummary summary(String rgm, MetricsPeriod period) {
    var bootstrap = 0;
    var videoEarnings = 0;
    var refunds = 0;
    var unlockSpend = 0;
    var editFees = 0;
    var penalties = 0;

    for (final t in _inPeriod(rgm, period)) {
      switch (t.type) {
        case CreditTransactionType.bootstrap:
          bootstrap += t.amount;
          break;
        case CreditTransactionType.unlockEarning:
          videoEarnings += t.amount;
          break;
        case CreditTransactionType.deletionRefund:
          refunds += t.amount;
          break;
        case CreditTransactionType.unlockSpend:
          unlockSpend += t.amount;
          break;
        case CreditTransactionType.editFee:
          editFees += t.amount;
          break;
        case CreditTransactionType.deletionPenalty:
          penalties += t.amount;
          break;
      }
    }

    return CreditSummary(
      bootstrap: bootstrap,
      videoEarnings: videoEarnings,
      refunds: refunds,
      unlockSpend: unlockSpend,
      editFees: editFees,
      penalties: penalties,
    );
  }

  // ---------- Extrato (respeita período e filtro) ----------
  List<CreditTransactionModel> statement(
    String rgm,
    MetricsPeriod period,
    StatementFilter filter,
  ) {
    final list = _inPeriod(rgm, period);
    switch (filter) {
      case StatementFilter.all:
        return list;
      case StatementFilter.income:
        return list.where((t) => t.isIncome).toList();
      case StatementFilter.expense:
        return list.where((t) => t.isExpense).toList();
    }
  }

  // ---------- Estimativas de uso (sempre "agora") ----------
  UsageEstimates estimates(String rgm) {
    final balance = _db.getUserByRgm(rgm)?.credits ?? 0;

    // Só entram vídeos que não são seus e que ainda não foram desbloqueados.
    final available = _db.allVideos
        .where((v) => !v.isOwnedBy(rgm) && !_db.hasUnlocked(rgm, v.id))
        .toList();

    int? cheapest;
    int? mostExpensive;
    var affordable = 0;
    for (final video in available) {
      final cost = video.creditCost;
      if (cheapest == null || cost < cheapest) cheapest = cost;
      if (mostExpensive == null || cost > mostExpensive) mostExpensive = cost;
      if (cost <= balance) affordable++;
    }

    return UsageEstimates(
      balance: balance,
      minutesAffordable: balance ~/ VideoModel.creditsPerMinute,
      availableVideos: available.length,
      affordableVideos: affordable,
      cheapestCost: cheapest,
      mostExpensiveCost: mostExpensive,
    );
  }

  // ---------- Histórico de desbloqueados (atalho de consumo) ----------
  /// Do mais recente para o mais antigo. Vídeos excluídos saem do atalho
  /// (o estorno continua registrado no extrato).
  List<UnlockedEntry> unlockedHistory(String rgm) {
    final seen = <String>{};
    final result = <UnlockedEntry>[];

    for (final t in _db.getTransactionsByUser(rgm)) {
      if (!t.isUnlockPurchase) continue;
      final id = t.videoId;
      if (id == null || !seen.add(id)) continue;
      final video = _db.getVideoById(id);
      if (video == null) continue;
      result
          .add(UnlockedEntry(video: video, paid: t.amount, date: t.createdAt));
    }
    return result;
  }

  // ---------- Rendimento dos vídeos do autor (sempre "até agora") ----------
  /// Do vídeo que mais rendeu para o que menos rendeu.
  List<VideoEarning> videoEarnings(String rgm) {
    final balance = _db.getUserByRgm(rgm)?.credits ?? 0;
    final result = <VideoEarning>[];

    for (final video in _db.getVideosByAuthor(rgm)) {
      var earned = 0;
      var buyers = 0;
      var refundable = 0;

      for (final t in _db.getTransactionsByVideo(video.id)) {
        if (t.type == CreditTransactionType.unlockEarning && t.userRgm == rgm) {
          earned += t.amount;
          buyers++;
        } else if (t.type == CreditTransactionType.unlockSpend) {
          refundable += t.amount; // seria devolvido (100%) na exclusão
        }
      }

      result.add(VideoEarning(
        video: video,
        earned: earned,
        buyers: buyers,
        refundOnDelete: refundable,
        // Piso de 0: o autor nunca perde mais do que o saldo que possui.
        penaltyOnDelete: earned > balance ? balance : earned,
      ));
    }

    result.sort((a, b) => b.earned.compareTo(a.earned));
    return result;
  }
}

// lib/screens/profile_screen.dart
//
// Aba "Perfil": dados do aluno, foto editável, nível e XP, sequência de
// dias, resumo da semana e Missões Diárias (no fundo da página).
// Toda a parte de progressão é privada: só o dono da conta vê.
//
// Esta tela só DESENHA e chama o MissionService (resgate de XP). Os níveis
// são SIMBÓLICOS: nada aqui altera créditos, preços ou acessos.
//
// Foto: todo usuário novo começa sem foto (silhueta universal). O ícone de
// câmera no canto da foto abre o seletor de imagens (JPG/PNG, até 2 MB).
// A foto fica só em memória (futuramente, no banco de dados).

import '../widgets/app_notice.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/mock_database.dart';
import '../models/user_model.dart';
import '../services/mission_service.dart';
import '../services/progression_service.dart';
import '../theme/app_theme.dart';
import '../utils/media_picker.dart';
import '../widgets/level_medal.dart';
import '../widgets/streak_chain.dart';

// =======================================================================
// AUXILIARES
// =======================================================================

String _days(int n) => n == 1 ? '1 dia' : '$n dias';

// =======================================================================
// TELA
// =======================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _weekLetters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  final MockDatabase _db = MockDatabase.instance;
  final MissionService _missions = MissionService.instance;

  // =====================================================================
  // AÇÕES
  // =====================================================================

  /// Troca a foto de perfil usando o mesmo seletor de imagens do Publicador.
  Future<void> _changePhoto() async {
    final user = _db.currentUser;
    if (user == null) return;

    PickedMedia? picked;
    try {
      picked = await MediaPicker.pickImage();
    } on MediaPickException catch (e) {
      if (mounted) showAppNotice(context, e.message);
      return;
    } catch (e) {
      debugPrint('Falha ao escolher a foto de perfil: $e');
      if (mounted)
        showAppNotice(context, 'Não foi possível abrir esta imagem.');
      return;
    }
    if (picked == null || !mounted) return; // o usuário cancelou

    final old = user.photoPath;
    _db.updateUser(user.copyWith(photoPath: picked.source));
    MediaPicker.release(old); // libera a foto anterior da memória
    showAppNotice(context, 'Foto atualizada!', error: false);
  }

  Future<void> _editBio() async {
    final user = _db.currentUser;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BioDialog(initial: user.bio ?? ''),
    );
    if (result == null) return;

    _db.updateUser(
      result.isEmpty
          ? user.copyWith(clearBio: true)
          : user.copyWith(bio: result),
    );
  }

  /// Resgata o XP de uma missão (só vale no mesmo dia da missão).
  void _claim(MissionStatus mission) {
    final user = _db.currentUser;
    if (user == null) return;

    final result = _missions.claim(user.rgm, mission.kind);
    if (!result.success) {
      showAppNotice(context, result.message);
      return;
    }

    var message = result.message;
    final tier = result.newTier;
    if (tier != null) message += ' Nova medalha: ${tier.label}!';
    showAppNotice(context, message,
        error: false, duration: const Duration(seconds: 3));
  }

  // =====================================================================
  // INTERFACE
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Perfil'),
      ),
      // Reconstrói sempre que o banco avisa uma mudança (curtida, compra...).
      body: AnimatedBuilder(
        animation: _db,
        builder: (context, _) {
          final user = _db.currentUser;
          if (user == null) return const SizedBox.shrink();
          final rgm = user.rgm;

          final level = _missions.levelInfo(rgm);
          final streak = _missions.streak(rgm);
          final week = _missions.weekSummary(rgm);
          final daily = _missions.todaysMissions(rgm);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildHeader(user),
              const SizedBox(height: 28),
              _sectionTitle('Nível e experiência'),
              _buildLevel(level),
              const SizedBox(height: 28),
              _sectionTitle('Sequência de dias'),
              _buildStreak(streak, week),
              const SizedBox(height: 28),
              // Missões Diárias: no fundo da página (privadas).
              _sectionTitle(
                'Missões Diárias',
                subtitle:
                    'Só você vê. O XP precisa ser resgatado no mesmo dia.',
              ),
              _buildMissions(daily),
              const SizedBox(height: 32),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _db.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Blocos reutilizáveis ----------
  Widget _sectionTitle(String text, {String? subtitle}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _block({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.fromBorderSide(AppTheme.thinBlack),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  /// Barra de proporção (0 a 1) sobre um trilho cinza claro.
  Widget _bar(double fraction, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        color: AppTheme.grayLight,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
          child: Container(color: color),
        ),
      ),
    );
  }

  // ---------- Cabeçalho: foto, dados e biografia ----------
  Widget _buildHeader(UserModel user) {
    final theme = Theme.of(context);
    final bio = (user.bio ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(
                photoPath: user.photoPath, size: 96, onChange: _changePhoto),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('RGM ${user.rgm}', style: theme.textTheme.bodySmall),
                  Text(
                    '${user.course} • ${user.semester}º semestre',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _principalPill(user.principalCount),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _editBio,
          highlightColor: AppTheme.yellowSoft,
          splashColor: AppTheme.yellowSoft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bio.isEmpty ? 'Adicione uma biografia' : bio,
                    style: bio.isEmpty
                        ? theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic)
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Selo "Principal": chama + quantidade de vezes no Top 20.
  Widget _principalPill(int count) {
    return Tooltip(
      message: 'Vezes em que seus vídeos figuraram no Top 20',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.fromBorderSide(AppTheme.thinBlack),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department,
                size: 18, color: AppTheme.yellow),
            const SizedBox(width: 4),
            const Text('Principal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('$count',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ---------- Nível, medalha e barra de XP ----------
  Widget _buildLevel(LevelInfo info) {
    final theme = Theme.of(context);

    return _block(
      child: Row(
        children: [
          LevelMedal.forLevel(level: info.level, size: 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nível ${info.level}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('Medalha ${info.tier.label}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                _bar(info.progress, AppTheme.blue),
                const SizedBox(height: 6),
                Text(
                  info.isMax
                      ? 'Nível máximo! ${info.totalXp} XP no total.'
                      : '${info.xpIntoLevel} / ${info.xpForNext} XP • '
                          'faltam ${info.xpMissing} para o nível '
                          '${info.level + 1}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Sequência de dias e resumo da semana ----------
  Widget _buildStreak(StreakInfo streak, WeekSummary week) {
    final theme = Theme.of(context);

    final String message;
    switch (streak.state) {
      case StreakState.active:
        message = streak.claimedToday
            ? 'Sequência de ${_days(streak.count)}. Hoje já contou!'
            : 'Sequência de ${_days(streak.count)}. Resgate uma missão hoje '
                'para mantê-la.';
        break;
      case StreakState.broken:
        message = 'Sua sequência de ${_days(streak.count)} foi quebrada. '
            'A corrente volta amanhã.';
        break;
      case StreakState.none:
        message = 'Sem sequência no momento. Resgate uma missão hoje para '
            'começar.';
        break;
    }

    return _block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreakChain.fromInfo(streak, size: 72),
              const SizedBox(width: 16),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
            ],
          ),
          const Divider(height: 28),
          Text(
            'Esta semana: você resgatou ${week.claimedCount} de 7 dias',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in week.days) _weekDay(day)],
          ),
        ],
      ),
    );
  }

  Widget _weekDay(WeekDayInfo day) {
    final Color borderColor = day.isToday
        ? AppTheme.black
        : (day.isFuture ? AppTheme.grayLight : AppTheme.gray);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: day.claimed ? AppTheme.blue : AppTheme.white,
            border: Border.all(color: borderColor, width: day.isToday ? 2 : 1),
          ),
          child: day.claimed
              ? const Icon(Icons.check, size: 18, color: AppTheme.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          _weekLetters[day.date.weekday - 1],
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: day.isToday ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  // ---------- Missões diárias ----------
  Widget _buildMissions(DailyMissions daily) {
    final theme = Theme.of(context);

    final summary = daily.claimableXp > 0
        ? 'Hoje: ${daily.claimedXp} de ${daily.possibleXp} XP resgatados • '
            '${daily.claimableXp} XP prontos para resgatar'
        : 'Hoje: ${daily.claimedXp} de ${daily.possibleXp} XP resgatados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final mission in daily.missions) ...[
          _missionCard(mission),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  IconData _iconOf(MissionKind kind) {
    switch (kind) {
      case MissionKind.like:
        return Icons.favorite_border;
      case MissionKind.comment:
        return Icons.chat_bubble_outline;
      case MissionKind.unlock:
        return Icons.lock_open;
      case MissionKind.rate:
        return Icons.star_border;
      case MissionKind.post:
        return Icons.upload_outlined;
    }
  }

  Widget _xpChip(int xp, {required bool dim}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dim ? AppTheme.grayLight : AppTheme.blue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$xp XP',
        style: TextStyle(
          color: dim ? AppTheme.gray : AppTheme.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _missionCard(MissionStatus mission) {
    final theme = Theme.of(context);
    final unavailable = mission.unavailable;
    final textColor = unavailable ? AppTheme.gray : AppTheme.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.fromBorderSide(AppTheme.thinBlack),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconOf(mission.kind), size: 22, color: textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(mission.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _xpChip(mission.xp, dim: unavailable || mission.claimed),
            ],
          ),
          const SizedBox(height: 10),
          if (unavailable) ...[
            // Missão impossível hoje: sem XP e sem penalidade.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppTheme.gray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${mission.unavailableReason} '
                    'Missão pulada hoje: sem XP e sem penalidade.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _bar(mission.fraction, AppTheme.blue)),
                const SizedBox(width: 10),
                Text('${mission.progress}/${mission.target}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            if (mission.adjusted) ...[
              const SizedBox(height: 6),
              Text(
                'Meta ajustada aos vídeos que você tem disponíveis.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (mission.claimed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 20, color: AppTheme.blue),
                  const SizedBox(width: 6),
                  Text('XP resgatado',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ] else if (mission.canClaim) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _claim(mission),
                  child: Text('Resgatar +${mission.xp} XP'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// =======================================================================
// FOTO DE PERFIL
// =======================================================================

/// Foto redonda: silhueta universal quando não há foto, com um pequeno
/// ícone de câmera no canto para trocar a imagem.
class _Avatar extends StatelessWidget {
  final String? photoPath;
  final double size;
  final VoidCallback onChange;

  const _Avatar({
    Key? key,
    required this.photoPath,
    required this.size,
    required this.onChange,
  }) : super(key: key);

  bool get _isRemote =>
      photoPath != null &&
      (photoPath!.startsWith('http') || photoPath!.startsWith('blob:'));

  // Arquivo local do celular (foto escolhida no APK).
  bool get _isLocalFile => !kIsWeb && photoPath != null && !_isRemote;

  /// Perfil padrão universal: silhueta de pessoa sobre cinza claro.
  Widget _defaultImage() {
    return Container(
      color: AppTheme.grayLight,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: size * 0.62, color: AppTheme.gray),
    );
  }

  Widget _image() {
    if (_isRemote) {
      return SizedBox.expand(
        child: Image.network(
          photoPath!,
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Foto de perfil falhou: $photoPath -> $error');
            return _defaultImage();
          },
        ),
      );
    }
    if (_isLocalFile) {
      return SizedBox.expand(
        child: Image.file(
          File(photoPath!),
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Foto de perfil falhou: $photoPath -> $error');
            return _defaultImage();
          },
        ),
      );
    }
    return _defaultImage();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foto de perfil',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(AppTheme.thinBlack),
                ),
                child: ClipOval(child: _image()),
              ),
            ),
            // Ícone pequeno de trocar foto (sem botão ocupando espaço).
            Positioned(
              right: 0,
              bottom: 0,
              child: Tooltip(
                message: 'Trocar foto',
                child: Material(
                  color: AppTheme.grayLight,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppTheme.white, width: 2),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    highlightColor: AppTheme.yellowSoft,
                    splashColor: AppTheme.yellowSoft,
                    onTap: onChange,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 18, color: AppTheme.gray),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// POP-UP DA BIOGRAFIA
// =======================================================================

class _BioDialog extends StatefulWidget {
  final String initial;
  const _BioDialog({Key? key, required this.initial}) : super(key: key);

  @override
  State<_BioDialog> createState() => _BioDialogState();
}

class _BioDialogState extends State<_BioDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: AppTheme.thinBlack,
      ),
      title: const Text('Biografia'),
      content: TextField(
        controller: _controller,
        maxLength: 160,
        minLines: 2,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Conte um pouco sobre você (opcional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

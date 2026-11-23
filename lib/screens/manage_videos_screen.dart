// lib/screens/manage_videos_screen.dart
//
// Tela "Gerenciar Vídeos" do Publicador.
//   - Lista os vídeos do aluno com visualizações, curtidas e média das
//     avaliações.
//   - Editar: título, descrição e tópico principal. Custa 10 créditos (que
//     saem de circulação) e SÓ é cobrado se algum campo realmente mudar.
//   - Excluir: justificativa obrigatória. Compradores recebem 100% de volta
//     e o autor perde 100% do que ganhou com o vídeo (piso de 0).
//
// Esta tela só DESENHA e chama o CreditService: nenhuma conta de créditos
// é feita aqui.

import 'package:flutter/material.dart';
import '../widgets/app_dialog.dart';
import '../data/mock_database.dart';
import '../models/credit_transaction_model.dart';
import '../models/video_model.dart';
import '../services/credit_service.dart';
import '../services/metrics_service.dart';
import '../theme/app_theme.dart';
import '../utils/media_picker.dart';
import '../widgets/video_thumbnail.dart';
import 'watch_screen.dart';
import '../widgets/app_notice.dart';

/// Tamanho mínimo da justificativa de exclusão.
const int _minJustification = 10;

// =======================================================================
// AUXILIARES
// =======================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDay(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _compact(int n) {
  if (n < 1000) return '$n';
  return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
}

/// Aviso de erro: X vermelho com a mensagem.
Widget _errorLine(BuildContext context, String message) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.close_rounded, size: 20, color: AppTheme.red),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.red),
          ),
        ),
      ],
    ),
  );
}

// =======================================================================
// TELA
// =======================================================================

class ManageVideosScreen extends StatelessWidget {
  const ManageVideosScreen({Key? key}) : super(key: key);

  // ---------- Editar ----------
  Future<void> _edit(BuildContext context, VideoModel video) async {
    final db = MockDatabase.instance;
    final user = db.currentUser;
    if (user == null) return;

    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditDialog(video: video, balance: user.credits),
    );
    if (result == null || !context.mounted) return;

    // O CreditService confere se algo mudou e cobra os 10 créditos.
    final outcome = CreditService.instance.editVideoMetadata(
      videoId: video.id,
      authorRgm: user.rgm,
      title: result.title,
      description: result.description,
      mainTopic: result.topic,
    );
    showAppNotice(
      context,
      outcome.message,
      error: !outcome.isSuccess,
      duration: const Duration(seconds: 3),
    );
  }

  // ---------- Excluir ----------
  Future<void> _delete(BuildContext context, VideoModel video) async {
    final db = MockDatabase.instance;
    final user = db.currentUser;
    if (user == null) return;

    // Prévia do que a exclusão causaria (mesmo cálculo das Métricas).
    VideoEarning? earning;
    for (final item in MetricsService.instance.videoEarnings(user.rgm)) {
      if (item.video.id == video.id) earning = item;
    }

    final justification = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteDialog(video: video, earning: earning),
    );
    if (justification == null || !context.mounted) return;

    // Guarda os endereços antes de excluir, para liberar a memória depois.
    final videoSource = video.videoPath;
    final coverSource = video.thumbnailPath;

    final outcome = CreditService.instance.deleteVideo(
      videoId: video.id,
      authorRgm: user.rgm,
      justification: justification,
    );
    if (outcome.isSuccess) {
      MediaPicker.release(videoSource);
      MediaPicker.release(coverSource);
    }
    if (!context.mounted) return;
    showAppNotice(
      context,
      outcome.message,
      error: !outcome.isSuccess,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = MockDatabase.instance;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar vídeos')),
      // Reconstrói sempre que o banco avisa uma mudança.
      body: AnimatedBuilder(
        animation: db,
        builder: (context, _) {
          final user = db.currentUser;
          if (user == null) return const SizedBox.shrink();
          final videos = db.getVideosByAuthor(user.rgm);

          if (videos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Você ainda não publicou vídeos.\n'
                  'Use "Enviar Vídeo" para publicar o primeiro.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.gray),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Cada edição custa '
                '${CreditTransactionModel.editFeeCredits} créditos, que saem '
                'de circulação, e só é cobrada se algum campo mudar. '
                'A exclusão exige justificativa.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final video in videos) ...[
                _ManagedVideoCard(
                  video: video,
                  onWatch: () => WatchScreen.open(context, video),
                  onEdit: () => _edit(context, video),
                  onDelete: () => _delete(context, video),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

// =======================================================================
// CARD DE UM VÍDEO
// =======================================================================

class _ManagedVideoCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onWatch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManagedVideoCard({
    Key? key,
    required this.video,
    required this.onWatch,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = MockDatabase.instance;
    final average = db.averageRating(video.id);
    final ratingCount = db.getRatings(video.id).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.fromBorderSide(AppTheme.thinBlack),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Miniatura + título e dados (toque para assistir sem cobrança)
          InkWell(
            onTap: onWatch,
            highlightColor: AppTheme.yellowSoft,
            splashColor: AppTheme.yellowSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: VideoThumbnail(
                        compact: true,
                        imageUrl: video.thumbnailPath,
                        durationText: video.formattedDuration,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.mainTopic} • ${_formatDay(video.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Métricas individuais: visualizações, curtidas e avaliações
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _metric(context, Icons.visibility_outlined, AppTheme.gray,
                  _compact(video.views)),
              _metric(context, Icons.favorite_border, AppTheme.red,
                  _compact(video.likes)),
              _metric(
                context,
                Icons.star,
                AppTheme.yellow,
                average == null
                    ? 'Sem avaliações'
                    : '${average.toStringAsFixed(1).replaceAll('.', ',')} '
                        '($ratingCount)',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ações
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  side: const BorderSide(color: AppTheme.red),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
      BuildContext context, IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// =======================================================================
// POP-UP DE EDIÇÃO
// =======================================================================

class _EditResult {
  final String title;
  final String description;
  final String topic;
  const _EditResult(this.title, this.description, this.topic);
}

class _EditDialog extends StatefulWidget {
  final VideoModel video;
  final int balance;

  const _EditDialog({Key? key, required this.video, required this.balance})
      : super(key: key);

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.video.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.video.description);
  late String _topic = widget.video.mainTopic;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // Algum campo realmente mudou? (só então a edição é cobrada)
  bool get _changed =>
      _title.text.trim() != widget.video.title ||
      _description.text.trim() != widget.video.description ||
      _topic != widget.video.mainTopic;

  bool get _valid =>
      _title.text.trim().isNotEmpty && _description.text.trim().isNotEmpty;

  bool get _enough => widget.balance >= CreditTransactionModel.editFeeCredits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fee = CreditTransactionModel.editFeeCredits;
    final topics = [
      ...MockDatabase.topics,
      if (!MockDatabase.topics.contains(_topic)) _topic,
    ];

    return AppDialog(
      icon: Icons.edit_outlined,
      title: 'Editar vídeo',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Tópico principal'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: _topic,
                  items: [
                    for (final topic in topics)
                      DropdownMenuItem<String>(
                          value: topic, child: Text(topic)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _topic = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Custo da edição, mostrado ANTES de salvar.
            Text(
              _changed
                  ? 'Custo desta edição: $fee créditos (saem de circulação).'
                  : 'Nenhuma alteração: sem custo.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text('Seu saldo: ${widget.balance} créditos',
                style: theme.textTheme.bodySmall),
            if (_changed && !_enough)
              _errorLine(
                  context, 'Saldo insuficiente: a edição custa $fee créditos.'),
            if (!_valid)
              _errorLine(context, 'Título e descrição são obrigatórios.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_changed && _valid && _enough)
              ? () => Navigator.of(context).pop(_EditResult(
                    _title.text.trim(),
                    _description.text.trim(),
                    _topic,
                  ))
              : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// =======================================================================
// POP-UP DE EXCLUSÃO
// =======================================================================

class _DeleteDialog extends StatefulWidget {
  final VideoModel video;
  final VideoEarning? earning;

  const _DeleteDialog({Key? key, required this.video, required this.earning})
      : super(key: key);

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final TextEditingController _justification = TextEditingController();

  @override
  void dispose() {
    _justification.dispose();
    super.dispose();
  }

  bool get _ok => _justification.text.trim().length >= _minJustification;

  /// Linhas que explicam o que a exclusão causa em créditos.
  List<String> _consequences() {
    final earning = widget.earning;
    final lines = <String>[];

    if (earning == null || earning.earned == 0) {
      lines.add('Nenhum aluno comprou este vídeo: a exclusão não tem custo '
          'em créditos.');
    } else {
      lines.add('${earning.buyers} '
          '${earning.buyers == 1 ? 'aluno receberá' : 'alunos receberão'} '
          '${earning.refundOnDelete} créditos de volta (100%).');
      lines.add('Você perderá ${earning.penaltyOnDelete} créditos '
          '(100% do que ganhou com este vídeo).');
      if (earning.penaltyOnDelete < earning.earned) {
        lines.add('O seu saldo é menor que esse valor: a perda é limitada ao '
            'saldo e ele ficará em 0.');
      }
    }
    lines.add('Comentários, avaliações e curtidas também serão removidos.');
    lines.add('Esta ação não pode ser desfeita.');
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialog(
      icon: Icons.delete_outline,
      title: 'Excluir vídeo?',
      danger: true,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.video.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Aviso importante: ícone de atenção em vermelho.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.red),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.red, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in _consequences())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(line, style: theme.textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _justification,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Justificativa (obrigatória)',
              ),
            ),
            if (!_ok)
              Text(
                'Escreva pelo menos $_minJustification caracteres.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _ok
              ? () => Navigator.of(context).pop(_justification.text.trim())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.red,
            foregroundColor: AppTheme.white,
          ),
          child: const Text('Excluir'),
        ),
      ],
    );
  }
}

// lib/screens/watch_screen.dart
//
// Tela do vídeo: pop-up de desbloqueio, player real e interações.
//
// ENTRADA ÚNICA: use WatchScreen.open(context, video) em qualquer tela.
//   - Vídeo do próprio autor ou já desbloqueado: abre direto (sem cobrar).
//   - Caso contrário: mostra o pop-up "Quer realmente desbloquear este
//     vídeo?". Só depois do "Sim!" o credit_service executa a compra.
//     Cancelar ou fechar o pop-up = nenhuma compra + aviso de 1,2 s.
//
// Regras desta tela:
//   - Visualização: conta 1 quando o player começa (só não-autor).
//   - Curtir: coração oco vermelho que fica cheio; tocar de novo remove.
//   - Comentários e Avaliações: duas seções que trocam de lugar.
//   - Avaliação: 1 a 5 estrelas + texto OPCIONAL; uma por aluno por vídeo;
//     o autor não avalia o próprio vídeo.
//   - Denúncia: pop-up com motivos; o conteúdo NÃO é enviado a lugar nenhum.
//
// FUTURO: comentários, avaliações e curtidas passarão a ser gravados no
// banco de dados online (a troca acontece só no mock_database.dart).
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../data/mock_database.dart';
import '../models/video_feedback_model.dart';
import '../models/video_model.dart';
import '../services/credit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';
import '../widgets/app_notice.dart';

// =======================================================================
// AUXILIARES
// =======================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDay(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _formatDateTime(DateTime d) =>
    '${_formatDay(d)} ${_two(d.hour)}:${_two(d.minute)}';

/// Duração no formato m:ss.
String _formatClock(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${_two(seconds)}';
}

/// 950 -> "950" | 1200 -> "1,2 mil"
String _compact(int n) {
  if (n < 1000) return '$n';
  return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
}

/// Linha de 5 estrelas: as preenchidas em amarelo, as demais em cinza.
Widget _starRow(int filled, {double size = 18}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= RatingModel.maxStars; i++)
        Icon(
          i <= filled ? Icons.star : Icons.star_border,
          size: size,
          color: i <= filled ? AppTheme.yellow : AppTheme.gray,
        ),
    ],
  );
}

// =======================================================================
// TELA DO VÍDEO
// =======================================================================

class WatchScreen extends StatefulWidget {
  final String videoId;

  const WatchScreen({Key? key, required this.videoId}) : super(key: key);

  /// ENTRADA ÚNICA para abrir um vídeo (decide se precisa comprar).
  static Future<void> open(BuildContext context, VideoModel video) async {
    final db = MockDatabase.instance;
    final user = db.currentUser;
    if (user == null) return;

    // Autor e vídeos já desbloqueados abrem direto, sem cobrança.
    final hasAccess =
        video.isOwnedBy(user.rgm) || db.hasUnlocked(user.rgm, video.id);

    if (!hasAccess) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _UnlockDialog(video: video, balance: user.credits),
      );

      // Cancelar, fechar o pop-up ou voltar = nenhuma compra.
      if (confirmed != true) {
        if (context.mounted) {
          showAppNotice(context, 'Compra não realizada'); // 1,2 s
        }
        return;
      }

      // A compra só acontece aqui, depois do "Sim!".
      final result = CreditService.instance.unlockVideo(
        videoId: video.id,
        buyerRgm: user.rgm,
      );
      if (!context.mounted) return;
      if (!result.canWatch) {
        showAppNotice(context, result.message);
        return;
      }
      showAppNotice(context, result.message,
          error: false, duration: const Duration(seconds: 2));
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WatchScreen(videoId: video.id)),
    );
  }

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final MockDatabase _db = MockDatabase.instance;
  final TextEditingController _commentController = TextEditingController();

  VideoPlayerController? _controller;
  bool _playerFailed = false;
  bool _viewCounted = false; // 1 visualização por abertura da tela
  bool _showRatings = false; // seção ativa: comentários (padrão) ou avaliações

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ---------- Acesso ----------
  /// Só vê o vídeo quem é o autor ou já o desbloqueou.
  bool get _hasAccess {
    final user = _db.currentUser;
    final video = _db.getVideoById(widget.videoId);
    if (user == null || video == null) return false;
    return video.isOwnedBy(user.rgm) || _db.hasUnlocked(user.rgm, video.id);
  }

  // ---------- Player ----------
  void _setupPlayer() {
    final video = _db.getVideoById(widget.videoId);
    if (video == null || !_hasAccess) return;

    final path = video.videoPath;
    if (path == null || path.isEmpty) {
      _playerFailed = true;
      return;
    }

    // Aceita: endereço de internet, endereço temporário do navegador (blob:)
    // e arquivo local do celular (vídeo enviado pelo Publicador no APK).
    final bool isRemote = path.startsWith('http') || path.startsWith('blob:');
    if (!isRemote && kIsWeb) {
      _playerFailed = true; // caminho de arquivo não existe no navegador
      return;
    }
    final VideoPlayerController controller = isRemote
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.file(File(path));

    _controller = controller;
    controller.addListener(_onPlayerUpdate);
    controller.initialize().then((_) {
      if (!mounted) return;
      _checkDuration(video, controller);
      setState(() {});
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _playerFailed = true);
    });
  }

  /// Confere se a duração real bate com a do banco (o preço depende dela).
  void _checkDuration(VideoModel video, VideoPlayerController controller) {
    final realSeconds = controller.value.duration.inSeconds;
    var realMinutes = realSeconds ~/ 60;
    if (realMinutes < VideoModel.minBillableMinutes) {
      realMinutes = VideoModel.minBillableMinutes;
    }
    if (realMinutes != video.billableMinutes) {
      debugPrint('ATENÇÃO (UniTime): "${video.title}" tem $realSeconds s '
          'reais ($realMinutes min cobráveis), mas o banco registra '
          '${video.durationSeconds} s (${video.billableMinutes} min). '
          'Ajuste durationSeconds no mock_database.dart.');
    }
  }

  void _onPlayerUpdate() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    if (value.hasError && !_playerFailed) _playerFailed = true;

    // Visualização: só com o vídeo desbloqueado, quando o player começa,
    // e nunca para o próprio autor.
    if (!_viewCounted && value.isPlaying && _canCountViews) {
      _viewCounted = true;
      _db.registerView(widget.videoId);
    }

    if (mounted) setState(() {}); // atualiza barra de progresso e tempo
  }

  bool get _canCountViews {
    final user = _db.currentUser;
    final video = _db.getVideoById(widget.videoId);
    if (user == null || video == null) return false;
    return !video.isOwnedBy(user.rgm) && _hasAccess;
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
      return;
    }
    final value = controller.value;
    final atEnd =
        value.duration > Duration.zero && value.position >= value.duration;
    if (atEnd) controller.seekTo(Duration.zero); // recomeça do início
    controller.play();
  }

  // ---------- Interações ----------
  void _toggleLike(VideoModel video, String rgm) {
    _db.toggleLike(rgm, video.id);
  }

  void _sendComment() {
    final user = _db.currentUser;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty) return;

    _db.addComment(CommentModel(
      id: _db.nextFeedbackId(),
      videoId: widget.videoId,
      authorRgm: user.rgm,
      authorName: user.fullName,
      text: text,
      createdAt: DateTime.now(),
    ));
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _openRatingDialog(VideoModel video) async {
    final user = _db.currentUser;
    if (user == null) return;

    // Se o aluno já avaliou, o diálogo abre com a nota anterior.
    final existing = _db.getRatingBy(user.rgm, video.id);
    final result = await showDialog<_RatingResult>(
      context: context,
      builder: (_) => _RatingDialog(
        initialStars: existing?.stars ?? 0,
        initialText: existing?.text ?? '',
      ),
    );
    if (result == null || !mounted) return;

    // Uma avaliação por aluno em cada vídeo: a nova substitui a antiga.
    _db.saveRating(RatingModel(
      id: _db.nextFeedbackId(),
      videoId: video.id,
      authorRgm: user.rgm,
      authorName: user.fullName,
      stars: result.stars,
      text: result.text, // nulo quando o aluno enviou só as estrelas
      createdAt: DateTime.now(),
    ));
    setState(() => _showRatings = true); // mostra a avaliação enviada
    showAppNotice(context, 'Avaliação enviada!',
        error: false, duration: const Duration(seconds: 2));
  }

  Future<void> _openReportDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (sent != true || !mounted) return;

    // ATENÇÃO: por enquanto o conteúdo da denúncia NÃO é guardado nem
    // enviado a lugar nenhum (será ligado ao banco online no futuro).
    showAppNotice(context, 'Obrigado! Sua denúncia foi recebida.',
        error: false, duration: const Duration(seconds: 2));
  }

  // =====================================================================
  // INTERFACE
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    // Reconstrói quando o banco muda (curtida, comentário, avaliação...).
    return AnimatedBuilder(
      animation: _db,
      builder: (context, _) {
        final video = _db.getVideoById(widget.videoId);
        final user = _db.currentUser;

        if (video == null || user == null) {
          return _messageScaffold('Este vídeo não está mais disponível.');
        }
        if (!_hasAccess) {
          return _messageScaffold('Vídeo bloqueado. Desbloqueie-o na Home.');
        }

        final comments = _db.getComments(video.id);
        final ratings = _db.getRatings(video.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildPlayer(video),
              _buildInfo(video, user.rgm),
              _buildSectionTabs(comments.length, ratings.length),
              if (_showRatings)
                _buildRatings(video, ratings)
              else
                _buildComments(comments),
            ],
          ),
        );
      },
    );
  }

  Widget _messageScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vídeo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.gray),
          ),
        ),
      ),
    );
  }

  // ---------- Player ----------
  Widget _buildPlayer(VideoModel video) {
    final controller = _controller;
    final ready =
        controller != null && controller.value.isInitialized && !_playerFailed;

    var aspect = 16 / 9;
    if (ready && controller.value.aspectRatio > 0) {
      aspect = controller.value.aspectRatio;
    }

    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        color: AppTheme.black,
        child: ready ? _playerLayers(controller) : _playerPlaceholder(),
      ),
    );
  }

  /// Espaço reservado: carregando ou falha (azul com a estrela).
  Widget _playerPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppTheme.blue),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UniStar(size: 44),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _playerFailed
                      ? 'Não foi possível carregar o vídeo. '
                          'Verifique a conexão com a internet.'
                      : 'Carregando vídeo...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playerLayers(VideoPlayerController controller) {
    final value = controller.value;
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(controller),

        // Toque em qualquer ponto: play / pause.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: Center(
            child: value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: AppTheme.white, size: 40),
                  ),
          ),
        ),

        // Barra de progresso (arrastável) e tempos.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: const Color(0x99000000),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: VideoProgressColors(
                    playedColor: AppTheme.yellow,
                    bufferedColor: const Color(0x66FFFFFF),
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatClock(value.position),
                        style: const TextStyle(
                            color: AppTheme.white, fontSize: 12)),
                    Text(_formatClock(value.duration),
                        style: const TextStyle(
                            color: AppTheme.white, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Informações e ações ----------
  Widget _buildInfo(VideoModel video, String myRgm) {
    final theme = Theme.of(context);
    final isOwner = video.isOwnedBy(myRgm);
    final liked = _db.hasLiked(myRgm, video.id);
    final myRating = _db.getRatingBy(myRgm, video.id);
    final authorName = isOwner
        ? 'você'
        : (_db.getUserByRgm(video.authorRgm)?.fullName ?? 'autor desconhecido');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Por $authorName • ${_formatDay(video.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(video.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Curtir: coração oco vermelho que fica cheio.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: liked ? 'Remover curtida' : 'Curtir',
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: AppTheme.red,
                    ),
                    onPressed: () => _toggleLike(video, myRgm),
                  ),
                  Text(_compact(video.likes), style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(width: 8),
              // Visualizações (cinza).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 18, color: AppTheme.gray),
                  const SizedBox(width: 4),
                  Text(_compact(video.views), style: theme.textTheme.bodySmall),
                ],
              ),
              // O autor não avalia nem denuncia o próprio vídeo.
              if (!isOwner)
                TextButton.icon(
                  onPressed: () => _openRatingDialog(video),
                  icon: const Icon(Icons.star_outline),
                  label:
                      Text(myRating == null ? 'Avaliar' : 'Editar avaliação'),
                ),
              if (!isOwner)
                IconButton(
                  tooltip: 'Denunciar',
                  icon: const Icon(Icons.flag_outlined, color: AppTheme.black),
                  onPressed: _openReportDialog,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Abas: Comentários / Avaliações ----------
  Widget _buildSectionTabs(int commentCount, int ratingCount) {
    return Row(
      children: [
        Expanded(
          child: _sectionTab(
            'Comentários ($commentCount)',
            !_showRatings,
            () => setState(() => _showRatings = false),
          ),
        ),
        Expanded(
          child: _sectionTab(
            'Avaliações ($ratingCount)',
            _showRatings,
            () => setState(() => _showRatings = true),
          ),
        ),
      ],
    );
  }

  Widget _sectionTab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      highlightColor: AppTheme.yellowSoft,
      splashColor: AppTheme.yellowSoft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.yellow,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppTheme.black : AppTheme.gray,
          ),
        ),
      ),
    );
  }

  // ---------- Seção de comentários ----------
  Widget _buildComments(List<CommentModel> comments) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLength: CommentModel.maxLength,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Escreva um comentário...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Enviar comentário',
                icon: const Icon(Icons.send, color: AppTheme.blue),
                onPressed: _sendComment,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            Text(
              'Ainda não há comentários. Seja o primeiro!',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final comment in comments) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          comment.authorName,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(_formatDateTime(comment.createdAt),
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(comment.text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ---------- Seção de avaliações ----------
  Widget _buildRatings(VideoModel video, List<RatingModel> ratings) {
    final theme = Theme.of(context);
    final average = _db.averageRating(video.id);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (average == null)
            Text('Ainda não há avaliações.', style: theme.textTheme.bodySmall)
          else
            // Média das estrelas no topo da seção.
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  average.toStringAsFixed(1).replaceAll('.', ','),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('de 5', style: theme.textTheme.bodySmall),
                _starRow(average.round(), size: 22),
                Text(
                  '(${ratings.length} '
                  '${ratings.length == 1 ? 'avaliação' : 'avaliações'})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          for (final rating in ratings) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _starRow(rating.stars),
                  // Se houver texto, aparece abaixo das estrelas;
                  // se não, aparecem só as estrelas.
                  if (rating.hasText) ...[
                    const SizedBox(height: 4),
                    Text(rating.text!, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${rating.authorName} • '
                    '${_formatDateTime(rating.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =======================================================================
// POP-UP DE DESBLOQUEIO
// =======================================================================

class _UnlockDialog extends StatelessWidget {
  final VideoModel video;
  final int balance;

  const _UnlockDialog({Key? key, required this.video, required this.balance})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = video.creditCost;
    final enough = balance >= cost; // sem saldo suficiente: compra bloqueada

    return AlertDialog(
      backgroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: AppTheme.thinBlack,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.black,
      ),
      title: const Text('Quer realmente desbloquear este vídeo?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('Custo: $cost créditos', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text('Seu saldo: $balance créditos',
              style: theme.textTheme.bodySmall),
          if (!enough) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.close_rounded, size: 20, color: AppTheme.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Saldo insuficiente para este vídeo.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: enough ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Sim!'),
        ),
      ],
    );
  }
}

// =======================================================================
// POP-UP DE AVALIAÇÃO (estrelas + texto OPCIONAL)
// =======================================================================

class _RatingResult {
  final int stars;
  final String? text; // nulo quando o aluno enviou só as estrelas
  const _RatingResult(this.stars, this.text);
}

class _RatingDialog extends StatefulWidget {
  final int initialStars;
  final String initialText;

  const _RatingDialog({
    Key? key,
    required this.initialStars,
    required this.initialText,
  }) : super(key: key);

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late int _stars = widget.initialStars;
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context)
        .pop(_RatingResult(_stars, text.isEmpty ? null : text));
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
      title: const Text('Avaliar vídeo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toque nas estrelas para dar a sua nota.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= RatingModel.maxStars; i++)
                  IconButton(
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                    icon: Icon(
                      i <= _stars ? Icons.star : Icons.star_border,
                      color: i <= _stars ? AppTheme.yellow : AppTheme.gray,
                    ),
                    onPressed: () => setState(() => _stars = i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLength: RatingModel.maxTextLength,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Comentário opcional',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        // A nota (1 a 5) é obrigatória; o texto, não.
        ElevatedButton(
          onPressed: _stars >= RatingModel.minStars ? _submit : null,
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

// =======================================================================
// POP-UP DE DENÚNCIA (motivo em caixa de seleção + texto)
// =======================================================================

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({Key? key}) : super(key: key);

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const List<String> _reasons = [
    'Conteúdo ofensivo ou inadequado',
    'Spam ou propaganda enganosa',
    'Informação incorreta',
    'Violação de direitos autorais',
    'Vídeo diferente do título ou descrição',
    'Outro',
  ];

  String? _reason;
  final TextEditingController _controller = TextEditingController();

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
      title: const Text('Denunciar vídeo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qual é o motivo da denúncia?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // Caixa de seleção de motivos.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.fromBorderSide(AppTheme.thinBlack),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _reason,
                  hint: const Text('Selecione o motivo'),
                  items: [
                    for (final reason in _reasons)
                      DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _reason = value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Detalhes (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed:
              _reason == null ? null : () => Navigator.of(context).pop(true),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

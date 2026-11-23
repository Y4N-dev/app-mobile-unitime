// lib/screens/upload_video_screen.dart
//
// Tela "Enviar Vídeo" do Publicador.
//   1. Vídeo: escolhe o arquivo, lê a DURAÇÃO REAL e mostra o preço.
//   2. Capa (opcional): imagem escolhida pelo autor; sem capa, o app usa a
//      imagem padrão (a mesma do espaço reservado das thumbnails).
//   3. Informações: título, descrição breve, tópico principal (obrigatório)
//      e sub-tópico (opcional).
//
// Regras: vídeo de até ~15 min e 100 MB; capa de até 2 MB. Publicar é
// gratuito: os créditos vêm das compras (o autor recebe 100% de cada
// desbloqueio). O preço é calculado pelo VideoModel (10 créditos por minuto
// inteiro). Esta tela não mexe em créditos.
//
// FUTURO: com o banco de dados online, o envio gravará o vídeo e a capa no
// armazenamento online e guardará os endereços (URLs).

import 'dart:async';
import 'dart:io';
import '../widgets/app_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/mock_database.dart';
import '../models/video_model.dart';
import '../theme/app_theme.dart';
import '../utils/media_picker.dart';
import '../widgets/video_thumbnail.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final MockDatabase _db = MockDatabase.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subTopicController = TextEditingController();

  String? _topic;
  bool _topicError = false;

  // Vídeo
  PickedMedia? _video;
  int? _durationSeconds;
  bool _readingDuration = false;
  String? _videoError;
  int _videoToken = 0; // evita misturar leituras se o aluno trocar o vídeo

  // Capa (opcional)
  PickedMedia? _cover;
  String? _coverError;
  Size? _coverSize; // dimensões reais da capa escolhida (para o alerta)
  int _coverToken = 0; // evita misturar leituras se o aluno trocar a capa

  bool _published = false;

  @override
  void dispose() {
    // Se saiu sem publicar, libera a memória dos arquivos temporários.
    if (!_published) {
      MediaPicker.release(_video?.source);
      MediaPicker.release(_cover?.source);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _subTopicController.dispose();
    super.dispose();
  }

  // =====================================================================
  // VÍDEO
  // =====================================================================

  Future<void> _chooseVideo() async {
    PickedMedia? picked;
    try {
      picked = await MediaPicker.pickVideo();
    } on MediaPickException catch (e) {
      if (mounted) setState(() => _videoError = e.message);
      return;
    } catch (e) {
      debugPrint('Falha ao escolher o vídeo: $e');
      if (mounted) {
        setState(() => _videoError = 'Não foi possível abrir este arquivo.');
      }
      return;
    }
    if (picked == null || !mounted) return; // o usuário cancelou

    final media = picked;
    final old = _video;
    final token = ++_videoToken;
    setState(() {
      _video = media;
      _durationSeconds = null;
      _videoError = null;
      _readingDuration = true;
    });
    MediaPicker.release(old?.source);

    final seconds = await _readDurationSeconds(media.source);
    if (!mounted || token != _videoToken) return;

    if (seconds == null || seconds <= 0) {
      MediaPicker.release(media.source);
      setState(() {
        _video = null;
        _readingDuration = false;
        _videoError = 'Não foi possível ler este vídeo. Tente um arquivo mp4.';
      });
      return;
    }
    if (seconds > MediaLimits.maxVideoSeconds) {
      MediaPicker.release(media.source);
      setState(() {
        _video = null;
        _readingDuration = false;
        _videoError = 'Este vídeo tem ${_clock(seconds)}. '
            'O limite é ${MediaLimits.maxVideoSeconds ~/ 60} minutos.';
      });
      return;
    }

    setState(() {
      _durationSeconds = seconds;
      _readingDuration = false;
    });
  }

  /// Lê a duração REAL do arquivo (é ela que define o preço).
  Future<int?> _readDurationSeconds(String source) async {
    VideoPlayerController? controller;
    try {
      final isRemote = source.startsWith('blob:') || source.startsWith('http');
      controller = isRemote
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));
      await controller.initialize();
      return controller.value.duration.inSeconds;
    } catch (e) {
      debugPrint('Falha ao ler a duração do vídeo: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  // =====================================================================
  // CAPA (opcional)
  // =====================================================================

  Future<void> _chooseCover() async {
    PickedMedia? picked;
    try {
      picked = await MediaPicker.pickImage();
    } on MediaPickException catch (e) {
      if (mounted) setState(() => _coverError = e.message);
      return;
    } catch (e) {
      debugPrint('Falha ao escolher a capa: $e');
      if (mounted) {
        setState(() => _coverError = 'Não foi possível abrir esta imagem.');
      }
      return;
    }
    if (picked == null || !mounted) return;

    final media = picked;
    final old = _cover;
    final token = ++_coverToken;
    setState(() {
      _cover = media;
      _coverSize = null;
      _coverError = null;
    });
    MediaPicker.release(old?.source);

    // Lê as dimensões reais e atualiza o alerta (não bloqueia o envio).
    _readImageSize(media.source).then((size) {
      if (!mounted || token != _coverToken) return;
      setState(() => _coverSize = size);
    });
  }

  void _removeCover() {
    MediaPicker.release(_cover?.source);
    _coverToken++;
    setState(() {
      _cover = null;
      _coverSize = null;
      _coverError = null;
    });
  }

  /// Lê a largura e a altura reais da imagem (null se não conseguir).
  Future<Size?> _readImageSize(String source) {
    final completer = Completer<Size?>();
    final ImageProvider<Object> provider;
    if (source.startsWith('blob:') || source.startsWith('http')) {
      provider = NetworkImage(source);
    } else {
      provider = FileImage(File(source));
    }
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ));
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Alerta sobre tamanho e proporção da capa. NÃO recusa a imagem: só avisa.
  Widget? _coverAdvice() {
    final size = _coverSize;
    if (size == null) return null;

    final theme = Theme.of(context);
    final w = size.width.round();
    final h = size.height.round();
    final ratio = size.width / size.height;
    const target = 16 / 9;
    final sameRatio = (ratio - target).abs() / target <= 0.03;

    final warnings = <String>[];
    if (w < MediaLimits.minImageWidth || h < MediaLimits.minImageHeight) {
      warnings.add('Imagem pequena ($w×$h): pode ficar sem nitidez. O mínimo '
          'recomendado é ${MediaLimits.minImageWidth}×'
          '${MediaLimits.minImageHeight}.');
    }
    if (!sameRatio) {
      warnings.add(ratio > target
          ? 'Sua imagem ($w×$h) é mais larga que 16:9: as laterais serão '
              'cortadas e essa parte da imagem ficará de fora.'
          : 'Sua imagem ($w×$h) é mais alta que 16:9: o topo e a base serão '
              'cortados e essa parte da imagem ficará de fora.');
    }

    Widget line(IconData icon, Color color, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ],
        ),
      );
    }

    if (warnings.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in warnings)
            line(Icons.warning_amber_rounded, AppTheme.red, text),
        ],
      );
    }
    if (w > MediaLimits.recommendedImageWidth) {
      return line(
        Icons.info_outline,
        AppTheme.gray,
        'Sua imagem tem $w×$h. Ela será reduzida para caber na capa e '
        'funciona normalmente, mas não precisa ser maior que '
        '${MediaLimits.recommendedImageWidth}×'
        '${MediaLimits.recommendedImageHeight}.',
      );
    }
    return line(Icons.check_circle_outline, AppTheme.gray,
        'Tamanho ótimo: $w×$h em 16:9.');
  }

  // =====================================================================
  // PUBLICAR
  // =====================================================================

  void _publish() {
    final user = _db.currentUser;
    if (user == null) return;

    final formOk = _formKey.currentState!.validate();
    final topicOk = _topic != null;
    final video = _video;
    final seconds = _durationSeconds;
    final videoOk = video != null && seconds != null;

    setState(() {
      _topicError = !topicOk;
      if (!videoOk && !_readingDuration) {
        _videoError = 'Escolha o vídeo que será publicado.';
      }
    });
    if (!formOk || !topicOk || !videoOk) return;

    final subTopic = _subTopicController.text.trim();
    _db.addVideo(VideoModel(
      id: _db.nextVideoId(),
      authorRgm: user.rgm,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      mainTopic: _topic!,
      subTopic: subTopic.isEmpty ? null : subTopic,
      durationSeconds: seconds,
      videoPath: video.source,
      thumbnailPath: _cover?.source, // nulo = imagem padrão
      createdAt: DateTime.now(),
    ));
    _published = true; // os arquivos agora pertencem ao vídeo publicado

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    showAppNoticeOnMessenger(
      messenger,
      'Vídeo publicado! Ele já aparece na Página Principal.',
      error: false,
      duration: const Duration(seconds: 2),
    );
  }

  // =====================================================================
  // AUXILIARES
  // =====================================================================

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Modelo temporário só para reaproveitar a regra de preço do VideoModel.
  VideoModel _previewModel(int seconds) {
    return VideoModel(
      id: 'preview',
      authorRgm: '',
      title: '',
      description: '',
      mainTopic: '',
      durationSeconds: seconds,
      createdAt: DateTime.now(),
    );
  }

  // =====================================================================
  // INTERFACE
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar vídeo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildVideoSection(),
            const SizedBox(height: 28),
            _buildCoverSection(),
            const SizedBox(height: 28),
            _buildInfoSection(),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _readingDuration ? null : _publish,
                child: const Text(
                  'Publicar vídeo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Publicar é gratuito. Você ganha créditos a cada desbloqueio '
              'do seu vídeo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

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

  /// Aviso de erro: X vermelho com a mensagem.
  Widget _errorLine(String message) {
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

  // ---------- 1. Vídeo ----------
  Widget _buildVideoSection() {
    final theme = Theme.of(context);
    final video = _video;
    final seconds = _durationSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          '1. Vídeo',
          subtitle: 'Até ${MediaLimits.maxVideoSeconds ~/ 60} minutos e '
              '${MediaLimits.formatBytes(MediaLimits.maxVideoBytes)}. '
              'Formatos: ${MediaLimits.videoExtensions.join(', ')}.',
        ),
        OutlinedButton.icon(
          onPressed: _readingDuration ? null : _chooseVideo,
          icon: const Icon(Icons.video_file_outlined),
          label: Text(video == null ? 'Escolher vídeo' : 'Trocar vídeo'),
        ),
        if (_readingDuration) ...[
          const SizedBox(height: 8),
          Text('Lendo a duração do vídeo...', style: theme.textTheme.bodySmall),
        ],
        if (video != null && seconds != null) ...[
          const SizedBox(height: 12),
          _buildVideoInfo(video, seconds),
        ],
        if (_videoError != null) _errorLine(_videoError!),
      ],
    );
  }

  Widget _buildVideoInfo(PickedMedia video, int seconds) {
    final theme = Theme.of(context);
    final preview = _previewModel(seconds);

    return _block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  video.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tamanho: ${MediaLimits.formatBytes(video.sizeBytes)} • '
            'Duração: ${_clock(seconds)}',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 20),
          Text(
            'Preço para quem desbloquear: ${preview.creditCost} créditos',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${preview.billableMinutes} min × ${VideoModel.creditsPerMinute} '
            'créditos. Você recebe 100% de cada desbloqueio.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ---------- 2. Capa ----------
  Widget _buildCoverSection() {
    final theme = Theme.of(context);
    final cover = _cover;
    final advice = _coverAdvice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          '2. Capa (opcional)',
          subtitle: 'JPG ou PNG, proporção 16:9, até '
              '${MediaLimits.formatBytes(MediaLimits.maxImageBytes)}. '
              'Ideal: ${MediaLimits.recommendedImageWidth}×'
              '${MediaLimits.recommendedImageHeight} '
              '(mínimo ${MediaLimits.minImageWidth}×'
              '${MediaLimits.minImageHeight}). '
              'Imagens de outra proporção são recortadas no centro.',
        ),
        // Prévia: sem capa, mostra a imagem padrão.
        Container(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(AppTheme.thinBlack),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoThumbnail(imageUrl: cover?.source),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cover == null
              ? 'Sem capa, será usada a imagem padrão.'
              : 'Capa: ${cover.name} (${MediaLimits.formatBytes(cover.sizeBytes)})',
          style: theme.textTheme.bodySmall,
        ),
        if (advice != null) ...[
          const SizedBox(height: 8),
          advice,
        ],
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _chooseCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(cover == null ? 'Escolher capa' : 'Trocar capa'),
            ),
            if (cover != null)
              TextButton(
                onPressed: _removeCover,
                child: const Text('Remover capa'),
              ),
          ],
        ),
        if (_coverError != null) _errorLine(_coverError!),
      ],
    );
  }

  // ---------- 3. Informações ----------
  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('3. Informações'),
        TextFormField(
          controller: _titleController,
          maxLength: 80,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Título'),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Informe o título.';
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLength: 300,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Descrição breve'),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Informe a descrição.';
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Tópico principal (obrigatório)
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Tópico principal',
            errorText: _topicError ? 'Escolha o tópico principal.' : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: _topic,
              hint: const Text('Selecione'),
              items: [
                for (final topic in MockDatabase.topics)
                  DropdownMenuItem<String>(value: topic, child: Text(topic)),
              ],
              onChanged: (value) => setState(() {
                _topic = value;
                _topicError = false;
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sub-tópico (opcional)
        TextFormField(
          controller: _subTopicController,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Sub-tópico (opcional)',
          ),
        ),
      ],
    );
  }
}

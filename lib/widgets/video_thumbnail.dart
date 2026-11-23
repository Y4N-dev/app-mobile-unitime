// lib/widgets/video_thumbnail.dart
//
// Thumbnail de vídeo, compartilhada por TODAS as telas (Home, Métricas,
// Publicador...). Mostra a imagem real quando existir e, por baixo dela,
// um espaço reservado azul com a estrela amarela, que aparece enquanto
// a imagem carrega, se ela falhar ou se o vídeo não tiver capa.
//
// Se a imagem falhar, o motivo é escrito no console do FlutLab, em uma
// linha que começa com "Thumbnail falhou".
//
// FUTURO (capa automática): quando o autor não enviar capa, a capa será o
// primeiro frame do vídeo, gerado no envio. Como todas as telas usam este
// widget, bastará entregar essa imagem em imageUrl.
//
// Uso: coloque dentro de um AspectRatio ou de um tamanho fixo (SizedBox):
//   AspectRatio(
//     aspectRatio: 16 / 9,
//     child: VideoThumbnail(
//       imageUrl: video.thumbnailPath,
//       durationText: video.formattedDuration,
//     ),
//   )
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'uni_star.dart';

class VideoThumbnail extends StatelessWidget {
  /// Endereço (URL) da capa. Nulo = só o espaço reservado.
  final String? imageUrl;

  /// Duração no canto (ex.: "9:56"). Nulo = não mostra.
  final String? durationText;

  /// Tamanho da estrela do espaço reservado.
  final double starSize;

  /// Modo compacto para miniaturas pequenas (listas): estrela, fonte e
  /// margens menores.
  final bool compact;

  const VideoThumbnail({
    Key? key,
    this.imageUrl,
    this.durationText,
    this.starSize = 44,
    this.compact = false,
  }) : super(key: key);

  // Endereço de internet ou endereço temporário do navegador (blob:).
  bool get _isRemoteImage =>
      imageUrl != null &&
      (imageUrl!.startsWith('http') || imageUrl!.startsWith('blob:'));

  // Arquivo local do celular (capa enviada pelo Publicador no APK).
  bool get _isLocalFile => !kIsWeb && imageUrl != null && !_isRemoteImage;

  @override
  Widget build(BuildContext context) {
    final margin = compact ? 4.0 : 6.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Espaço reservado (fica por baixo da imagem)
        const ColoredBox(color: AppTheme.blue),
        Center(child: UniStar(size: compact ? starSize * 0.6 : starSize)),

        // Imagem real: se falhar, some e o espaço reservado continua visível.
        if (_isRemoteImage)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            // Decodifica em tamanho menor: economiza memória e ajuda no FPS.
            cacheWidth: compact ? 240 : 480,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Thumbnail falhou: $imageUrl -> $error');
              return const SizedBox.shrink();
            },
          ),

        if (_isLocalFile)
          Image.file(
            File(imageUrl!),
            fit: BoxFit.cover,
            cacheWidth: compact ? 240 : 480,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Thumbnail falhou: $imageUrl -> $error');
              return const SizedBox.shrink();
            },
          ),

        // Duração no canto
        if (durationText != null)
          Positioned(
            right: margin,
            bottom: margin,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: compact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xB3000000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                durationText!,
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

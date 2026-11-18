// lib/utils/media_picker.dart
//
// Escolha de vídeo e de imagem (capa) para o Publicador.
// Devolve SEMPRE um texto (PickedMedia.source) que vai direto para
// VideoModel.videoPath / VideoModel.thumbnailPath:
//   - navegador (web): endereço temporário "blob:..." (o arquivo fica só na
//     memória do navegador e some ao recarregar a página, como o resto do
//     banco local);
//   - celular (APK): caminho do arquivo no aparelho.
// Assim, as telas não precisam saber em qual plataforma estão.
//
// FUTURO: com o banco de dados online, o envio devolverá um endereço (URL)
// de armazenamento; o restante do app continuará igual.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'blob_url_stub.dart' if (dart.library.js_interop) 'blob_url_web.dart';

/// Limites do envio, definidos em UM lugar só.
class MediaLimits {
  MediaLimits._();

  // Vídeo
  static const int maxVideoSeconds = 15 * 60; // ~15 minutos
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100 MB
  static const List<String> videoExtensions = ['mp4', 'webm', 'mov'];

  // Capa (thumbnail)
  static const int maxImageBytes = 2 * 1024 * 1024; // 2 MB
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png'];
  static const int recommendedImageWidth = 1280; // ideal: 1280 x 720 (16:9)
  static const int recommendedImageHeight = 720;
  static const int minImageWidth = 640; // mínimo: 640 x 360
  static const int minImageHeight = 360;

  /// 2097152 -> "2 MB" | 512000 -> "500 KB"
  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(mb == mb.roundToDouble() ? 0 : 1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }
}

/// Problema ao escolher o arquivo (mensagem pronta para a tela exibir).
class MediaPickException implements Exception {
  final String message;
  const MediaPickException(this.message);

  @override
  String toString() => message;
}

/// Arquivo escolhido e já validado.
class PickedMedia {
  final String name;
  final int sizeBytes;

  /// Texto para gravar em videoPath / thumbnailPath (blob: ou caminho local).
  final String source;

  const PickedMedia({
    required this.name,
    required this.sizeBytes,
    required this.source,
  });
}

class MediaPicker {
  MediaPicker._();

  /// Escolhe um vídeo. Devolve null se o usuário cancelar.
  /// Lança MediaPickException se o arquivo não servir.
  static Future<PickedMedia?> pickVideo() => _pick(
        extensions: MediaLimits.videoExtensions,
        maxBytes: MediaLimits.maxVideoBytes,
      );

  /// Escolhe uma imagem de capa. Devolve null se o usuário cancelar.
  static Future<PickedMedia?> pickImage() => _pick(
        extensions: MediaLimits.imageExtensions,
        maxBytes: MediaLimits.maxImageBytes,
      );

  /// Libera a memória de um arquivo que não será mais usado (ex.: o aluno
  /// trocou a capa antes de enviar). Só faz algo no navegador.
  static void release(String? source) {
    if (source != null && source.startsWith('blob:')) {
      revokeBlobUrl(source);
    }
  }

  static Future<PickedMedia?> _pick({
    required List<String> extensions,
    required int maxBytes,
  }) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } catch (e) {
      throw MediaPickException('Não foi possível abrir o seletor de arquivos.');
    }
    if (file == null) return null; // o usuário cancelou

    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!extensions.contains(ext)) {
      throw MediaPickException(
          'Formato não aceito. Use: ${extensions.join(', ')}.');
    }

    // O tamanho é conferido ANTES de ler o arquivo (evita travar o navegador).
    final size = file.lengthSync() ?? await file.length() ?? 0;
    if (size <= 0) {
      throw const MediaPickException('Não foi possível ler este arquivo.');
    }
    if (size > maxBytes) {
      throw MediaPickException(
          'Arquivo muito grande (${MediaLimits.formatBytes(size)}). '
          'O limite é ${MediaLimits.formatBytes(maxBytes)}.');
    }

    final String source;
    if (kIsWeb) {
      // Navegador: o arquivo vira um endereço temporário na memória.
      final bytes = await file.readAsBytes();
      source = createBlobUrl(bytes, _mimeOf(ext));
    } else {
      // Celular: usa o caminho do arquivo no aparelho.
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw const MediaPickException('Não foi possível ler este arquivo.');
      }
      source = path;
    }

    return PickedMedia(name: name, sizeBytes: size, source: source);
  }

  static String _mimeOf(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg'; // jpg e jpeg
    }
  }
}

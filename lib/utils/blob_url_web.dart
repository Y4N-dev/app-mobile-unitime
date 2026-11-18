// lib/utils/blob_url_web.dart
//
// Versão para o navegador: transforma os bytes de um arquivo em um endereço
// temporário "blob:..." que o player de vídeo e a imagem sabem abrir.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

void revokeBlobUrl(String url) {
  web.URL.revokeObjectURL(url);
}

// lib/utils/blob_url_stub.dart
//
// Versão para celular (APK). Endereços "blob:" só existem no navegador,
// então aqui não há nada a fazer. O media_picker.dart escolhe este arquivo
// ou o blob_url_web.dart automaticamente (importação condicional).

import 'dart:typed_data';

String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Endereços blob: só existem no navegador.');
}

void revokeBlobUrl(String url) {}

// lib/widgets/app_notice.dart
//
// AVISO RÁPIDO único do app (antes repetido em várias telas).
// Branco, com linha fina preta. Falhas e cancelamentos levam o X vermelho
// (error = true); avisos neutros ou de sucesso não levam ícone
// (error = false). Duração padrão: 1,2 segundo (AppTheme.noticeDuration).
//
// Uso:
//   showAppNotice(context, 'Compra não realizada');
//   showAppNotice(context, 'Foto atualizada!', error: false);
//
// Use showAppNoticeOnMessenger quando o aviso for mostrado DEPOIS de fechar
// a tela (capture o messenger antes: ScaffoldMessenger.of(context)).

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

void showAppNotice(
  BuildContext context,
  String message, {
  bool error = true,
  Duration duration = AppTheme.noticeDuration,
}) {
  showAppNoticeOnMessenger(
    ScaffoldMessenger.of(context),
    message,
    error: error,
    duration: duration,
  );
}

void showAppNoticeOnMessenger(
  ScaffoldMessengerState messenger,
  String message, {
  bool error = true,
  Duration duration = AppTheme.noticeDuration,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: AppTheme.thinBlack,
      ),
      content: Row(
        children: [
          if (error) ...[
            const Icon(Icons.close_rounded, color: AppTheme.red),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(message, style: const TextStyle(color: AppTheme.black)),
          ),
        ],
      ),
    ),
  );
}

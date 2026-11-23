// lib/widgets/app_dialog.dart
//
// "Casca" única dos pop-ups do app: moldura com cantos arredondados e borda
// preta fina, cabeçalho azul com ícone em círculo amarelo, linha amarela na
// base do cabeçalho e botões alinhados à direita. O conteúdo e os botões de
// CADA pop-up continuam sendo do próprio pop-up.
//
// O título fica em UMA linha (se for longo, diminui para caber). O cabeçalho
// vermelho (danger = true) é só para avisos importantes, como a exclusão.
//
// Uso (dentro de showDialog):
//   AppDialog(
//     icon: Icons.lock_open,
//     title: 'Desbloquear vídeo',
//     content: Text('...'),
//     actions: [TextButton(...), ElevatedButton(...)],
//   )

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;

  /// Cabeçalho vermelho (aviso importante, como exclusão).
  final bool danger;

  const AppDialog({
    Key? key,
    required this.icon,
    required this.title,
    required this.content,
    this.actions = const [],
    this.danger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headerColor = danger ? AppTheme.red : AppTheme.blue;

    return Dialog(
      backgroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: AppTheme.thinBlack,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho: ícone em círculo amarelo + título em uma linha.
            Container(
              color: headerColor,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppTheme.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: danger ? AppTheme.red : AppTheme.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Linha amarela na base do cabeçalho.
            Container(height: AppTheme.headerLineWidth, color: AppTheme.yellow),
            // Conteúdo (rola, se for maior que a tela).
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: content,
              ),
            ),
            // Botões, alinhados à direita.
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/publisher_screen.dart
//
// Aba "Publicador de Vídeos": dois botões de grande destaque.
//   - Enviar Vídeo     -> UploadVideoScreen
//   - Gerenciar Vídeos -> ManageVideosScreen
// Cada botão é azul, com linha amarela na base, a estrela como marca d'água
// ao fundo da tela e um ícone grande, em azul mais escuro, atrás do botão.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';
import 'manage_videos_screen.dart';
import 'upload_video_screen.dart';

class PublisherScreen extends StatelessWidget {
  const PublisherScreen({Key? key}) : super(key: key);

  void _openUpload(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
    );
  }

  void _openManage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageVideosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Publicador de Vídeos'),
      ),
      body: UniStarWatermark(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BigAction(
                    icon: Icons.upload_rounded,
                    backgroundIcon: Icons.cloud_upload,
                    title: 'Enviar Vídeo',
                    subtitle: 'Publique uma videoaula e ganhe créditos.',
                    onTap: () => _openUpload(context),
                  ),
                  const SizedBox(height: 16),
                  _BigAction(
                    icon: Icons.video_settings_outlined,
                    backgroundIcon: Icons.video_library,
                    title: 'Gerenciar Vídeos',
                    subtitle: 'Métricas, edição e exclusão dos seus vídeos.',
                    onTap: () => _openManage(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão grande de destaque: azul, com um ícone enorme de fundo (tom mais
/// escuro, levemente inclinado) e linha amarela na base.
class _BigAction extends StatelessWidget {
  final IconData icon; // ícone pequeno, à esquerda do texto
  final IconData backgroundIcon; // ícone grande de fundo
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigAction({
    Key? key,
    required this.icon,
    required this.backgroundIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // O recorte arredondado corta o que passar da borda (ícone de fundo,
    // linha amarela e o efeito de toque).
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppTheme.blue,
        child: InkWell(
          onTap: onTap,
          // Hover e toque dos botões azul escuro: azul um pouco mais claro.
          hoverColor: AppTheme.blueHover,
          highlightColor: AppTheme.blueHover,
          splashColor: AppTheme.blueHover,
          child: Stack(
            children: [
              // Ícone grande de fundo: azul mais escuro, saindo pelo canto.
              Positioned(
                right: -16,
                bottom: -24,
                child: Transform.rotate(
                  angle: -0.22,
                  child: Icon(
                    backgroundIcon,
                    size: 132,
                    color: AppTheme.blueDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.white, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Linha amarela na base do botão.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 4,
                  child: ColoredBox(color: AppTheme.yellow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

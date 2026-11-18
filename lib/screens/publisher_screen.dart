// lib/screens/publisher_screen.dart
//
// Aba "Publicador de Vídeos": dois botões de grande destaque.
//   - Enviar Vídeo     -> UploadVideoScreen
//   - Gerenciar Vídeos -> (próximo passo: ManageVideosScreen)

import 'package:flutter/material.dart';
import 'manage_videos_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';
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
                    title: 'Enviar Vídeo',
                    subtitle: 'Publique uma videoaula e ganhe créditos.',
                    onTap: () => _openUpload(context),
                  ),
                  const SizedBox(height: 16),
                  _BigAction(
                    icon: Icons.video_settings_outlined,
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

/// Botão grande de destaque: azul, com linha amarela na base.
class _BigAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigAction({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.blue,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          bottom: BorderSide(color: AppTheme.yellow, width: 4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          highlightColor: AppTheme.yellowSoft,
          splashColor: AppTheme.yellowSoft,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
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
      ),
    );
  }
}

// lib/widgets/level_medal.dart
//
// Medalha de nível (decoração simbólica do Perfil, sem nenhum efeito no app).
// Desenhada por CÓDIGO (sem imagem): fita azul (colar do pescoço) sempre
// igual, medalha na cor da faixa e, no centro, a MESMA estrela da logo em uma
// cor de destaque que contrasta com a medalha. Só a cor da medalha muda.
//
// Faixas (ProgressionService): Chocolate 0-4, Bronze 5-11, Prata 12-19,
// Ouro 20-26 e Diamante 27-30. As cores ficam no AppTheme.
//
// Uso:
//   LevelMedal.forLevel(level: 7, size: 96)
//   LevelMedal(tier: MedalTier.gold, size: 120)

import 'package:flutter/material.dart';

import '../data/mock_database.dart';
import '../services/progression_service.dart';
import '../theme/app_theme.dart';
import 'uni_star.dart';

class _MedalColors {
  final Color base; // cor da medalha
  final Color ring; // anel (tom mais escuro)
  final Color star; // estrela central (destaque)

  const _MedalColors(this.base, this.ring, this.star);
}

_MedalColors _colorsOf(MedalTier tier) {
  switch (tier) {
    case MedalTier.chocolate:
      return const _MedalColors(AppTheme.medalChocolate,
          AppTheme.medalChocolateRing, AppTheme.medalChocolateStar);
    case MedalTier.bronze:
      return const _MedalColors(AppTheme.medalBronze, AppTheme.medalBronzeRing,
          AppTheme.medalBronzeStar);
    case MedalTier.silver:
      return const _MedalColors(AppTheme.medalSilver, AppTheme.medalSilverRing,
          AppTheme.medalSilverStar);
    case MedalTier.gold:
      return const _MedalColors(
          AppTheme.medalGold, AppTheme.medalGoldRing, AppTheme.medalGoldStar);
    case MedalTier.diamond:
      return const _MedalColors(AppTheme.medalDiamond,
          AppTheme.medalDiamondRing, AppTheme.medalDiamondStar);
  }
}

/// Medidas da medalha, calculadas a partir do tamanho do desenho.
class _MedalGeometry {
  final double w;
  final double h;

  const _MedalGeometry(this.w, this.h);

  double get radius => w * 0.36;
  double get cx => w / 2;
  double get cy => h - radius - w * 0.03;
}

class LevelMedal extends StatelessWidget {
  /// Altura = largura x 1,4 (fita em cima, medalha embaixo).
  static const double aspect = 1.4;

  final MedalTier tier;

  /// Largura do desenho.
  final double size;

  const LevelMedal({Key? key, required this.tier, this.size = 96})
      : super(key: key);

  /// Atalho: escolhe a faixa a partir do nível do aluno.
  factory LevelMedal.forLevel(
      {Key? key, required int level, double size = 96}) {
    return LevelMedal(
      key: key,
      tier: ProgressionService.tierFor(level),
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsOf(tier);
    final w = size;
    final h = size * aspect;
    final g = _MedalGeometry(w, h);
    final starSize = g.radius * 1.25;

    return Semantics(
      label: 'Medalha ${tier.label}',
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MedalPainter(colors))),
            // A mesma estrela da logo, no centro da medalha.
            Positioned(
              left: g.cx - starSize / 2,
              top: g.cy - starSize / 2,
              width: starSize,
              height: starSize,
              child: UniStar(size: starSize, color: colors.star),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final _MedalColors colors;

  _MedalPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final g = _MedalGeometry(size.width, size.height);
    final w = g.w;
    final r = g.radius;
    final cx = g.cx;
    final cy = g.cy;
    final ribbonEnd =
        cy - r - w * 0.05; // onde a fita termina (acima da medalha)

    // ---------- Fita azul (duas faixas em V) ----------
    final left = Path()
      ..moveTo(w * 0.16, 0)
      ..lineTo(w * 0.38, 0)
      ..lineTo(cx + w * 0.02, ribbonEnd)
      ..lineTo(cx - w * 0.10, ribbonEnd)
      ..close();
    final right = Path()
      ..moveTo(w * 0.62, 0)
      ..lineTo(w * 0.84, 0)
      ..lineTo(cx + w * 0.10, ribbonEnd)
      ..lineTo(cx - w * 0.02, ribbonEnd)
      ..close();

    final ribbonFill = Paint()
      ..color = AppTheme.blue
      ..style = PaintingStyle.fill;
    final ribbonLine = Paint()
      ..color = AppTheme.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeJoin = StrokeJoin.round;
    for (final path in [left, right]) {
      canvas.drawPath(path, ribbonFill);
      canvas.drawPath(path, ribbonLine);
    }

    // ---------- Argola que prende a medalha à fita ----------
    canvas.drawCircle(
      Offset(cx, cy - r - w * 0.015),
      w * 0.045,
      Paint()
        ..color = colors.ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025,
    );

    // ---------- Medalha: anel, disco e um leve brilho ----------
    final center = Offset(cx, cy);
    final inner = r * 0.84;
    canvas.drawCircle(center, r, Paint()..color = colors.ring);
    canvas.drawCircle(center, inner, Paint()..color = colors.base);

    final shine = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: inner * 0.88),
      -2.6, // começa no alto, à esquerda
      0.8, // abre cerca de 46 graus
      false,
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) =>
      oldDelegate.colors.base != colors.base ||
      oldDelegate.colors.ring != colors.ring ||
      oldDelegate.colors.star != colors.star;
}

// =======================================================================
// GALERIA DE PRÉVIA (provisória, só para conferir as 5 medalhas)
// =======================================================================

class LevelMedalGallery extends StatelessWidget {
  const LevelMedalGallery({Key? key}) : super(key: key);

  /// "níveis 5 a 11"
  static String _range(MedalTier tier) {
    final tiers = MedalTier.values;
    final index = tiers.indexOf(tier);
    final from = tier.minLevel;
    final to = index + 1 < tiers.length
        ? tiers[index + 1].minLevel - 1
        : ProgressionService.maxLevel;
    return 'níveis $from a $to';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Prévia das medalhas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (final tier in MedalTier.values)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LevelMedal(tier: tier, size: 96),
                      const SizedBox(height: 8),
                      Text(
                        tier.label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(_range(tier), style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // Provisório: mantém o logout enquanto o Perfil não existe.
            OutlinedButton.icon(
              onPressed: MockDatabase.instance.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}

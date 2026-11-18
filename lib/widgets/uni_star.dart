// lib/widgets/uni_star.dart
//
// Estrela amarela da UNIPÊ: logo do UniTime.
// Desenhada por CÓDIGO (sem imagem): leve e nítida em qualquer tamanho.
// Formato: estrela de cinco pontas feita com UM traço contínuo de caneta,
// com um pequeno cruzamento no topo, onde o traço se encontra.
//
// Uso como logo:       const UniStar(size: 64)
// Uso como marca d'água: UniStarWatermark(child: MeuConteudo())

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A estrela como widget quadrado. Por padrão, amarelo de destaque.
class UniStar extends StatelessWidget {
  final double size;
  final Color color;

  /// Inclinação em radianos (efeito de desenho feito à mão). Use 0 para
  /// uma estrela perfeitamente reta.
  final double tilt;

  const UniStar({
    Key? key,
    this.size = 48,
    this.color = AppTheme.yellow,
    this.tilt = 0.12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(color: color, tilt: tilt),
      ),
    );
  }
}

/// Coloca a estrela esmaecida ATRÁS do conteúdo, como marca d'água.
/// Atenção: o conteúdo precisa ter fundo transparente para a estrela
/// aparecer (um Scaffold com fundo branco a esconderia).
class UniStarWatermark extends StatelessWidget {
  final Widget child;
  final double starSize;
  final double opacity; // 0.0 a 1.0 (sugestão: 0.06 a 0.12)
  final Alignment alignment;

  const UniStarWatermark({
    Key? key,
    required this.child,
    this.starSize = 220,
    this.opacity = 0.08,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Opacity(
                opacity: opacity,
                child: UniStar(size: starSize),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final double tilt;

  _StarPainter({required this.color, required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final strokeWidth = side * 0.09;

    // O raio deixa uma folga para a espessura do traço não ser cortada.
    final radius = side / 2 - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);

    // Os 5 vértices da estrela, a partir do topo (com a leve inclinação).
    final points = List<Offset>.generate(5, (k) {
      final angle = -math.pi / 2 + k * 2 * math.pi / 5 + tilt;
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    });

    // Traço contínuo: pula um vértice de cada vez (0 -> 2 -> 4 -> 1 -> 3 -> 0).
    final p = points;
    final path = Path()
      // Começa um pouco antes do topo (o início do traço de caneta)...
      ..moveTo(_lerp(p[3], p[0], 0.88).dx, _lerp(p[3], p[0], 0.88).dy)
      ..lineTo(p[0].dx, p[0].dy)
      ..lineTo(p[2].dx, p[2].dy)
      ..lineTo(p[4].dx, p[4].dy)
      ..lineTo(p[1].dx, p[1].dy)
      ..lineTo(p[3].dx, p[3].dy)
      ..lineTo(p[0].dx, p[0].dy)
      // ...e termina um pouco depois do topo, cruzando o começo.
      ..lineTo(_lerp(p[0], p[2], 0.10).dx, _lerp(p[0], p[2], 0.10).dy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  /// Ponto entre a e b (t = 0 é a, t = 1 é b).
  Offset _lerp(Offset a, Offset b, double t) {
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tilt != tilt;
}

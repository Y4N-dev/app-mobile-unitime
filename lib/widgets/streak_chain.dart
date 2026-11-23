// lib/widgets/streak_chain.dart
//
// Corrente da SEQUÊNCIA DE DIAS (puramente simbólica). Só 2 desenhos, feitos
// por código: corrente inteira e corrente estilhaçada. A corrente é cinza com
// borda preta; o número fica em uma pequena etiqueta no canto inferior
// direito, SEM cobrir o desenho (preto na inteira, vermelho na quebrada).
//
// Este ícone é diferente da chama do contador "Principal" do Perfil.
//
// Uso:
//   StreakChain(count: 7)                                // sequência viva
//   StreakChain(count: 12, broken: true)                 // quebrada
//   StreakChain.fromInfo(MissionService.instance.streak(rgm))

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/mission_service.dart';
import '../theme/app_theme.dart';

class StreakChain extends StatelessWidget {
  /// Número da etiqueta (dias da sequência; na quebrada, o que foi perdido).
  final int count;

  /// true = corrente estilhaçada, com o número em vermelho.
  final bool broken;

  /// Largura e altura do ícone.
  final double size;

  const StreakChain({
    Key? key,
    required this.count,
    this.broken = false,
    this.size = 72,
  }) : super(key: key);

  /// Atalho: monta o ícone a partir do resultado do MissionService.streak().
  factory StreakChain.fromInfo(StreakInfo info, {Key? key, double size = 72}) {
    return StreakChain(
      key: key,
      count: info.count,
      broken: info.state == StreakState.broken,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Números maiores usam fonte menor, para caberem na etiqueta.
    final fontSize = size * (count >= 100 ? 0.17 : (count >= 10 ? 0.22 : 0.26));

    return Semantics(
      label: broken
          ? 'Sequência quebrada: você perdeu $count dias seguidos'
          : 'Sequência de $count dias',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ChainPainter(broken: broken)),
            ),
            // Etiqueta do número, no canto (não cobre a corrente).
            Positioned(
              right: size * 0.01,
              bottom: size * 0.01,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: size * 0.40,
                  minHeight: size * 0.40,
                ),
                padding: EdgeInsets.symmetric(horizontal: size * 0.07),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  border: Border.all(
                    color: AppTheme.black,
                    width: math.max(1.0, size * 0.012),
                  ),
                  borderRadius: BorderRadius.circular(size),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: broken ? AppTheme.red : AppTheme.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um estilhaço solto da corrente quebrada.
class _Shard {
  final double along; // posição ao longo da corrente (em "unit")
  final double across; // posição para o lado (em "unit")
  final double size;
  final double rotation;
  final bool light; // true = cinza claro; false = cinza

  const _Shard(this.along, this.across, this.size, this.rotation, this.light);
}

class _ChainPainter extends CustomPainter {
  final bool broken;

  _ChainPainter({required this.broken});

  static const List<_Shard> _shards = [
    _Shard(-0.03, -0.21, 0.105, 0.4, false),
    _Shard(0.07, 0.10, 0.095, 1.2, true),
    _Shard(0.14, -0.14, 0.07, 2.3, false),
    _Shard(-0.10, 0.11, 0.065, 0.1, true),
    _Shard(0.02, 0.01, 0.05, 1.9, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final unit = s * 0.78; // a corrente deixa o canto livre para a etiqueta
    final c0 = Offset(s * 0.455, s * 0.47);
    final angle = -math.pi * 40 / 180; // corrente na diagonal
    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);

    final wideW = unit * 0.46;
    final wideH = unit * 0.25;
    final thinW = unit * 0.44;
    final thinH = unit * 0.10;
    final spacing = unit * 0.29;
    final stroke = unit * 0.06;
    final outline = unit * 0.025;

    if (!broken) {
      // Corrente inteira: dois elos de frente e um de lado no meio.
      _at(canvas, c0 - dir * spacing, angle,
          () => _wideLink(canvas, wideW, wideH, stroke, outline));
      _at(canvas, c0 + dir * spacing, angle,
          () => _wideLink(canvas, wideW, wideH, stroke, outline));
      _at(canvas, c0, angle, () => _thinLink(canvas, thinW, thinH, outline));
      return;
    }

    // ---------- Corrente estilhaçada ----------
    final gap = unit * 0.10;
    _brokenLink(canvas, c0 + dir * (-spacing - gap), angle - 0.09, 1, wideW,
        wideH, stroke, outline, unit);
    _brokenLink(canvas, c0 + dir * (spacing + gap), angle + 0.09, -1, wideW,
        wideH, stroke, outline, unit);

    // Estilhaços soltos no meio.
    const vertices = [
      [0.0, 1.0],
      [2.2, 0.75],
      [4.0, 1.1],
    ];
    for (final shard in _shards) {
      final c = c0 + dir * (unit * shard.along) + perp * (unit * shard.across);
      final points = [
        for (final v in vertices)
          Offset(
            c.dx + math.cos(shard.rotation + v[0]) * unit * shard.size * v[1],
            c.dy + math.sin(shard.rotation + v[0]) * unit * shard.size * v[1],
          ),
      ];
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(
        path,
        Paint()..color = shard.light ? AppTheme.grayLight : AppTheme.gray,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, outline * 0.9)
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// Desenha em um sistema de coordenadas girado, com origem no centro [c].
  void _at(Canvas canvas, Offset c, double angle, VoidCallback draw) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    draw();
    canvas.restore();
  }

  /// Elo visto de frente: contorno arredondado cinza, borda preta e brilho.
  void _wideLink(
      Canvas canvas, double w, double h, double stroke, double outline) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + outline * 2,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.gray
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // Brilho metálico na ponta do elo.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w / 2 - h / 2, 0), radius: h / 2),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..color = AppTheme.grayLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, stroke * 0.28)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Elo visto de lado: barra cinza com borda preta fina e brilho.
  void _thinLink(Canvas canvas, double w, double h, double outline) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.gray);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline * 1.8,
    );
    canvas.drawLine(
      Offset(-w * 0.30, -h * 0.12),
      Offset(w * 0.30, -h * 0.12),
      Paint()
        ..color = AppTheme.grayLight
        ..strokeWidth = h * 0.16
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Elo cortado em ponta irregular. [side] = +1 corta o lado direito do elo
  /// (o elo de baixo); -1 corta o lado esquerdo (o elo de cima).
  void _brokenLink(
    Canvas canvas,
    Offset center,
    double angle,
    int side,
    double w,
    double h,
    double stroke,
    double outline,
    double unit,
  ) {
    final cutX = unit * 0.05;
    final amp = unit * 0.035;
    const steps = 9;
    final yMin = -h * 1.4;
    final yMax = h * 1.4;

    // Linha irregular da quebra (em coordenadas do elo).
    final edge = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final y = yMin + (yMax - yMin) * i / steps;
      final k = (i == 0 || i == steps) ? 0.6 : 1.0;
      final x = cutX + (i.isEven ? amp : -amp) * k;
      edge.add(Offset(x * side, y));
    }

    // Região que MANTÉM o elo (o restante é cortado).
    final keep = Path()..moveTo(-w * 1.2 * side, yMin);
    for (final p in edge) {
      keep.lineTo(p.dx, p.dy);
    }
    keep
      ..lineTo(-w * 1.2 * side, yMax)
      ..close();

    // Borda preta irregular, só junto às duas passagens do anel.
    final nearRing = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(cutX * side, -h / 2), radius: stroke * 0.72))
      ..addOval(Rect.fromCircle(
          center: Offset(cutX * side, h / 2), radius: stroke * 0.72));
    final edgePath = Path()..moveTo(edge.first.dx, edge.first.dy);
    for (final p in edge.skip(1)) {
      edgePath.lineTo(p.dx, p.dy);
    }

    _at(canvas, center, angle, () {
      canvas.save();
      canvas.clipPath(keep);
      _wideLink(canvas, w, h, stroke, outline);
      canvas.restore();

      canvas.save();
      canvas.clipPath(nearRing);
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = AppTheme.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, outline)
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(covariant _ChainPainter oldDelegate) =>
      oldDelegate.broken != broken;
}

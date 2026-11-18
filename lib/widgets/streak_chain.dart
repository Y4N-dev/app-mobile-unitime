// lib/widgets/streak_chain.dart
//
// Corrente da SEQUÊNCIA DE DIAS (puramente simbólica). Só 2 desenhos,
// feitos por código: corrente inteira e corrente quebrada. O número é
// escrito por cima do desenho (preto na inteira, vermelho na quebrada).
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
  /// Número mostrado por cima (dias da sequência; na quebrada, o que foi perdido).
  final int count;

  /// true = corrente quebrada, com o número em vermelho.
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
    // Números maiores usam fonte menor, para caberem no desenho.
    final fontSize = size * (count >= 100 ? 0.26 : (count >= 10 ? 0.32 : 0.40));
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    return Semantics(
      label: broken
          ? 'Sequência quebrada: você perdeu $count dias seguidos'
          : 'Sequência de $count dias',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ChainPainter(broken: broken)),
            ),
            // Contorno branco do número (legível sobre qualquer parte do desenho)
            Text(
              '$count',
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.07
                  ..strokeJoin = StrokeJoin.round
                  ..color = AppTheme.white,
              ),
            ),
            // Número: preto na corrente inteira, vermelho na quebrada.
            Text(
              '$count',
              style: base.copyWith(
                color: broken ? AppTheme.red : AppTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainPainter extends CustomPainter {
  final bool broken;

  _ChainPainter({required this.broken});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide * 0.88;
    final center = Offset(size.width / 2, size.height / 2);
    final angle = -math.pi * 40 / 180; // corrente na diagonal
    final dir = Offset(math.cos(angle), math.sin(angle));

    final wideW = unit * 0.46;
    final wideH = unit * 0.25;
    final thinW = unit * 0.44;
    final thinH = unit * 0.10;
    final spacing = unit * 0.29;
    final stroke = unit * 0.06;
    final outline = unit * 0.025;

    if (!broken) {
      // Corrente inteira: dois elos de frente e um de lado no meio.
      _wideLink(
          canvas, center - dir * spacing, angle, wideW, wideH, stroke, outline);
      _wideLink(
          canvas, center + dir * spacing, angle, wideW, wideH, stroke, outline);
      _thinLink(canvas, center, angle, thinW, thinH, outline);
    } else {
      // Corrente quebrada: elos afastados e levemente inclinados.
      final gap = unit * 0.12;
      _wideLink(canvas, center - dir * (spacing + gap), angle - 0.14, wideW,
          wideH, stroke, outline);
      _wideLink(canvas, center + dir * (spacing + gap), angle + 0.14, wideW,
          wideH, stroke, outline);

      // Pequena rachadura (zigue-zague) no meio.
      final perp = Offset(-dir.dy, dir.dx);
      final crack = Path()
        ..moveTo(center.dx - perp.dx * unit * 0.12,
            center.dy - perp.dy * unit * 0.12)
        ..lineTo(center.dx - perp.dx * unit * 0.03 + dir.dx * unit * 0.04,
            center.dy - perp.dy * unit * 0.03 + dir.dy * unit * 0.04)
        ..lineTo(center.dx + perp.dx * unit * 0.03 - dir.dx * unit * 0.04,
            center.dy + perp.dy * unit * 0.03 - dir.dy * unit * 0.04)
        ..lineTo(center.dx + perp.dx * unit * 0.12,
            center.dy + perp.dy * unit * 0.12);
      canvas.drawPath(
        crack,
        Paint()
          ..color = AppTheme.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.03
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// Elo visto de frente: contorno arredondado amarelo com borda preta.
  void _wideLink(Canvas canvas, Offset c, double angle, double w, double h,
      double stroke, double outline) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
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
        ..color = AppTheme.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.restore();
  }

  /// Elo visto de lado: barra amarela com borda preta fina.
  void _thinLink(Canvas canvas, Offset c, double angle, double w, double h,
      double outline) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.yellow);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline * 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChainPainter oldDelegate) =>
      oldDelegate.broken != broken;
}

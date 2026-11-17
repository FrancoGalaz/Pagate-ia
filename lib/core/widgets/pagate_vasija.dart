import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Ilustración de las pantallas vacías: una vasija de greda dibujada con los
/// dos colores del sistema. Decorativa: el lector de pantalla la salta.
///
/// Es la misma de docs/diseno/variantes-cabal.html (viewBox 120 × 104).
class PagateVasija extends StatelessWidget {
  final double width;

  const PagateVasija({super.key, this.width = 96});

  @override
  Widget build(final BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: width * 104 / 120,
      child: const CustomPaint(painter: _PintorVasija()),
    ),
  );
}

class _PintorVasija extends CustomPainter {
  const _PintorVasija();

  @override
  void paint(final Canvas canvas, final Size size) {
    canvas.scale(size.width / 120, size.height / 104);

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppPalette.ink;

    // Sombra en el suelo.
    canvas.drawOval(
      const Rect.fromLTWH(20, 91, 80, 10),
      Paint()..color = AppPalette.sunken,
    );

    // Cuerpo.
    final cuerpo = Path()
      ..moveTo(42, 22)
      ..lineTo(78, 22)
      ..lineTo(74, 32)
      ..cubicTo(88, 38, 96, 50, 96, 64)
      ..cubicTo(96, 82, 80, 94, 60, 94)
      ..cubicTo(40, 94, 24, 82, 24, 64)
      ..cubicTo(24, 50, 32, 38, 46, 32)
      ..close();
    canvas
      ..drawPath(cuerpo, Paint()..color = AppPalette.brandSurface)
      ..drawPath(cuerpo, trazo);

    // Boca.
    const boca = Rect.fromLTWH(40, 16, 40, 6);
    canvas
      ..drawRect(boca, Paint()..color = AppPalette.surface)
      ..drawRect(boca, trazo);

    // Dos líneas de decoración en la greda.
    final decoracion = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.brand;
    canvas
      ..drawPath(
        Path()
          ..moveTo(30, 60)
          ..cubicTo(40, 66, 80, 66, 90, 60),
        decoracion,
      )
      ..drawPath(
        Path()
          ..moveTo(33, 72)
          ..cubicTo(42, 77, 78, 77, 87, 72),
        decoracion,
      );
  }

  @override
  bool shouldRepaint(final _PintorVasija oldDelegate) => false;
}

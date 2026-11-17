import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// ESQUELETO DE CARGA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 12.
//
// NO EXISTÍA. Un grep de `Shimmer|Skeleton` sobre lib/ daba cero
// resultados y había once `CircularProgressIndicator`, varios a pantalla
// completa. Un indicador centrado no dice cuánto contenido viene ni evita
// el salto de layout cuando llega: la pantalla pasa de 48 dp a 1.700 de
// golpe y el dedo del usuario toca lo que no quería.
//
// CADA BLOQUE TIENE LA ALTURA DEL TEXTO QUE SUSTITUYE (13 para `bodySmall`,
// 16 para `titleMedium`, 24 para `displaySmall`, 42 para la cifra héroe) y
// un ancho FIJO POR POSICIÓN, nunca aleatorio entre frames: un esqueleto
// que cambia de forma en cada pasada llama más la atención que el contenido.
//
// SIN BARRIDO DIAGONAL Y SIN GRADIENTE, porque no hay gradientes en el
// sistema, y sin paquete extra. Solo opacidad: 1,0 → 0,55 → 1,0 en 1200 ms.
// ═══════════════════════════════════════════════════════════════════════

/// Rectángulo gris que ocupa el sitio de un texto mientras carga.
///
/// El pulso se monta una sola vez por subárbol con
/// [PagateSkeletonGroup]; un bloque suelto fuera de un grupo se dibuja
/// estático, que es lo correcto dentro de un test.
class PagateSkeleton extends StatelessWidget {
  /// Alto del bloque, igual al del texto que sustituye.
  final double height;

  /// Fracción del ancho disponible, de 0 a 1. Fijo por posición.
  final double widthFactor;

  const PagateSkeleton({
    super.key,
    required this.height,
    this.widthFactor = 1,
  });

  /// Alturas de los cuatro slots que el sistema sustituye.
  static const double lineaMetadato = 13;
  static const double lineaTitulo = 16;
  static const double lineaTotal = 24;
  static const double cifraHeroe = 42;

  @override
  // `SizedBox(height:)` fija el alto y deja el ancho al padre; dentro,
  // `FractionallySizedBox` recorta a la fracción. Al revés —un `Align`
  // envolviendo— el bloque ocuparía todo el alto disponible, que es
  // exactamente lo que un esqueleto no debe hacer: su trabajo es reservar el
  // sitio del texto, ni un dp más.
  Widget build(final BuildContext context) => SizedBox(
        height: height,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.skeleton,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.r4)),
            ),
          ),
        ),
      );

  /// El bloque de saldo de Inicio: la línea guía, la cifra héroe y la línea
  /// de meta, con los mismos altos y los mismos huecos que el contenido real.
  static Widget balance() => const PagateSkeletonGroup(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PagateSkeleton(height: 11, widthFactor: 0.4),
              SizedBox(height: AppSpacing.x2),
              PagateSkeleton(height: cifraHeroe, widthFactor: 0.6),
              SizedBox(height: AppSpacing.x5),
              PagateSkeleton(height: lineaMetadato, widthFactor: 0.8),
            ],
          ),
        ),
      );

  /// [cantidad] filas con el alto y el relleno de una fila de movimiento.
  static Widget rows(final int cantidad) => PagateSkeletonGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cantidad; i++)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PagateSkeleton(height: lineaTitulo, widthFactor: 0.6),
                    SizedBox(height: AppSpacing.x2),
                    PagateSkeleton(height: lineaMetadato, widthFactor: 0.4),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Aplica el pulso a todo su subárbol.
///
/// Un solo `AnimationController` para el bloque entero: si cada rectángulo
/// animara por su cuenta, cinco filas serían diez animaciones desfasadas y
/// el bloque parpadearía como una guirnalda.
class PagateSkeletonGroup extends StatefulWidget {
  final Widget child;

  const PagateSkeletonGroup({super.key, required this.child});

  @override
  State<PagateSkeletonGroup> createState() => _PagateSkeletonGroupState();
}

class _PagateSkeletonGroupState extends State<PagateSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _opacidad = Tween<double>(
    begin: 1,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.standard));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => ExcludeSemantics(
        // Un esqueleto es decorativo: el lector de pantalla no tiene nada
        // que anunciar de cinco rectángulos grises.
        child: FadeTransition(opacity: _opacidad, child: widget.child),
      );
}

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// BARRA DE ACCIÓN FIJA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 15.
//
// SUSTITUYE AL `FloatingActionButton.extended` de Finanzas, y no por gusto.
// Ese FAB flotaba con sombra propia, tapaba la última fila de la lista —no
// hay padding inferior que lo compense— y, cuando se deshabilitaba por un
// error del stream, SEGUÍA VIÉNDOSE verde y blanco, porque
// `backgroundColor` y `foregroundColor` estaban fijados explícitamente y
// ganan sobre el estado deshabilitado del tema. Un botón que parece activo y
// no responde es peor que un botón apagado.
//
// Misma estructura que el pie de la hoja modal: una línea arriba, fondo
// blanco, relleno 16 y el botón a ancho completo. Va sobre la barra de
// navegación, no encima del contenido.
// ═══════════════════════════════════════════════════════════════════════

/// Pie fijo de una pantalla con una acción principal.
class PagateActionBar extends StatelessWidget {
  /// Botón primario, normalmente a ancho completo.
  final Widget child;

  /// Acción alternativa. Va encima de la principal, no al lado.
  final Widget? secondary;

  const PagateActionBar({
    super.key,
    required this.child,
    this.secondary,
  });

  @override
  Widget build(final BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppPalette.surface,
          border: Border(
            top: BorderSide(
              color: AppPalette.hairline,
              width: AppSizes.borderHairline,
            ),
          ),
        ),
        child: SafeArea(
          // Arriba no: la barra vive al pie de la pantalla y el recorte
          // superior lo resuelve el `body`.
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondary != null) ...[
                  secondary!,
                  const SizedBox(height: AppSpacing.x3),
                ],
                child,
              ],
            ),
          ),
        ),
      );
}

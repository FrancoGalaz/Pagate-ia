import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// ERROR EN LÍNEA
// ═══════════════════════════════════════════════════════════════════════
// POR QUÉ EXISTE: un fallo al guardar dinero no puede contarse con un aviso
// que se va solo. Antes de este widget, el `catch` de las hojas de
// formulario llamaba a `AppFeedback`, que pintaba un `SnackBar` en el
// Scaffold que estaba DETRÁS de la hoja: invisible. El aviso flotante ya está
// arreglado y se pinta encima, pero igual se desvanece.
//
// Esto se queda hasta que el usuario vuelve a pulsar guardar. Va DENTRO de la
// hoja, pegado al botón que falló, que es donde está mirando.
//
// NO ES [PagateErrorState]: ese es el bloque que sustituye al contenido de
// una pantalla cuando una LECTURA falla, con título y botón de reintentar.
// Este es una línea dentro de un formulario cuyo reintento es el propio botón
// del formulario.
// ═══════════════════════════════════════════════════════════════════════

/// Franja de error dentro de un formulario.
///
/// Se dibuja solo si [message] no es nulo, de modo que el llamante puede
/// ponerla en el árbol sin condicionales.
class PagateInlineError extends StatelessWidget {
  const PagateInlineError({super.key, required this.message});

  /// Texto del fallo, ya traducido por `describeDataError`. Nulo = no hay
  /// error y no se dibuja nada.
  final String? message;

  @override
  Widget build(final BuildContext context) {
    final texto = message;
    if (texto == null) return const SizedBox.shrink();

    return Semantics(
      // El lector de pantalla lo anuncia al aparecer: si no, un usuario
      // ciego pulsaría guardar y no recibiría ninguna señal.
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: AppPalette.dangerSurface,
          borderRadius: AppRadius.r8Border,
          border: Border.all(
            color: AppPalette.danger,
            width: AppSizes.borderHairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: AppIconSize.sm,
              color: AppPalette.danger,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textPrimary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

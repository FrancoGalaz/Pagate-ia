import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pagate_primary_button.dart';

// ═══════════════════════════════════════════════════════════════════════
// ESTADO VACÍO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 11.
//
// ALINEADO A LA IZQUIERDA Y SIN ILUSTRACIÓN. La app tenía cuatro
// reimplementaciones, todas con un icono de 32-48 dp centrado: un icono
// grande de nube tachada ocupa el espacio de tres líneas de texto y no
// dice nada que el título no diga.
//
// REGLA DE COPY, y es la que importa: la descripción dice QUÉ FALTA y el
// botón dice QUÉ HACER. Un "Aún no hay actividad registrada" sin acción al
// lado deja al usuario donde estaba.
// ═══════════════════════════════════════════════════════════════════════

/// Bloque que ocupa el sitio de una lista vacía.
///
/// Va dentro de una [PagateSectionCard], no en el lienzo: es contenido de la
/// sección, no una pantalla aparte.
class PagateEmptyState extends StatelessWidget {
  /// Nombra lo que falta, con el periodo si lo hay: "Sin movimientos en
  /// septiembre". Nunca "Vaya, parece que...".
  final String title;

  /// Qué hacer, en dos líneas como máximo.
  final String description;

  /// Etiqueta de la acción. Si es `null`, no se dibuja botón: solo en los
  /// casos donde el usuario no puede hacer nada desde esta pantalla.
  final String? actionLabel;
  final VoidCallback? onAction;

  const PagateEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x2),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.x4),

            // Ancho de contenido, no completo: el botón acompaña al texto;
            // si ocupara la línea entera sería el elemento dominante de una
            // pantalla que justamente no tiene nada que mostrar.
            Align(
              alignment: Alignment.centerLeft,
              child: PagatePrimaryButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pagate_primary_button.dart';

// ═══════════════════════════════════════════════════════════════════════
// ENCABEZADO DE SECCIÓN
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 8.
//
// VA FUERA DE LA SECCIÓN BLANCA, sobre el lienzo. Es lo que separa el
// título del contenido sin gastar una línea divisoria y sin que el título
// parezca la primera fila de la lista.
//
// SUSTITUYE A DOS CRITERIOS OPUESTOS que convivían:
//   · `_Section` de configuracion_screen: versalitas con letterSpacing 1,2
//     dentro de un contenedor de radio 32.
//   · `_SectionLabel` de setup_inicial_screen: numeración "1.", "2.", "3."
//     en otro peso y otro color.
//
// SIN versalitas, sin icono, sin contador entre paréntesis y sin línea
// debajo. La única excepción con mayúsculas del sistema es la variante
// [PagateSectionHeader.overline], el agrupador pegajoso de una lista larga
// ("HOY", "AYER").
// ═══════════════════════════════════════════════════════════════════════

/// Título de un bloque de la pantalla, con una acción opcional a la derecha.
class PagateSectionHeader extends StatelessWidget {
  final String title;

  /// Etiqueta de la acción de la derecha ("Ver todos", "Agregar"). Se dibuja
  /// como botón de texto, nunca como icono suelto.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Variante agrupadora dentro de una lista larga: fondo `sunken`, alto 32
  /// y la etiqueta en mayúsculas. Es el único sitio de la app con versalitas.
  final bool isOverline;

  const PagateSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  }) : isOverline = false;

  const PagateSectionHeader.overline({
    super.key,
    required this.title,
  })  : isOverline = true,
        actionLabel = null,
        onAction = null;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    if (isOverline) {
      return Container(
        width: double.infinity,
        color: AppPalette.sunken,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        constraints: const BoxConstraints(minHeight: _altoOverline),
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppPalette.textSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.x4,
        right: AppSpacing.x4,
        top: AppSpacing.x4,
        bottom: AppSpacing.x2,
      ),
      child: ConstrainedBox(
        // Mínimo, no fijo: a 2,0x el título crece y la fila crece con él.
        constraints: const BoxConstraints(minHeight: _altoMinimo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // `Expanded` y no ancho intrínseco: es la causa exacta de los dos
            // desbordes medidos a 1,3x en la cabecera de Inicio.
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.x2),
              PagatePrimaryButton.text(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 44 menos los 8 dp de aire inferior, que ya los pone el `Padding`.
  static const double _altoMinimo = 36;
  static const double _altoOverline = 32;
}

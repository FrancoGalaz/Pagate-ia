import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// HOJA MODAL
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 14.
//
// ABSORBE LOS CUATRO `AlertDialog` de la app (dos en finanzas_tab, dos en
// detalle_item_screen). El motivo no es estético: el `elevatedButtonTheme`
// impone `minimumSize: Size(double.infinity, 48)`, y dentro del
// `OverflowBar` de un diálogo eso apila los botones a ancho completo y
// descoloca la jerarquía Cancelar / Eliminar. En una hoja el pie es
// explícito y la jerarquía la decide quien la escribe.
//
// `PopScope` OBLIGATORIO cuando hay formulario: en todo `lib/` había CERO
// `PopScope` y el botón atrás descartaba cinco campos escritos sin avisar.
// [PagateSheet.scaffold] lo monta por su cuenta cuando se le pasa
// [onIntentarCerrar].
//
// EL PIE NO LLEVA DEGRADADO DE DESVANECIDO. El `fadeToWhite` que había
// dibujaba un degradado sobre fondo blanco, es decir nada, y costaba un
// `saveLayer`.
// ═══════════════════════════════════════════════════════════════════════

/// Abre una hoja modal del sistema.
///
/// El radio 16 arriba, el fondo blanco, el velo al 40%, el asa y la
/// ausencia de elevación salen de `bottomSheetTheme`. Aquí solo quedan las
/// tres decisiones que el tema no puede tomar: que sea desplazable, que
/// respete las zonas seguras y que no supere el 90% de la pantalla.
Future<T?> showPagateSheet<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,

  /// `false` impide cerrar tocando el velo. Se usa mientras se guarda.
  final bool isDismissible = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: builder,
    );

/// Estructura interna de una hoja: cabecera, cuerpo desplazable y pie fijo.
class PagateSheet extends StatelessWidget {
  /// Título a la izquierda, en `headlineSmall` 18/600. Sin icono de color al
  /// lado: el cuadrado teñido según el tipo que había no añadía información
  /// que el título no diera.
  final String title;

  /// Contenido. Se desplaza por su cuenta y respeta el teclado.
  final Widget child;

  /// Acción principal del pie, a ancho completo.
  final Widget? primaryAction;

  /// Acción alternativa. Va ENCIMA de la principal, nunca al lado: dos
  /// botones en la misma línea obligan a decidir cuál es cuál por su
  /// posición, y eso cambia entre plataformas.
  final Widget? secondaryAction;

  /// Si devuelve `false`, el cierre se cancela. Es lo que impide perder un
  /// formulario a medio escribir con el botón atrás.
  final Future<bool> Function()? onIntentarCerrar;

  const PagateSheet({
    super.key,
    required this.title,
    required this.child,
    this.primaryAction,
    this.secondaryAction,
    this.onIntentarCerrar,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final tienePie = primaryAction != null || secondaryAction != null;

    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Cabecera ───────────────────────────────────────────────
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _altoCabecera),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.x4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _cerrar(context),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: AppSizes.borderHairline,
          thickness: AppSizes.borderHairline,
          color: AppPalette.hairline,
        ),

        // ─── Cuerpo ─────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.x4,
              right: AppSpacing.x4,
              top: AppSpacing.x4,

              // El teclado: sin esto el último campo queda debajo de él.
              bottom: AppSpacing.x4 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: child,
          ),
        ),

        // ─── Pie ────────────────────────────────────────────────────
        if (tienePie) ...[
          const Divider(
            height: AppSizes.borderHairline,
            thickness: AppSizes.borderHairline,
            color: AppPalette.hairline,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondaryAction != null) ...[
                  secondaryAction!,
                  const SizedBox(height: AppSpacing.x3),
                ],
                ?primaryAction,
              ],
            ),
          ),
        ],
      ],
    );

    if (onIntentarCerrar == null) return contenido;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (final didPop, final _) async {
        if (didPop) return;
        if (await onIntentarCerrar!()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: contenido,
    );
  }

  Future<void> _cerrar(final BuildContext context) async {
    if (onIntentarCerrar != null && !await onIntentarCerrar!()) return;
    if (context.mounted) Navigator.of(context).pop();
  }

  static const double _altoCabecera = 52;
}

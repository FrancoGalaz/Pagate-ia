import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// FILA DE MOVIMIENTO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 7.
//
// SIN CÍRCULO DE ICONO TEÑIDO A LA IZQUIERDA. Las dos listas de la app
// dibujaban un círculo de 36 dp con fondo de color según el tipo: duplicaba
// una información que el signo del monto ya da y robaba ~48 dp de ancho al
// nombre del movimiento, que es el dato que el usuario lee.
//
// EL GASTO VA EN TINTA, NO EN ROJO. Un gasto corriente no es un error:
// pintar media lista de rojo mata la jerarquía y convierte un hecho normal
// en una alarma. Lo distingue el signo U+2212 y la posición. El ingreso sí
// lleva color (`moneyIn` #0B6A47, 6,63:1) porque es el minoritario y el que
// interesa encontrar de un vistazo.
// Si esa decisión se revierte, el reemplazo correcto NO es #EF4444 (3,76,
// falla AA) sino `moneyOut` #A32019 (7,56): es una línea, [amountColor].
//
// DOS ARREGLOS FUNCIONALES QUE TRAE EL COMPONENTE:
//   (a) El `Dismissible` de finanzas_tab NO definía `onDismissed` y dependía
//       de que el stream de Firestore reemitiera antes de que terminara la
//       animación. Aquí es obligatorio.
//   (b) El gesto de deslizar era el ÚNICO camino para borrar un movimiento,
//       lo que lo hace imposible con lector de pantalla o con temblor. Se
//       añade `customSemanticsActions` y un toque que abre el detalle.
// ═══════════════════════════════════════════════════════════════════════

/// Una línea de la cartola: título, metadato y monto.
///
/// El monto llega ya formateado (`formatSigned`), con su signo dentro del
/// mismo `Text` que la cifra. Nunca como widget aparte: el signo tiene que
/// participar de la alineación tabular de la columna.
class PagateMovementRow extends StatelessWidget {
  /// Nombre del movimiento. Una línea; si no cabe, puntos suspensivos.
  final String title;

  /// Segunda línea, con el formato `12 oct · Materiales`. Lo compone quien
  /// llama, con `formatDayMonth` y la categoría.
  final String meta;

  /// Monto ya formateado, con signo: `+$120.000` o `−$35.000`.
  final String amount;

  /// `true` pinta el monto en `moneyIn`. `false` lo deja en tinta.
  final bool isIncome;

  /// Abre el detalle. Es el camino accesible para cualquier acción sobre el
  /// movimiento, incluida la de borrarlo.
  final VoidCallback? onTap;

  /// Si se pasa, la fila se puede deslizar de derecha a izquierda para
  /// eliminar. El `Future<bool>` es la confirmación: devolver `false`
  /// cancela y la fila vuelve a su sitio.
  final Future<bool> Function()? onConfirmDelete;

  /// Se ejecuta cuando la fila ya salió de la lista. Obligatorio junto con
  /// [onConfirmDelete]: es lo que faltaba y provocaba que la lista quedara
  /// con un hueco si el stream tardaba.
  final VoidCallback? onDeleted;

  /// Identidad de la fila para el `Dismissible`. El id del documento.
  final String? dismissKey;

  const PagateMovementRow({
    super.key,
    required this.title,
    required this.meta,
    required this.amount,
    required this.isIncome,
    this.onTap,
    this.onConfirmDelete,
    this.onDeleted,
    this.dismissKey,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: ConstrainedBox(
        // 40 + 12 + 12 = los 64 dp mínimos de la fila de movimiento.
        constraints: const BoxConstraints(minHeight: _altoContenido),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            // Ver el mismo comentario en `PagateDataRow`: el monto tiene que
            // poder encoger o la fila desborda con la fuente del sistema
            // ampliada.
            Flexible(
              child: Text(
                amount,
                textAlign: TextAlign.right,
                style: AppText.amountRow.copyWith(color: amountColor),
              ),
            ),
          ],
        ),
      ),
    );

    Widget fila = Material(
      color: AppPalette.surface,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppPalette.sunken,
        splashFactory: NoSplash.splashFactory,
        child: contenido,
      ),
    );

    if (onConfirmDelete != null && dismissKey != null) {
      fila = Dismissible(
        key: ValueKey(dismissKey),
        direction: DismissDirection.endToStart,
        background: _fondoEliminar(theme),
        confirmDismiss: (final _) => onConfirmDelete!(),

        // Lo que faltaba: sin esto la fila desaparece de la pantalla pero
        // sigue en el árbol hasta que el stream reemite.
        onDismissed: (final _) => onDeleted?.call(),
        child: fila,
      );

      // El deslizamiento no existe para un lector de pantalla. Esta acción
      // personalizada es la que lo hace alcanzable.
      fila = Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Eliminar movimiento'): () {
            onConfirmDelete!().then((final confirmado) {
              if (confirmado) onDeleted?.call();
            });
          },
        },
        child: fila,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        fila,
        const Divider(
          height: AppSizes.borderHairline,
          thickness: AppSizes.borderHairline,
          color: AppPalette.hairline,
        ),
      ],
    );
  }

  /// Ingreso en verde dinero; gasto en tinta. Ver la cabecera del archivo.
  Color get amountColor =>
      isIncome ? AppPalette.moneyIn : AppPalette.textPrimary;

  /// Fondo que aparece bajo la fila al deslizar: `dangerSurface` con el
  /// icono y la palabra en `danger` (6,49:1). La palabra no sobra: un icono
  /// solo de papelera no dice si borra la fila o la lista entera.
  Widget _fondoEliminar(final ThemeData theme) => ColoredBox(
        color: AppPalette.dangerSurface,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: AppIconSize.sm,
                  color: AppPalette.danger,
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Eliminar',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppPalette.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  static const double _altoContenido = 40;
}

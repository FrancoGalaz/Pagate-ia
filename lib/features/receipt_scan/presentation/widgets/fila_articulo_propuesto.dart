import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/domain/entities/inventory_item_type.dart';
import '../../domain/entities/scanned_line_item.dart';

// ═══════════════════════════════════════════════════════════════════════
// UNA FILA DE LA LISTA PROPUESTA
// ═══════════════════════════════════════════════════════════════════════
// NO ES EDITABLE EN LÍNEA, Y ES A PROPÓSITO. Cinco campos editables en una
// fila serían cinco cajas táctiles por debajo de los 48 dp que manda el
// sistema (docs/DISENO-v2.md, "ÁREAS TÁCTILES"). La fila muestra y la hoja
// edita.
//
// LA CIFRA DE LA DERECHA ES `cantidad × precio unitario`, nunca abreviada
// y con figuras tabulares. Es la que deja la consecuencia a la vista antes
// de guardar: con un solo monto en la línea, la diferencia entre leerlo
// como unitario o como total es el doble de dinero, y esta fila es el
// único sitio donde el usuario puede verlo antes de que entre al
// inventario.
// ═══════════════════════════════════════════════════════════════════════

class FilaArticuloPropuesto extends StatelessWidget {
  const FilaArticuloPropuesto({
    super.key,
    required this.item,
    required this.onAlternar,
    required this.onAbrir,
    required this.mostrarDivisor,
  });

  final ScannedLineItem item;
  final ValueChanged<bool> onAlternar;
  final VoidCallback onAbrir;
  final bool mostrarDivisor;

  /// Segunda línea. Cuando hay algo que avisar, el aviso MANDA sobre el
  /// detalle: el tipo y la unidad se ven en la hoja, pero "no encontré este
  /// nombre en la boleta" solo se puede decir aquí.
  String get _subtitulo {
    if (item.notInText) return 'No encontré este nombre en la boleta';

    final partes = <String>[
      item.type == InventoryItemType.product ? 'producto' : 'material',
      item.unit,
    ];

    if (item.matches && item.action == ScanAction.sumarStock) {
      return 'Ya existe · stock ${item.matchedStock} → ${item.stockResultante}';
    }
    if (item.matches) {
      return '${partes.join(' · ')} · ficha nueva aunque ya existe';
    }
    if (item.ambiguous) {
      return '${partes.join(' · ')} · un solo monto en la línea';
    }
    return '${partes.join(' · ')} · '
        '${formatCurrency(item.lineTotal, currency: kFallbackCurrency)} '
        'en total';
  }

  /// Ámbar solo cuando hay algo que revisar de verdad. El color NO es el
  /// único portador: el texto lo dice igual (WCAG 1.4.1).
  Color get _colorDelSubtitulo =>
      item.notInText || item.ambiguous ? AppPalette.warning : AppPalette.textMuted;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final cifra = '${item.quantity} × '
        '${formatCurrency(item.unitPrice, currency: kFallbackCurrency)}';

    final fila = Material(
      color: AppPalette.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // La casilla lleva su propia caja táctil de 48: tocar el nombre
          // abre la hoja y tocar la casilla incluye o excluye, así que las
          // dos zonas tienen que ser inequívocas y grandes.
          Semantics(
            label: 'Incluir ${item.name}',
            child: Checkbox(
              value: item.included,
              onChanged: (final valor) => onAlternar(valor ?? false),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onAbrir,
              highlightColor: AppPalette.sunken,
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.x3,
                  horizontal: AppSpacing.x1,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _altoMinimo),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.x1),
                            Text(
                              _subtitulo,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _colorDelSubtitulo,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Expanded(
                        flex: 2,
                        child: Text(
                          cifra,
                          textAlign: TextAlign.right,
                          style: AppText.amountRow.copyWith(
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: AppIconSize.sm,
                        color: AppPalette.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
        ],
      ),
    );

    if (!mostrarDivisor) return fila;

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

  /// 24 de contenido + 12 + 12 de relleno = los 48 dp del sistema, sin fijar
  /// el alto para que crezca con el ajuste de fuente del teléfono.
  static const double _altoMinimo = 24;
}

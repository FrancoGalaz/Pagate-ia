import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../providers/inventory_provider.dart';
import '../widgets/item_form_sheet.dart';
import 'detalle_item_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA DE INVENTARIO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7 ("barrido del resto"). No es un
// rediseño: es aplicar el sistema que ya existe en Inicio y Finanzas.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · LAS 22 REFERENCIAS A LOS TOKENS DEL TEMA OSCURO. Eran los alias del
//   paso 3, que mienten a propósito: el token de superficie devolvía blanco
//   pero el código seguía diciendo "oscuro". Ahora nombran lo que pintan.
//
// · LAS TARJETAS DE ÍTEM (`Container` de radio 24 con borde, una por fila,
//   separadas por 8 dp) pasan a filas de una sección: [PagateSectionCard]
//   con [PagateDataRow]. Es el mismo píxel que la lista de movimientos de
//   Finanzas, y recupera los 48 dp de ancho que la caja le robaba al nombre.
//
// · `_TypeTab`, el cuarto patrón de selección de la app: un
//   `GestureDetector` sobre un `AnimatedContainer` de radio 100 y ~33 dp de
//   caja táctil, que no anunciaba ningún rol al lector de pantalla. Pasa a
//   [PagateChip], que es un `ChoiceChip` de Material con caja de 48.
//
// · EL VACÍO CENTRADO con un icono de 48 dp pasa a [PagateEmptyState]:
//   alineado a la izquierda, sin icono, y con la acción que corresponde.
//
// · EL `CircularProgressIndicator` CENTRADO pasa a [PagateSkeleton]: la
//   lista aparece donde va a estar, no después de un hueco en blanco.
//
// · LA HOJA DE NUEVO ÍTEM. Tenía cinco `TextField` con su decoración
//   escrita a mano (radio 20, relleno `surfaceDarkSecondary`), validaba
//   los cinco campos de golpe con un solo aviso genérico, no tenía
//   `PopScope` —el botón atrás descartaba cinco campos escritos sin
//   avisar—, no tenía `isLoading` —se podía guardar dos veces el mismo
//   ítem— y mostraba el error en un aviso flotante que se iba. Ahora es
//   una [PagateSheet] con `Form`, un mensaje por campo, confirmación de
//   cierre, botón con spinner y el error DENTRO de la hoja. Y ya no vive
//   aquí: pasó a `../widgets/item_form_sheet.dart` porque la comparten la
//   lista (alta) y la ficha (edición), que están en archivos distintos.
//
// · EL FAB conserva su sitio (el paso 7 no toca el layout) pero pierde la
//   elevación: el sistema no lleva sombra en ningún control. Gana el
//   `tooltip` que le faltaba.
// ═══════════════════════════════════════════════════════════════════════

class InventarioTab extends StatelessWidget {
  const InventarioTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Stack(
      children: [
        Column(
          children: [
            _InventarioHeader(activeTab: provider.activeTab),
            Expanded(
              child: provider.error != null
                  ? ListView(
                      padding: const EdgeInsets.only(top: AppSpacing.x6),
                      children: [
                        PagateErrorState(
                          message: provider.error!,
                          onRetry: provider.retry,
                        ),
                      ],
                    )
                  : provider.isLoading
                      ? ListView(children: [PagateSkeleton.rows(5)])
                      : _ItemList(
                          items: provider.items,
                          isSearching: provider.searchQuery.isNotEmpty,
                          activeTab: provider.activeTab,
                        ),
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.x4,
          bottom: AppSpacing.x4,
          child: FloatingActionButton(
            heroTag: 'inventario_agregar',
            tooltip: provider.activeTab == InventoryItemType.product
                ? 'Agregar producto'
                : 'Agregar material',

            // Cero sombra, como todo control del sistema: el FAB se separa
            // del lienzo por su relleno de marca, que da 6,43 contra blanco.
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            disabledElevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.r12)),
            ),
            backgroundColor: AppPalette.brand,
            foregroundColor: AppPalette.textOnBrand,
            onPressed: provider.error != null
                ? null
                : () => mostrarHojaDeItem(context, provider.activeTab),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

// ─── Cabecera: título, búsqueda y tipo ─────────────────────────────────

class _InventarioHeader extends StatelessWidget {
  const _InventarioHeader({required this.activeTab});

  final InventoryItemType activeTab;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              // Mismo alto de cabecera que Finanzas, para que el título no
              // salte al cambiar de pestaña.
              constraints: const BoxConstraints(minHeight: _altoTitulo),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              onChanged: (final q) =>
                  context.read<InventoryProvider>().search(q),
              textInputAction: TextInputAction.search,

              // Toda la decoración sale de `inputDecorationTheme`: borde de
              // 1 dp `borderField` (3,63:1), relleno blanco y radio 12. Lo
              // único propio es el icono de lupa, que aquí SÍ informa (dice
              // que el campo busca, no que escribe).
              decoration: const InputDecoration(
                hintText: 'Buscar producto o material',
                prefixIcon: Icon(Icons.search_rounded, size: AppIconSize.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: [
                PagateChip(
                  label: 'Productos',
                  isSelected: activeTab == InventoryItemType.product,
                  onSelected: () => context
                      .read<InventoryProvider>()
                      .setActiveTab(InventoryItemType.product),
                ),
                const SizedBox(width: AppSpacing.x2),
                PagateChip(
                  label: 'Materiales',
                  isSelected: activeTab == InventoryItemType.material,
                  onSelected: () => context
                      .read<InventoryProvider>()
                      .setActiveTab(InventoryItemType.material),
                ),
              ],
            ),
          ],
        ),
      );

  static const double _altoTitulo = 40;
}

// ─── Lista ─────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.activeTab,
    this.isSearching = false,
  });

  final List<InventoryItemEntity> items;
  final InventoryItemType activeTab;
  final bool isSearching;

  @override
  Widget build(final BuildContext context) {
    final esProducto = activeTab == InventoryItemType.product;

    if (items.isEmpty) {
      return ListView(
        children: [
          PagateSectionCard(
            child: isSearching
                ? const PagateEmptyState(
                    title: 'Sin resultados',
                    description:
                        'Ninguna ficha coincide con lo que escribiste. '
                        'Prueba con menos letras.',
                  )
                : PagateEmptyState(
                    title: esProducto
                        ? 'Sin productos registrados'
                        : 'Sin materiales registrados',
                    description: esProducto
                        ? 'Anota lo que vendes, con su precio y su stock, '
                            'para saber qué te queda.'
                        : 'Anota lo que compras para producir, con su precio '
                            'y su stock.',
                    actionLabel: esProducto ? 'Agregar producto' : 'Agregar material',
                    onAction: () => mostrarHojaDeItem(context, activeTab),
                  ),
          ),
        ],
      );
    }

    return ListView(
      // El hueco del FAB: 56 de botón + 16 de margen + 16 de aire.
      padding: const EdgeInsets.only(bottom: _huecoDelFab),
      children: [
        PagateSectionCard(
          child: Column(
            children: [
              // Por índice y no por `item == items.last`: dos fichas con los
              // mismos campos son iguales para Equatable y marcarían las dos
              // como última, dejando una fila sin divisor.
              for (var i = 0; i < items.length; i++)
                _FilaDeItem(
                  item: items[i],
                  esUltima: i == items.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static const double _huecoDelFab = 88;
}

/// Una ficha del inventario, como fila de cartola.
///
/// La CIFRA de la fila es el stock, no el precio, y es deliberado: en esta
/// pantalla lo que se consulta es cuánto queda. El precio baja a la línea de
/// metadato, donde ya va formateado por `formatCurrency`.
class _FilaDeItem extends StatelessWidget {
  const _FilaDeItem({required this.item, required this.esUltima});

  final InventoryItemEntity item;
  final bool esUltima;

  /// Rojo para "sin stock", ámbar para "bajo del mínimo" y tinta normal
  /// cuando no hay nada que avisar. Mismo criterio que la lista de stock de
  /// Inicio, para que el color signifique lo mismo en las dos pantallas.
  Color? get _colorDelStock {
    switch (item.stockStatus) {
      case StockStatus.critical:
        return AppPalette.danger;
      case StockStatus.low:
        return AppPalette.warning;
      case StockStatus.ok:
        return null;
    }
  }

  /// El estado en palabras. El color no basta: WCAG 1.4.1 prohíbe que el
  /// color sea el único portador de la información.
  String? get _estadoEnPalabras {
    switch (item.stockStatus) {
      case StockStatus.critical:
        return 'Sin stock';
      case StockStatus.low:
        return 'Bajo el mínimo';
      case StockStatus.ok:
        return null;
    }
  }

  @override
  Widget build(final BuildContext context) {
    final precio = formatCurrency(item.price, currency: kFallbackCurrency);
    final estado = _estadoEnPalabras;

    return PagateDataRow(
      label: item.name,
      subtitle: estado == null ? precio : '$precio · $estado',
      value: '${item.stock} ${item.unit}',
      valueColor: _colorDelStock,
      showDivider: !esUltima,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (final _) => DetalleItemScreen(item: item),
        ),
      ),
    );
  }
}

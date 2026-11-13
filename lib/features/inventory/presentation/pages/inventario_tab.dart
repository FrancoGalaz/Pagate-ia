import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../receipt_scan/presentation/widgets/hoja_origen_de_ficha.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../providers/inventory_provider.dart';
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
//   caja táctil, que no anunciaba ningún rol al lector de pantalla. Pasó a
//   [PagateChip] y, con la variante A, a [PagateSegmented]: dos opciones
//   excluyentes, como Ingreso/Gasto.
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
// · EL FAB conserva su sitio y gana el `tooltip` que le faltaba. Con la
//   variante A lleva radio 18 y `sombra-2`, y la lista deja al final el
//   hueco de 88 dp para que no tape la última fila.
//
// QUÉ CAMBIÓ CON EL LECTOR DE BOLETAS. El FAB y la acción del estado vacío
// ya no abren el formulario manual: abren [abrirAgregarAlInventario], que
// es el punto de entrada único. En Android e iOS ofrece las tres formas de
// crear una ficha (a mano, foto de la boleta, imagen de la galería) y en
// web y escritorio va directo al formulario de siempre, porque allí los
// plugins de lectura no están registrados. Esta pestaña no sabe de
// plataformas: la decisión vive en un solo sitio.
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
          // Variante A: radio 18 y `sombra-2`, la de lo que flota sobre la
          // lista. La sombra va en una caja propia porque la del FAB es la
          // de Material, más dura.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(_radioFab)),
              boxShadow: AppShadows.level2,
            ),
            child: FloatingActionButton(
              heroTag: 'inventario_agregar',
              tooltip: provider.activeTab == InventoryItemType.product
                  ? 'Agregar producto'
                  : 'Agregar material',
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              disabledElevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_radioFab)),
              ),
              backgroundColor: AppPalette.brand,
              foregroundColor: AppPalette.textOnBrand,
              onPressed: provider.error != null
                  ? null
                  : () => abrirAgregarAlInventario(context, provider.activeTab),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }

  static const double _radioFab = 18;
}

// ─── Cabecera: título, tipo y búsqueda ─────────────────────────────────

class _InventarioHeader extends StatelessWidget {
  const _InventarioHeader({required this.activeTab});

  final InventoryItemType activeTab;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<InventoryProvider>();
    final todo = provider.inventarioCompleto;
    final productos = todo
        .where((final i) => i.type == InventoryItemType.product)
        .length;
    final materiales = todo.length - productos;

    return Padding(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Inventario', style: theme.textTheme.headlineMedium),
                // Cuánto hay de cada tipo, de un vistazo y sin cambiar de
                // pestaña. Mientras carga, nada: un «0 productos» mentiría.
                if (!provider.isLoading && provider.error == null)
                  Text(
                    '${_cuantos(productos, 'producto', 'productos')} · '
                    '${_cuantos(materiales, 'material', 'materiales')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          // Dos opciones excluyentes: segmentado, como Ingreso/Gasto.
          PagateSegmented<InventoryItemType>(
            options: const [
              (InventoryItemType.product, 'Productos'),
              (InventoryItemType.material, 'Materiales'),
            ],
            selected: activeTab,
            onChanged: context.read<InventoryProvider>().setActiveTab,
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            onChanged: (final q) => context.read<InventoryProvider>().search(q),
            textInputAction: TextInputAction.search,

            // Toda la decoración sale de `inputDecorationTheme`. Lo único
            // propio es la lupa, que aquí SÍ informa: dice que el campo
            // busca. Y busca también por código: el provider lo compara.
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o código',
              prefixIcon: Icon(Icons.search_rounded, size: AppIconSize.sm),
            ),
          ),
        ],
      ),
    );
  }

  static String _cuantos(final int n, final String uno, final String varios) =>
      '$n ${n == 1 ? uno : varios}';

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
                    actionLabel:
                        esProducto ? 'Agregar producto' : 'Agregar material',
                    onAction: () =>
                        abrirAgregarAlInventario(context, activeTab),
                  ),
          ),
        ],
      );
    }

    return ListView(
      // El hueco del FAB: sin él, el + tapaba la última fila.
      padding: const EdgeInsets.only(bottom: huecoDelFab),
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

  /// 56 del FAB + 16 de margen + 16 de aire.
  static const double huecoDelFab = 88;
}

/// Una ficha del inventario, como fila de cartola.
///
/// La CIFRA de la fila es el stock, no el precio, y es deliberado: en esta
/// pantalla lo que se consulta es cuánto queda. Va en una píldora a la
/// derecha; el precio y el mínimo bajan a la línea de metadato.
class _FilaDeItem extends StatelessWidget {
  const _FilaDeItem({required this.item, required this.esUltima});

  final InventoryItemEntity item;
  final bool esUltima;

  @override
  Widget build(final BuildContext context) {
    final precio = formatCurrency(item.price, currency: kFallbackCurrency);

    // El estado también en palabras: WCAG 1.4.1 prohíbe que el color sea el
    // único portador de la información. «Sin stock» lo dice la píldora;
    // «bajo el mínimo», el metadato.
    final metadato = switch (item.stockStatus) {
      StockStatus.low => '$precio · bajo el mínimo (${item.minStock})',
      _ => '$precio · mínimo ${item.minStock}',
    };

    // Con letra de 1,5 o más la píldora no cabe al lado del nombre: el
    // stock baja bajo el nombre como el valor de cualquier fila, con el
    // mismo color.
    final apilado = MediaQuery.textScalerOf(context).scale(10) >= 15;

    return PagateDataRow(
      icon: item.type == InventoryItemType.product
          ? Icons.inventory_2_outlined
          : Icons.category_outlined,
      label: item.name,
      subtitle: metadato,
      subtitleMaxLines: 2,
      value: apilado ? _PildoraDeStock.texto(item) : '',
      valueColor: item.stockStatus == StockStatus.ok
          ? null
          : AppPalette.danger,
      trailing: apilado ? null : _PildoraDeStock(item: item),
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

/// El stock en una píldora: «5 unidades» en el suave, y en carmesí cuando
/// es una alerta («Sin stock», o bajo el mínimo). El carmesí es solo para
/// alertas, y estas lo son.
class _PildoraDeStock extends StatelessWidget {
  const _PildoraDeStock({required this.item});

  final InventoryItemEntity item;

  /// «Sin stock» o «5 unidades».
  static String texto(final InventoryItemEntity item) =>
      item.stockStatus == StockStatus.critical
          ? 'Sin stock'
          : '${item.stock} ${item.unit}';

  @override
  Widget build(final BuildContext context) {
    final alerta = item.stockStatus != StockStatus.ok;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.x3),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2 + 2,
          vertical: AppSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: alerta ? AppPalette.dangerSurface : AppPalette.sunken,
          borderRadius: AppRadius.fullBorder,
        ),
        child: Text(
          texto(item),
          maxLines: 1,
          softWrap: false,
          style: AppText.weight(
            Theme.of(context).textTheme.labelMedium!,
            800,
          ).copyWith(color: alerta ? AppPalette.danger : AppPalette.ink),
        ),
      ),
    );
  }
}

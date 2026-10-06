import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/widgets.dart';
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
//   cierre, botón con spinner y el error DENTRO de la hoja.
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

// ─── Hoja de nuevo ítem ────────────────────────────────────────────────

/// Abre el formulario de nuevo producto o material.
///
/// Toma el [InventoryProvider] del [context] que recibe y no del contexto de
/// la hoja: los providers viven por debajo del Navigator raíz.
Future<void> mostrarHojaDeItem(
  final BuildContext context,
  final InventoryItemType tipo,
) {
  final provider = context.read<InventoryProvider>();
  return showPagateSheet<void>(
    context: context,
    builder: (final _) => ChangeNotifierProvider<InventoryProvider>.value(
      value: provider,
      child: _HojaDeItem(tipo: tipo),
    ),
  );
}

class _HojaDeItem extends StatefulWidget {
  const _HojaDeItem({required this.tipo});

  final InventoryItemType tipo;

  @override
  State<_HojaDeItem> createState() => _HojaDeItemState();
}

class _HojaDeItemState extends State<_HojaDeItem> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _minimo = TextEditingController(text: '1');
  late final _unidad = TextEditingController(
    text: widget.tipo == InventoryItemType.product ? 'piezas' : 'unidades',
  );

  bool _guardando = false;

  /// Mensaje del último guardado fallido. Se dibuja DENTRO de la hoja: el
  /// aviso flotante que había lo pintaba el Scaffold de detrás y quedaba
  /// tapado por la propia hoja.
  String? _errorGuardado;

  bool get _esProducto => widget.tipo == InventoryItemType.product;

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    _stock.dispose();
    _minimo.dispose();
    _unidad.dispose();
    super.dispose();
  }

  /// `true` si hay algo escrito que se perdería al cerrar.
  bool get _tieneCambios =>
      _nombre.text.trim().isNotEmpty || _precio.text.trim().isNotEmpty;

  /// Confirma el cierre cuando hay datos a medio escribir.
  Future<bool> _confirmarCierre() async {
    if (_guardando) return false;
    if (!_tieneCambios) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (final dialogo) => AlertDialog(
        title: const Text('¿Descartar la ficha?'),
        content: const Text(
          'Lo que escribiste no se va a guardar.',
        ),
        actions: [
          PagatePrimaryButton.text(
            label: 'Seguir editando',
            onPressed: () => Navigator.pop(dialogo, false),
          ),
          PagatePrimaryButton.text(
            label: 'Descartar',
            isDestructive: true,
            onPressed: () => Navigator.pop(dialogo, true),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  /// Valida un entero no negativo. Devuelve `null` si es válido.
  String? _validarEntero(final String? valor, final String queFalta) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe $queFalta';
    final numero = int.tryParse(texto);
    if (numero == null) return 'Usa solo números enteros';
    if (numero < 0) return 'No puede ser negativo';
    return null;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // `parseCurrencyInput` y no `double.tryParse`: un precio escrito
    // "150.000" como lo escribe un chileno se guardaba como 150 pesos.
    final precio = parseCurrencyInput(_precio.text);
    if (precio == null) return;

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    final provider = context.read<InventoryProvider>();
    final navigator = Navigator.of(context);
    try {
      await provider.addItem(
        name: _nombre.text.trim(),
        type: widget.tipo,
        price: precio,
        stock: int.parse(_stock.text.trim()),
        minStock: int.parse(_minimo.text.trim()),
        unit: _unidad.text.trim(),
      );
      if (!mounted) return;
      navigator.pop();
      AppFeedback.showMessage(
        context,
        _esProducto ? 'Producto agregado.' : 'Material agregado.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = InventoryProvider.describeError(
          e,
          operation: DataOperation.write,
          fallback: 'No se pudo guardar la ficha',
        );
      });
    }
  }

  @override
  Widget build(final BuildContext context) => PagateSheet(
        title: _esProducto ? 'Nuevo producto' : 'Nuevo material',
        onIntentarCerrar: _confirmarCierre,
        primaryAction: PagatePrimaryButton(
          label: 'Guardar ficha',
          isLoading: _guardando,
          onPressed: _guardar,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PagateTextField(
                labelText: 'Nombre',
                controller: _nombre,
                hintText: _esProducto ? 'Ej: taza de greda' : 'Ej: greda 25 kg',
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un nombre'
                    : null,
              ),
              const SizedBox(height: AppSpacing.x4),

              PagateTextField.amount(
                labelText: 'Precio',
                controller: _precio,
                hintText: '0',
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (final v) {
                  final precio = parseCurrencyInput(v ?? '');
                  if (precio == null) return 'Ingresa un precio válido';
                  if (precio < 0) return 'El precio no puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.x4),

              // Stock y mínimo en la misma línea: son el mismo dato medido
              // de dos formas y se comparan de un vistazo.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PagateTextField(
                      labelText: 'Stock',
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (final v) =>
                          _validarEntero(v, 'cuántas unidades tienes'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: PagateTextField(
                      labelText: 'Mínimo',
                      controller: _minimo,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (final v) =>
                          _validarEntero(v, 'el mínimo que quieres mantener'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),

              PagateTextField(
                labelText: 'Unidad',
                controller: _unidad,
                hintText: 'piezas, kg, litros',
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (final _) => _guardar(),
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe la unidad en la que lo mides'
                    : null,
              ),

              if (_errorGuardado != null) ...[
                const SizedBox(height: AppSpacing.x4),
                PagateInlineError(message: _errorGuardado),
              ],
            ],
          ),
        ),
      );
}

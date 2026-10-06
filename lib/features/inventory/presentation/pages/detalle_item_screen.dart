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

// ═══════════════════════════════════════════════════════════════════════
// DETALLE DE UNA FICHA DE INVENTARIO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · EL HÉROE DE MARCA: un bloque de radio 32 relleno con el degradado de
//   marca, con un cuadrado blanco al 20% dentro, un icono de 36 dp y el nombre en
//   blanco centrado. Era el único sitio de la app con texto blanco sobre
//   verde a tamaño de titular, no decía nada que el nombre no dijera y el
//   `Colors.white70` del código daba 2,9:1 sobre el verde de marca. Ahora
//   el nombre es el titular de la pantalla, en tinta sobre el lienzo.
//
// · EL AVISO DE STOCK pintado con `_statusColor.withValues(alpha: 0.1)` y
//   borde al 30%: dos opacidades inventadas sobre un fondo que ya no es
//   oscuro. Pasa a las superficies planas del sistema
//   (`dangerSurface` / `warningSurface` / `moneyInSurface`), cada una con su
//   borde de 1 dp y su color de texto verificado.
//
// · `_DetailCard` + `_DetailRow`, la segunda de las seis reimplementaciones
//   de la fila etiqueta/valor. Pasan a [PagateSectionCard] y
//   [PagateDataRow], que traen cifras tabulares y divisor a sangre.
//
// · EL BOTÓN "Eliminar Item" en pastilla delineada roja de ancho completo:
//   competía en peso con la acción principal. Pasa a la variante de texto
//   destructiva del sistema.
//
// · LOS DOS `AlertDialog`. El de actualizar stock no validaba hasta pulsar,
//   no tenía estado de carga (se podía guardar dos veces) y apilaba sus
//   botones a ancho completo, porque el tema impone
//   `minimumSize: Size(infinity, 48)` al botón elevado y dentro del
//   `OverflowBar` de un diálogo eso descoloca la jerarquía. El de stock pasa
//   a hoja con `Form`; el de borrado conserva el diálogo (es una pregunta de
//   una línea) pero con botones de texto.
// ═══════════════════════════════════════════════════════════════════════

class DetalleItemScreen extends StatelessWidget {
  const DetalleItemScreen({super.key, required this.item});

  /// La ficha con la que se abrió la pantalla. Es el punto de partida, no la
  /// fuente de verdad: ver [_vigente].
  final InventoryItemEntity item;

  /// La ficha tal como está AHORA en el stream, o la de partida si ya no
  /// está en la lista (porque se borró, o porque el usuario cambió de
  /// pestaña mientras tenía el detalle abierto).
  ///
  /// EL DEFECTO QUE ARREGLA, visto en emulator-5554: la pantalla recibía la
  /// entidad por constructor y no volvía a leerla nunca. Tras actualizar el
  /// stock de 3 a 9 salía el aviso "Stock actualizado.", la lista de
  /// Inventario mostraba 9 —el stream sí reemite— y esta pantalla seguía
  /// diciendo "3 unidad" y "Bajo el mínimo". Una app de inventario que
  /// confirma un cambio y sigue mostrando el valor viejo es peor que una que
  /// no confirma nada.
  ///
  /// Principio 5 de docs/ARQUITECTURA.md: las lecturas son streams.
  InventoryItemEntity _vigente(final BuildContext context) {
    final items = context.watch<InventoryProvider>().items;
    for (final candidato in items) {
      if (candidato.id == item.id) return candidato;
    }
    return item;
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final item = _vigente(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ficha'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.x8),
          children: [
            // ─── Nombre: el titular de la pantalla ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    item.type == InventoryItemType.product
                        ? 'Producto'
                        : 'Material',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  if (item.code != null) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      'Código ${item.code}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            _AvisoDeStock(item: item),

            const SizedBox(height: AppSpacing.x6),

            // ─── Los datos de la ficha ──────────────────────────────
            PagateSectionCard(
              child: Column(
                children: [
                  PagateDataRow(
                    label: 'Precio',
                    value: formatCurrency(
                      item.price,
                      currency: kFallbackCurrency,
                    ),
                  ),
                  PagateDataRow(
                    label: 'Stock actual',
                    value: '${item.stock} ${item.unit}',
                  ),
                  PagateDataRow(
                    label: 'Stock mínimo',
                    value: '${item.minStock} ${item.unit}',
                    showDivider: item.supplier != null,
                  ),
                  if (item.supplier != null)
                    PagateDataRow(
                      label: 'Proveedor',
                      value: item.supplier!,
                      showDivider: false,
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.x8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PagatePrimaryButton(
                    label: 'Actualizar stock',
                    onPressed: () => mostrarHojaDeStock(context, item),
                  ),
                  const SizedBox(height: AppSpacing.x3),

                  // Variante de texto destructiva, no una pastilla roja de
                  // ancho completo: borrar la ficha no compite en peso con
                  // actualizar el stock.
                  PagatePrimaryButton.text(
                    label: 'Eliminar ficha',
                    isDestructive: true,
                    leadingIcon: Icons.delete_outline_rounded,
                    onPressed: () => _confirmarBorrado(context, item),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de stock, con el estado dicho en palabras y no solo en color.
///
/// WCAG 1.4.1: el color no puede ser el único portador de la información.
class _AvisoDeStock extends StatelessWidget {
  const _AvisoDeStock({required this.item});

  final InventoryItemEntity item;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final (Color fondo, Color tinta, IconData icono, String etiqueta) =
        switch (item.stockStatus) {
      StockStatus.critical => (
          AppPalette.dangerSurface,
          AppPalette.danger,
          Icons.error_outline_rounded,
          'Sin stock',
        ),
      StockStatus.low => (
          AppPalette.warningSurface,
          AppPalette.warning,
          Icons.warning_amber_rounded,
          'Bajo el mínimo',
        ),
      StockStatus.ok => (
          AppPalette.moneyInSurface,
          AppPalette.moneyIn,
          Icons.check_circle_outline_rounded,
          'Stock suficiente',
        ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: AppRadius.r12Border,
        border: Border.all(color: tinta, width: AppSizes.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorativo: la etiqueta de al lado ya dice el estado.
          ExcludeSemantics(
            child: Icon(icono, size: AppIconSize.sm, color: tinta),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              // La unidad la escribe el usuario ("unidad", "kg", "set"), así
              // que la frase no puede concordar con ella: "3 de 12 unidad
              // mínimas" era lo que salía en pantalla. Con la unidad pegada
              // al número y el mínimo aparte, funciona con cualquier palabra.
              '$etiqueta · ${item.stock} ${item.unit}, '
              'mínimo ${item.minStock}',
              style: theme.textTheme.bodyMedium?.copyWith(color: tinta),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Actualizar stock ──────────────────────────────────────────────────

/// Abre la hoja para corregir el stock de [item].
Future<void> mostrarHojaDeStock(
  final BuildContext context,
  final InventoryItemEntity item,
) {
  final provider = context.read<InventoryProvider>();
  return showPagateSheet<void>(
    context: context,
    builder: (final _) => ChangeNotifierProvider<InventoryProvider>.value(
      value: provider,
      child: _HojaDeStock(item: item),
    ),
  );
}

class _HojaDeStock extends StatefulWidget {
  const _HojaDeStock({required this.item});

  final InventoryItemEntity item;

  @override
  State<_HojaDeStock> createState() => _HojaDeStockState();
}

class _HojaDeStockState extends State<_HojaDeStock> {
  final _formKey = GlobalKey<FormState>();
  late final _stock = TextEditingController(
    text: widget.item.stock.toString(),
  );

  bool _guardando = false;
  String? _errorGuardado;

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    final provider = context.read<InventoryProvider>();
    final navigator = Navigator.of(context);
    try {
      await provider.updateStock(
        itemId: widget.item.id,
        newStock: int.parse(_stock.text.trim()),
      );
      if (!mounted) return;
      navigator.pop();
      AppFeedback.showMessage(context, 'Stock actualizado.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = InventoryProvider.describeError(
          e,
          operation: DataOperation.write,
          fallback: 'No se pudo actualizar el stock',
        );
      });
    }
  }

  @override
  Widget build(final BuildContext context) => PagateSheet(
        title: 'Actualizar stock',
        primaryAction: PagatePrimaryButton(
          label: 'Guardar',
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
                labelText: 'Unidades que tienes ahora',
                controller: _stock,
                helperText: 'Mínimo que quieres mantener: '
                    '${widget.item.minStock} ${widget.item.unit}',
                keyboardType: TextInputType.number,
                autofocus: true,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onFieldSubmitted: (final _) => _guardar(),
                validator: (final v) {
                  final texto = (v ?? '').trim();
                  if (texto.isEmpty) return 'Escribe cuántas unidades tienes';
                  final numero = int.tryParse(texto);
                  if (numero == null) return 'Usa solo números enteros';
                  if (numero < 0) return 'No puede ser negativo';
                  return null;
                },
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

// ─── Borrado ───────────────────────────────────────────────────────────

/// Pregunta y, si la respuesta es sí, borra la ficha y vuelve a la lista.
Future<void> _confirmarBorrado(
  final BuildContext context,
  final InventoryItemEntity item,
) async {
  final provider = context.read<InventoryProvider>();

  final borrar = await showDialog<bool>(
    context: context,
    builder: (final dialogo) => AlertDialog(
      title: const Text('¿Eliminar la ficha?'),
      content: Text(
        '${item.name} deja de aparecer en tu inventario. Los movimientos '
        'que ya registraste no cambian.',
      ),
      actions: [
        // Botones de texto, no elevados: el tema impone ancho completo al
        // elevado y dentro de un diálogo eso los apila y descoloca la
        // jerarquía Cancelar / Eliminar.
        PagatePrimaryButton.text(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(dialogo, false),
        ),
        PagatePrimaryButton.text(
          label: 'Eliminar',
          isDestructive: true,
          onPressed: () => Navigator.pop(dialogo, true),
        ),
      ],
    ),
  );

  if (borrar != true || !context.mounted) return;

  try {
    await provider.deleteItem(item.id);
  } catch (e) {
    if (!context.mounted) return;
    AppFeedback.showError(
      context,
      InventoryProvider.describeError(e, operation: DataOperation.delete),
    );
    return;
  }
  if (!context.mounted) return;
  AppFeedback.showMessage(context, 'Ficha eliminada.');
  Navigator.pop(context);
}

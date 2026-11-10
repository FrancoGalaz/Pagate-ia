import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../inventory/domain/entities/inventory_item_type.dart';
import '../../domain/entities/scanned_line_item.dart';

// ═══════════════════════════════════════════════════════════════════════
// CORREGIR UN ARTÍCULO LEÍDO
// ═══════════════════════════════════════════════════════════════════════
// Es el "el usuario confirma" de "la app propone, el usuario confirma".
// Todo lo que el reconocimiento pudo equivocar se puede arreglar aquí, y
// cada cosa que el código SABE que puede estar mal lo dice en su campo:
//
// · Cantidad fraccionaria → `helperText` con el número de la boleta y el
//   que se va a guardar. No se esconde el redondeo.
// · Un solo monto en la línea → `helperText` bajo el precio explicando que
//   se tomó como precio por unidad.
// · Ficha que ya existe → los dos precios a la vista y un interruptor
//   APAGADO para sobrescribir el guardado.
//
// EL PRECIO SE LEE CON `parseCurrencyInput`, NUNCA CON `double.tryParse`.
// Es el defecto ya documentado en `currency_formatter.dart`: `150.000`
// escrito como lo escribe un chileno se guardaba como 150 pesos.
// ═══════════════════════════════════════════════════════════════════════

/// Abre la hoja de revisión y devuelve el artículo corregido, o `null` si
/// el usuario la cerró sin guardar.
Future<ScannedLineItem?> mostrarHojaRevisarArticulo(
  final BuildContext context,
  final ScannedLineItem item,
) =>
    showPagateSheet<ScannedLineItem>(
      context: context,
      builder: (final _) => HojaRevisarArticulo(item: item),
    );

class HojaRevisarArticulo extends StatefulWidget {
  const HojaRevisarArticulo({super.key, required this.item});

  final ScannedLineItem item;

  @override
  State<HojaRevisarArticulo> createState() => _HojaRevisarArticuloState();
}

class _HojaRevisarArticuloState extends State<HojaRevisarArticulo> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _precio;
  late final TextEditingController _cantidad;
  late final TextEditingController _unidad;
  late final TextEditingController _codigo;
  late final TextEditingController _proveedor;

  late InventoryItemType _tipo;
  late ScanAction _accion;
  late bool _actualizarPrecio;
  late List<String> _valoresIniciales;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nombre = TextEditingController(text: item.name);
    _precio = TextEditingController(text: _precioEditable(item.unitPrice));
    _cantidad = TextEditingController(text: item.quantity.toString());
    _unidad = TextEditingController(text: item.unit);
    _codigo = TextEditingController(text: item.code ?? '');
    _proveedor = TextEditingController(text: item.supplier ?? '');
    _tipo = item.type;
    _accion = item.matches ? item.action : ScanAction.crearFicha;
    _actualizarPrecio = item.updatePrice;
    _valoresIniciales = _valoresActuales;
  }

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _campos =>
      [_nombre, _precio, _cantidad, _unidad, _codigo, _proveedor];

  List<String> get _valoresActuales => [
        ..._campos.map((final c) => c.text),
        _tipo.name,
        _accion.name,
        '$_actualizarPrecio',
      ];

  /// `true` si algo cambió respecto a como se abrió la hoja.
  ///
  /// La pregunta no puede ser "¿hay algo escrito?": los seis campos vienen
  /// llenos de la lectura, así que eso avisaría de perder cambios cada vez
  /// que el usuario abre la hoja y se arrepiente sin tocar nada. Es el mismo
  /// criterio de `item_form_sheet.dart`.
  bool get _tieneCambios {
    final actuales = _valoresActuales;
    for (var i = 0; i < actuales.length; i++) {
      if (actuales[i] != _valoresIniciales[i]) return true;
    }
    return false;
  }

  static String _precioEditable(final double precio) =>
      precio == precio.roundToDouble()
          ? precio.round().toString()
          : precio.toString().replaceAll('.', ',');

  Future<bool> _confirmarCierre() async {
    if (!_tieneCambios) return true;
    final salir = await confirmar(
      context,
      title: '¿Descartar los cambios?',
      message: 'Lo que corregiste no se va a guardar.',
      cancelLabel: 'Seguir editando',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    return salir;
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final precio = parseCurrencyInput(_precio.text);
    if (precio == null) return;
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (cantidad == null || cantidad <= 0) return;

    Navigator.of(context).pop(
      widget.item.copyWith(
        name: _nombre.text.trim(),
        rawQuantity: cantidad.toDouble(),
        unit: _unidad.text.trim().isEmpty ? 'unidades' : _unidad.text.trim(),
        unitPrice: precio,
        code: _codigo.text.trim(),
        limpiarCode: _codigo.text.trim().isEmpty,
        supplier: _proveedor.text.trim(),
        limpiarSupplier: _proveedor.text.trim().isEmpty,
        type: _tipo,
        action: _accion,
        updatePrice: _actualizarPrecio,
        // Al corregir el nombre a mano, el aviso de "no encontré este
        // nombre en la boleta" deja de tener sentido: lo escribió el
        // usuario, no el modelo. Y la casilla se marca, porque corregirlo
        // es justamente decir que sí lo quiere.
        notInText: false,
        included: true,
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);

    return PagateSheet(
      title: 'Revisar el artículo',
      onIntentarCerrar: _confirmarCierre,
      primaryAction: PagatePrimaryButton(
        label: 'Guardar cambios',
        onPressed: _guardar,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.notInText) ...[
              const _AvisoDeLectura(
                mensaje: 'Este nombre no aparece en el texto que leí de la '
                    'boleta. Puede que lo haya completado el asistente. '
                    'Compáralo con el papel antes de guardarlo.',
              ),
              const SizedBox(height: AppSpacing.x4),
            ],

            PagateTextField(
              labelText: 'Nombre',
              controller: _nombre,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: (final v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.x4),

            PagateTextField.amount(
              labelText: 'Precio por unidad',
              controller: _precio,
              hintText: '0',
              textInputAction: TextInputAction.next,
              helperText: item.ambiguous
                  ? 'En la boleta había un solo monto en esta línea. Lo tomé '
                      'como el precio por unidad.'
                  : null,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (final v) {
                final precio = parseCurrencyInput(v ?? '');
                if (precio == null) return 'Ingresa un precio válido';
                if (precio <= 0) return 'El precio tiene que ser mayor que 0';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.x4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PagateTextField(
                    labelText: 'Cantidad',
                    controller: _cantidad,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    helperText: item.tieneCantidadFraccionaria
                        ? 'En la boleta decía '
                            '${_conComa(item.rawQuantity)}. El inventario '
                            'guarda unidades enteras.'
                        : null,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (final v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Usa solo números enteros';
                      if (n <= 0) return 'Tiene que ser 1 o más';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: PagateTextField(
                    labelText: 'Unidad',
                    controller: _unidad,
                    hintText: 'sacos, kg',
                    maxLength: 40,
                    textInputAction: TextInputAction.next,
                    validator: (final v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe la unidad'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),

            Text('Tipo', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.x2),
            Row(
              children: [
                PagateChip(
                  label: 'Material',
                  isSelected: _tipo == InventoryItemType.material,
                  onSelected: () =>
                      setState(() => _tipo = InventoryItemType.material),
                ),
                const SizedBox(width: AppSpacing.x2),
                PagateChip(
                  label: 'Producto',
                  isSelected: _tipo == InventoryItemType.product,
                  onSelected: () =>
                      setState(() => _tipo = InventoryItemType.product),
                ),
              ],
            ),

            if (item.matches) ...[
              const SizedBox(height: AppSpacing.x6),
              _BloqueFichaExistente(
                item: item,
                accion: _accion,
                actualizarPrecio: _actualizarPrecio,
                cantidad: int.tryParse(_cantidad.text.trim()) ?? item.quantity,
                onAccion: (final a) => setState(() => _accion = a),
                onActualizarPrecio: (final v) =>
                    setState(() => _actualizarPrecio = v),
              ),
            ],

            const SizedBox(height: AppSpacing.x6),

            // Los dos campos que el modelo de datos ya tenía y que hasta
            // este carril nadie rellenaba de verdad.
            PagateTextField(
              labelText: 'Código (opcional)',
              controller: _codigo,
              hintText: 'Ej: GR-25',
              maxLength: 200,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.x4),

            PagateTextField(
              labelText: 'Proveedor (opcional)',
              controller: _proveedor,
              hintText: 'Ej: Cerámicas del Sur',
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (final _) => _guardar(),
            ),
          ],
        ),
      ),
    );
  }

  static String _conComa(final double valor) =>
      valor.toString().replaceAll('.', ',');
}

/// Las dos decisiones que aparecen cuando la ficha ya existe.
class _BloqueFichaExistente extends StatelessWidget {
  const _BloqueFichaExistente({
    required this.item,
    required this.accion,
    required this.actualizarPrecio,
    required this.cantidad,
    required this.onAccion,
    required this.onActualizarPrecio,
  });

  final ScannedLineItem item;
  final ScanAction accion;
  final bool actualizarPrecio;
  final int cantidad;
  final ValueChanged<ScanAction> onAccion;
  final ValueChanged<bool> onActualizarPrecio;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final stockActual = item.matchedStock ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ya tienes una ficha así',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          '«${item.matchedName}», con $stockActual ${item.unit} en stock.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppPalette.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          children: [
            PagateChip(
              label: 'Sumar al stock',
              isSelected: accion == ScanAction.sumarStock,
              onSelected: () => onAccion(ScanAction.sumarStock),
            ),
            const SizedBox(width: AppSpacing.x2),
            PagateChip(
              label: 'Crear ficha nueva',
              isSelected: accion == ScanAction.crearFicha,
              onSelected: () => onAccion(ScanAction.crearFicha),
            ),
          ],
        ),
        if (accion == ScanAction.sumarStock) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            'El stock queda en ${stockActual + cantidad} ${item.unit}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
        ],

        // EL PRECIO NO SE ACTUALIZA POR DEFECTO, y no es pereza. El precio
        // guardado de un producto es a cuánto lo VENDE el usuario;
        // sobrescribirlo con un precio de compra le rompe sus propias
        // finanzas en silencio. Para un material suele interesar, así que
        // está a un toque, pero el toque lo da él.
        if (accion == ScanAction.sumarStock && item.precioDifiere) ...[
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Guardado '
            '${formatCurrency(item.matchedPrice!, currency: kFallbackCurrency)}'
            ' · en la boleta '
            '${formatCurrency(item.unitPrice, currency: kFallbackCurrency)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
            ),
          ),
          SwitchListTile.adaptive(
            value: actualizarPrecio,
            onChanged: onActualizarPrecio,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Actualizar el precio guardado',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

/// Franja de aviso con las superficies planas del sistema.
class _AvisoDeLectura extends StatelessWidget {
  const _AvisoDeLectura({required this.mensaje});

  final String mensaje;

  @override
  Widget build(final BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: AppPalette.warningSurface,
          borderRadius: AppRadius.r8Border,
          border: Border.all(
            color: AppPalette.warning,
            width: AppSizes.borderHairline,
          ),
        ),
        child: Text(
          mensaje,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.warning,
              ),
        ),
      );
}

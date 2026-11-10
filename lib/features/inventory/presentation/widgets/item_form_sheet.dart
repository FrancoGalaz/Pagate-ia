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
// FORMULARIO DE UNA FICHA DE INVENTARIO — ALTA Y EDICIÓN
// ═══════════════════════════════════════════════════════════════════════
// Sale de `inventario_tab.dart`, donde era la hoja privada `_HojaDeItem`,
// por dos motivos concretos:
//
// 1. AHORA TIENE DOS LLAMADORES Y ESTÁN EN ARCHIVOS DISTINTOS: la lista
//    (alta) y la ficha (edición). Dejarla en `inventario_tab.dart` obligaba
//    a que `detalle_item_screen.dart` importara la pestaña que a su vez lo
//    importa a él.
// 2. Es la misma separación que ya tiene Finanzas
//    (`presentation/widgets/transaction_form_sheet.dart`).
//
// DOS DEFECTOS QUE CIERRA, y ninguno es cosmético:
//
// · `supplier` Y `code` ERAN CÓDIGO MUERTO A UN FORMULARIO DE DISTANCIA.
//   Los dos campos existían en la entidad, en el modelo, en
//   `firestore.rules` (`isNullableStr(..., 200)`), se dibujaban en la ficha
//   y el buscador del inventario ya filtraba por código. Pero el único
//   formulario que creaba fichas no los pasaba nunca, así que valían `null`
//   siempre: la línea "Proveedor" de la ficha no se dibujaba jamás y buscar
//   por código no podía encontrar nada. La política de privacidad publicada
//   afirma que el usuario puede indicarlos.
//
// · NO HABÍA FORMA DE EDITAR UNA FICHA. `updateItem` existía en el
//   datasource, el repositorio y el provider, las reglas lo permitían, y no
//   tenía ni un llamador en la interfaz: desde la ficha solo se podía
//   corregir el stock o borrarla. Un nombre mal escrito o un precio que
//   cambió obligaban a borrar y volver a crear. La política de privacidad
//   publicada afirma que el inventario se puede editar desde la app.
// ═══════════════════════════════════════════════════════════════════════

/// Abre el formulario para crear una ficha del tipo [tipo].
///
/// Toma el [InventoryProvider] del [context] que recibe y no del contexto de
/// la hoja: los providers viven por debajo del Navigator raíz.
Future<void> mostrarHojaDeItem(
  final BuildContext context,
  final InventoryItemType tipo,
) =>
    _mostrarHoja(context, ItemFormSheet(tipo: tipo));

/// Abre el MISMO formulario con los valores de [item] ya cargados.
Future<void> mostrarHojaDeEdicionDeItem(
  final BuildContext context,
  final InventoryItemEntity item,
) =>
    _mostrarHoja(
      context,
      ItemFormSheet(tipo: item.type, itemExistente: item),
    );

Future<void> _mostrarHoja(
  final BuildContext context,
  final ItemFormSheet hoja,
) {
  final provider = context.read<InventoryProvider>();
  return showPagateSheet<void>(
    context: context,
    builder: (final _) => ChangeNotifierProvider<InventoryProvider>.value(
      value: provider,
      child: hoja,
    ),
  );
}

/// Hoja de alta o de edición de una ficha de inventario.
class ItemFormSheet extends StatefulWidget {
  const ItemFormSheet({
    super.key,
    required this.tipo,
    this.itemExistente,
  });

  /// Producto o material. En una edición es el tipo de la ficha, y no se
  /// puede cambiar: mover una ficha de una pestaña a la otra no es editarla.
  final InventoryItemType tipo;

  /// Ficha que se está editando, o `null` si es un alta.
  final InventoryItemEntity? itemExistente;

  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _precio;
  late final TextEditingController _stock;
  late final TextEditingController _minimo;
  late final TextEditingController _unidad;
  late final TextEditingController _proveedor;
  late final TextEditingController _codigo;

  /// Lo que había escrito al abrir la hoja.
  ///
  /// La confirmación de cierre no puede preguntar "¿hay algo escrito?": en
  /// una edición los siete campos vienen llenos, así que eso avisaría de que
  /// se van a perder cambios cada vez que el usuario abre la hoja y se
  /// arrepiente sin tocar nada. La pregunta correcta es "¿hay algo
  /// DISTINTO?".
  late final List<String> _valoresIniciales;

  bool _guardando = false;

  /// Mensaje del último guardado fallido. Se dibuja DENTRO de la hoja: el
  /// aviso flotante que había lo pintaba el Scaffold de detrás y quedaba
  /// tapado por la propia hoja.
  String? _errorGuardado;

  InventoryItemEntity? get _existente => widget.itemExistente;

  bool get _esEdicion => _existente != null;

  bool get _esProducto => widget.tipo == InventoryItemType.product;

  @override
  void initState() {
    super.initState();
    final item = _existente;
    _nombre = TextEditingController(text: item?.name ?? '');
    _precio = TextEditingController(
      text: item == null ? '' : _precioEditable(item.price),
    );
    _stock = TextEditingController(text: item?.stock.toString() ?? '1');
    _minimo = TextEditingController(text: item?.minStock.toString() ?? '1');
    _unidad = TextEditingController(
      text: item?.unit ?? (_esProducto ? 'piezas' : 'unidades'),
    );
    _proveedor = TextEditingController(text: item?.supplier ?? '');
    _codigo = TextEditingController(text: item?.code ?? '');
    _valoresIniciales = _valoresActuales;
  }

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _campos => [
        _nombre,
        _precio,
        _stock,
        _minimo,
        _unidad,
        _proveedor,
        _codigo,
      ];

  List<String> get _valoresActuales =>
      _campos.map((final campo) => campo.text).toList(growable: false);

  /// `true` si algún campo ya no vale lo que valía al abrir la hoja.
  bool get _tieneCambios {
    final actuales = _valoresActuales;
    for (var i = 0; i < actuales.length; i++) {
      if (actuales[i] != _valoresIniciales[i]) return true;
    }
    return false;
  }

  /// El precio en dígitos pelados ("18990"), igual que la meta mensual de
  /// `editar_perfil_screen`: el campo lo lee con `parseCurrencyInput`, que
  /// acepta los puntos de millar que escribe un chileno, pero precargarlo
  /// con puntos invita a borrarlos a mano.
  ///
  /// Si el precio guardado tuviera decimales —en pesos no los tiene, pero el
  /// modelo acepta un `double`— se escriben con coma, que es el separador
  /// decimal que `parseCurrencyInput` reconoce cuando hay una sola.
  static String _precioEditable(final double precio) =>
      precio == precio.roundToDouble()
          ? precio.round().toString()
          : precio.toString().replaceAll('.', ',');

  /// Confirma el cierre cuando hay algo a medio escribir o a medio cambiar.
  Future<bool> _confirmarCierre() async {
    if (_guardando) return false;
    if (!_tieneCambios) return true;

    final salir = await confirmar(
      context,
      title: _esEdicion ? '¿Descartar los cambios?' : '¿Descartar la ficha?',
      message: _esEdicion
              ? 'Lo que cambiaste no se va a guardar.'
              : 'Lo que escribiste no se va a guardar.',
      cancelLabel: 'Seguir editando',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    return salir;
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
    final existente = _existente;
    try {
      if (existente == null) {
        await provider.addItem(
          name: _nombre.text,
          type: widget.tipo,
          price: precio,
          stock: int.parse(_stock.text.trim()),
          minStock: int.parse(_minimo.text.trim()),
          unit: _unidad.text,
          supplier: _proveedor.text,
          code: _codigo.text,
        );
      } else {
        // La entidad se construye a mano y NO con `copyWith`: ahí un `null`
        // significa "déjalo como estaba", así que vaciar el proveedor o el
        // código de una ficha que ya los tenía era imposible por ese camino.
        // El `id` y el `type` son los de la ficha original.
        await provider.updateItem(
          InventoryItemEntity(
            id: existente.id,
            name: _nombre.text,
            type: existente.type,
            price: precio,
            stock: int.parse(_stock.text.trim()),
            minStock: int.parse(_minimo.text.trim()),
            unit: _unidad.text,
            supplier: _proveedor.text,
            code: _codigo.text,
          ),
        );
      }
      if (!mounted) return;
      navigator.pop();
      AppFeedback.showMessage(context, _mensajeDeExito);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = InventoryProvider.describeError(
          e,
          operation: DataOperation.write,
          fallback: _esEdicion
              ? 'No se pudieron guardar los cambios'
              : 'No se pudo guardar la ficha',
        );
      });
    }
  }

  String get _mensajeDeExito {
    if (_esEdicion) return 'Ficha actualizada.';
    return _esProducto ? 'Producto agregado.' : 'Material agregado.';
  }

  String get _titulo {
    if (_esEdicion) {
      return _esProducto ? 'Editar producto' : 'Editar material';
    }
    return _esProducto ? 'Nuevo producto' : 'Nuevo material';
  }

  @override
  Widget build(final BuildContext context) => PagateSheet(
        title: _titulo,
        onIntentarCerrar: _confirmarCierre,
        primaryAction: PagatePrimaryButton(
          label: _esEdicion ? 'Guardar cambios' : 'Guardar ficha',
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
              //
              // En una edición el stock sigue siendo editable aquí, además
              // de en la hoja de "Actualizar stock": `updateItem` escribe el
              // documento completo, así que esconderlo no evitaría
              // sobrescribirlo, solo lo haría a ciegas.
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
                textInputAction: TextInputAction.next,
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe la unidad en la que lo mides'
                    : null,
              ),
              const SizedBox(height: AppSpacing.x4),

              // ─── Los dos campos opcionales ────────────────────────────
              // Van al final y dicen "(opcional)" en la etiqueta, como la
              // comisión y la descripción de un movimiento: el formulario
              // no puede dar a entender que hacen falta para guardar.
              //
              // El tope de 200 caracteres no es un número elegido aquí: es
              // el que impone `firestore.rules` para los dos campos, y lo
              // que sobre lo rechazaría el servidor con un error opaco.
              PagateTextField(
                labelText: 'Proveedor (opcional)',
                controller: _proveedor,
                hintText: 'Ej: Cerámicas del Sur',
                maxLength: 200,

                // `sentences` y no `words`: medido en emulator-5554, con
                // `words` el teclado de Android escribía "Cerámicas Del
                // Sur", porque capitaliza TODAS las palabras, y en español
                // las preposiciones de un nombre propio van en minúscula.
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),

              PagateTextField(
                labelText: 'Código (opcional)',
                controller: _codigo,
                hintText: 'Ej: GR-25',
                helperText: 'El buscador del inventario también busca por '
                    'código.',
                maxLength: 200,

                // Mayúsculas por defecto porque un código de bodega se
                // escribe así; es el comportamiento del teclado, no un
                // formateador, así que el usuario puede escribirlo en
                // minúscula si quiere.
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (final _) => _guardar(),
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

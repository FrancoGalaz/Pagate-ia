import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../providers/finances_provider.dart';

// ─── Categorías ──────────────────────────────────────────────────────────
// Las que usa de verdad un taller chileno, no las genéricas de antes
// ('Venta', 'Materiales', 'Servicios', 'Arriendo', 'Otro'), que no
// distinguían vender en una feria de vender por Instagram ni el arriendo del
// taller de la boleta de la luz.
//
// La categoría se guarda como texto libre (así está en firestore.rules y en
// docs/ARQUITECTURA.md), de modo que los movimientos ya registrados con las
// categorías viejas se siguen leyendo y mostrando tal cual: lo único que
// cambia es lo que se ofrece al registrar uno nuevo. No hay migración de
// datos ni valor que deje de ser válido.

/// Categorías de INGRESO. Son los canales por los que vende un artesano:
/// la feria, Instagram, el pedido a medida y la tienda que le compra.
const List<String> incomeCategories = [
  'Venta en feria',
  'Venta por Instagram',
  'Pedido personalizado',
  'Venta a tienda',
  'Otro ingreso',
];

/// Categorías de GASTO. Incluye 'Comisión de plataforma' como gasto propio,
/// que es distinto del campo `platformFee` de un ingreso: aquí va el cobro
/// que llega aparte (por ejemplo la liquidación mensual de un marketplace) y
/// allá lo que se descontó de una venta concreta.
const List<String> expenseCategories = [
  'Insumos y materiales',
  'Arriendo del taller',
  'Gas y electricidad',
  'Envíos',
  'Comisión de plataforma',
  'Herramientas',
  'Difusión',
  'Otro gasto',
];

/// Categorías ofrecidas según el tipo de movimiento.
List<String> categoriesFor(final TransactionType type) =>
    type == TransactionType.income ? incomeCategories : expenseCategories;

/// Abre el formulario para registrar un ingreso o gasto, a pantalla
/// completa (variante A: docs/diseno/variantes-cabal.html, pantalla 4).
///
/// Conserva el nombre de cuando era una hoja para no tocar a quien lo
/// llama. Toma el [FinancesProvider] del [context] que recibe, así funciona
/// aunque los providers vivan por debajo del Navigator.
Future<void> showTransactionSheet(
  final BuildContext context, {
  final TransactionType? initialType,
}) {
  final provider = context.read<FinancesProvider>();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (final _) => ChangeNotifierProvider<FinancesProvider>.value(
        value: provider,
        child: TransactionFormSheet(
          initialType: initialType ?? TransactionType.income,
        ),
      ),
    ),
  );
}

/// Formulario de registro de movimientos. Úsalo a través de
/// [showTransactionSheet].
///
/// El total grande ES el campo del monto: no hay un campo «Monto» aparte.
/// Categoría, documento, fecha y comisión son filas que abren su selector.
class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.initialType = TransactionType.income,
  });

  final TransactionType initialType;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TransactionType _type = widget.initialType;
  late String _category = _defaultCategory(widget.initialType);

  /// Documento del ingreso (contrato C-3). En un gasto no se pregunta y
  /// mantiene el valor por defecto, que es el que se asume cuando el campo
  /// no está en Firestore.
  TransactionDocType _docType = TransactionDocType.fallback;

  /// Comisión del medio de pago. Solo existe en un ingreso; 0 = ninguna.
  double _fee = 0;

  /// Error de la comisión al guardar (si el monto bajó por debajo de ella).
  String? _errorComision;

  DateTime _date = DateTime.now();
  bool _saving = false;

  /// Mensaje del último guardado fallido, o `null` si no hubo ninguno.
  ///
  /// Se dibuja DENTRO del formulario, justo encima de los botones: un fallo
  /// al registrar dinero tiene que seguir legible cuando el usuario vuelve a
  /// mirar el formulario, no desvanecerse a los pocos segundos.
  String? _errorGuardado;

  static String _defaultCategory(final TransactionType type) =>
      categoriesFor(type).first;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTypeChanged(final TransactionType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = _defaultCategory(type);
      // Los dos campos del contrato C-3 describen un ingreso. Si el usuario
      // puso una comisión y luego cambió a Gasto, se limpia: guardar una
      // comisión en un gasto sería un dato falso.
      _docType = TransactionDocType.fallback;
      _fee = 0;
      _errorComision = null;
      // El error era de otro movimiento: dejarlo visible sería mentir.
      _errorGuardado = null;
    });
  }

  /// Vuelve a dejar el formulario como al abrirlo, sin cambiar el tipo.
  void _limpiar() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _category = _defaultCategory(_type);
      _docType = TransactionDocType.fallback;
      _fee = 0;
      _errorComision = null;
      _date = DateTime.now();
      _errorGuardado = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Fecha del movimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final elegida = await _elegir(
      context,
      titulo: 'Categoría',
      opciones: categoriesFor(_type),
      actual: _category,
    );
    if (elegida != null && mounted) setState(() => _category = elegida);
  }

  Future<void> _pickDocType() async {
    final elegida = await _elegir(
      context,
      titulo: 'Documento',
      opciones: [for (final t in TransactionDocType.values) t.label],
      actual: _docType.label,
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _docType = TransactionDocType.values.firstWhere(
        (final t) => t.label == elegida,
        orElse: () => TransactionDocType.fallback,
      );
    });
  }

  Future<void> _pickFee() async {
    final comision = await showPagateSheet<double>(
      context: context,
      builder: (final _) => _HojaComision(
        inicial: _fee,
        monto: _parseAmount(_amountController.text),
      ),
    );
    if (comision == null || !mounted) return;
    setState(() {
      _fee = comision;
      _errorComision = null;
    });
  }

  /// Lee el monto escrito con el formateador único de la app.
  ///
  /// Antes normalizaba la coma a punto y llamaba a `double.tryParse`, de modo
  /// que un movimiento de "150.000" se guardaba como **150 pesos** sin que
  /// ninguna validación lo detectara.
  static double? _parseAmount(final String raw) => parseCurrencyInput(raw);

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) return;

    // La comisión se eligió contra el monto de ese momento: si después el
    // monto bajó, no se guarda una comisión mayor que lo cobrado.
    final fee = _type == TransactionType.income ? _fee : 0.0;
    if (fee > amount) {
      setState(() => _errorComision = _comisionMayorQueMonto);
      return;
    }

    setState(() {
      _saving = true;
      _errorComision = null;
      // Un reintento empieza sin el error del intento anterior en pantalla.
      _errorGuardado = null;
    });
    final provider = context.read<FinancesProvider>();
    final navigator = Navigator.of(context);
    try {
      await provider.addTransaction(
        title: _titleController.text,
        amount: amount,
        type: _type,
        category: _category,
        date: _date,
        description: _descriptionController.text,
        docType: _type == TransactionType.income
            ? _docType
            : TransactionDocType.fallback,
        platformFee: fee,
      );
      if (!mounted) return;
      navigator.pop();
      AppFeedback.showMessage(
        context,
        _type == TransactionType.income
            ? 'Ingreso registrado.'
            : 'Gasto registrado.',
      );
    } catch (e) {
      if (!mounted) return;
      // EL ERROR SE QUEDA DENTRO DEL FORMULARIO, no en un aviso que se va:
      // el `SnackBar` lo dibujaba el Scaffold de la pantalla de DETRÁS, y
      // quedaba tapado.
      setState(() {
        _saving = false;
        _errorGuardado = FinancesProvider.describeError(
          e,
          operation: DataOperation.write,
        );
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    final isIncome = _type == TransactionType.income;
    final now = DateTime.now();
    final esHoy = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo movimiento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          children: [
            PagateSegmented<TransactionType>(
              options: const [
                (TransactionType.income, 'Ingreso'),
                (TransactionType.expense, 'Gasto'),
              ],
              selected: _type,
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: AppSpacing.x4),

            _CampoTotal(
              controller: _amountController,
              isIncome: isIncome,
              validator: (final v) {
                final amount = _parseAmount(v ?? '');
                if (amount == null) return 'Ingresa un monto válido';
                if (amount <= 0) return 'El monto debe ser mayor que cero';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.x4),

            PagateTextField(
              labelText: 'Título',
              controller: _titleController,
              hintText: isIncome ? 'Ej: venta en la feria' : 'Ej: greda 25 kg',
              maxLength: 200,
              validator: (final v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
            ),
            const SizedBox(height: AppSpacing.x2),

            PagateSectionCard(
              child: Column(
                children: [
                  _FilaFormulario(
                    icon: Icons.sell_outlined,
                    label: 'Categoría',
                    value: _category,
                    onTap: _pickCategory,
                  ),
                  // ─── Contrato C-3: documento y comisión, solo en un
                  // ingreso. En un gasto no significan nada, así que no se
                  // dibujan en lugar de dibujarse deshabilitados.
                  if (isIncome)
                    _FilaFormulario(
                      icon: Icons.description_outlined,
                      label: 'Documento',
                      value: _docType.label,
                      onTap: _pickDocType,
                    ),
                  _FilaFormulario(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha',
                    value: esHoy
                        ? 'Hoy, ${formatDayMonth(_date)}'
                        : formatDayMonthYear(_date),
                    onTap: _pickDate,
                    showDivider: isIncome,
                  ),
                  if (isIncome)
                    _FilaFormulario(
                      icon: Icons.percent_rounded,
                      label: 'Comisión',
                      subtitle: 'Opcional',
                      value: formatCurrency(_fee, currency: kFallbackCurrency),
                      onTap: _pickFee,
                      showDivider: false,
                    ),
                ],
              ),
            ),
            if (_errorComision != null) ...[
              const SizedBox(height: AppSpacing.x2),
              PagateInlineError(message: _errorComision),
            ],
            const SizedBox(height: AppSpacing.x4),

            PagateTextField(
              labelText: 'Descripción (opcional)',
              controller: _descriptionController,
              hintText: 'Detalles, cliente, notas...',
              maxLength: 2000,
            ),

            if (_errorGuardado != null) ...[
              const SizedBox(height: AppSpacing.x2),
              PagateInlineError(message: _errorGuardado),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          decoration: const BoxDecoration(
            color: AppPalette.surface,
            border: Border(
              top: BorderSide(
                color: AppPalette.hairline,
                width: AppSizes.borderHairline,
              ),
            ),
          ),
          child: PagateClearCreateBar(
            createLabel: isIncome ? 'Crear ingreso' : 'Crear gasto',
            onCreate: _submit,
            onClear: _saving ? null : _limpiar,
            isLoading: _saving,
          ),
        ),
      ),
    );
  }
}

/// Fila de la lista del formulario: icono, etiqueta y el valor elegido.
///
/// No es [PagateDataRow] porque aquí el valor es TEXTO («Venta por
/// Instagram»), no un monto: tiene que poder partirse en vez de desbordar.
/// Con letra de 1,5 o más el valor baja bajo la etiqueta.
class _FilaFormulario extends StatelessWidget {
  const _FilaFormulario({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final apilado = MediaQuery.textScalerOf(context).scale(10) >= 15;
    final valor = Text(
      value,
      textAlign: apilado ? TextAlign.left : TextAlign.right,
      style: AppText.weight(theme.textTheme.bodyMedium!, 700).copyWith(
        color: AppPalette.ink,
      ),
    );
    final etiqueta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
            ),
          ),
        if (apilado) ...[const SizedBox(height: AppSpacing.x1), valor],
      ],
    );

    return Material(
      color: AppPalette.surface,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppPalette.sunken,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppPalette.hairline,
                      width: AppSizes.borderHairline,
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              PagateIconSquare(icon: icon),
              const SizedBox(width: AppSpacing.x3),
              if (apilado)
                Expanded(child: etiqueta)
              else ...[
                etiqueta,
                const SizedBox(width: AppSpacing.x3),
                Expanded(child: valor),
              ],
              const SizedBox(width: AppSpacing.x2),
              const Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.sm,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const String _comisionMayorQueMonto =
    'La comisión no puede ser mayor que el monto';

/// El total grande, editable. Verde con «+» en un ingreso; oscuro con «−»
/// en un gasto.
class _CampoTotal extends StatelessWidget {
  const _CampoTotal({
    required this.controller,
    required this.isIncome,
    required this.validator,
  });

  final TextEditingController controller;
  final bool isIncome;
  final FormFieldValidator<String> validator;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final color = isIncome ? AppPalette.moneyIn : AppPalette.ink;
    final estilo = AppText.weight(
      theme.textTheme.displayMedium!,
      800,
    ).copyWith(color: color);
    const sinBorde = InputBorder.none;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadius.r16Border,
        border: Border.all(color: AppPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
          // El signo va fuera del campo: el `prefixText` de un campo vacío
          // no se dibuja hasta que recibe el foco.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // U+2212, el mismo signo que la columna de montos.
              Text(isIncome ? r'+$' : r'−$', style: estilo),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  style: estilo,
                  cursorColor: AppPalette.ink,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: validator,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: estilo.copyWith(color: AppPalette.textDisabled),
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: sinBorde,
                    enabledBorder: sinBorde,
                    focusedBorder: sinBorde,
                    errorBorder: sinBorde,
                    focusedErrorBorder: sinBorde,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Escribe el total. El teclado es numérico.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja con una lista de opciones; devuelve la elegida o `null`.
Future<String?> _elegir(
  final BuildContext context, {
  required final String titulo,
  required final List<String> opciones,
  required final String actual,
}) =>
    showPagateSheet<String>(
      context: context,
      builder: (final hoja) => PagateSheet(
        title: titulo,
        bodyPadding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opcion in opciones)
              Semantics(
                selected: opcion == actual,
                child: PagateDataRow(
                  label: opcion,
                  value: '',
                  trailing: opcion == actual
                      ? const Icon(Icons.check_rounded, color: AppPalette.ink)
                      : null,
                  onTap: () => Navigator.of(hoja).pop(opcion),
                  showDivider: opcion != opciones.last,
                ),
              ),
          ],
        ),
      ),
    );

/// Hoja de la comisión del medio de pago. Devuelve la comisión o `null`.
class _HojaComision extends StatefulWidget {
  const _HojaComision({required this.inicial, required this.monto});

  final double inicial;

  /// Monto escrito en el formulario, si hay uno válido.
  final double? monto;

  @override
  State<_HojaComision> createState() => _HojaComisionState();
}

class _HojaComisionState extends State<_HojaComision> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    // «4.560», sin el signo de peso: es lo que el usuario escribiría.
    text: widget.inicial > 0
        ? formatCurrency(
            widget.inicial,
            currency: kFallbackCurrency,
          ).replaceAll(r'$', '')
        : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validar(final String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final fee = parseCurrencyInput(raw);
    if (fee == null) return 'Ingresa una comisión válida';
    if (fee < 0) return 'La comisión no puede ser negativa';
    final monto = widget.monto;
    if (monto != null && fee > monto) return _comisionMayorQueMonto;
    return null;
  }

  void _listo() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final raw = _controller.text.trim();
    Navigator.of(context).pop(raw.isEmpty ? 0.0 : parseCurrencyInput(raw));
  }

  @override
  Widget build(final BuildContext context) => PagateSheet(
    title: 'Comisión del medio de pago',
    primaryAction: PagatePrimaryButton(label: 'Listo', onPressed: _listo),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PagateTextField(
            labelText: 'Comisión (opcional)',
            controller: _controller,
            hintText: '0',
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: _validar,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Lo que te descuenta el medio de pago: Mercado Pago, Khipu, '
            'Transbank. Si te pagaron por transferencia o en efectivo, déjalo '
            'en 0.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

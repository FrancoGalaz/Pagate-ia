import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/pagate_chip_selector.dart';
import '../../../../core/widgets/pagate_inline_error.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_text_field.dart';
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

/// Abre el formulario para registrar un ingreso o gasto.
///
/// Toma el [FinancesProvider] del [context] que recibe (no del contexto del
/// sheet), así funciona aunque los providers vivan por debajo del Navigator.
Future<void> showTransactionSheet(
  final BuildContext context, {
  final TransactionType? initialType,
}) {
  final provider = context.read<FinancesProvider>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Ni `backgroundColor` ni `shape`: los pone `bottomSheetTheme`
    // (blanco, radio 16 arriba, cero elevación, velo al 40% y asa). Aquí
    // estaban escritos a mano con radio 24 y la superficie del tema oscuro.
    builder: (final _) => ChangeNotifierProvider<FinancesProvider>.value(
      value: provider,
      child: TransactionFormSheet(
        initialType: initialType ?? TransactionType.income,
      ),
    ),
  );
}

/// Formulario de registro de movimientos. Úsalo a través de
/// [showTransactionSheet].
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
  static const _typeLabels = {
    TransactionType.income: 'Ingreso',
    TransactionType.expense: 'Gasto',
  };

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Comisión del medio de pago. Solo se pide en un ingreso.
  final _feeController = TextEditingController();

  late TransactionType _type = widget.initialType;
  late String _category = _defaultCategory(widget.initialType);

  /// Documento del ingreso (contrato C-3). En un gasto no se pregunta y
  /// mantiene el valor por defecto, que es el que se asume cuando el campo
  /// no está en Firestore.
  TransactionDocType _docType = TransactionDocType.fallback;

  DateTime _date = DateTime.now();
  bool _saving = false;

  /// Mensaje del último guardado fallido, o `null` si no hubo ninguno.
  ///
  /// Se dibuja DENTRO de la hoja, justo encima del botón: un fallo al
  /// registrar dinero tiene que seguir legible cuando el usuario vuelve a
  /// mirar el formulario, no desvanecerse a los pocos segundos.
  String? _errorGuardado;

  static String _defaultCategory(final TransactionType type) =>
      categoriesFor(type).first;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _onTypeToggle(final String label) {
    final type = _typeLabels.entries
        .firstWhere((final e) => e.value == label)
        .key;
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = _defaultCategory(type);
      // Los dos campos del contrato C-3 describen un ingreso. Si el usuario
      // escribió una comisión y luego cambió a Gasto, se limpia: guardar una
      // comisión en un gasto sería un dato falso.
      _docType = TransactionDocType.fallback;
      _feeController.clear();
      // El error era de otro movimiento: dejarlo visible sería mentir.
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

  /// Lee el monto escrito con el formateador único de la app.
  ///
  /// Antes normalizaba la coma a punto y llamaba a `double.tryParse`, de modo
  /// que un movimiento de "150.000" se guardaba como **150 pesos** sin que
  /// ninguna validación lo detectara.
  static double? _parseAmount(final String raw) => parseCurrencyInput(raw);

  /// Comisión escrita, o 0 si el campo está vacío o no corresponde.
  ///
  /// El campo es opcional: vacío significa "no me descontaron nada", que es
  /// lo que pasa al cobrar en efectivo o por transferencia.
  double get _platformFee {
    if (_type != TransactionType.income) return 0;
    final raw = _feeController.text.trim();
    if (raw.isEmpty) return 0;
    return _parseAmount(raw) ?? 0;
  }

  /// Valida la comisión contra el monto escrito en el mismo formulario.
  String? _validateFee(final String? value) {
    if (_type != TransactionType.income) return null;
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final fee = _parseAmount(raw);
    if (fee == null) return 'Ingresa una comisión válida';
    if (fee < 0) return 'La comisión no puede ser negativa';
    final amount = _parseAmount(_amountController.text);
    if (amount != null && fee > amount) {
      return 'La comisión no puede ser mayor que el monto';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() {
      _saving = true;
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
        platformFee: _platformFee,
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
      // EL ERROR SE QUEDA DENTRO DE LA HOJA, no en un aviso que se va.
      //
      // Aquí estaba el defecto grave: la hoja sigue abierta en el `catch`, y
      // el `SnackBar` que pintaba `AppFeedback` lo dibujaba el Scaffold de
      // la pantalla de DETRÁS, así que quedaba tapado por la hoja. El botón
      // volvía a su estado normal y no pasaba nada visible: ocho capturas
      // seguidas sin spinner, sin aviso y sin error.
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
    final theme = Theme.of(context);
    final isIncome = _type == TransactionType.income;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El tema ya dibuja el asa de arrastre (showDragHandle).
              //
              // Y el título va solo: el cuadrado teñido de 32 dp con la
              // flecha arriba/abajo según el tipo no añadía nada que los
              // chips "Ingreso / Gasto" de la línea siguiente no digan, y
              // su `accent.withValues(alpha: 0.15)` era una opacidad
              // inventada sobre un fondo que ya no es oscuro.
              Text(
                'Registrar movimiento',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),

              const _EtiquetaDeGrupo('Tipo'),
              const SizedBox(height: AppSpacing.xs),
              PagateChipSelector(
                options: _typeLabels.values.toList(),
                selected: {_typeLabels[_type]!},
                onToggle: _onTypeToggle,
              ),
              const SizedBox(height: AppSpacing.md),

              PagateTextField(
                labelText: 'Título',
                controller: _titleController,
                hintText: isIncome ? 'Ej: venta en la feria' : 'Ej: greda 25 kg',
                maxLength: 200,
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un título'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              PagateTextField(
                labelText: 'Monto',
                controller: _amountController,
                hintText: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (final v) {
                  final amount = _parseAmount(v ?? '');
                  if (amount == null) return 'Ingresa un monto válido';
                  if (amount <= 0) return 'El monto debe ser mayor que cero';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Contrato C-3: documento y comisión, solo en un ingreso ──
              // En un gasto estos dos campos no significan nada, así que no
              // se dibujan en lugar de dibujarse deshabilitados.
              if (isIncome) ...[
                const _EtiquetaDeGrupo('Documento'),
                const SizedBox(height: AppSpacing.xs),
                PagateChipSelector(
                  options: TransactionDocType.values
                      .map((final t) => t.label)
                      .toList(),
                  selected: {_docType.label},
                  onToggle: (final label) => setState(() {
                    _docType = TransactionDocType.values.firstWhere(
                      (final t) => t.label == label,
                      orElse: () => TransactionDocType.fallback,
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),

                PagateTextField(
                  labelText: 'Comisión del medio de pago (opcional)',
                  controller: _feeController,
                  hintText: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: _validateFee,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Lo que te descuenta el medio de pago: Mercado Pago, '
                  'Khipu, Transbank. Si te pagaron por transferencia o en '
                  'efectivo, déjalo en 0.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              const _EtiquetaDeGrupo('Categoría'),
              const SizedBox(height: AppSpacing.xs),
              PagateChipSelector(
                options: categoriesFor(_type),
                selected: {_category},
                onToggle: (final c) => setState(() => _category = c),
              ),
              const SizedBox(height: AppSpacing.md),

              const _EtiquetaDeGrupo('Fecha'),
              const SizedBox(height: AppSpacing.xs),
              _DateField(date: _date, onTap: _pickDate),
              const SizedBox(height: AppSpacing.md),

              PagateTextField(
                labelText: 'Descripción (opcional)',
                controller: _descriptionController,
                hintText: 'Detalles, cliente, notas...',
                maxLength: 2000,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_errorGuardado != null) ...[
                PagateInlineError(message: _errorGuardado),
                const SizedBox(height: AppSpacing.md),
              ],
              PagatePrimaryButton(
                label: isIncome ? 'Registrar ingreso' : 'Registrar gasto',
                leadingIcon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final label =
        '${formatDayMonthYear(date)}${isToday ? ' (hoy)' : ''}';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r8Border,
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),

        // El mismo píxel que un campo de texto del tema: blanco con
        // contorno `borderField` de 1 dp (3,63:1) y radio 8. Era un relleno
        // gris al 50% de opacidad con radio 100.
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: AppRadius.r8Border,
          border: Border.all(
            color: AppPalette.borderField,
            width: AppSizes.borderField,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppPalette.textMuted,
              size: AppIconSize.sm,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppPalette.textPrimary,
                    ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: AppPalette.textMuted,
              size: AppIconSize.sm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de un grupo de controles que no es un campo de texto (los chips
/// y el selector de fecha).
///
/// Sustituye a `PagateLabel`, que pintaba versalitas con tracking 0,8 en
/// `textTertiary` #9CA3AF —2,54 sobre blanco, un fallo de AA— y que el paso
/// R-5 retira. Es el mismo estilo que `PagateTextField` usa para su propia
/// etiqueta, así que el formulario se lee con un solo criterio.
class _EtiquetaDeGrupo extends StatelessWidget {
  const _EtiquetaDeGrupo(this.texto);

  final String texto;

  @override
  Widget build(final BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
      );
}

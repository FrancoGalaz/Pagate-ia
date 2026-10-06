import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/pagate_chip_selector.dart';
import '../../../../core/widgets/pagate_label.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_text_field.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../providers/finances_provider.dart';
import '../../../../core/theme/app_text.dart';

/// Categorías fijas disponibles al registrar un movimiento.
const List<String> transactionCategories = [
  'Venta',
  'Materiales',
  'Herramientas',
  'Servicios',
  'Arriendo',
  'Otro',
];

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
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
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

  late TransactionType _type = widget.initialType;
  late String _category = _defaultCategory(widget.initialType);
  DateTime _date = DateTime.now();
  bool _saving = false;

  static String _defaultCategory(final TransactionType type) =>
      type == TransactionType.income ? 'Venta' : 'Materiales';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
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

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
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
      setState(() => _saving = false);
      AppFeedback.showMessage(
        context,
        FinancesProvider.describeError(e, fallback: 'No se pudo guardar'),
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = _type == TransactionType.income;
    final accent = isIncome ? AppColors.success : AppColors.error;

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
              // El tema ya dibuja el drag handle (showDragHandle: true).
              Row(
                children: [
                  Container(
                    width: AppSizes.iconContainerSmall,
                    height: AppSizes.iconContainerSmall,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: accent,
                      size: AppIconSize.xs,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Registrar movimiento',
                    style: AppText.weight(
                      theme.textTheme.titleLarge!,
                      700,
                    ).copyWith(color: AppColors.textPrimaryDark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              const PagateLabel('Tipo', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              PagateChipSelector(
                options: _typeLabels.values.toList(),
                selected: {_typeLabels[_type]!},
                onToggle: _onTypeToggle,
              ),
              const SizedBox(height: AppSpacing.md),

              const PagateLabel('Título', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              PagateTextField(
                controller: _titleController,
                hintText: isIncome ? 'Ej: Venta de mesa' : 'Ej: Madera pino',
                prefixIcon: Icons.edit_outlined,
                maxLength: 200,
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un título'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              const PagateLabel('Monto', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              PagateTextField(
                controller: _amountController,
                hintText: '0',
                prefixIcon: Icons.attach_money_rounded,
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

              const PagateLabel('Categoría', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              PagateChipSelector(
                options: transactionCategories,
                selected: {_category},
                onToggle: (final c) => setState(() => _category = c),
              ),
              const SizedBox(height: AppSpacing.md),

              const PagateLabel('Fecha', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              _DateField(date: _date, onTap: _pickDate),
              const SizedBox(height: AppSpacing.md),

              const PagateLabel('Descripción (opcional)', isUppercase: true),
              const SizedBox(height: AppSpacing.xs),
              PagateTextField(
                controller: _descriptionController,
                hintText: 'Detalles, cliente, notas...',
                prefixIcon: Icons.notes_rounded,
                maxLength: 2000,
              ),
              const SizedBox(height: AppSpacing.xl),

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
      borderRadius: AppRadius.pillBorder,
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceDarkSecondary.withValues(alpha: 0.5),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textSecondaryDark,
              size: AppIconSize.sm,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppText.weight(
                  Theme.of(context).textTheme.bodyLarge!,
                  500,
                ).copyWith(color: AppColors.textPrimaryDark),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

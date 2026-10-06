import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/pagate_error_state.dart';
import '../../domain/entities/finances_summary_entity.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../providers/finances_provider.dart';
import '../widgets/transaction_form_sheet.dart';
import '../../../../core/theme/app_text.dart';

class FinanzasTab extends StatelessWidget {
  const FinanzasTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();

    final Widget body;
    if (provider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (provider.error != null) {
      body = PagateErrorState(
        message: provider.error!,
        onRetry: provider.retry,
      );
    } else {
      body = const _FinanzasBody();
    }

    return Stack(
      children: [
        Column(
          children: [
            const _FinanzasHeader(),
            Expanded(child: body),
          ],
        ),
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.xl,
          child: FloatingActionButton.extended(
            heroTag: 'finanzas_registrar',
            onPressed: provider.error != null
                ? null
                : () => showTransactionSheet(context),
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar'),
          ),
        ),
      ],
    );
  }
}

// ─── Header + selector de mes ─────────────────────────────────────────────
class _FinanzasHeader extends StatefulWidget {
  const _FinanzasHeader();

  @override
  State<_FinanzasHeader> createState() => _FinanzasHeaderState();
}

class _FinanzasHeaderState extends State<_FinanzasHeader> {
  bool _isExporting = false;

  Future<void> _onExport() async {
    final provider = context.read<FinancesProvider>();
    final summary = provider.summary;

    setState(() => _isExporting = true);
    try {
      final pdfBytes = await PdfReportService.generateReport(
        summary: summary,
        transactions: provider.transactions,
        fixedExpenses: provider.fixedExpenses,
        monthlyGoal: provider.monthlyGoal,
      );
      await PdfReportService.share(pdfBytes: pdfBytes, month: summary.month);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, 'Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();
    final months = provider.months.isNotEmpty
        ? provider.months
        : <FinancesSummaryEntity>[provider.summary];
    final selectedKey = provider.selectedMonthKey;
    final canExport = !_isExporting && provider.error == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Finanzas',
                style: AppText.weight(
                  Theme.of(context).textTheme.headlineMedium!,
                  800,
                ).copyWith(color: AppColors.textPrimaryDark),
              ),
              IconButton(
                onPressed: canExport ? _onExport : null,
                tooltip: 'Exportar PDF',
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : const Icon(
                        Icons.file_download_outlined,
                        color: AppColors.textSecondaryDark,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSizes.chipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: months.length,
              separatorBuilder: (final _, final _) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (final context, final i) {
                final month = months[i];
                final isSelected = month.monthKey == selectedKey;
                return GestureDetector(
                  onTap: () => context
                      .read<FinancesProvider>()
                      .selectMonthKey(month.monthKey),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.brand : AppColors.surfaceDark,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Text(
                      month.month,
                      style: AppText.weight(
                        Theme.of(context).textTheme.labelMedium!,
                        600,
                      ).copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ─── Cuerpo scrolleable ───────────────────────────────────────────────────
class _FinanzasBody extends StatelessWidget {
  const _FinanzasBody();

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();
    final summary = provider.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
        AppSpacing.screenHorizontal,
        100,
      ),
      children: [
        _SummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.xl),
        _GoalProgress(
          progress: provider.goalProgress,
          monthlyGoal: provider.monthlyGoal,
        ),
        const SizedBox(height: AppSpacing.xl),
        _FixedExpensesSection(expenses: provider.fixedExpenses),
        const SizedBox(height: AppSpacing.xl),
        _TransactionsSection(
          transactions: provider.transactions,
          isLoading: provider.isLoadingTransactions,
        ),
      ],
    );
  }
}

// ─── Resumen ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final FinancesSummaryEntity summary;

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            _StatRow(
              label: 'Ingresos',
              value: summary.totalIncome,
              color: AppColors.success,
              icon: Icons.arrow_upward_rounded,
            ),
            const Divider(color: AppColors.borderDark, height: AppSpacing.xl),
            _StatRow(
              label: 'Gastos',
              value: summary.totalExpenses,
              color: AppColors.error,
              icon: Icons.arrow_downward_rounded,
            ),
            const Divider(color: AppColors.borderDark, height: AppSpacing.xl),
            _StatRow(
              label: 'Balance',
              value: summary.balance,
              color: summary.balance >= 0 ? AppColors.brand : AppColors.error,
              icon: Icons.account_balance_wallet_outlined,
              isBold: true,
            ),
          ],
        ),
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isBold = false,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isBold;

  @override
  Widget build(final BuildContext context) => Row(
        children: [
          Container(
            width: AppSizes.iconContainerSmall,
            height: AppSizes.iconContainerSmall,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smBorder,
            ),
            child: Icon(icon, color: color, size: AppIconSize.xs),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppText.weight(
                Theme.of(context).textTheme.bodyMedium!,
                isBold ? 700 : 500,
              ).copyWith(color: AppColors.textSecondaryDark),
            ),
          ),
          Text(
            formatCurrency(value, currency: kFallbackCurrency),
            style: AppText.weight(
              Theme.of(context).textTheme.titleMedium!,
              700,
            ).copyWith(color: isBold ? color : AppColors.textPrimaryDark),
          ),
        ],
      );
}

// ─── Meta mensual ─────────────────────────────────────────────────────────
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.progress, required this.monthlyGoal});
  final double progress;
  final double monthlyGoal;

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meta Mensual',
                  style: AppText.weight(
                    Theme.of(context).textTheme.titleSmall!,
                    700,
                  ).copyWith(color: AppColors.textPrimaryDark),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: AppText.weight(
                    Theme.of(context).textTheme.titleSmall!,
                    700,
                  ).copyWith(color: AppColors.brand),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.pillBorder,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceDarkSecondary,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              monthlyGoal > 0
                  ? 'Objetivo: ${formatCurrency(monthlyGoal, currency: kFallbackCurrency)}'
                  : 'Define tu meta mensual en tu perfil',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
        ),
      );
}

// ─── Gastos fijos ─────────────────────────────────────────────────────────
class _FixedExpensesSection extends StatelessWidget {
  const _FixedExpensesSection({required this.expenses});
  final List<FixedExpenseEntity> expenses;

  Future<void> _addExpense(final BuildContext context) async {
    final provider = context.read<FinancesProvider>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (final dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Nuevo gasto fijo',
          style: TextStyle(color: AppColors.textPrimaryDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(hintText: 'Nombre (ej: Local)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: const InputDecoration(hintText: 'Monto mensual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final name = nameController.text;
    // Antes: double.tryParse(texto.replaceAll(',', '.')), que convertía
    // "50.000" en 50 y guardaba un gasto fijo mil veces menor.
    final amount = parseCurrencyInput(amountController.text);
    nameController.dispose();
    amountController.dispose();
    if (saved != true || !context.mounted) return;

    try {
      await provider.addFixedExpense(name: name, amount: amount ?? 0);
      if (!context.mounted) return;
      AppFeedback.showMessage(context, 'Gasto fijo agregado.');
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showMessage(
        context,
        FinancesProvider.describeError(e, fallback: 'No se pudo guardar'),
      );
    }
  }

  Future<void> _deleteExpense(
    final BuildContext context,
    final FixedExpenseEntity expense,
  ) async {
    final provider = context.read<FinancesProvider>();
    final confirmed = await _confirm(
      context,
      title: 'Eliminar gasto fijo',
      message: '¿Eliminar "${expense.name}"?',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await provider.deleteFixedExpense(expense.id);
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showMessage(
        context,
        FinancesProvider.describeError(e, fallback: 'No se pudo eliminar'),
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final total = expenses.fold<double>(0, (final s, final e) => s + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gastos Fijos',
              style: AppText.weight(
                Theme.of(context).textTheme.titleMedium!,
                700,
              ).copyWith(color: AppColors.textPrimaryDark),
            ),
            TextButton.icon(
              onPressed: () => _addExpense(context),
              icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: AppRadius.xxlBorder,
            border: Border.all(color: AppColors.borderDark),
          ),
          child: expenses.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Sin gastos fijos. Agrega arriendo, servicios u otros '
                    'costos que pagas todos los meses.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < expenses.length; i++) ...[
                      _FixedExpenseRow(
                        expense: expenses[i],
                        onDelete: () => _deleteExpense(context, expenses[i]),
                      ),
                      if (i < expenses.length - 1)
                        const Divider(
                          height: 1,
                          color: AppColors.borderDark,
                          indent: AppSpacing.md,
                          endIndent: AppSpacing.md,
                        ),
                    ],
                    const Divider(height: 1, color: AppColors.borderDark),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total mensual',
                            style: AppText.weight(
                              Theme.of(context).textTheme.bodyMedium!,
                              600,
                            ).copyWith(color: AppColors.textSecondaryDark),
                          ),
                          Text(
                            formatSigned(-total, currency: kFallbackCurrency),
                            style: AppText.weight(
                              Theme.of(context).textTheme.bodyMedium!,
                              700,
                            ).copyWith(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FixedExpenseRow extends StatelessWidget {
  const _FixedExpenseRow({required this.expense, required this.onDelete});
  final FixedExpenseEntity expense;
  final VoidCallback onDelete;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xxs,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: AppRadius.smBorder,
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: AppColors.error,
                size: AppIconSize.xs,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                expense.name,
                style: AppText.weight(
                  Theme.of(context).textTheme.bodyMedium!,
                  600,
                ).copyWith(color: AppColors.textPrimaryDark),
              ),
            ),
            Text(
              formatSigned(-expense.amount, currency: kFallbackCurrency),
              style: AppText.weight(
                Theme.of(context).textTheme.bodyMedium!,
                700,
              ).copyWith(color: AppColors.error),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Eliminar',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.textSecondaryDark,
                size: AppIconSize.sm,
              ),
            ),
          ],
        ),
      );
}

// ─── Transacciones del mes ────────────────────────────────────────────────
class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({
    required this.transactions,
    required this.isLoading,
  });
  final List<FinancesTransactionEntity> transactions;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (transactions.isEmpty) {
      content = _EmptyTransactions(
        onRegister: () => showTransactionSheet(context),
      );
    } else {
      content = Column(
        children: [
          for (final t in transactions) ...[
            _DismissibleTransaction(transaction: t),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movimientos del mes',
          style: AppText.weight(
            Theme.of(context).textTheme.titleMedium!,
            700,
          ).copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: AppSpacing.md),
        content,
      ],
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(final BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textSecondaryDark,
              size: AppIconSize.xl,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sin movimientos este mes',
              style: AppText.weight(
                Theme.of(context).textTheme.bodyLarge!,
                600,
              ).copyWith(color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Registra tu primera venta o gasto para ver tu balance.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
              label: const Text('Registrar movimiento'),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            ),
          ],
        ),
      );
}

class _DismissibleTransaction extends StatelessWidget {
  const _DismissibleTransaction({required this.transaction});
  final FinancesTransactionEntity transaction;

  @override
  Widget build(final BuildContext context) => Dismissible(
        key: ValueKey('tx-${transaction.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            borderRadius: AppRadius.xlBorder,
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
        ),
        confirmDismiss: (final _) async {
          final provider = context.read<FinancesProvider>();
          final confirmed = await _confirm(
            context,
            title: 'Eliminar movimiento',
            message: '¿Eliminar "${transaction.title}"?',
          );
          if (!confirmed) return false;
          try {
            await provider.deleteTransaction(transaction.id);
            return true;
          } catch (e) {
            if (context.mounted) {
              AppFeedback.showMessage(
                context,
                FinancesProvider.describeError(
                  e,
                  fallback: 'No se pudo eliminar',
                ),
              );
            }
            return false;
          }
        },
        child: _TransactionTile(transaction: transaction),
      );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final FinancesTransactionEntity transaction;

  @override
  Widget build(final BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome ? AppColors.success : AppColors.error;
    final d = transaction.date;
    final subtitle = [
      formatDayMonth(d),
      if (transaction.category.isNotEmpty) transaction.category,
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: AppIconSize.xs,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.weight(
                    Theme.of(context).textTheme.bodyMedium!,
                    600,
                  ).copyWith(color: AppColors.textPrimaryDark),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          ),
          Text(
            formatSigned(
              isIncome ? transaction.amount : -transaction.amount,
              currency: kFallbackCurrency,
            ),
            style: AppText.weight(
              Theme.of(context).textTheme.bodyMedium!,
              700,
            ).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Diálogo de confirmación ──────────────────────────────────────────────
Future<bool> _confirm(
  final BuildContext context, {
  required final String title,
  required final String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (final dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimaryDark)),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondaryDark),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

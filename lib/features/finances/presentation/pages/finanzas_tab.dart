import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/finances_provider.dart';
import '../../domain/entities/finances_summary_entity.dart';

class FinanzasTab extends StatelessWidget {
  const FinanzasTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = provider.selected;
    if (summary == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanzasHeader(months: provider.months, selectedIndex: provider.selectedIndex),
          const SizedBox(height: AppSpacing.xl),
          _SummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.xl),
          _GoalProgress(summary: summary),
          const SizedBox(height: AppSpacing.xl),
          _FixedExpenses(summary: summary),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Header + month selector ──────────────────────────────────────────────
class _FinanzasHeader extends StatelessWidget {
  const _FinanzasHeader({required this.months, required this.selectedIndex});
  final List<FinancesSummaryEntity> months;
  final int selectedIndex;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
          AppSpacing.screenHorizontal,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finanzas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: months.length,
                separatorBuilder: (final context, final index) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (final context, final i) {
                  final isSelected = i == selectedIndex;
                  return GestureDetector(
                    onTap: () => context.read<FinancesProvider>().selectMonth(i),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brand : AppColors.surfaceDark,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: isSelected ? AppColors.brand : AppColors.borderDark,
                        ),
                      ),
                      child: Text(
                        months[i].month,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

// ─── Summary Card ─────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final FinancesSummaryEntity summary;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: AppRadius.xxlBorder,
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
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
              ),
            ],
          ),
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

  String _fmt(final double v) =>
      '\$${v.abs().toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (final m) => '${m[1]},')}';

  @override
  Widget build(final BuildContext context) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smBorder,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            _fmt(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isBold ? color : AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      );
}

// ─── Goal Progress ────────────────────────────────────────────────────────
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.summary});
  final FinancesSummaryEntity summary;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Container(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '${(summary.goalProgress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.pillBorder,
                child: LinearProgressIndicator(
                  value: summary.goalProgress,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceDarkSecondary,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Objetivo: \$${summary.monthlyGoal.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ],
          ),
        ),
      );
}

// ─── Fixed Expenses ───────────────────────────────────────────────────────
class _FixedExpenses extends StatelessWidget {
  const _FixedExpenses({required this.summary});
  final FinancesSummaryEntity summary;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos Fijos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: AppRadius.xxlBorder,
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: summary.fixedExpenses.asMap().entries.map((final e) {
                  final expense = e.value;
                  final isLast = e.key == summary.fixedExpenses.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
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
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textPrimaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    expense.category,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondaryDark,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '-\$${expense.amount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          color: AppColors.borderDark,
                          indent: AppSpacing.md,
                          endIndent: AppSpacing.md,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
}

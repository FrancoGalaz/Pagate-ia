import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/month_labels.dart';
import '../../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../../finances/presentation/providers/finances_provider.dart';
import '../../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../../../../core/widgets/pagate_error_state.dart';
import '../../widgets/financial_charts.dart';
import '../../../../../core/theme/app_text.dart';

enum HomeQuickAction {
  sale,
  expense,
  inventory,
  ai,
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onQuickActionTap,
    required this.onNotificationsTap,
  });

  final ValueChanged<HomeQuickAction> onQuickActionTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(onNotificationsTap: onNotificationsTap),
            const SizedBox(height: AppSpacing.md),
            const _BalanceCard(),
            const SizedBox(height: AppSpacing.xl),
            _QuickActions(onActionTap: onQuickActionTap),
            const SizedBox(height: AppSpacing.xl),
            const _ChartsSection(),
            const SizedBox(height: AppSpacing.xl),
            const _RecentActivity(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      );
}

// ─── Header ───────────────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                profile?.avatarInitials ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Sin perfil cargado no se saluda a un nombre inventado.
                  profile == null
                      ? 'Hola'
                      : 'Hola, ${profile.name.split(' ').first}',
                  style: AppText.weight(
                    Theme.of(context).textTheme.titleMedium!,
                    700,
                  ).copyWith(color: AppColors.textPrimaryDark),
                ),
                Text(
                  profile?.businessName ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: onNotificationsTap,
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textSecondaryDark,
                  size: AppIconSize.md,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Balance Card ─────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final summary = finances.summary;

    final income = summary.totalIncome;
    final expenses = summary.totalExpenses;
    final balance = summary.balance;
    final goal = finances.monthlyGoal;
    final progress = finances.goalProgress;
    final month = summary.month;
    final hasData = finances.hasData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: AppRadius.xxlBorder,
          boxShadow: AppShadows.brandStrong,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance del mes',
                  style: AppText.weight(
                    Theme.of(context).textTheme.labelMedium!,
                    600,
                  ).copyWith(color: Colors.white70),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    hasData ? month : 'Sin datos',
                    style: AppText.weight(
                      Theme.of(context).textTheme.labelSmall!,
                      600,
                    ).copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatCurrency(hasData ? balance : 0, currency: kFallbackCurrency),
              style: AppText.weight(
                Theme.of(context).textTheme.displaySmall!,
                800,
              ).copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _MiniStat(label: 'Ingresos', amount: income, icon: Icons.arrow_upward_rounded, isPositive: true),
                const SizedBox(width: AppSpacing.xl),
                _MiniStat(label: 'Gastos', amount: expenses, icon: Icons.arrow_downward_rounded, isPositive: false),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (hasData && goal > 0) ...[
              ClipRRect(
                borderRadius: AppRadius.pillBorder,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Meta: ${formatCurrency(goal, currency: kFallbackCurrency)}'
                '  •  ${(progress * 100).toStringAsFixed(0)}% completado',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ] else
              Text(
                hasData
                    ? 'Define tu meta mensual en tu perfil para ver el progreso'
                    : 'Registra tus primeros ingresos y gastos en Finanzas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
          ],
        ),
      ),
    );
  }

}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.icon,
    required this.isPositive,
  });

  final String label;
  final double amount;
  final IconData icon;
  final bool isPositive;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'Manrope',
                ),
              ),
              Text(
                formatCurrency(amount, currency: kFallbackCurrency),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ],
      );
}

// ─── Quick Actions ────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onActionTap});

  final ValueChanged<HomeQuickAction> onActionTap;

  static const List<_Action> _actions = [
    _Action(
      icon: Icons.add_circle_rounded,
      label: 'Venta',
      color: Color(0xFF00C2B8),
      action: HomeQuickAction.sale,
    ),
    _Action(
      icon: Icons.remove_circle_rounded,
      label: 'Gasto',
      color: Color(0xFFEF4444),
      action: HomeQuickAction.expense,
    ),
    _Action(
      icon: Icons.inventory_2_outlined,
      label: 'Inventario',
      color: Color(0xFF3B82F6),
      action: HomeQuickAction.inventory,
    ),
    _Action(
      icon: Icons.smart_toy_outlined,
      label: 'Preguntar IA',
      color: Color(0xFFF97316),
      action: HomeQuickAction.ai,
    ),
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones rápidas',
              style: AppText.weight(
                Theme.of(context).textTheme.titleMedium!,
                700,
              ).copyWith(color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: _actions
                  .map(
                    (final a) => Expanded(
                      child: _ActionButton(
                        action: a,
                        onTap: () => onActionTap(a.action),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.action,
  });

  final IconData icon;
  final String label;
  final Color color;
  final HomeQuickAction action;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});

  final _Action action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.15),
                borderRadius: AppRadius.lgBorder,
                border: Border.all(
                  color: action.color.withValues(alpha: 0.3),
                  width: AppSizes.borderThin,
                ),
              ),
              child: Icon(action.icon, color: action.color, size: AppIconSize.md),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              action.label,
              style: AppText.weight(
                Theme.of(context).textTheme.labelSmall!,
                600,
              ).copyWith(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ─── Charts Section ──────────────────────────────────────────────────
class _ChartsSection extends StatelessWidget {
  const _ChartsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métricas financieras',
            style: AppText.weight(
              Theme.of(context).textTheme.titleMedium!,
              700,
            ).copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppSpacing.md),
          const MonthlyBarChart(),
          const SizedBox(height: AppSpacing.md),
          const NetBalanceLineChart(),
          const SizedBox(height: AppSpacing.md),
          const CategoryPieChart(),
        ],
      ),
    );
  }
}

// ─── Recent Activity (now from Firestore) ────────────────────────────────
class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final transactions = finances.transactions.take(5).toList();
    final error = finances.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad reciente',
            style: AppText.weight(
              Theme.of(context).textTheme.titleMedium!,
              700,
            ).copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppSpacing.md),
          if (error != null)
            PagateErrorState(
              message: error,
              onRetry: finances.retry,
              compact: true,
            )
          else if (finances.isLoading || finances.isLoadingTransactions)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (transactions.isEmpty)
            Container(
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
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Todavía no registras movimientos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Anota tu primera venta o tu primer gasto en Finanzas.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: AppRadius.xxlBorder,
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: transactions
                    .asMap()
                    .entries
                    .map((entry) => _TransactionRow(
                          transaction: entry.value,
                          isLast: entry.key == transactions.length - 1,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.isLast,
  });

  final FinancesTransactionEntity transaction;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome ? AppColors.success : AppColors.error;

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
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title.isNotEmpty
                          ? transaction.title
                          : transaction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.weight(
                        Theme.of(context).textTheme.bodyMedium!,
                        600,
                      ).copyWith(color: AppColors.textPrimaryDark),
                    ),
                    Text(
                      formatDayMonthYear(transaction.date),
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
  }

}

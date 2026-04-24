import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_mock_data.dart';
import '../../../../finances/presentation/providers/finances_provider.dart';
import '../../../../user_profile/presentation/providers/user_profile_provider.dart';

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
  Widget build(final BuildContext context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(onNotificationsTap: onNotificationsTap),
            const SizedBox(height: AppSpacing.md),
            const _BalanceCard(),
            const SizedBox(height: AppSpacing.xl),
            _QuickActions(onActionTap: onQuickActionTap),
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
  Widget build(final BuildContext context) {
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
                profile?.avatarInitials ?? 'IA',
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
                  'Hola, ${profile?.name.split(' ').first ?? 'Artesano'} 👋',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  profile?.businessName ?? 'Mi Negocio',
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
  Widget build(final BuildContext context) {
    final summary = context.watch<FinancesProvider>().selected;
    final income = summary?.totalIncome ?? 23800;
    final expenses = summary?.totalExpenses ?? 8300;
    final balance = income - expenses;
    final progress = summary?.goalProgress ?? 0.68;
    final goal = summary?.monthlyGoal ?? 35000;

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
                  'Balance del Mes',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
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
                    summary?.month ?? 'Marzo 2025',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '\$${_fmt(balance)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
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
              'Meta: \$${_fmt(goal)}  •  ${(progress * 100).toStringAsFixed(0)}% completado',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(final double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
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
  Widget build(final BuildContext context) => Row(
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
                '\$${amount >= 1000 ? '${(amount / 1000).toStringAsFixed(1)}K' : amount.toStringAsFixed(0)}',
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
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones Rápidas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w700,
                  ),
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
  Widget build(final BuildContext context) => GestureDetector(
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ─── Recent Activity ──────────────────────────────────────────────────────
class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad Reciente',
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
                children: AppMockData.recentActivity
                    .asMap()
                    .entries
                    .map((final e) => _ActivityRow(
                          item: e.value,
                          isLast: e.key == AppMockData.recentActivity.length - 1,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.isLast});
  final Map<String, String> item;
  final bool isLast;

  @override
  Widget build(final BuildContext context) {
    final isIncome = item['type'] == 'income';
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
                      item['title'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      item['time'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                item['amount'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
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
  }
}

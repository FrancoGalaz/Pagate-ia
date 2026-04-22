import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Informational callout card used for tips and contextual hints.
///
/// Displays an icon + rich text inside a light-brand-colored container.
/// Used in FinancialGoalStepScreen and similar informational contexts.
class PagateInfoCard extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Color? backgroundColor;
  final Color? iconColor;

  const PagateInfoCard({
    super.key,
    this.icon = Icons.tips_and_updates_rounded,
    required this.child,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.brandLight,
          borderRadius: AppRadius.xlBorder,
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.1),
            width: AppSizes.borderThin,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor ?? AppColors.brand,
              size: AppIconSize.lg,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: child),
          ],
        ),
      );
}

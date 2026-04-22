import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Unified step header for onboarding flows.
///
/// Provides a consistent layout with:
/// - Back button (left)
/// - Step indicator badge (right)
/// - Linear progress bar
///
/// All three onboarding screens MUST use this component to guarantee
/// visual and behavioral consistency.
class PagateStepHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? stepLabel;
  final VoidCallback? onBack;

  const PagateStepHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabel,
    this.onBack,
  });

  double get _progress => currentStep / totalSteps;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          // Navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              GestureDetector(
                onTap: onBack ?? () => Navigator.pop(context),
                child: Container(
                  width: AppSizes.backButtonSize,
                  height: AppSizes.backButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: AppSizes.borderThin,
                    ),
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: AppColors.textSecondary,
                    size: AppIconSize.md,
                  ),
                ),
              ),

              // Step badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: AppRadius.lgBorder,
                ),
                child: Text(
                  'Paso $currentStep de $totalSteps',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Progress bar
          ClipRRect(
            borderRadius: AppRadius.xsBorder,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: AppSizes.progressBarHeight,
            ),
          ),

          // Optional step label
          if (stepLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                stepLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

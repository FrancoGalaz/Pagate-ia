import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Chip selector for multi/single selection flows.
///
/// Used for category selection (workshop step) and similar patterns.
/// Supports single and multi-select modes.
class PagateChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool allowMultiple;

  const PagateChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.allowMultiple = false,
  });

  @override
  Widget build(final BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: options.map((final option) {
          final isSelected = selected.contains(option);
          return _PagateChip(
            label: option,
            isSelected: isSelected,
            onTap: () => onToggle(option),
          );
        }).toList(),
      );
}

class _PagateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PagateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brand.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: AppRadius.lgBorder,
            border: isSelected
                ? Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                    width: AppSizes.borderThin,
                  )
                : Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: AppSizes.borderThin,
                  ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? AppColors.brand
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
}

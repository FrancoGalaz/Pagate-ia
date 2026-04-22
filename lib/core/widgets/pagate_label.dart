import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Uppercase form field label.
///
/// Standardizes the label pattern used above inputs across all forms.
class PagateLabel extends StatelessWidget {
  final String text;
  final bool isUppercase;

  const PagateLabel(
    this.text, {
    super.key,
    this.isUppercase = false,
  });

  @override
  Widget build(final BuildContext context) => Text(
        isUppercase ? text.toUpperCase() : text,
        style: isUppercase
            ? Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                )
            : Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
      );
}

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_text.dart';

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
            ? AppText.weight(
              Theme.of(context).textTheme.labelSmall!,
              700,
            ).copyWith(color: AppColors.textTertiary, letterSpacing: 0.8)
            : AppText.weight(
              Theme.of(context).textTheme.titleSmall!,
              600,
            ).copyWith(color: AppColors.textSecondary),
      );
}

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Elevated section card used for grouping related form fields.
///
/// Provides a white card with subtle shadow and border, used in
/// workshop step and similar forms.
class PagateSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PagateSectionCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(final BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: AppSizes.borderThin,
          ),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? AppShadows.none
              : AppShadows.sm,
        ),
        child: child,
      );
}

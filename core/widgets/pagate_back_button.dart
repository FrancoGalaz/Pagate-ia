import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Standard back button used across all screens.
///
/// Circular container with a chevron-left icon using consistent
/// sizing and styling from the design system.
class PagateBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const PagateBackButton({super.key, this.onPressed});

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: onPressed ?? () => Navigator.pop(context),
        child: Container(
          width: AppSizes.backButtonSize,
          height: AppSizes.backButtonSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: AppSizes.borderThin,
            ),
          ),
          child: Icon(
            Icons.chevron_left_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: AppIconSize.md,
          ),
        ),
      );
}

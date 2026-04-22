import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Social login button (Google, Apple, etc.).
///
/// Uses [OutlinedButton] with consistent styling from the theme.
class PagateSocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const PagateSocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(final BuildContext context) => SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight - 2,
        child: OutlinedButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurface,
                size: AppIconSize.sm,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label),
            ],
          ),
        ),
      );
}

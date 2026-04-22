import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Primary CTA button with brand gradient shadow.
///
/// Wraps [ElevatedButton] with the standard brand shadow, consistent
/// sizing, and optional leading/trailing icons.
class PagatePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final bool isLoading;
  final bool hasShadow;

  const PagatePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.isLoading = false,
    this.hasShadow = true,
  });

  @override
  Widget build(final BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Container(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      decoration: hasShadow && isEnabled
          ? BoxDecoration(
              borderRadius: AppRadius.pillBorder,
              boxShadow: AppShadows.brand,
            )
          : null,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        child: isLoading
            ? const SizedBox(
                width: AppIconSize.md,
                height: AppIconSize.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textOnBrand,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: AppIconSize.md),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(label),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(trailingIcon, size: AppIconSize.md),
                  ],
                ],
              ),
      ),
    );
  }
}

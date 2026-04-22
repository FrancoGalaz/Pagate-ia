import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

/// Glassmorphism card with blur effect (Dark theme).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(final BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.6),
          borderRadius: AppRadius.xlBorder,
          border: Border.all(
            color: AppColors.glassStrong,
            width: AppSizes.borderNormal,
          ),
          boxShadow: AppShadows.lg,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      );
}

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Estado de error genérico con botón de reintento.
///
/// Se usa cuando un stream o una carga falla (sin conexión, sin permisos,
/// etc.). No está en el barrel `widgets.dart`: impórtalo directo.
class PagateErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  const PagateErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: AppColors.error,
          size: compact ? AppIconSize.lg : AppIconSize.hero,
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
              ?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: AppRadius.xlBorder,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      ),
    );
  }
}

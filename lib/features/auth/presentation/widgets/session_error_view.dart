import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/theme/app_text.dart';

/// Estado de error a pantalla completa con reintento y, opcionalmente,
/// cierre de sesión (útil cuando el perfil no se puede leer por permisos).
class SessionErrorView extends StatelessWidget {
  const SessionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSignOut;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: AppIconSize.hero,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'No pudimos cargar tus datos',
                textAlign: TextAlign.center,
                style: AppText.weight(textTheme.headlineSmall!, 800).copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PagatePrimaryButton(
                label: 'Reintentar',
                trailingIcon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
              if (onSignOut != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

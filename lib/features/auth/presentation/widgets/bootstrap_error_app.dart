import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/theme/app_text.dart';

/// App mínima que se monta cuando `bootstrapFirebase()` falla antes de que
/// exista [PagateIAApp]. Sin esto el usuario vería una pantalla negra.
///
/// No depende de Firebase ni de providers: solo del tema y de los tokens.
/// [onRetry] debe volver a intentar el arranque y, si tiene éxito, montar la
/// app real con `runApp`.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) => MaterialApp(
        title: 'Págate-IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: _BootstrapErrorView(error: error, onRetry: onRetry),
      );
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: AppIconSize.hero,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'No pudimos iniciar la app',
                  textAlign: TextAlign.center,
                  style: AppText.weight(textTheme.headlineSmall!, 800).copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Revisa tu conexión e inténtalo de nuevo. '
                  'Si el problema continúa, cierra la app y vuelve a abrirla.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Detalle: $error',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PagatePrimaryButton(
                  label: 'Reintentar',
                  trailingIcon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

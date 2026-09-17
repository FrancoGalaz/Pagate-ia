import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Pantalla de espera mientras se resuelve la sesión o se carga el perfil.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.xlBorder,
                  boxShadow: AppShadows.brandStrong,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: AppIconSize.xxl,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Págate-IA',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SizedBox(
                width: AppIconSize.md,
                height: AppIconSize.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      );
}

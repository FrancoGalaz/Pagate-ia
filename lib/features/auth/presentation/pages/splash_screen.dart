import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';

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
                style: AppText.weight(
                  Theme.of(context).textTheme.headlineSmall!,
                  800,
                ).copyWith(color: AppColors.textPrimaryDark),
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

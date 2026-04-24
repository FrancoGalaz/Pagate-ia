import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';
import '../../../onboarding/presentation/pages/setup_inicial_screen.dart';

class PostLoginWelcomeScreen extends StatelessWidget {
  const PostLoginWelcomeScreen({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: AppRadius.xlBorder,
                    boxShadow: AppShadows.brandStrong,
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: AppIconSize.xxl,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Bienvenido, $userName',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tu sesión ya está activa. Vamos a dejar tu negocio listo para trabajar con Págate-IA.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _FeatureBullet(
                  icon: Icons.bar_chart_rounded,
                  text: 'Monitorea ingresos y gastos en tiempo real.',
                ),
                const SizedBox(height: AppSpacing.sm),
                _FeatureBullet(
                  icon: Icons.inventory_2_outlined,
                  text: 'Controla inventario y alertas de stock bajo.',
                ),
                const SizedBox(height: AppSpacing.sm),
                _FeatureBullet(
                  icon: Icons.smart_toy_outlined,
                  text: 'Usa IA para decisiones de precios y margen.',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (final _) => const SetupInicialScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Continuar configuración'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (final _) => const DashboardScreen(),
                        ),
                      );
                    },
                    child: const Text('Entrar al Dashboard ahora'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      );
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(final BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.16),
              borderRadius: AppRadius.smBorder,
            ),
            child: Icon(icon, size: 16, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ),
        ],
      );
}

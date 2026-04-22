import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import 'phone_input_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow effect
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Logo Header
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: AppSizes.avatarSmall,
                        height: AppSizes.avatarSmall,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.brand,
                        ),
                        child: const Icon(
                          Icons.paid_outlined,
                          color: AppColors.textOnBrand,
                          size: AppIconSize.sm - 2,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Págate-IA',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.lg),

                        // Hero illustration area
                        SizedBox(
                          height: 340,
                          width: 340,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Center circle
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.surface,
                                      AppColors.brand.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.surface
                                        .withValues(alpha: 0.5),
                                    width: AppSizes.borderThin,
                                  ),
                                  boxShadow: AppShadows.xl,
                                ),
                                child: Icon(
                                  Icons.handyman_outlined,
                                  size: 80,
                                  color: AppColors.textTertiary
                                      .withValues(alpha: 0.3),
                                ),
                              ),

                              // Floating card: Ganancia
                              const Positioned(
                                right: 10,
                                top: 100,
                                child: _FloatingStatsCard(
                                  icon: Icons.trending_up,
                                  iconColor: AppColors.textOnBrand,
                                  iconBackground: AppColors.brand,
                                  label: 'GANANCIA',
                                  value: '+24%',
                                ),
                              ),

                              // Floating card: Stock
                              const Positioned(
                                left: 0,
                                bottom: 80,
                                child: _FloatingStatsCard(
                                  icon: Icons.inventory_2_outlined,
                                  iconColor: AppColors.accent,
                                  iconBackground: AppColors.accentLight,
                                  label: 'STOCK',
                                  value: 'Optimizado',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Hero text
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: textTheme.displaySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            children: const [
                              TextSpan(text: 'Tu talento crea,\n'),
                              TextSpan(
                                text: 'nosotros calculamos.',
                                style: TextStyle(
                                  color: AppColors.brand,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.brand,
                                  decorationStyle: TextDecorationStyle.solid,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Subtitle
                        Text(
                          'La primera herramienta financiera\ndiseñada por y para artesanos.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Footer actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PagatePrimaryButton(
                        label: 'Empezar ahora (Gratis)',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (final context) =>
                                  const PhoneInputScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      PagateSocialButton(
                        label: 'Continuar con Google',
                        icon: Icons.g_mobiledata,
                        onPressed: () {},
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PagateSocialButton(
                        label: 'Continuar con Apple',
                        icon: Icons.apple,
                        onPressed: () {},
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Login link
                      GestureDetector(
                        onTap: () {
                          // TODO: Navigate to Login
                        },
                        child: RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            children: [
                              const TextSpan(
                                text: '¿Ya eres parte de la comunidad? ',
                              ),
                              TextSpan(
                                text: 'Inicia Sesión',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Terms
                      Text(
                        'Al continuar, aceptas nuestros Términos y Privacidad.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal stat card for the welcome hero illustration.
class _FloatingStatsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  const _FloatingStatsCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdBorder,
          boxShadow: AppShadows.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxs + 2),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadius.xsBorder,
              ),
              child: Icon(icon, color: iconColor, size: AppIconSize.xs),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ],
        ),
      );
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import 'login_screen.dart';
import '../../../onboarding/presentation/pages/identity_step_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _signInWithGoogle(final BuildContext context) async {
    try {
      await GoogleAuthService().signIn();
      // El AuthGate detecta la sesión nueva.
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    }
  }

  // Ya no fuerza su propio tema: la app tiene un tema claro único, y ningún
  // widget vuelve a decidir su propio brillo.
  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final googleAvailable = GoogleAuthService().isAvailable;

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
                        decoration: const BoxDecoration(
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
                                    color: AppColors.surface.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: AppSizes.borderThin,
                                  ),
                                  boxShadow: AppShadows.xl,
                                ),
                                child: Icon(
                                  Icons.handyman_outlined,
                                  size: 80,
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),

                              // AQUI IBAN DOS TARJETAS FLOTANTES Y SE
                              // BORRARON A PROPOSITO: una decia
                              // "GANANCIA +24%" y la otra "STOCK Optimizado".
                              // Ninguna de las dos salia de Firestore: eran
                              // literales escritos en el widget, con la forma
                              // de un dato real del negocio, en la primera
                              // pantalla que ve alguien que todavia no tiene
                              // cuenta. Ningun pixel de la app afirma algo que
                              // Firestore no diga (docs/DISENO-v2.md,
                              // principio 7).
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
                                  const IdentityStepScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      if (googleAvailable) ...[
                        PagateSocialButton(
                          label: 'Continuar con Google',
                          icon: Icons.g_mobiledata,
                          onPressed: () => _signInWithGoogle(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      PagateSocialButton(
                        label: 'Continuar con Apple',
                        icon: Icons.apple,
                        onPressed: () => AppFeedback.showMessage(
                          context,
                          'Apple Sign-In estará disponible próximamente.',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Login link
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (final _) => const LoginScreen(),
                            ),
                          );
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
                      const SizedBox(height: AppSpacing.xxs),
                      TextButton(
                        onPressed: () => AppFeedback.showMessage(
                          context,
                          'Puedes revisar los términos desde configuración.',
                        ),
                        child: const Text('Ver términos'),
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

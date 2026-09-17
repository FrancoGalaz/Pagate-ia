import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_social_button.dart';
import '../../../../core/widgets/pagate_text_field.dart';
import '../../../onboarding/presentation/pages/identity_step_screen.dart';

/// Inicio de sesión con correo/contraseña (y Google en web).
///
/// No navega al terminar: el `AuthGate` reacciona al cambio de sesión.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleAuth = GoogleAuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (final _) => const IdentityStepScreen()),
    );
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Ingresa tu correo primero para enviarte el enlace de recuperación.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context
          .read<FirebaseAuthService>()
          .sendPasswordReset(email: email);
      if (!mounted) return;
      AppFeedback.showMessage(
        context,
        'Te enviamos un enlace de recuperación a $email',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (!_googleAuth.isAvailable) return;

    setState(() => _isLoading = true);
    try {
      await _googleAuth.signIn();
      // El AuthGate detecta la sesión nueva.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return; // El usuario cerró el popup: no es un error.
      }
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onAppleSignIn() {
    AppFeedback.showMessage(
      context,
      'Apple Sign-In estará disponible próximamente.',
    );
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Completa correo y contraseña para continuar.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<FirebaseAuthService>().signInWithEmailAndPassword(
            email: email,
            password: password,
          );
      // El AuthGate detecta la sesión nueva.
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.hero),

                // Logo
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

                // Title
                Text(
                  'Págate-IA',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Controla tu taller, maximiza tus ganancias',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.section),

                // Form
                PagateTextField(
                  controller: _emailController,
                  hintText: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                PagateTextField(
                  controller: _passwordController,
                  hintText: 'Contraseña',
                  isPassword: true,
                  prefixIcon: Icons.lock_outline_rounded,
                ),

                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _onForgotPassword,
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brand,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                PagatePrimaryButton(
                  label: 'Iniciar Sesión',
                  isLoading: _isLoading,
                  onPressed: _onLogin,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        'o continúa con',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Social buttons
                if (_googleAuth.isAvailable) ...[
                  PagateSocialButton(
                    label: 'Continuar con Google',
                    icon: Icons.g_mobiledata_rounded,
                    onPressed: _onGoogleSignIn,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                PagateSocialButton(
                  label: 'Continuar con Apple',
                  icon: Icons.apple_rounded,
                  onPressed: _onAppleSignIn,
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    TextButton(
                      onPressed: _goToRegister,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Crear cuenta',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_social_button.dart';
import '../../../../core/widgets/pagate_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/google_auth_service.dart';
import 'post_login_welcome_screen.dart';
import 'welcome_screen.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToPostLoginWelcome() {
    final fallbackName = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim().split('@').first
        : 'Artesano';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (final _) => PostLoginWelcomeScreen(userName: fallbackName),
      ),
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
      AppFeedback.showMessage(
        context,
        'Error al enviar recuperación. Verifica que el correo esté registrado.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (!kIsWeb) {
      AppFeedback.showMessage(
        context,
        'Google Sign-In en Android requiere configuración adicional.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final googleAuth = GoogleAuthService();
      await googleAuth.signIn();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (final _) => const DashboardScreen()),
        (final route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'web-config-not-found' ||
          e.code == 'configuration-not-found') {
        AppFeedback.showMessage(
          context,
          'Configura una App Web en Firebase Console para usar Google Sign-In.',
        );
      } else if (e.code == 'popup-closed-by-user') {
        // User closed the popup, do nothing
      } else {
        AppFeedback.showMessage(
          context,
          'Error al iniciar con Google: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(
        context,
        'Google Sign-In no disponible en esta plataforma.',
      );
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
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (final _) => const DashboardScreen()),
        (final route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(
        context,
        'Error al iniciar sesión. Verifica tus credenciales.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
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
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
              PagateSocialButton(
                label: 'Continuar con Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: _onGoogleSignIn,
              ),
              const SizedBox(height: AppSpacing.sm),
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
                    onPressed: _goToSignupWelcome,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Crear cuenta',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
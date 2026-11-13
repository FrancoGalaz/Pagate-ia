import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/presentation/pages/identity_step_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// INICIO DE SESIÓN
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · EL BOTÓN "Continuar con Apple". Era un botón visible, a ancho completo,
//   cuya única consecuencia era un aviso que decía 'El ingreso con Apple
//   todavía no está disponible.' No hay `sign_in_with_apple` en
//   `pubspec.yaml` ni proveedor de Apple configurado. En el APK que va a
//   Play, con Google oculto (`isAvailable` es `kIsWeb`), ESE era el único
//   botón social visible: la pantalla ofrecía una forma de entrar que no
//   existía. Fuera el botón y fuera `_onAppleSignIn`.
//
// · EL SEPARADOR "o continúa con", que ahora solo se dibuja si queda algún
//   proveedor social. Antes partía la pantalla en dos para presentar un
//   botón muerto.
//
// · EL LOGOTIPO: un cuadrado de 72 dp con degradado de marca, glow verde
//   al 40% y un
//   `Icons.bolt_rounded` dentro, más el nombre debajo en `displaySmall` con
//   `AppText.weight(..., 800)`. Era el SEGUNDO logotipo de la app. Pasa a
//   [PagateWordmark], el único.
//
// · EL CENTRADO. Toda la pantalla iba en `CrossAxisAlignment.center`,
//   incluida la frase bajo el nombre; el sistema alinea a la izquierda.
//
// · "¿Olvidaste tu contraseña?" y "Crear cuenta", que eran `TextButton` con
//   `minimumSize: Size.zero` + `tapTargetSize: shrinkWrap` —dos de los once
//   controles por debajo del área táctil mínima—, pasan a la variante de
//   texto del botón del sistema, que trae los 48 dp.
//
// · LOS DOS CAMPOS pierden su `prefixIcon` (sobre y candado) y ganan
//   etiqueta, `autofillHints` y `textInputAction`: el gestor de contraseñas
//   del teléfono ahora los reconoce.
// ═══════════════════════════════════════════════════════════════════════

/// Inicio de sesión con correo/contraseña (y Google en web).
///
/// No navega al terminar: el `AuthGate` reacciona al cambio de sesión.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleAuth = GoogleAuthService();

  bool _isLoading = false;

  /// Mensaje del último intento fallido.
  ///
  /// Se queda EN LA PANTALLA y no en un aviso flotante: un error de
  /// autenticación hay que poder volver a leerlo mientras se corrige el
  /// correo, y el `SnackBar` se iba a los cuatro segundos.
  String? _error;

  /// Confirmación de que se envió el correo de recuperación.
  String? _aviso;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToRegister() => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (final _) => const IdentityStepScreen(),
        ),
      );

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _aviso = null;
        _error = 'Escribe tu correo y te enviamos el enlace de recuperación.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _aviso = null;
    });
    try {
      await context
          .read<FirebaseAuthService>()
          .sendPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _aviso = 'Te enviamos un enlace de recuperación '
          'a $email.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (!_googleAuth.isAvailable) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _aviso = null;
    });
    try {
      await _googleAuth.signIn();
      // El AuthGate detecta la sesión nueva.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return; // El usuario cerró el popup: no es un error.
      }
      setState(() => _error = describeFirebaseError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLogin() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _aviso = null;
    });
    try {
      await context.read<FirebaseAuthService>().signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // El AuthGate detecta la sesión nueva.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x8,
            ),
            children: [
              const PagateWordmark(size: PagateWordmarkSize.grande),
              const SizedBox(height: AppSpacing.x6),
              Text(
                'Entra con el correo con el que creaste tu cuenta.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppPalette.textSecondary,
                ),
              ),

              const SizedBox(height: AppSpacing.x8),

              PagateTextField(
                labelText: 'Correo',
                controller: _emailController,
                hintText: 'tu@correo.cl',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe tu correo'
                    : null,
              ),
              const SizedBox(height: AppSpacing.x4),
              PagateTextField(
                labelText: 'Contraseña',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (final _) => _onLogin(),
                validator: (final v) => (v == null || v.isEmpty)
                    ? 'Escribe tu contraseña'
                    : null,
              ),

              const SizedBox(height: AppSpacing.x2),
              Align(
                alignment: Alignment.centerLeft,
                child: PagatePrimaryButton.text(
                  label: '¿Olvidaste tu contraseña?',
                  onPressed: _isLoading ? null : _onForgotPassword,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.x2),
                PagateInlineError(message: _error),
              ],
              if (_aviso != null) ...[
                const SizedBox(height: AppSpacing.x2),
                Text(
                  _aviso!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.brand,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x6),
              PagatePrimaryButton(
                label: 'Iniciar sesión',
                isLoading: _isLoading,
                onPressed: _onLogin,
              ),

              // El separador y el botón de Google solo existen donde Google
              // existe de verdad: `isAvailable` es `kIsWeb`. Antes, en el
              // APK, este bloque dejaba en pantalla un único botón social y
              // era el de Apple, que no hacía nada.
              if (_googleAuth.isAvailable) ...[
                const SizedBox(height: AppSpacing.x6),
                const _Separador(),
                const SizedBox(height: AppSpacing.x4),
                PagateSocialButton(
                  label: 'Continuar con Google',
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: _isLoading ? null : _onGoogleSignIn,
                ),
              ],

              const SizedBox(height: AppSpacing.x8),
              Align(
                alignment: Alignment.centerLeft,
                child: PagatePrimaryButton.text(
                  label: 'No tengo cuenta: crear una',
                  onPressed: _isLoading ? null : _goToRegister,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea con "o continúa con" en medio.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(final BuildContext context) => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
            child: Text(
              'o continúa con',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.textMuted,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );
}

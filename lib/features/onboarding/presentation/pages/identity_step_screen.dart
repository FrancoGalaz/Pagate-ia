import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════════
// REGISTRO CON CORREO Y CONTRASEÑA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 6.2, y tarea B2-04 de
// docs/PLAN.md.
//
// Al crear la cuenta el `AuthGate` detecta la sesión y abre el onboarding
// (`SetupInicialScreen`) dentro del `UserScope`; el nombre se guarda en el
// `displayName` de Auth para precargarlo allí. Esta pantalla no navega.
//
// QUÉ SE BORRÓ Y POR QUÉ:
//
// · LA SECCIÓN "CONFIGURACIÓN REGIONAL" ENTERA, con sus dos builders. Eran
//   ~130 px que no producían NINGÚN dato: el selector de país era un
//   `Container` con un chevron que no tenía `onTap` en ninguna línea —no se
//   podía tocar— y no existe campo `country` en el modelo
//   (docs/ARQUITECTURA.md). Y `_selectedCurrency` cambiaba con las
//   pestañas, pero `_onNext` NO LO LEÍA NUNCA, y acto seguido
//   `setup_inicial_screen` volvía a preguntar la moneda. Es la tarea B2-04.
//
// · LA BARRA DE PROGRESO "Paso 1 de 3". Los pasos 2 y 3 no existen: en
//   `features/onboarding/presentation/pages/` solo hay dos archivos y el
//   segundo no usa `PagateStepHeader` en ninguna línea. Dos pantallas no
//   necesitan barra de progreso.
//
// · EL SALUDO "¡Hola, artesano! 👋" y "para que puedas recibir pagos
//   globalmente": la app no procesa pagos ni tiene pasarela.
//
// · EL DEGRADADO `fadeToWhite` del pie, que además no podía funcionar —el
//   árbol es una cabecera, un scroll y el contenedor del botón, así que el
//   botón nunca se superponía al scroll y el degradado se dibujaba sobre
//   blanco— y con él los 96 px de espacio vacío puro que lo acompañaban.
//
// · LOS ENLACES LEGALES FALSOS: "Términos" y "Privacidad" iban pintados en
//   color de marca pero eran `TextSpan` SIN `recognizer`, es decir, no
//   respondían al toque. Y el bloque estaba dentro de un `Center`,
//   rompiendo la alineación del formulario. La aceptación se declara en la
//   bienvenida, que es donde el usuario decide crear la cuenta, y allí los
//   dos enlaces sí son controles de verdad.
//
// QUÉ GANA:
//
// · `Form` con `validator` por campo, en vez de tres `if` que disparaban un
//   snackbar genérico: el error sale debajo del campo que lo causa.
// · `AutofillGroup` con `.name`, `.email` y `.newPassword`, y `next` entre
//   campos con `done` en el último. En todo `lib/` había CERO
//   `autofillHints`.
// · `PopScope`: el botón atrás ya no descarta tres campos escritos sin
//   avisar.
// ═══════════════════════════════════════════════════════════════════════

class IdentityStepScreen extends StatefulWidget {
  const IdentityStepScreen({super.key});

  @override
  State<IdentityStepScreen> createState() => _IdentityStepScreenState();
}

class _IdentityStepScreenState extends State<IdentityStepScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;

  /// Mínimo que exige Firebase Auth. Se declara una vez para que el mensaje
  /// y la comprobación no puedan desincronizarse.
  static const int _minimoContrasena = 6;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _hayAlgoEscrito =>
      _nameController.text.trim().isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _passwordController.text.isNotEmpty;

  String? _validarNombre(final String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Escribe tu nombre' : null;

  /// Comprobación deliberadamente laxa: la de verdad la hace Firebase Auth y
  /// su error llega al usuario por `describeFirebaseError`. Una expresión
  /// regular estricta rechaza direcciones válidas y no aporta seguridad.
  String? _validarCorreo(final String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe tu correo';
    if (!texto.contains('@') || !texto.contains('.')) {
      return 'Ese correo no parece válido';
    }
    return null;
  }

  String? _validarContrasena(final String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Escribe una contraseña';
    if (texto.length < _minimoContrasena) {
      return 'Usa al menos $_minimoContrasena caracteres';
    }
    return null;
  }

  Future<void> _crearCuenta() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await context.read<FirebaseAuthService>().createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          );
      // El AuthGate detecta la sesión nueva y abre el onboarding.
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pregunta antes de descartar lo escrito. `true` si se puede salir.
  Future<bool> _confirmarSalida() async {
    if (!_hayAlgoEscrito || _isLoading) return true;

    final salir = await showPagateSheet<bool>(
      context: context,
      builder: (final sheetContext) => PagateSheet(
        title: '¿Descartar lo escrito?',
        primaryAction: PagatePrimaryButton.secondary(
          label: 'Seguir escribiendo',
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
        secondaryAction: PagatePrimaryButton(
          label: 'Descartar',
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        child: Text(
          'Perderás el nombre, el correo y la contraseña que escribiste.',
          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: AppPalette.textSecondary,
              ),
        ),
      ),
    );
    return salir ?? false;
  }

  Future<void> _volver() async {
    if (!await _confirmarSalida()) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (final didPop, final _) {
        if (didPop) return;
        unawaited(_volver());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _volver,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  child: Form(
                    key: _formKey,

                    // El error aparece en cuanto el campo se toca, no solo al
                    // pulsar el botón: así el usuario no llega al pie para
                    // enterarse de que escribió mal el correo.
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crea tu cuenta',
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppSpacing.x2),
                          Text(
                            'Después configuras tu taller y tu meta del mes.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppPalette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x8),
                          PagateTextField(
                            labelText: 'Nombre completo',
                            hintText: 'Camila Rojas',
                            controller: _nameController,
                            validator: _validarNombre,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (final _) =>
                                _emailFocus.requestFocus(),
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          PagateTextField(
                            labelText: 'Correo electrónico',
                            hintText: 'camila@taller.cl',
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validarCorreo,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (final _) =>
                                _passwordFocus.requestFocus(),
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          PagateTextField(
                            labelText: 'Contraseña',
                            hintText: 'Al menos $_minimoContrasena caracteres',
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            isPassword: true,
                            validator: _validarContrasena,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (final _) =>
                                unawaited(_crearCuenta()),
                          ),
                          const SizedBox(height: AppSpacing.x6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // El pie es una barra con línea de 1 px, no un degradado.
              PagateActionBar(
                child: PagatePrimaryButton(
                  label: 'Crear cuenta',
                  isLoading: _isLoading,
                  onPressed: _crearCuenta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// ONBOARDING — CONFIGURAR EL TALLER
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 6.3.
//
// Se muestra dentro del `UserScope` cuando el usuario autenticado todavía no
// tiene perfil en `users/{uid}`. Al guardar, el stream del perfil hace que el
// gate pase solo al dashboard; no hay navegación manual.
//
// EL BUG FUNCIONAL QUE SE ARREGLA AQUÍ. La versión anterior reinyectaba el
// `displayName` desde `didChangeDependencies`, que se dispara con CADA
// cambio de dependencia: abrir el teclado, rotar, cambiar el tamaño de
// fuente. Si el usuario borraba el nombre para escribir otro, se lo volvían
// a rellenar y el cursor saltaba al inicio. Ahora la precarga ocurre UNA
// vez, controlada por [_nombrePrecargado].
//
// QUÉ MÁS CAMBIA:
//   · `_SectionLabel` (titleSmall en 700, numerado "1.", "2.", "3.") y
//     `_PillSelector` (GestureDetector + AnimatedContainer con radio
//     pastilla) desaparecen: son dos de los cuatro criterios de selección
//     que coexistían en la app. Ahora son `PagateSectionHeader` y
//     `PagateChipSelector`, con el rol y el estado que pone Material.
//   · Las tres validaciones dejan de ser snackbars genéricos lanzados al
//     pulsar el botón y pasan a `Form` con `validator`: el error sale
//     debajo del campo que lo causa. La del tipo de negocio, que no es un
//     campo de texto, sigue siendo un aviso, pero ahora al lado del grupo.
//   · El botón de guardar vive en una `PagateActionBar` fija: en un
//     formulario de cuatro datos no tiene sentido desplazarse para llegar
//     a la acción.
//
// LA META SE LEE CON `parseCurrencyInput`, que ya estaba. Vale la pena
// repetir por qué: `double.tryParse('800.000')` devuelve 800.0 y la
// validación `goal <= 0` lo dejaba pasar en silencio, así que una meta de
// ochocientos mil pesos entraba al perfil como OCHOCIENTOS y la barra de
// progreso de Inicio marcaba 100% con la primera venta.
// ═══════════════════════════════════════════════════════════════════════

class SetupInicialScreen extends StatefulWidget {
  const SetupInicialScreen({super.key});

  @override
  State<SetupInicialScreen> createState() => _SetupInicialScreenState();
}

class _SetupInicialScreenState extends State<SetupInicialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _goalController = TextEditingController();

  final _businessFocus = FocusNode();
  final _goalFocus = FocusNode();

  Set<String> _selectedType = {};
  String _selectedCurrency = kDefaultCurrency;
  bool _isSaving = false;

  /// El `displayName` de Auth llega de forma asíncrona, así que no se puede
  /// leer en `initState`. Esta bandera hace que la precarga sea de UNA sola
  /// vez aunque `didChangeDependencies` se dispare muchas.
  bool _nombrePrecargado = false;

  /// Se muestra bajo los chips cuando el usuario intenta guardar sin elegir
  /// rubro. No es un campo de texto, así que no tiene `validator` propio.
  bool _faltaRubro = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nombrePrecargado) return;

    final displayName = context.watch<FirebaseAuthService>().displayName;
    if (displayName == null || displayName.isEmpty) return;

    _nameController.text = displayName;
    _nombrePrecargado = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _goalController.dispose();
    _businessFocus.dispose();
    _goalFocus.dispose();
    super.dispose();
  }

  String? _validarObligatorio(final String? valor, final String queFalta) =>
      (valor == null || valor.trim().isEmpty) ? queFalta : null;

  String? _validarMeta(final String? valor) {
    final meta = parseCurrencyInput(valor ?? '');
    if (meta == null) return 'Escribe cuánto quieres ganar al mes';
    if (meta <= 0) return 'La meta tiene que ser mayor que cero';
    return null;
  }

  Future<void> _guardar() async {
    if (_isSaving) return;

    final formularioValido = _formKey.currentState?.validate() ?? false;
    final hayRubro = _selectedType.isNotEmpty;
    if (!hayRubro) setState(() => _faltaRubro = true);
    if (!formularioValido || !hayRubro) return;

    setState(() => _isSaving = true);
    try {
      await context.read<UserProfileProvider>().updateFromSetup(
            name: _nameController.text.trim(),
            businessName: _businessController.text.trim(),
            businessType: _selectedType.first,
            currency: _selectedCurrency,
            monthlyGoal: parseCurrencyInput(_goalController.text)!,
          );
      // El gate reacciona al stream del perfil y muestra el dashboard.
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.x6),
                      Text(
                        'Configura tu taller',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        'Puedes cambiar todo esto después.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x8),

                      // ── Quién eres ────────────────────────────────────
                      PagateTextField(
                        labelText: 'Tu nombre',
                        hintText: 'Camila Rojas',
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (final _) =>
                            _businessFocus.requestFocus(),
                        validator: (final v) =>
                            _validarObligatorio(v, 'Escribe tu nombre'),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      PagateTextField(
                        labelText: 'Nombre de tu taller',
                        hintText: 'Greda Austral',
                        controller: _businessController,
                        focusNode: _businessFocus,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (final _) => _goalFocus.requestFocus(),
                        validator: (final v) => _validarObligatorio(
                          v,
                          'Escribe el nombre de tu taller',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.x6),

                      // ── Rubro ─────────────────────────────────────────
                      Text(
                        '¿A qué te dedicas?',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      PagateChipSelector(
                        options: kBusinessTypes,
                        selected: _selectedType,
                        onToggle: (final option) => setState(() {
                          _selectedType = {option};
                          _faltaRubro = false;
                        }),
                      ),
                      if (_faltaRubro) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          'Elige tu rubro para continuar',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.danger,
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.x6),

                      // ── Meta del mes ──────────────────────────────────
                      Text(
                        'Moneda',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      PagateChipSelector(
                        options: kSupportedCurrencies,
                        selected: {_selectedCurrency},
                        onToggle: (final v) =>
                            setState(() => _selectedCurrency = v),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      PagateTextField.amount(
                        labelText: '¿Cuánto quieres ganar al mes?',
                        hintText: '0',
                        controller: _goalController,
                        focusNode: _goalFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (final _) => unawaited(_guardar()),
                        validator: _validarMeta,
                      ),

                      const SizedBox(height: AppSpacing.x6),
                      PagatePrimaryButton.text(
                        label: 'Usar otra cuenta',
                        onPressed: () =>
                            context.read<FirebaseAuthService>().signOut(),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                    ],
                  ),
                ),
              ),
            ),
            PagateActionBar(
              child: PagatePrimaryButton(
                label: 'Guardar y empezar',
                isLoading: _isSaving,
                onPressed: _guardar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

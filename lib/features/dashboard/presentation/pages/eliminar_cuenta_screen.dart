/// PROPÓSITO: la ruta de borrado de cuenta DENTRO de la app.
///
/// REQUISITO DE GOOGLE PLAY. La política de eliminación de datos pide dos
/// caminos para borrar una cuenta: una URL pública (que la landing ya tiene) y
/// uno dentro de la app. El callable `deleteAccount` existe desde hace tiempo
/// en `functions/src/account.ts`, pero en `lib/` no había una sola referencia,
/// así que el camino que el revisor de Play prueba de verdad no existía.
///
/// Decisiones de esta pantalla, por si no son obvias:
///
/// - Es una PANTALLA y no un diálogo. Hay que caber una lista de lo que se
///   borra, un aviso de que no se puede deshacer y un campo de confirmación;
///   nada de eso entra en un `AlertDialog` sin volverse ilegible.
/// - La confirmación es ESCRIBIR una palabra, no un segundo botón. Un segundo
///   botón se pulsa con el mismo gesto que el primero; escribir "ELIMINAR"
///   obliga a leer.
/// - El cierre de sesión va DESPUÉS de que el callable confirme. Si se
///   cerrara antes, el token se habría ido y la llamada llegaría sin auth.
/// - El error se muestra tal como lo manda el servidor, porque solo él sabe
///   en qué paso se quedó: "no se borró nada" y "tus datos se borraron pero no
///   se pudo cerrar la cuenta" no son lo mismo y no se pueden confundir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/account_service.dart';
import '../../../../core/widgets/widgets.dart';

/// Palabra que hay que escribir para habilitar el botón.
const String kConfirmacionBorrado = 'ELIMINAR';

/// Lo que borra el callable, en el mismo orden en que el backend recorre el
/// árbol. No es decorativo: Play pide que la persona sepa qué pierde.
const List<String> kDatosQueSeBorran = [
  'Tu perfil: nombre, negocio, moneda, meta y valor hora.',
  'Tu inventario completo, productos y materiales.',
  'Todos tus movimientos y tus gastos fijos.',
  'Los resúmenes mensuales calculados a partir de ellos.',
  'Tus conversaciones con el asistente.',
  'Tu credencial de acceso, para que nadie pueda volver a entrar.',
];

class EliminarCuentaScreen extends StatefulWidget {
  const EliminarCuentaScreen({
    super.key,
    required this.email,
    required this.onDeleted,
    this.accountService,
  });

  /// Correo de la cuenta, solo para decir en pantalla cual se va a borrar.
  final String? email;

  /// Que hacer cuando el callable confirma el borrado: en la app, cerrar
  /// sesion.
  ///
  /// Llega por parametro y no por `context.read<FirebaseAuthService>()` para
  /// que esta pantalla no dependa de Firebase y se pueda probar con un
  /// `MaterialApp` pelado, como pide AGENTS.md para los widget tests.
  final Future<void> Function() onDeleted;

  /// Inyectable para las pruebas; en la app se construye el real.
  final AccountService? accountService;

  @override
  State<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends State<EliminarCuentaScreen> {
  final _confirmacion = TextEditingController();
  late final AccountService _service =
      widget.accountService ?? AccountService();

  bool _borrando = false;
  String? _error;

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _puedeBorrar =>
      _confirmacion.text.trim().toUpperCase() == kConfirmacionBorrado;

  Future<void> _eliminar() async {
    if (!_puedeBorrar || _borrando) return;

    setState(() {
      _borrando = true;
      _error = null;
    });

    try {
      await _service.deleteAccount();
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        _borrando = false;
        _error = e.message;
      });
      return;
    }

    // No se baja `_borrando`: tras un borrado correcto el botón se queda en
    // carga hasta que la pantalla desaparece. Devolverlo a su estado normal
    // mostraría, durante un instante, un botón de "Eliminar mi cuenta"
    // pulsable sobre una cuenta que ya no existe.
    //
    // Los datos y la credencial ya no están. Queda soltar el token local: el
    // `AuthGate` escucha `authStateChanges` y reconstruye la app desde la
    // bienvenida, con un `MaterialApp` de sesión nueva, así que esta ruta
    // desaparece sola y no hace falta navegar a mano.
    await widget.onDeleted();
  }

  @override
  Widget build(final BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final correo = widget.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.md,
                AppSpacing.screenHorizontal,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Eliminar cuenta',
                      style: textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppPalette.dangerSurface,
                      borderRadius: AppRadius.r12Border,
                      border: Border.all(color: AppPalette.danger),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esto no se puede deshacer',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppPalette.danger,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'No hay papelera ni periodo de gracia. En cuanto '
                          'confirmes, tus datos se borran del servidor y no '
                          'se pueden recuperar.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Qué se borra',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final dato in kDatosQueSeBorran)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '·  ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              dato,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (correo != null && correo.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Se eliminará la cuenta de $correo. Si más adelante '
                      'quieres volver, tendrás que registrarte de nuevo y '
                      'empezar desde cero.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Escribe $kConfirmacionBorrado para confirmar',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PagateTextField(
                    controller: _confirmacion,
                    hintText: kConfirmacionBorrado,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        kConfirmacionBorrado.length,
                      ),
                    ],
                    onChanged: (final _) => setState(() {}),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppPalette.dangerSurface,
                        borderRadius: AppRadius.r8Border,
                        border: Border.all(color: AppPalette.danger),
                      ),
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppPalette.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PagatePrimaryButton.destructive(
                    label: 'Eliminar mi cuenta',
                    isLoading: _borrando,
                    onPressed: _puedeBorrar ? _eliminar : null,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

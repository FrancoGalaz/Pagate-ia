import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/widgets/pagate_primary_button.dart';

/// Cierre de sesión pedido por el usuario: avisa si hay cambios sin
/// sincronizar antes de borrar la caché de Firestore.
///
/// Tras `deleteAccount` no se usa esto sino `cerrarSesion()` sin aviso.
Future<void> cerrarSesionConAviso(final BuildContext context) =>
    context.read<FirebaseAuthService>().cerrarSesion(
          confirmarPerdidaDeCambios: () => confirmarCierreSinSincronizar(context),
        );

/// `true` si el usuario elige cerrar igual.
Future<bool> confirmarCierreSinSincronizar(final BuildContext context) async {
  if (!context.mounted) return false;
  final cerrar = await showDialog<bool>(
    context: context,
    builder: (final dialogo) => AlertDialog(
      content: const Text(
        'Tienes cambios sin sincronizar. Si cierras sesión sin conexión se '
        'perderán.',
      ),
      actions: [
        PagatePrimaryButton.text(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(dialogo, false),
        ),
        PagatePrimaryButton.text(
          label: 'Cerrar igual',
          isDestructive: true,
          onPressed: () => Navigator.pop(dialogo, true),
        ),
      ],
    ),
  );
  return cerrar ?? false;
}

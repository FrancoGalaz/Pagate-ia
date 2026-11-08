import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';

/// Aviso de Inicio mientras el correo no está verificado. No bloquea nada:
/// solo el asistente y la lectura ordenada de boletas lo exigen.
class VerificarCorreoBanner extends StatelessWidget {
  const VerificarCorreoBanner({super.key});

  @override
  Widget build(final BuildContext context) {
    final auth = context.watch<FirebaseAuthService>();
    if (auth.correoVerificado) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: AppPalette.brandSurface,
          borderRadius: AppRadius.r12Border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verifica tu correo', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Te enviamos un enlace a ${auth.email ?? 'tu correo'}. Lo '
              'necesitas para usar el asistente.',
              style: theme.textTheme.bodySmall,
            ),
            Wrap(
              spacing: AppSpacing.x2,
              children: [
                PagatePrimaryButton.text(
                  label: 'Reenviar correo',
                  onPressed: () => unawaited(reenviarCorreo(context)),
                ),
                PagatePrimaryButton.text(
                  label: 'Ya lo verifiqué',
                  onPressed: () => unawaited(_comprobar(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _comprobar(final BuildContext context) async {
    try {
      final listo = await context
          .read<FirebaseAuthService>()
          .comprobarVerificacion();
      if (!context.mounted) return;
      if (!listo) {
        AppFeedback.showError(
          context,
          'Todavía no aparece verificado. Abre el enlace del correo y vuelve '
          'a intentarlo.',
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      AppFeedback.showError(
        context,
        'No se pudo comprobar. Revisa tu conexión.',
      );
    }
  }
}

/// Reenvía el correo de verificación y lo avisa. Lo usan el aviso de Inicio
/// y el chat.
Future<void> reenviarCorreo(final BuildContext context) async {
  try {
    await context.read<FirebaseAuthService>().reenviarVerificacion();
    if (!context.mounted) return;
    AppFeedback.showMessage(
      context,
      'Te reenviamos el correo de verificación.',
    );
  } catch (_) {
    if (!context.mounted) return;
    AppFeedback.showError(
      context,
      'No se pudo reenviar el correo. Espera un momento e inténtalo de nuevo.',
    );
  }
}

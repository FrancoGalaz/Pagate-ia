import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';

/// Aviso de Inicio mientras el correo no está verificado. No bloquea nada:
/// solo el asistente y la lectura ordenada de boletas lo exigen.
///
/// Compacto: una línea y «Reenviar». Al tocarlo se abre el detalle con el
/// correo y «Ya lo verifiqué». Con letra 2,0 el aviso entero de tres líneas
/// y dos botones empujaba el balance fuera de la primera pantalla.
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
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x0,
      ),
      child: Material(
        color: AppPalette.brandSurface,
        borderRadius: AppRadius.r12Border,
        child: InkWell(
          borderRadius: AppRadius.r12Border,
          onTap: () => unawaited(_verDetalle(context)),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.x3),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: AppIconSize.sm,
                  color: AppPalette.ink,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'Verifica tu correo',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(reenviarCorreo(context)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.brand,
                  ),
                  child: const Text('Reenviar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verDetalle(final BuildContext context) => showPagateSheet<void>(
    context: context,
    builder: (final hoja) => PagateSheet(
      title: 'Verifica tu correo',
      primaryAction: PagatePrimaryButton(
        label: 'Ya lo verifiqué',
        onPressed: () => unawaited(_comprobar(hoja)),
      ),
      secondaryAction: PagatePrimaryButton.secondary(
        label: 'Reenviar correo',
        onPressed: () => unawaited(reenviarCorreo(hoja)),
      ),
      child: Text(
        'Te enviamos un enlace a '
        '${context.read<FirebaseAuthService>().email ?? 'tu correo'}. Lo '
        'necesitas para usar el asistente y la lectura de boletas.',
        style: Theme.of(hoja).textTheme.bodyMedium,
      ),
    ),
  );

  Future<void> _comprobar(final BuildContext context) async {
    try {
      final listo = await context
          .read<FirebaseAuthService>()
          .comprobarVerificacion();
      if (!context.mounted) return;
      if (listo) {
        // Cierra el detalle: el aviso de Inicio ya desapareció solo.
        Navigator.of(context).pop();
        return;
      }
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

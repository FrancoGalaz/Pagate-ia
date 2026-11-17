import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/chat_history_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/ai_provider.dart';

/// Fila de Configuración que borra el historial del asistente.
///
/// Se desactiva mientras el asistente está respondiendo: esa respuesta
/// volvería a crear la conversación recién borrada.
class BorrarHistorialRow extends StatelessWidget {
  const BorrarHistorialRow({super.key});

  @override
  Widget build(final BuildContext context) {
    final respondiendo = context.watch<AiProvider>().isSending;
    return PagateDataRow(
      label: 'Borrar historial del asistente',
      subtitle: respondiendo
          ? 'Espera a que el asistente responda'
          : 'Borra tus conversaciones; tu cupo de mensajes no cambia',
      value: '',
      showDivider: false,
      trailing: const Padding(
        padding: EdgeInsets.only(left: AppSpacing.x2),
        child: Icon(
          Icons.delete_sweep_outlined,
          size: AppIconSize.sm,
          color: AppPalette.danger,
        ),
      ),
      onTap: respondiendo ? null : () => unawaited(_borrar(context)),
    );
  }

  Future<void> _borrar(final BuildContext context) async {
    final confirmado = await confirmar(
      context,
      title: '¿Borrar el historial?',
      message: 'Se borran todas tus conversaciones con el asistente. No se '
          'puede deshacer.',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!confirmado || !context.mounted) return;

    try {
      final borrado = await context.read<AiProvider>().borrarHistorial();
      if (!context.mounted) return;
      if (borrado) {
        AppFeedback.showMessage(context, 'Historial del asistente borrado.');
      } else {
        AppFeedback.showError(
          context,
          'Espera a que el asistente responda e inténtalo de nuevo.',
        );
      }
    } on ChatHistoryDeletionException catch (e) {
      if (!context.mounted) return;
      AppFeedback.showError(context, e.message);
    }
  }
}

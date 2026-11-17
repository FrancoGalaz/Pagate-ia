import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pagate_primary_button.dart';

// ═══════════════════════════════════════════════════════════════════════
// DIÁLOGO DE CONFIRMACIÓN
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/diseno/variantes-cabal.html, componente 6.
//
// Un solo diálogo para toda la app: título, texto y el par Cancelar /
// confirmar, lado a lado. Si la acción destruye algo (borrar, eliminar,
// cerrar perdiendo cambios), el botón de confirmar va en carmesí; si no, en
// la greda de la acción. Con letra grande los botones se apilan, el de
// confirmar arriba.
// ═══════════════════════════════════════════════════════════════════════

/// Pide confirmación. Devuelve `true` solo si el usuario confirma; cerrar
/// tocando el velo o con atrás cuenta como cancelar.
Future<bool> confirmar(
  final BuildContext context, {
  final String? title,
  required final String message,
  required final String confirmLabel,
  final String cancelLabel = 'Cancelar',
  final bool destructive = false,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (final dialogo) => _DialogoConfirmacion(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return respuesta ?? false;
}

class _DialogoConfirmacion extends StatelessWidget {
  final String? title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  const _DialogoConfirmacion({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  @override
  Widget build(final BuildContext context) {
    final cancelar = PagatePrimaryButton.secondary(
      label: cancelLabel,
      onPressed: () => Navigator.pop(context, false),
    );
    final aceptar = destructive
        ? PagatePrimaryButton.destructive(
            label: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
          )
        : PagatePrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
          );

    // Con letra grande «Cancelar» y la acción no caben lado a lado.
    final apilar = MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return AlertDialog(
      title: title == null ? null : Text(title!),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        0,
        AppSpacing.x6,
        AppSpacing.x5,
      ),
      actions: [
        if (apilar)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              aceptar,
              const SizedBox(height: AppSpacing.x2),
              cancelar,
            ],
          )
        else
          Row(
            children: [
              Expanded(child: cancelar),
              const SizedBox(width: AppSpacing.x3),
              Expanded(child: aceptar),
            ],
          ),
      ],
    );
  }
}

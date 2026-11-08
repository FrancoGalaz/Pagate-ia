import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/services/firebase_auth_service.dart';
import '../../../../../core/utils/app_feedback.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../auth/presentation/widgets/verificar_correo_banner.dart';
import '../../providers/ai_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// PESTAÑA DEL ASISTENTE
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · LOS CUATRO DEGRADADOS DE MARCA (cabecera, avatar del asistente, botón
//   de enviar y el avatar del indicador de escritura). Eran relleno
//   plano de marca desde el paso 3; ahora lo dicen. Y los dos círculos
//   pasan a cuadrados de radio 8, que es la forma del sistema para un
//   contenedor de icono.
//
// · LOS CUATRO RADIOS DE 32 dp DEL CAMPO DEL COMPOSITOR (uno
//   por cada estado del borde) y el radio 100 del chip "Nueva". Toda la
//   decoración del campo sale ahora de `inputDecorationTheme`.
//
// · EL BOTÓN DE ENVIAR era un `GestureDetector` sobre un círculo con
//   `AnimatedOpacity` al 50% cuando estaba apagado: no anunciaba rol de
//   botón, no tenía etiqueta y "deshabilitado" se comunicaba solo con
//   opacidad. Ahora es un `IconButton` con `tooltip: 'Enviar'` y colores de
//   estado del sistema.
//
// · EL CHIP "Nueva" era otro `GestureDetector` con ~33 dp de caja táctil.
//   Pasa a la variante de texto del botón del sistema, que trae los 48.
//
// · EL BOTÓN DE CERRAR DEL BANNER DE ERROR medía ~16×16 (`padding: zero` +
//   `constraints: BoxConstraints()`), el control más pequeño de la app.
//   Vuelve a los 48 dp que exige el informe previo al lanzamiento de Play.
//
// · EL BANNER DE ERROR pintado con `error.withValues(alpha: 0.12)` y borde
//   al 40%: dos opacidades inventadas. Pasa a `dangerSurface` con borde
//   `danger`, verificados a 6,49:1.
//
// · LOS TRES `fontSize:` NUMÉRICOS (12, 12 y el `height: 1.4` de la
//   burbuja). Nadie construye un `TextStyle` a mano: salen del `TextTheme`.
// ═══════════════════════════════════════════════════════════════════════

/// Aviso de IA generativa que la pestaña muestra fijo bajo la cabecera.
///
/// Es público para que una prueba pueda comprobar que sigue diciendo las dos
/// cosas que exige la política de Google Play: que responde una IA y que
/// puede equivocarse. En una app de dinero la segunda es la que importa.
const String kAiDisclosureText =
    'Las respuestas las genera una IA y pueden tener errores. '
    'Revisa las cifras antes de tomar una decisión.';

/// Pestaña del asistente IA.
///
/// Solo presenta el estado de [AiProvider]: no arma contexto, no escribe en
/// Firestore y no conoce el `userId` (el provider ya nace con alcance de
/// usuario debajo del auth gate).
class IaTab extends StatefulWidget {
  const IaTab({super.key});

  @override
  State<IaTab> createState() => _IaTabState();
}

class _IaTabState extends State<IaTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _renderedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    context.read<AiProvider>().sendMessage(text);
    _controller.clear();
  }

  /// Si `chat` rechazó por correo sin verificar, primero se pide un token
  /// nuevo: el viejo seguiría diciendo `email_verified: false`.
  Future<void> _reintentar(final AiProvider ai) async {
    if (ai.faltaVerificarCorreo) {
      try {
        await context.read<FirebaseAuthService>().comprobarVerificacion();
      } catch (_) {
        // Sin conexión: el reintento fallará y lo dirá.
      }
    }
    await ai.retry();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.normal,
        curve: AppCurves.enter,
      );
    });
  }

  @override
  Widget build(final BuildContext context) {
    final ai = context.watch<AiProvider>();
    final messages = ai.messages;
    final isSending = ai.isSending;

    // Auto-scroll cuando entra un mensaje nuevo o arranca la respuesta.
    final visibleCount = messages.length + (isSending ? 1 : 0);
    if (visibleCount != _renderedCount) {
      _renderedCount = visibleCount;
      _scrollToBottom();
    }

    return Column(
      children: [
        _Header(
          conversationActive: ai.conversationId != null,
          onNewConversation: isSending ? null : ai.newConversation,
        ),
        const _AiDisclosure(),
        Expanded(
          child: ai.isLoadingHistory
              ? ListView(children: [PagateSkeleton.rows(3)])
              : messages.isEmpty
                  ? ListView(
                      children: const [
                        PagateEmptyState(
                          title: 'Pregúntale lo que quieras',
                          description:
                              'Escribe abajo y el asistente responde con lo '
                              'que registraste este mes.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x4,
                        AppSpacing.x4,
                        AppSpacing.x0,
                      ),
                      itemCount: messages.length + (isSending ? 1 : 0),
                      itemBuilder: (final context, final i) =>
                          i == messages.length
                              ? const _TypingIndicator()
                              : _MessageBubble(message: messages[i]),
                    ),
        ),
        if (ai.error != null)
          _ErrorBanner(
            message: ai.error!,
            onRetry: ai.canRetry && !isSending
                ? () => unawaited(_reintentar(ai))
                : null,
            onDismiss: ai.clearError,
            onReenviarCorreo: ai.faltaVerificarCorreo
                ? () => unawaited(reenviarCorreo(context))
                : null,
          ),
        _Composer(
          controller: _controller,
          enabled: !isSending && !ai.isLoadingHistory,
          onSend: _send,
        ),
      ],
    );
  }
}

// ─── Cabecera ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.conversationActive,
    required this.onNewConversation,
  });

  final bool conversationActive;
  final VoidCallback? onNewConversation;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _altoMinimo),
        child: Row(
          children: [
            const _IconoDeMarca(lado: AppSizes.iconContainerSmall),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Asistente', style: theme.textTheme.headlineMedium),
                  Text(
                    conversationActive
                        ? 'Conversación guardada'
                        : 'Conversación nueva',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (conversationActive)
              PagatePrimaryButton.text(
                label: 'Nueva',
                leadingIcon: Icons.add_comment_outlined,
                onPressed: onNewConversation,
              ),
          ],
        ),
      ),
    );
  }

  static const double _altoMinimo = 48;
}

/// Cuadrado de marca con el icono del asistente. Decorativo.
class _IconoDeMarca extends StatelessWidget {
  const _IconoDeMarca({required this.lado});

  final double lado;

  @override
  Widget build(final BuildContext context) => ExcludeSemantics(
        child: Container(
          width: lado,
          height: lado,
          decoration: const BoxDecoration(
            color: AppPalette.brand,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: AppPalette.textOnBrand,
            size: AppIconSize.xs,
          ),
        ),
      );
}

// ─── Mensajes ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Row(
          children: [
            const _IconoDeMarca(lado: _ladoAvatar),
            const SizedBox(width: AppSpacing.x2),
            const SizedBox(
              width: AppIconSize.xs,
              height: AppIconSize.xs,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'Escribiendo…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.textMuted,
                  ),
            ),
          ],
        ),
      );
}

const double _ladoAvatar = 28;

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isAssistant = message.isAssistant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: message.pending ? 0.6 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isAssistant) ...[
              const _IconoDeMarca(lado: _ladoAvatar),
              const SizedBox(width: AppSpacing.x2),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x3,
                      vertical: AppSpacing.x3,
                    ),
                    decoration: BoxDecoration(
                      // Superficie y borde, no tinte translúcido: la
                      // respuesta del asistente va en blanco sobre el lienzo
                      // y la pregunta del usuario en la superficie de marca.
                      color: isAssistant
                          ? AppPalette.surface
                          : AppPalette.brandSurface,
                      borderRadius: AppRadius.r12Border,
                      border: Border.all(
                        color:
                            isAssistant ? AppPalette.border : AppPalette.brand,
                        width: AppSizes.borderHairline,
                      ),
                    ),
                    child: SelectableText(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                  // El saludo local queda fuera a propósito: no lo genera el
                  // modelo, es texto de la app, y reportarlo no informa de
                  // nada. Tampoco se ofrece sobre un mensaje aún pendiente,
                  // que todavía no existe como documento.
                  if (isAssistant &&
                      message.id != 'welcome' &&
                      !message.pending)
                    _ReportAction(message: message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Banner de error ───────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
    this.onReenviarCorreo,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  /// Solo cuando `chat` rechazó por correo sin verificar.
  final VoidCallback? onReenviarCorreo;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x0,
        ),
        child: Container(
          padding: const EdgeInsets.only(left: AppSpacing.x3),
          decoration: BoxDecoration(
            color: AppPalette.dangerSurface,
            borderRadius: AppRadius.r12Border,
            border: Border.all(
              color: AppPalette.danger,
              width: AppSizes.borderHairline,
            ),
          ),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppPalette.danger,
                  size: AppIconSize.sm,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.danger,
                      ),
                ),
              ),
              if (onReenviarCorreo != null)
                PagatePrimaryButton.text(
                  label: 'Reenviar correo',
                  isDestructive: true,
                  onPressed: onReenviarCorreo,
                ),
              if (onRetry != null)
                PagatePrimaryButton.text(
                  label: 'Reintentar',
                  isDestructive: true,
                  onPressed: onRetry,
                ),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Cerrar el aviso',
                color: AppPalette.danger,
                icon: const Icon(Icons.close_rounded, size: AppIconSize.sm),
              ),
            ],
          ),
        ),
      );
}

// ─── Compositor ────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x3,
          AppSpacing.x4,
          AppSpacing.x4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (final _) => onSend(),
                // Toda la decoración sale del tema.
                decoration: const InputDecoration(
                  hintText: 'Escribe una pregunta',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            SizedBox(
              width: AppSizes.minTouchTarget,
              height: AppSizes.minTouchTarget,
              child: IconButton(
                tooltip: 'Enviar',
                onPressed: enabled ? onSend : null,
                style: IconButton.styleFrom(
                  // El estado apagado se dice con color, no con opacidad:
                  // `sunken` con icono `textMuted` da 4,77:1.
                  backgroundColor:
                      enabled ? AppPalette.brand : AppPalette.sunken,
                  foregroundColor:
                      enabled ? AppPalette.textOnBrand : AppPalette.textMuted,
                  disabledBackgroundColor: AppPalette.sunken,
                  disabledForegroundColor: AppPalette.textMuted,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.r12)),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: AppIconSize.sm),
              ),
            ),
          ],
        ),
      );
}

// ─── Política de Play: aviso y reporte ─────────────────────────────────

/// Aviso permanente de que quien responde es una IA.
///
/// REQUISITO DE POLÍTICA DE GOOGLE PLAY, no un detalle de estilo: una app con
/// IA generativa tiene que dejarle claro a la persona que el contenido lo
/// genera una IA, sin que tenga que investigarlo. Por eso vive fijo bajo la
/// cabecera del chat, se lee antes que la primera respuesta y no se puede
/// cerrar: un diálogo que se descarta una vez, o una línea enterrada en
/// Ayuda, no cumplen.
///
/// Y dice las dos cosas, no una: que responde una IA y que puede equivocarse.
/// En una app de dinero la segunda es la que importa.
class _AiDisclosure extends StatelessWidget {
  const _AiDisclosure();

  @override
  Widget build(final BuildContext context) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppPalette.sunken,
          border: Border(
            bottom: BorderSide(
              color: AppPalette.border,
              width: AppSizes.borderHairline,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.info_outline_rounded,
                size: AppIconSize.xs,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                kAiDisclosureText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      );
}

/// Botón de reportar bajo una respuesta del asistente.
///
/// La otra mitad del requisito de Play: tiene que haber una forma de marcar
/// contenido ofensivo DENTRO de la app. Va pegado a la respuesta que reporta,
/// que es donde la persona está cuando decide reportarla, y no en un menú de
/// ajustes.
class _ReportAction extends StatelessWidget {
  const _ReportAction({required this.message});

  final ChatMessage message;

  Future<void> _report(final BuildContext context) async {
    final provider = context.read<AiProvider>();
    final eleccion =
        await showPagateSheet<({AiReportReason reason, String comment})>(
      context: context,
      builder: (final _) => const _ReportSheet(),
    );
    if (eleccion == null) return;

    final guardado = await provider.reportMessage(
      message: message,
      reason: eleccion.reason,
      comment: eleccion.comment,
    );
    if (!context.mounted) return;
    // `AppFeedback` y no `ScaffoldMessenger`: el aviso del overlay raíz se ve
    // también si queda una hoja abierta encima. Aquí la hoja ya se cerró,
    // pero tener DOS mecanismos de aviso en la app es justo lo que dejó el
    // error de guardado invisible durante semanas.
    if (guardado) {
      AppFeedback.showMessage(context, 'Reporte enviado. Gracias por avisar.');
    } else {
      // No se dice "enviado" si no se envió.
      AppFeedback.showError(
        context,
        'No se pudo enviar el reporte. Intenta de nuevo.',
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final reportado = context.select<AiProvider, bool>(
      (final ai) => ai.isReported(message.id),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: PagatePrimaryButton.text(
        label: reportado ? 'Reportado' : 'Reportar respuesta',
        leadingIcon: reportado ? Icons.check_rounded : Icons.flag_outlined,
        onPressed: reportado ? null : () => _report(context),
      ),
    );
  }
}

/// Hoja para elegir el motivo del reporte.
///
/// Devuelve `null` si se cierra sin reportar, o el motivo y el comentario.
/// No escribe nada: de persistir se encarga [AiProvider.reportMessage].
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _comment = TextEditingController();
  AiReportReason? _reason;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return PagateSheet(
      title: 'Reportar esta respuesta',
      primaryAction: PagatePrimaryButton(
        label: 'Enviar reporte',
        onPressed: _reason == null
            ? null
            : () => Navigator.of(context).pop((
                  reason: _reason!,
                  comment: _comment.text,
                )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cuéntanos qué pasa con lo que respondió el asistente.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // `RadioGroup` y no `groupValue`/`onChanged` por tile: esos dos
          // estan deprecados desde Flutter 3.32 y el analizador los marca.
          RadioGroup<AiReportReason>(
            groupValue: _reason,
            onChanged: (final elegido) => setState(() => _reason = elegido),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final motivo in AiReportReason.values)
                  RadioListTile<AiReportReason>(
                    value: motivo,
                    title: Text(
                      motivo.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    activeColor: AppPalette.brand,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.standard,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          PagateTextField(
            labelText: 'Comentario (opcional)',
            controller: _comment,
            hintText: '¿Qué debería saber quien revise esto?',
            maxLines: 3,
            maxLength: AiProvider.maxReportCommentChars,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}

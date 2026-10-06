import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/utils/app_feedback.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../providers/ai_provider.dart';

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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.normal,
        curve: AppCurves.enter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
              ? const Center(
                  child: SizedBox(
                    width: AppIconSize.md,
                    height: AppIconSize.md,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                )
              : messages.isEmpty
              ? const Center(
                  child: Text(
                    'Inicia una conversación con tu asistente.',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  itemCount: messages.length + (isSending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length) {
                      return const _TypingIndicator();
                    }
                    return _MessageBubble(message: messages[i]);
                  },
                ),
        ),
        if (ai.error != null)
          _ErrorBanner(
            message: ai.error!,
            onRetry: ai.canRetry && !isSending ? ai.retry : null,
            onDismiss: ai.clearError,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.conversationActive,
    required this.onNewConversation,
  });

  final bool conversationActive;
  final VoidCallback? onNewConversation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xl,
      AppSpacing.screenHorizontal,
      AppSpacing.md,
    ),
    child: Row(
      children: [
        Container(
          width: AppSizes.avatarMedium,
          height: AppSizes.avatarMedium,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: AppRadius.lgBorder,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: AppIconSize.sm,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asistente IA',
                style: AppText.weight(
                  Theme.of(context).textTheme.headlineMedium!,
                  800,
                ).copyWith(color: AppColors.textPrimaryDark),
              ),
              Text(
                conversationActive
                    ? 'Conversación guardada'
                    : 'Conversación nueva',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        if (conversationActive)
          Tooltip(
            message: 'Nueva conversación',
            child: GestureDetector(
              onTap: onNewConversation,
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: onNewConversation == null ? 0.5 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_comment_outlined,
                        color: AppColors.textSecondaryDark,
                        size: AppIconSize.xs,
                      ),
                      SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Nueva',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        _AssistantAvatar(),
        SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.brand,
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          'Escribiendo...',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      0,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: AppIconSize.sm,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimaryDark),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reintentar'),
            ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Cerrar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondaryDark,
              size: AppIconSize.xs,
            ),
          ),
        ],
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.xl,
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            textInputAction: TextInputAction.send,
            style: const TextStyle(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              hintText: 'Escribe una pregunta...',
              hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: AppRadius.xxlBorder,
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.xxlBorder,
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.xxlBorder,
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.xxlBorder,
                borderSide: const BorderSide(color: AppColors.brand),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: enabled ? onSend : null,
          child: AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: enabled ? 1 : 0.5,
            child: Container(
              width: AppSizes.avatarMedium,
              height: AppSizes.avatarMedium,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: AppIconSize.sm,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: const BoxDecoration(
      gradient: AppColors.brandGradient,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.smart_toy_outlined,
      color: Colors.white,
      size: AppIconSize.xs,
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.isAssistant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: message.pending ? 0.6 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isAssistant
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (isAssistant) ...[
              const _AssistantAvatar(),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isAssistant
                          ? AppColors.surfaceDark
                          : AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: AppRadius.lgBorder,
                      border: Border.all(
                        color: isAssistant
                            ? AppColors.borderDark
                            : AppColors.brand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SelectableText(
                      message.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                  // El saludo local queda fuera a propósito: no lo genera el
                  // modelo, es texto de la app, y reportarlo no informa de
                  // nada. Tampoco se ofrece sobre un mensaje aún pendiente,
                  // que todavía no existe como documento.
                  if (isAssistant && message.id != 'welcome' && !message.pending)
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
      color: AppColors.surfaceSecondary,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: AppIconSize.xs,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            kAiDisclosureText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
    final eleccion = await showModalBottomSheet<({AiReportReason reason, String comment})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      barrierColor: AppPalette.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.r16TopBorder,
      ),
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
      child: TextButton.icon(
        onPressed: reportado ? null : () => _report(context),
        icon: Icon(
          reportado ? Icons.check_rounded : Icons.flag_outlined,
          size: AppIconSize.xs,
        ),
        label: Text(reportado ? 'Reportado' : 'Reportar respuesta'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          disabledForegroundColor: AppColors.textSecondary,
          textStyle: AppText.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          // Caja táctil de 48 aunque el texto mida menos: es lo que exige el
          // informe previo al lanzamiento de Play.
          minimumSize: const Size(0, AppSizes.minTouchTarget),
        ),
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
  Widget build(final BuildContext context) => Padding(
    // El teclado no puede tapar el campo de comentario.
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El asa de arrastre no se dibuja aqui: el tema ya la pone
            // (`bottomSheetTheme.showDragHandle`), y dibujarla otra vez
            // sacaba dos.
            Text(
              'Reportar esta respuesta',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cuéntanos qué pasa con lo que respondió el asistente.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
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
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                      activeColor: AppColors.brand,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.standard,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: AiProvider.maxReportCommentChars,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: '¿Qué debería saber quien revise esto?',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PagatePrimaryButton(
              label: 'Enviar reporte',
              onPressed: _reason == null
                  ? null
                  : () => Navigator.of(context).pop((
                      reason: _reason!,
                      comment: _comment.text,
                    )),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../providers/ai_provider.dart';

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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w800,
                ),
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
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }
}

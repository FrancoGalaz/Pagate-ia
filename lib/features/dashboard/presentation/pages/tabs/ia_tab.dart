import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../finances/presentation/providers/finances_provider.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../providers/ai_provider.dart';

class IaTab extends StatefulWidget {
  const IaTab({super.key});

  @override
  State<IaTab> createState() => _IaTabState();
}

class _IaTabState extends State<IaTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize the AI chat after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _injectFullContext();
    });
  }

  /// Injects all available context from across the app into the AI provider.
  void _injectFullContext() {
    final aiProvider = context.read<AiProvider>();
    final profile = context.read<UserProfileProvider>().profile;
    final finances = context.read<FinancesProvider>();
    final inventory = context.read<InventoryProvider>();
    final hourlyRate = context.read<HourlyRateProvider>().currentRate;

    aiProvider.updateContext(
      profile: profile,
      currentSummary: finances.selected,
      recentTransactions: finances.recentTransactions,
      inventoryItems: inventory.items,
      hourlyRate: hourlyRate,
      allMonths: finances.months,
      currency: profile?.currency ?? 'MXN',
    );

    // Set userId for Firestore persistence
    final authUserId =
        context.read<FirebaseAuthService>().userId;
    if (authUserId != 'anonymous') {
      aiProvider.setUserId(authUserId);
    }

    aiProvider.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    // Refresh context before each message to get latest data
    _injectFullContext();
    context.read<AiProvider>().sendMessage(text);
    _controller.clear();
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.medium,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiProvider>();
    final messages = aiProvider.messages;
    final isLoading = aiProvider.isLoading;
    final isReady = aiProvider.isReady;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.lgBorder,
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistente IA',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    Text(
                      isReady ? 'Conectado' : 'No configurado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                isReady ? AppColors.success : AppColors.error,
                          ),
                    ),
                  ],
                ),
              ),
              if (messages.length > 1)
                GestureDetector(
                  onTap: () => aiProvider.clearChat(),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm - 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.textSecondaryDark, size: 18),
                  ),
                ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messages.isEmpty
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
                  itemCount: messages.length,
                  itemBuilder: (context, i) =>
                      _MessageBubble(message: messages[i]),
                ),
        ),

        // Typing indicator
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.screenHorizontal,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Pensando...',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Input
        Padding(
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
                  controller: _controller,
                  enabled: !isLoading,
                  style:
                      const TextStyle(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Escribe una pregunta...',
                    hintStyle:
                        const TextStyle(color: AppColors.textSecondaryDark),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.xxlBorder,
                      borderSide:
                          const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.xxlBorder,
                      borderSide:
                          const BorderSide(color: AppColors.borderDark),
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
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: isLoading ? null : _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              message.isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (message.isAi) ...[
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: message.isAi
                      ? AppColors.surfaceDark
                      : AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: AppRadius.lgBorder,
                  border: Border.all(
                    color: message.isAi
                        ? AppColors.borderDark
                        : AppColors.brand.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
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
      );
}

import 'package:flutter/material.dart';
import '../../../../../core/constants/app_constants.dart';

class IaTab extends StatefulWidget {
  const IaTab({super.key});

  @override
  State<IaTab> createState() => _IaTabState();
}

class _IaTabState extends State<IaTab> {
  final _controller = TextEditingController();
  final List<_Message> _messages = [
    const _Message(
      text: '¡Hola! Soy tu asistente de IA para Págate-IA. '
          'Puedo ayudarte a analizar tus finanzas, dar sugerencias de precios, '
          'y optimizar tu inventario. ¿En qué te ayudo hoy?',
      isAi: true,
    ),
  ];

  static const List<String> _suggestions = [
    '¿Cuál es mi margen de ganancia este mes?',
    'Sugiere cómo bajar mis gastos fijos',
    '¿Cuándo llegaré a mi meta mensual?',
    '¿Qué productos tienen mejor margen?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(final String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isAi: false));
      _messages.add(const _Message(
        text: 'Analizando tu negocio... Con base en tus datos de Marzo 2025: '
            'tienes ingresos de \$23,800 y gastos de \$8,300. '
            'Tu balance positivo de \$15,500 es una buena señal. '
            'Te recomiendo enfocarte en los servicios de mayor margen.',
        isAi: true,
      ));
    });
    _controller.clear();
  }

  @override
  Widget build(final BuildContext context) => Column(
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
                Column(
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
                      'Powered by Págate-IA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brand,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              itemCount: _messages.length,
              itemBuilder: (final context, final i) =>
                  _MessageBubble(message: _messages[i]),
            ),
          ),

          // Suggestions
          if (_messages.length <= 2)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal),
                itemCount: _suggestions.length,
                separatorBuilder: (final context, final index) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (final context, final i) => GestureDetector(
                  onTap: () => _sendMessage(_suggestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Text(
                      _suggestions[i],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xs),

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
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
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

class _Message {
  const _Message({required this.text, required this.isAi});
  final String text;
  final bool isAi;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _Message message;

  @override
  Widget build(final BuildContext context) => Padding(
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

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_mock_data.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_back_button.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  int? _expandedIndex;

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    const PagateBackButton(),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Ayuda e Ideas',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  children: [
                    // IA suggestion card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: AppRadius.xxlBorder,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              color: Colors.white, size: AppIconSize.lg),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sugerencia del día',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Reduce tus gastos fijos en 10% para ganar \$830 extra este mes.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    Text(
                      'PREGUNTAS FRECUENTES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: AppRadius.xxlBorder,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        children: AppMockData.faqItems
                            .asMap()
                            .entries
                            .map((final e) {
                          final i = e.key;
                          final faq = e.value;
                          final isLast =
                              i == AppMockData.faqItems.length - 1;
                          final isExpanded = _expandedIndex == i;

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _expandedIndex =
                                        isExpanded ? null : i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          faq['question'] ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    AppColors.textPrimaryDark,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons
                                                .keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondaryDark,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    0,
                                    AppSpacing.md,
                                    AppSpacing.md,
                                  ),
                                  child: Text(
                                    faq['answer'] ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryDark,
                                          height: 1.5,
                                        ),
                                  ),
                                ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderDark,
                                  indent: AppSpacing.md,
                                  endIndent: AppSpacing.md,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'CONTACTO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: AppRadius.xxlBorder,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Column(
                        children: [
                          _ContactRow(
                            icon: Icons.email_outlined,
                            label: 'soporte@pagate-ia.com',
                          ),
                          Divider(
                              height: 1,
                              color: AppColors.borderDark,
                              indent: AppSpacing.md,
                              endIndent: AppSpacing.md),
                          _ContactRow(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Chat en vivo (Pro)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: () => AppFeedback.showMessage(
          context,
          'Te pondremos en contacto con soporte desde "$label".',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(icon, color: AppColors.brand, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark, size: 20),
            ],
          ),
        ),
      );
}

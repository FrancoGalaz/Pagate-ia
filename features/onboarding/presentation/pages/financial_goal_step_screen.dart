import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';

class FinancialGoalStepScreen extends StatefulWidget {
  const FinancialGoalStepScreen({super.key});

  @override
  State<FinancialGoalStepScreen> createState() =>
      _FinancialGoalStepScreenState();
}

class _FinancialGoalStepScreenState extends State<FinancialGoalStepScreen> {
  double _currentValue = 2500;
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Background decor
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    blurRadius: 32,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Unified step header
                const PagateStepHeader(
                  currentStep: 3,
                  totalSteps: 3,
                ),

                // 2. Main content
                Expanded(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: AppColors.brand,
                            size: AppIconSize.lg + 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Title
                        Text(
                          'Tu Meta Mensual',
                          style: textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Define cuánto quieres ganar libre al mes.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        // Amount display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                '\$',
                                style: textTheme.displaySmall?.copyWith(
                                  color: AppColors.brand,
                                  fontSize: 40,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              _currencyFormat.format(_currentValue),
                              style: textTheme.displayLarge?.copyWith(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.0,
                                letterSpacing: -2.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'USD / MES',
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 1.4,
                          ),
                        ),

                        const Spacer(),

                        // Slider
                        Slider(
                          value: _currentValue,
                          min: 500,
                          max: 10000,
                          divisions: 190,
                          onChanged: (final value) {
                            setState(() {
                              _currentValue = value;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$500',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '\$10k+',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xxl),

                        // Info card
                        PagateInfoCard(
                          child: RichText(
                            text: TextSpan(
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Este valor nos ayudará a calcular tu ',
                                ),
                                TextSpan(
                                  text: 'valor hora',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const TextSpan(text: ' real en Dólares.'),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // 3. Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    children: [
                      PagatePrimaryButton(
                        label: '¡Comenzar mi Taller!',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (final context) =>
                                  const DashboardScreen(),
                            ),
                            (final route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Podrás ajustar esta meta en cualquier momento.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import 'financial_goal_step_screen.dart';

class WorkshopStepScreen extends StatefulWidget {
  const WorkshopStepScreen({super.key});

  @override
  State<WorkshopStepScreen> createState() => _WorkshopStepScreenState();
}

class _WorkshopStepScreenState extends State<WorkshopStepScreen> {
  final List<String> _categories = [
    'Carpintería',
    'Textil',
    'Cerámica',
    'Joyería',
  ];
  final Set<String> _selectedCategories = {};

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background decor
          Positioned(
            top: -90,
            right: -40,
            child: Container(
              width: 195,
              height: 277,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.05),
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          Positioned(
            top: 400,
            left: -40,
            child: Container(
              width: 234,
              height: 370,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.05),
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Unified step header
                const PagateStepHeader(
                  currentStep: 2,
                  totalSteps: 3,
                ),

                // 2. Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.xl),

                        // Icon
                        Container(
                          width: AppSizes.iconContainerLarge,
                          height: AppSizes.iconContainerLarge,
                          decoration: const BoxDecoration(
                            color: AppColors.brandLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.brand,
                            size: AppIconSize.xxl,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Title
                        Text(
                          'Cuéntanos de tu oficio',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Personalizaremos la app para que se ajuste a\nlas necesidades de tu taller.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl),

                        // Workshop name
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: PagateLabel('Nombre de tu Taller'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const PagateTextField(
                          hintText: 'Ej: El Arte de la Madera',
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Specialty section card
                        PagateSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PagateLabel('¿Cuál es tu rubro?'),
                              const SizedBox(height: AppSpacing.sm),

                              // Search input
                              PagateTextField(
                                hintText: 'Ej: Carpintería, Joyería...',
                                prefixIcon: Icons.search,
                                suffix: Container(
                                  margin: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: AppColors.textTertiary,
                                    size: AppIconSize.sm,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),

                              // Category chips
                              PagateChipSelector(
                                options: _categories,
                                selected: _selectedCategories,
                                onToggle: (final category) {
                                  setState(() {
                                    if (_selectedCategories
                                        .contains(category)) {
                                      _selectedCategories.remove(category);
                                    } else {
                                      _selectedCategories.clear();
                                      _selectedCategories.add(category);
                                    }
                                  });
                                },
                              ),

                              const SizedBox(height: AppSpacing.xl),

                              const PagateLabel('Nicho / Especialidad'),
                              const SizedBox(height: AppSpacing.xs),
                              const PagateTextField(
                                hintText: 'Ej: Muebles de autor, Restauración',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),

                // 3. Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxl,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.fadeToBackground,
                  ),
                  child: Column(
                    children: [
                      PagatePrimaryButton(
                        label: 'Siguiente',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (final context) =>
                                  const FinancialGoalStepScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'La información de tu taller es privada y segura.',
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

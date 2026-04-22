import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import 'workshop_step_screen.dart';

class IdentityStepScreen extends StatefulWidget {
  const IdentityStepScreen({super.key});

  @override
  State<IdentityStepScreen> createState() => _IdentityStepScreenState();
}

class _IdentityStepScreenState extends State<IdentityStepScreen> {
  String _selectedCurrency = 'MXN';

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Unified step header
            const PagateStepHeader(
              currentStep: 1,
              totalSteps: 3,
              stepLabel: 'Identidad y Región',
            ),

            // 2. Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      '¡Hola, artesano! 👋',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Comencemos configurando tu identidad para que puedas recibir pagos globalmente.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Name
                    const PagateLabel('NOMBRE COMPLETO', isUppercase: true),
                    const SizedBox(height: AppSpacing.xs),
                    const PagateTextField(
                      hintText: 'Ej. María González',
                      prefixIcon: Icons.person_outline,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Email
                    const PagateLabel('CORREO ELECTRÓNICO', isUppercase: true),
                    const SizedBox(height: AppSpacing.xs),
                    const PagateTextField(
                      hintText: 'hola@ejemplo.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Password
                    const PagateLabel('CONTRASEÑA', isUppercase: true),
                    const SizedBox(height: AppSpacing.xs),
                    const PagateTextField(
                      hintText: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Separator
                    const Divider(),
                    const SizedBox(height: AppSpacing.xxl),

                    // Regional settings
                    Text(
                      'Configuración Regional',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Country selector
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PagateLabel('PAÍS', isUppercase: true),
                              const SizedBox(height: AppSpacing.xs),
                              _buildCountrySelector(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Currency selector
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PagateLabel('MONEDA', isUppercase: true),
                              const SizedBox(height: AppSpacing.xs),
                              _buildCurrencySelector(),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Terms
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Al continuar, aceptas nuestros ',
                            ),
                            TextSpan(
                              text: 'Términos',
                              style: TextStyle(color: AppColors.brand),
                            ),
                            TextSpan(text: ' y '),
                            TextSpan(
                              text: 'Privacidad',
                              style: TextStyle(color: AppColors.brand),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),

                    // Bottom spacer for scroll
                    const SizedBox(height: AppSpacing.hero + AppSpacing.xxl),
                  ],
                ),
              ),
            ),

            // 3. Fixed bottom action
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.fadeToWhite,
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              child: PagatePrimaryButton(
                label: 'Siguiente',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (final context) => const WorkshopStepScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountrySelector() => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.xxlBorder,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: AppIconSize.md,
                  height: AppIconSize.md,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textTertiary,
                  ),
                  child: const Icon(
                    Icons.flag,
                    color: AppColors.textOnBrand,
                    size: AppIconSize.xs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'México',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const Icon(
              Icons.expand_more,
              color: AppColors.textTertiary,
              size: AppIconSize.md,
            ),
          ],
        ),
      );

  Widget _buildCurrencySelector() => Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.xxlBorder,
        ),
        child: Row(
          children: [
            _buildCurrencyTab('MXN', _selectedCurrency == 'MXN'),
            _buildCurrencyTab('USD', _selectedCurrency == 'USD'),
          ],
        ),
      );

  Widget _buildCurrencyTab(final String code, final bool isSelected) =>
      Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedCurrency = code;
            });
          },
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.xlBorder,
                    boxShadow: AppShadows.sm,
                  )
                : null,
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        isSelected ? AppColors.brand : AppColors.textTertiary,
                  ),
            ),
          ),
        ),
      );
}

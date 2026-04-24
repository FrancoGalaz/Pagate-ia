import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import 'login_screen.dart';
import '../../../onboarding/presentation/pages/identity_step_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Back button
              const PagateBackButton(),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                '¡Comencemos!',
                style: textTheme.headlineLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                'Ingresa tu número de celular. Te enviaremos un código de confirmación.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Phone input row
              Row(
                children: [
                  // Country code selector
                  Container(
                    height: AppSizes.inputHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdBorder,
                      border: Border.all(
                        color: AppColors.border,
                        width: AppSizes.borderThin,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇲🇽', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '+52',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: AppIconSize.sm,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Phone number input
                  Expanded(
                    child: PagateTextField(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      hintText: 'Tu celular',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // CTA Button
                PagatePrimaryButton(
                  label: 'Crear cuenta',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_phoneController.text.trim().isEmpty) {
                      AppFeedback.showMessage(
                        context,
                        'Ingresa tu número de celular para continuar.',
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                      builder: (final context) => const IdentityStepScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // Login link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (final _) => const LoginScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: '¿Ya tienes cuenta? '),
                        TextSpan(
                          text: 'Inicia sesión',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

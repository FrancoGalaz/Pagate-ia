import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../../../core/theme/app_text.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  late TextEditingController _nameController;
  late TextEditingController _businessController;
  late TextEditingController _goalController;
  String _selectedBusinessType = '';
  String _selectedCurrency = kDefaultCurrency;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _businessController = TextEditingController();
    _goalController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final profile = context.read<UserProfileProvider>().profile;
      _nameController.text = profile?.name ?? '';
      _businessController.text = profile?.businessName ?? '';
      _goalController.text =
          profile?.monthlyGoal.toStringAsFixed(0) ?? '';
      _selectedBusinessType = profile?.businessType ?? '';
      _selectedCurrency = profile?.currency ?? kDefaultCurrency;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    final businessName = _businessController.text.trim();
    // Mismo defecto que en el onboarding: "800.000" se guardaba como 800.
    final goal = parseCurrencyInput(_goalController.text);

    if (name.isEmpty || businessName.isEmpty) {
      AppFeedback.showError(
        context,
        'Completa tu nombre y el nombre del negocio.',
      );
      return;
    }

    if (_selectedBusinessType.isEmpty) {
      AppFeedback.showError(
        context,
        'Selecciona un tipo de negocio.',
      );
      return;
    }

    if (goal == null || goal <= 0) {
      AppFeedback.showError(
        context,
        'Ingresa una meta económica válida.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<UserProfileProvider>().updateFromSetup(
            name: name,
            businessName: businessName,
            businessType: _selectedBusinessType,
            currency: _selectedCurrency,
            monthlyGoal: goal,
          );
      if (!mounted) return;
      AppFeedback.showMessage(context, 'Perfil actualizado correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
        title: Text(
          'Editar Perfil',
          style: AppText.weight(theme.textTheme.titleLarge!, 800).copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // ── Name ─────────────────────────────
            Text(
              'NOMBRE COMPLETO',
              style: AppText.weight(theme.textTheme.labelSmall!, 700).copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PagateTextField(
              controller: _nameController,
              hintText: 'Tu nombre',
              prefixIcon: Icons.person_outline_rounded,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Business name ─────────────────────
            Text(
              'NOMBRE DEL NEGOCIO',
              style: AppText.weight(theme.textTheme.labelSmall!, 700).copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PagateTextField(
              controller: _businessController,
              hintText: 'Nombre de tu negocio',
              prefixIcon: Icons.store_outlined,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Business type ─────────────────────
            Text(
              'TIPO DE NEGOCIO',
              style: AppText.weight(theme.textTheme.labelSmall!, 700).copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: kBusinessTypes.map((type) {
                final isSelected = type == _selectedBusinessType;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBusinessType = type),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.surfaceDarkSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.borderDark,
                        width: AppSizes.borderThin,
                      ),
                    ),
                    child: Text(
                      type,
                      style: AppText.weight(
                        theme.textTheme.labelMedium!,
                        600,
                      ).copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Currency ──────────────────────────
            Text(
              'MONEDA',
              style: AppText.weight(theme.textTheme.labelSmall!, 700).copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: kSupportedCurrencies.map((code) {
                final isSelected = code == _selectedCurrency;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCurrency = code),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.surfaceDarkSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.borderDark,
                        width: AppSizes.borderThin,
                      ),
                    ),
                    child: Text(
                      code,
                      style: AppText.weight(
                        theme.textTheme.labelMedium!,
                        600,
                      ).copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Monthly goal ──────────────────────
            Text(
              'META MENSUAL',
              style: AppText.weight(theme.textTheme.labelSmall!, 700).copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PagateTextField(
              controller: _goalController,
              hintText: 'Meta de ingresos mensual',
              prefixIcon: Icons.flag_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.xlBorder,
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Guardar cambios',
                        style: AppText.weight(theme.textTheme.titleSmall!, 700),
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

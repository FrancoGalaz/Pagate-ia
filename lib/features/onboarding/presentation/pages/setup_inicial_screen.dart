import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_chip_selector.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_section_card.dart';
import '../../../../core/widgets/pagate_text_field.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';

/// Onboarding: se muestra dentro del `UserScope` cuando el usuario autenticado
/// todavía no tiene perfil en `users/{uid}`. Al guardar, el stream del perfil
/// hace que el gate pase solo al dashboard; no hay navegación manual.
class SetupInicialScreen extends StatefulWidget {
  const SetupInicialScreen({super.key});

  @override
  State<SetupInicialScreen> createState() => _SetupInicialScreenState();
}

class _SetupInicialScreenState extends State<SetupInicialScreen> {
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _goalController = TextEditingController();

  Set<String> _selectedType = {};
  String _selectedCurrency = kDefaultCurrency;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precarga el nombre guardado en Auth durante el registro (llega de forma
    // asíncrona, por eso se observa el servicio y no solo initState).
    final displayName = context.watch<FirebaseAuthService>().displayName;
    if (_nameController.text.isEmpty &&
        displayName != null &&
        displayName.isNotEmpty) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final name = _nameController.text.trim();
    final businessName = _businessController.text.trim();
    final rawGoal = _goalController.text.replaceAll(',', '.').trim();
    final goal = double.tryParse(rawGoal);

    if (name.isEmpty || businessName.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Completa tu nombre y el nombre del negocio.',
      );
      return;
    }

    if (_selectedType.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Selecciona un tipo de negocio para continuar.',
      );
      return;
    }

    if (goal == null || goal <= 0) {
      AppFeedback.showMessage(context, 'Ingresa una meta económica válida.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<UserProfileProvider>().updateFromSetup(
            name: name,
            businessName: businessName,
            businessType: _selectedType.first,
            currency: _selectedCurrency,
            monthlyGoal: goal,
          );
      // El gate reacciona al stream del perfil y muestra el dashboard.
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, describeFirebaseError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Header
                Text(
                  'Configura tu negocio',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Solo tarda 2 minutos. Puedes editar esto después.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Sección 1: Datos básicos ───────────────────────────
                const _SectionLabel(label: '1. ¿Cómo te llamas?'),
                const SizedBox(height: AppSpacing.sm),
                PagateSectionCard(
                  child: Column(
                    children: [
                      PagateTextField(
                        controller: _nameController,
                        hintText: 'Tu nombre',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PagateTextField(
                        controller: _businessController,
                        hintText: 'Nombre de tu negocio',
                        prefixIcon: Icons.store_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Sección 2: Tipo de negocio ─────────────────────────
                const _SectionLabel(label: '2. ¿Qué tipo de negocio tienes?'),
                const SizedBox(height: AppSpacing.sm),
                PagateChipSelector(
                  options: kBusinessTypes,
                  selected: _selectedType,
                  onToggle: (final option) =>
                      setState(() => _selectedType = {option}),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Sección 3: Meta económica ──────────────────────────
                const _SectionLabel(label: '3. ¿Cuánto quieres ganar al mes?'),
                const SizedBox(height: AppSpacing.sm),
                PagateSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moneda',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _PillSelector(
                        options: kSupportedCurrencies,
                        selected: _selectedCurrency,
                        onSelect: (final v) =>
                            setState(() => _selectedCurrency = v),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PagateTextField(
                        controller: _goalController,
                        hintText: 'Meta de ingresos mensual',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.flag_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                PagatePrimaryButton(
                  label: 'Empezar a ganar más',
                  trailingIcon: Icons.arrow_forward_rounded,
                  isLoading: _isSaving,
                  onPressed: _onContinue,
                ),

                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        context.read<FirebaseAuthService>().signOut(),
                    child: const Text('Usar otra cuenta'),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      );
}

// ─── Helper widgets ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(final BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
      );
}

class _PillSelector extends StatelessWidget {
  const _PillSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(final BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: options.map((final opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
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
                  color: isSelected ? AppColors.brand : AppColors.borderDark,
                  width: AppSizes.borderThin,
                ),
              ),
              child: Text(
                opt,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          );
        }).toList(),
      );
}

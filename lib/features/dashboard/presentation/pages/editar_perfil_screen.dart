import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';

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
  String _selectedCurrency = 'MXN';
  bool _isSaving = false;
  bool _initialized = false;

  static const List<String> _businessTypes = [
    'Taller Mecánico',
    'Carpintería',
    'Herrería',
    'Electrónica',
    'Costura / Moda',
    'Construcción',
    'Otro',
  ];

  static const List<String> _currencies = ['MXN', 'USD', 'EUR', 'ARS', 'COP'];

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
      _selectedCurrency = profile?.currency ?? 'MXN';
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
    final rawGoal = _goalController.text.replaceAll(',', '.').trim();
    final goal = double.tryParse(rawGoal);

    if (name.isEmpty || businessName.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Completa tu nombre y el nombre del negocio.',
      );
      return;
    }

    if (_selectedBusinessType.isEmpty) {
      AppFeedback.showMessage(
        context,
        'Selecciona un tipo de negocio.',
      );
      return;
    }

    if (goal == null || goal <= 0) {
      AppFeedback.showMessage(
        context,
        'Ingresa una meta económica válida.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final initialsParts = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .toList();
    final initials = initialsParts.isEmpty ? 'IA' : initialsParts.join();

    final currentProfile = context.read<UserProfileProvider>().profile;
    final updated = UserProfileEntity(
      id: currentProfile?.id ?? 'local-user',
      name: name,
      businessName: businessName,
      businessType: _selectedBusinessType,
      currency: _selectedCurrency,
      monthlyGoal: goal,
      isPro: currentProfile?.isPro ?? false,
      avatarInitials: initials,
    );

    try {
      await context.read<UserProfileProvider>().updateProfile(updated);
      if (!mounted) return;
      AppFeedback.showMessage(context, 'Perfil actualizado correctamente.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showMessage(context, 'Error al guardar. Intenta de nuevo.');
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
        leading: const PagateBackButton(),
        title: Text(
          'Editar Perfil',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w800,
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _businessTypes.map((type) {
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w600,
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: _currencies.map((code) {
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w600,
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
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
                        'Guardar Cambios',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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

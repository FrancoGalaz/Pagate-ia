import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/pagate_chip_selector.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../../../core/widgets/pagate_section_card.dart';
import '../../../../core/widgets/pagate_text_field.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';

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
  String _selectedCurrency = 'MXN';
  String _selectedUnit = 'mensual';

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
  static const List<String> _units = ['mensual', 'semanal', 'diario'];

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _onContinue() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (final _) => const DashboardScreen()),
        (final route) => false,
      );

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
                options: _businessTypes,
                selected: _selectedType,
                onToggle: (final option) =>
                    setState(() => _selectedType = {option}),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Sección 3: Meta económica ──────────────────────────
              const _SectionLabel(label: '3. ¿Cuánto quieres ganar?'),
              const SizedBox(height: AppSpacing.sm),
              PagateSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Currency pills
                    Text(
                      'Moneda',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PillSelector(
                      options: _currencies,
                      selected: _selectedCurrency,
                      onSelect: (final v) =>
                          setState(() => _selectedCurrency = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PagateTextField(
                      controller: _goalController,
                      hintText: 'Meta de ingresos',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: Icons.flag_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Período',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PillSelector(
                      options: _units,
                      selected: _selectedUnit,
                      onSelect: (final v) =>
                          setState(() => _selectedUnit = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              PagatePrimaryButton(
                label: 'Empezar a ganar más',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: _onContinue,
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
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.borderDark,
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

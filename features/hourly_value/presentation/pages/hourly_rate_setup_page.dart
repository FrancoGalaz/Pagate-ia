import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/hourly_rate_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/premium_text_field.dart';

/// Premium configuration page for setting up hourly rate.
/// Features: Gradient background, glassmorphism, smooth animations.
class HourlyRateSetupPage extends StatefulWidget {
  const HourlyRateSetupPage({super.key});

  @override
  State<HourlyRateSetupPage> createState() => _HourlyRateSetupPageState();
}

class _HourlyRateSetupPageState extends State<HourlyRateSetupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();
  final _daysController = TextEditingController();
  final _hoursController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: AppDurations.slow,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppCurves.enter,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppCurves.emphasis,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _daysController.dispose();
    _hoursController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HourlyRateProvider>();

    final success = await provider.calculateAndSave(
      desiredSalary: double.parse(_salaryController.text.replaceAll(',', '')),
      workingDays: int.parse(_daysController.text),
      hoursPerDay: double.parse(_hoursController.text),
    );

    if (success && mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    final provider = context.read<HourlyRateProvider>();
    final hourlyValue = provider.currentRate?.hourlyValue ?? 0;

    showDialog(
      context: context,
      builder: (final context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                borderRadius: AppRadius.xsBorder,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text('¡Configuración Guardada!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu valor hora es:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: AppRadius.smBorder,
              ),
              child: Text(
                '\$${hourlyValue.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ahora podrás calcular el costo real de tus productos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.backgroundDark,
                AppColors.brand.withValues(alpha: 0.1),
                AppColors.backgroundDark,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        _buildHeader(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildInputCard(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSubmitButton(),
                        const SizedBox(height: AppSpacing.md),
                        _buildHelper(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: AppRadius.smBorder,
            ),
            child: const Icon(
              Icons.schedule,
              color: AppColors.textOnBrand,
              size: AppIconSize.xl,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '¿Cuánto quieres ganar?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Configura tu meta y te diremos cuánto vale tu hora de trabajo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      );

  Widget _buildInputCard() => GlassCard(
        child: Column(
          children: [
            PremiumTextField(
              label: 'Sueldo mensual deseado',
              hint: 'Ej: 1000000',
              controller: _salaryController,
              keyboardType: TextInputType.number,
              prefix: '\$ ',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (final value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu meta de sueldo';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Debe ser un número positivo';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumTextField(
              label: 'Días de trabajo al mes',
              hint: 'Ej: 20',
              controller: _daysController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (final value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa los días que trabajas';
                }
                final number = int.tryParse(value);
                if (number == null || number <= 0 || number > 31) {
                  return 'Debe ser entre 1 y 31 días';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumTextField(
              label: 'Horas por día',
              hint: 'Ej: 8',
              controller: _hoursController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (final value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa las horas diarias';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0 || number > 24) {
                  return 'Debe ser entre 0 y 24 horas';
                }
                return null;
              },
            ),
          ],
        ),
      );

  Widget _buildSubmitButton() => Consumer<HourlyRateProvider>(
        builder: (final context, final provider, final child) => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.isLoading ? null : _handleSubmit,
            child: provider.isLoading
                ? const SizedBox(
                    height: AppIconSize.sm,
                    width: AppIconSize.sm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Calcular mi Valor Hora'),
          ),
        ),
      );

  Widget _buildHelper() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.info,
              size: AppIconSize.sm,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Este cálculo te permitirá saber cuánto cobrar por tus productos sin perder dinero.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ),
          ],
        ),
      );
}

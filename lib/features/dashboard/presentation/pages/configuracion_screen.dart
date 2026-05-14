import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_back_button.dart';
import '../../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../hourly_value/presentation/pages/hourly_rate_setup_page.dart';
import 'editar_perfil_screen.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final hourlyRate = context.watch<HourlyRateProvider>().currentRate;

    return Scaffold(
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
                    'Configuración',
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
                  _Section(
                    title: 'Negocio',
                    children: [
                      _ItemRow(
                        icon: Icons.store_outlined,
                        label: 'Nombre del negocio',
                        subtitle: profile?.businessName ?? 'No definido',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.build_outlined,
                        label: 'Tipo de negocio',
                        subtitle: profile?.businessType ?? 'No definido',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Moneda',
                        subtitle: profile?.currency ?? 'MXN',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Metas',
                    children: [
                      _ItemRow(
                        icon: Icons.flag_outlined,
                        label: 'Meta de ingresos',
                        subtitle: profile != null
                            ? '\$${profile.monthlyGoal.toStringAsFixed(0)} mensuales'
                            : '\$0 mensuales',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.timer_outlined,
                        label: 'Valor Hora',
                        subtitle: hourlyRate != null
                            ? '\$${hourlyRate.hourlyValue.toStringAsFixed(0)}/h'
                            : 'Calcular desde sueldo objetivo',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HourlyRateSetupPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Seguridad',
                    children: [
                      _ItemRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Cambiar contraseña',
                        subtitle: 'Enviar correo de restablecimiento',
                        onTap: () => _resetPassword(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Notificaciones',
                    children: [
                      _ItemRow(
                        icon: Icons.notifications_outlined,
                        label: 'Alertas de stock bajo',
                        subtitle: 'Próximamente',
                        onTap: () => AppFeedback.showMessage(
                          context,
                          'Próximamente disponible.',
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.bar_chart_rounded,
                        label: 'Resumen semanal',
                        subtitle: 'Próximamente',
                        onTap: () => AppFeedback.showMessage(
                          context,
                          'Próximamente disponible.',
                        ),
                      ),
                    ],
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

  Future<void> _resetPassword(BuildContext context) async {
    final auth = context.read<FirebaseAuthService>();
    final email = auth.email;
    if (email.isEmpty) {
      AppFeedback.showMessage(
        context,
        'No hay un correo asociado a esta cuenta.',
      );
      return;
    }
    try {
      await auth.sendPasswordReset(email: email);
      if (!context.mounted) return;
      AppFeedback.showMessage(
        context,
        'Correo de restablecimiento enviado a $email.',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showMessage(
        context,
        'Error al enviar correo. Intenta de nuevo.',
      );
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
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
            child: Column(children: children),
          ),
        ],
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        color: AppColors.borderDark,
        indent: AppSpacing.md,
        endIndent: AppSpacing.md,
      );
}

class _ItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ItemRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
        ),
      );
}

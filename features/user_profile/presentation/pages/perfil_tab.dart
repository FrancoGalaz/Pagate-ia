import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/user_profile_provider.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../dashboard/presentation/pages/configuracion_screen.dart';
import '../../../dashboard/presentation/pages/ayuda_screen.dart';

class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          // Avatar + info
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.brandStrong,
                  ),
                  child: Center(
                    child: Text(
                      profile?.avatarInitials ?? 'IA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile?.name ?? 'Tu Nombre',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  profile?.businessName ?? 'Mi Negocio',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (profile?.isPro == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      'PRO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: AppRadius.xxlBorder,
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Moneda',
                      value: profile?.currency ?? 'MXN',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.borderDark,
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Meta',
                      value:
                          '\$${profile?.monthlyGoal.toStringAsFixed(0) ?? '0'}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.borderDark,
                  ),
                  const Expanded(
                    child: _StatItem(label: 'Negocio', value: 'Taller'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Menu items
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal),
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (final _) => const ConfiguracionScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Ayuda e Ideas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (final _) => const AyudaScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _MenuItem(
                  icon: Icons.star_outline_rounded,
                  label: 'Calificar la App',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.xs),
                _MenuItem(
                  icon: Icons.share_outlined,
                  label: 'Compartir Págate-IA',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.xl),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Cerrar Sesión',
                  isDestructive: true,
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (final _) => const LoginScreen()),
                    (final route) => false,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Págate-IA v1.0.0 • MVP',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiaryDark,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) => Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(
              color:
                  isDestructive ? AppColors.error.withValues(alpha: 0.3) : AppColors.borderDark,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.surfaceDarkSecondary,
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppColors.error : AppColors.textSecondaryDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDestructive ? AppColors.error : AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive ? AppColors.error : AppColors.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_back_button.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  static const List<_ConfigSection> _sections = [
    _ConfigSection(title: 'Negocio', items: [
      _ConfigItem(
        icon: Icons.store_outlined,
        label: 'Nombre del negocio',
        subtitle: 'Taller Mendoza',
      ),
      _ConfigItem(
        icon: Icons.build_outlined,
        label: 'Tipo de negocio',
        subtitle: 'Taller Mecánico',
      ),
      _ConfigItem(
        icon: Icons.currency_exchange_rounded,
        label: 'Moneda',
        subtitle: 'MXN — Peso Mexicano',
      ),
    ]),
    _ConfigSection(title: 'Metas', items: [
      _ConfigItem(
        icon: Icons.flag_outlined,
        label: 'Meta de ingresos',
        subtitle: '\$35,000 mensuales',
      ),
      _ConfigItem(
        icon: Icons.timer_outlined,
        label: 'Valor Hora',
        subtitle: 'Calcular desde sueldo objetivo',
      ),
    ]),
    _ConfigSection(title: 'Seguridad', items: [
      _ConfigItem(
        icon: Icons.lock_outline_rounded,
        label: 'Cambiar contraseña',
        subtitle: 'Actualiza tu contraseña',
      ),
      _ConfigItem(
        icon: Icons.fingerprint_rounded,
        label: 'Biometría',
        subtitle: 'Desactivada',
      ),
    ]),
    _ConfigSection(title: 'Notificaciones', items: [
      _ConfigItem(
        icon: Icons.notifications_outlined,
        label: 'Alertas de stock bajo',
        subtitle: 'Activadas',
      ),
      _ConfigItem(
        icon: Icons.bar_chart_rounded,
        label: 'Resumen semanal',
        subtitle: 'Cada domingo',
      ),
    ]),
  ];

  @override
  Widget build(final BuildContext context) => Scaffold(
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
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  itemCount: _sections.length,
                  separatorBuilder: (final context, final index) =>
                      const SizedBox(height: AppSpacing.xl),
                  itemBuilder: (final context, final i) =>
                      _SectionWidget(section: _sections[i]),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ConfigSection {
  const _ConfigSection({required this.title, required this.items});
  final String title;
  final List<_ConfigItem> items;
}

class _ConfigItem {
  const _ConfigItem({
    required this.icon,
    required this.label,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String subtitle;
}

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.section});
  final _ConfigSection section;

  @override
  Widget build(final BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title.toUpperCase(),
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
            child: Column(
              children: section.items.asMap().entries.map((final e) {
                final item = e.value;
                final isLast = e.key == section.items.length - 1;
                return Column(
                  children: [
                    _ItemRow(item: item),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        color: AppColors.borderDark,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final _ConfigItem item;

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: () => AppFeedback.showMessage(
          context,
          'Editar "${item.label}" estará disponible en una próxima actualización.',
        ),
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
                child: Icon(item.icon, color: AppColors.brand, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      item.subtitle,
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

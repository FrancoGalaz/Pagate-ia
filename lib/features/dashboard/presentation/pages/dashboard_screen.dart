import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import 'ayuda_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/ia_tab.dart';
import '../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../finances/presentation/pages/finanzas_tab.dart';
import '../../../finances/presentation/providers/finances_provider.dart';
import '../../../finances/presentation/widgets/transaction_form_sheet.dart';
import '../../../hourly_value/presentation/pages/hourly_rate_setup_page.dart';
import '../../../inventory/presentation/pages/inventario_tab.dart';
import '../../../user_profile/presentation/pages/perfil_tab.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // ─── Navigation Items ──────────────────────────────────────────────

  static const List<PagateNavItem> _navItems = [
    PagateNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    PagateNavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Finanzas',
    ),
    PagateNavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Inventario',
    ),
    PagateNavItem(
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy_rounded,
      label: 'IA',
    ),
    PagateNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  // ─── Pages ─────────────────────────────────────────────────────────

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeTab(
        onRegistrarIngreso: () => showTransactionSheet(
          context,
          initialType: TransactionType.income,
        ),
        onRegistrarGasto: () => showTransactionSheet(
          context,
          initialType: TransactionType.expense,
        ),
        onVerFinanzas: () => _setPage(1),
        onVerValorHora: _abrirValorHora,
        onAyuda: _abrirAyuda,
      ),
      const FinanzasTab(),
      const InventarioTab(),
      const IaTab(),
      const PerfilTab(),
    ];
  }

  void _setPage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _abrirAyuda() {
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (final _) => const AyudaScreen()),
      ),
    );
  }

  /// Inicio enseña el valor hora y lleva a configurarlo. Hasta ahora esa
  /// pantalla estaba enterrada detrás de Perfil → Configuración.
  void _abrirValorHora() {
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (final _) => const HourlyRateSetupPage()),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _MonthlyGoalSync(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide) {
            return _buildDesktopLayout();
          }

          // Se elimina la variante `compact` por debajo de 380 dp, que
          // escondía las etiquetas de la barra: un icono sin etiqueta no se
          // entiende, y es de lo que revisa el informe previo de Play.
          return _buildMobileLayout();
        },
      ),
    );
  }

  // ─── Desktop Layout (NavigationRail) ───────────────────────────────

  Widget _buildDesktopLayout() => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Los colores, los iconos y los dos estilos de etiqueta salen
              // de `navigationRailTheme`, que el paso R-4 añadió al tema.
              // Antes se escribían aquí en línea con ocho colores oscuros,
              // porque ese tema no existía en ninguno de los dos temas.
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _setPage,
                labelType: NavigationRailLabelType.all,
                minWidth: 80,
                groupAlignment: 0.8,
                leading: const Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.x5,
                    bottom: AppSpacing.x4,
                  ),
                  child: _RailWordmark(),
                ),
                destinations: [
                  for (final item in _navItems)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(
                width: AppSizes.borderHairline,
                thickness: AppSizes.borderHairline,
                color: AppPalette.border,
              ),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
        ),
      );

  // ─── Layout móvil ──────────────────────────────────────────────────

  Widget _buildMobileLayout() => Scaffold(
        // `SafeArea(bottom: false)`: hasta ahora las cinco pestañas empezaban
        // a 24 dp del borde FÍSICO, así que en cualquier móvil con muesca el
        // avatar y el título quedaban bajo la barra de estado. Abajo no,
        // porque de esa zona ya se ocupa la barra de navegación.
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _currentIndex, children: _pages),
        ),
        bottomNavigationBar: PagateBottomNav(
          items: _navItems,
          currentIndex: _currentIndex,
          onSelected: _setPage,
        ),
      );
}

// ─── Meta mensual: perfil → finanzas ────────────────────────────────────

/// La meta mensual vive en `users/{uid}.monthlyGoal`. Este widget la copia al
/// [FinancesProvider] cada vez que cambia en el perfil, fuera del build.
class _MonthlyGoalSync extends StatelessWidget {
  const _MonthlyGoalSync({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final goal = context.select<UserProfileProvider, double>(
      (p) => p.profile?.monthlyGoal ?? 0,
    );
    final finances = Provider.of<FinancesProvider>(context, listen: false);
    if (finances.monthlyGoal != goal) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => finances.setMonthlyGoal(goal),
      );
    }
    return child;
  }
}

// ─── Marca del rail ─────────────────────────────────────────────────────

/// Wordmark provisional del rail de escritorio.
///
/// Sustituye al cuadrado con `brandGradient` y el `Icons.bolt_rounded` que
/// había aquí: era una TERCERA marca distinta para la misma app —la
/// bienvenida usaba `Icons.paid_outlined` y el avatar por defecto las
/// iniciales "IA"—. Hasta que exista un logotipo real, un wordmark en
/// Manrope 700 es honesto, consistente y no cuesta nada.
class _RailWordmark extends StatelessWidget {
  const _RailWordmark();

  @override
  Widget build(final BuildContext context) => Column(
        children: [
          Container(
            width: AppSizes.avatarSmall,
            height: AppSizes.avatarSmall,
            decoration: const BoxDecoration(
              color: AppPalette.brand,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Págate',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppPalette.textSecondary,
                ),
          ),
        ],
      );
}

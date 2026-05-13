import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import 'ayuda_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/ia_tab.dart';
import '../../../finances/presentation/pages/finanzas_tab.dart';
import '../../../inventory/presentation/pages/inventario_tab.dart';
import '../../../user_profile/presentation/pages/perfil_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // ─── Navigation Items ──────────────────────────────────────────────

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Finanzas',
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Inventario',
    ),
    _NavItem(
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy_rounded,
      label: 'IA',
    ),
    _NavItem(
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
        onQuickActionTap: _onQuickAction,
        onNotificationsTap: _openHelp,
      ),
      const FinanzasTab(),
      const InventarioTab(),
      const IaTab(),
      const PerfilTab(),
    ];
  }

  void _onQuickAction(HomeQuickAction action) {
    switch (action) {
      case HomeQuickAction.sale:
        _setPage(1);
        AppFeedback.showMessage(
          context,
          'Abre Finanzas para registrar una venta.',
        );
      case HomeQuickAction.expense:
        _setPage(1);
        AppFeedback.showMessage(
          context,
          'Abre Finanzas para registrar un gasto.',
        );
      case HomeQuickAction.inventory:
        _setPage(2);
      case HomeQuickAction.ai:
        _setPage(3);
    }
  }

  void _setPage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AyudaScreen()),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ─── Desktop Layout (NavigationRail) ───────────────────────────────

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Row(
        children: [
          // Rail
          NavigationRail(
            backgroundColor: AppColors.surfaceDark,
            selectedIndex: _currentIndex,
            onDestinationSelected: _setPage,
            labelType: NavigationRailLabelType.all,
            elevation: 0,
            minWidth: 80,
            groupAlignment: 0.8,
            leading: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: AppRadius.xlBorder,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagate',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            destinations: _navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon, color: AppColors.textSecondaryDark),
                      selectedIcon:
                          Icon(item.activeIcon, color: AppColors.brand),
                      label: Text(
                        item.label,
                        style: TextStyle(
                          color: _currentIndex == _navItems.indexOf(item)
                              ? AppColors.brand
                              : AppColors.textSecondaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ))
                .toList(),
          ),

          // Separator
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.borderDark,
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
              ),
              child: _pages[_currentIndex],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile Layout (BottomNavigationBar) ───────────────────────────

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(color: AppColors.borderDark, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(
                _navItems.length,
                (i) => Expanded(
                  child: _NavButton(
                    item: _navItems[i],
                    isSelected: _currentIndex == i,
                    onTap: () => _setPage(i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Navigation Item Models ─────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.textSecondaryDark,
                  size: AppIconSize.md,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      );
}

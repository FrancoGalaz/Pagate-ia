import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/inventory_provider.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import 'detalle_item_screen.dart';

class InventarioTab extends StatelessWidget {
  const InventarioTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Stack(
      children: [
        Column(
          children: [
            _InventarioHeader(
              activeTab: provider.activeTab,
              searchQuery: provider.searchQuery,
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ItemList(items: provider.items),
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.xl,
          child: FloatingActionButton(
            onPressed: () {},
            backgroundColor: AppColors.brand,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ─── Header + search + tabs ───────────────────────────────────────────────
class _InventarioHeader extends StatelessWidget {
  const _InventarioHeader({
    required this.activeTab,
    required this.searchQuery,
  });
  final InventoryItemType activeTab;
  final String searchQuery;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
          AppSpacing.screenHorizontal,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventario',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Search
            TextField(
              onChanged: (final q) => context.read<InventoryProvider>().search(q),
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                hintText: 'Buscar producto o material...',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.lgBorder,
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.lgBorder,
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.lgBorder,
                  borderSide: const BorderSide(color: AppColors.brand),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Type tabs
            Row(
              children: [
                _TypeTab(
                  label: 'Productos',
                  type: InventoryItemType.product,
                  activeTab: activeTab,
                ),
                const SizedBox(width: AppSpacing.xs),
                _TypeTab(
                  label: 'Materiales',
                  type: InventoryItemType.material,
                  activeTab: activeTab,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      );
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.type,
    required this.activeTab,
  });
  final String label;
  final InventoryItemType type;
  final InventoryItemType activeTab;

  @override
  Widget build(final BuildContext context) {
    final isActive = type == activeTab;
    return GestureDetector(
      onTap: () => context.read<InventoryProvider>().setActiveTab(type),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brand : AppColors.surfaceDark,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brand : AppColors.borderDark,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

// ─── Item List ────────────────────────────────────────────────────────────
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});
  final List<InventoryItemEntity> items;

  @override
  Widget build(final BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: AppColors.textSecondaryDark, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No hay items registrados',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        100,
      ),
      itemCount: items.length,
      separatorBuilder: (final context, final index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (final context, final i) => _ItemCard(item: items[i]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final InventoryItemEntity item;

  Color get _statusColor {
    switch (item.stockStatus) {
      case StockStatus.critical:
        return AppColors.error;
      case StockStatus.low:
        return AppColors.warning;
      case StockStatus.ok:
        return AppColors.success;
    }
  }

  String get _statusLabel {
    switch (item.stockStatus) {
      case StockStatus.critical:
        return 'Sin stock';
      case StockStatus.low:
        return 'Bajo';
      case StockStatus.ok:
        return 'OK';
    }
  }

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (final _) => DetalleItemScreen(item: item)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdBorder,
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${item.stock} ${item.unit}  •  \$${item.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
}

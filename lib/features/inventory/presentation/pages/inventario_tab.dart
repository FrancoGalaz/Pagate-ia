import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../providers/inventory_provider.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import 'detalle_item_screen.dart';

class InventarioTab extends StatelessWidget {
  const InventarioTab({super.key});

  Future<void> _openAddItemSheet(
    final BuildContext context,
    final InventoryItemType type,
  ) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '1');
    final minStockController = TextEditingController(text: '1');
    final unitController = TextEditingController(
      text: type == InventoryItemType.product ? 'piezas' : 'unidades',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (final sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuevo ${type == InventoryItemType.product ? 'producto' : 'material'}',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SheetField(
              controller: nameController,
              hint: 'Nombre',
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SheetField(
              controller: priceController,
              hint: 'Precio',
              icon: Icons.attach_money_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SheetField(
                    controller: stockController,
                    hint: 'Stock',
                    icon: Icons.add_chart_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SheetField(
                    controller: minStockController,
                    hint: 'Mínimo',
                    icon: Icons.warning_amber_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _SheetField(
              controller: unitController,
              hint: 'Unidad (piezas, kg, litros)',
              icon: Icons.straighten_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            PagatePrimaryButton(
              label: 'Guardar item',
              onPressed: () async {
                final name = nameController.text.trim();
                final price =
                    double.tryParse(priceController.text.replaceAll(',', '.'));
                final stock = int.tryParse(stockController.text.trim());
                final minStock = int.tryParse(minStockController.text.trim());
                final unit = unitController.text.trim();

                if (name.isEmpty ||
                    price == null ||
                    stock == null ||
                    minStock == null ||
                    unit.isEmpty ||
                    price <= 0 ||
                    stock < 0 ||
                    minStock < 0) {
                  AppFeedback.showMessage(
                    context,
                    'Completa todos los campos con valores válidos.',
                  );
                  return;
                }

                await context.read<InventoryProvider>().addItem(
                      name: name,
                      type: type,
                      price: price,
                      stock: stock,
                      minStock: minStock,
                      unit: unit,
                    );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                AppFeedback.showMessage(context, 'Item agregado correctamente.');
              },
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    minStockController.dispose();
    unitController.dispose();
  }

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
            onPressed: () => _openAddItemSheet(context, provider.activeTab),
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

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(final BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimaryDark),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textSecondaryDark),
          filled: true,
          fillColor: AppColors.surfaceDarkSecondary,
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
        ),
      );
}

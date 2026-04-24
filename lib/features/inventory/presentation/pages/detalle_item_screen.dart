import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/pagate_back_button.dart';
import '../../../../core/widgets/pagate_primary_button.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/entities/inventory_item_type.dart';
import '../providers/inventory_provider.dart';

class DetalleItemScreen extends StatelessWidget {
  const DetalleItemScreen({super.key, required this.item});
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
        return 'Stock bajo';
      case StockStatus.ok:
        return 'En stock';
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: Row(
                  children: [
                    const PagateBackButton(),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Detalle del Item',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showUpdateStockDialog(context),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // Icon + Name card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: AppRadius.xxlBorder,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: AppRadius.xlBorder,
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white,
                                size: AppIconSize.xxl,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            if (item.code != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Código: ${item.code}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Stock status
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.xlBorder,
                          border: Border.all(
                              color: _statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.stockStatus == StockStatus.ok
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.warning_amber_rounded,
                              color: _statusColor,
                              size: AppIconSize.md,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _statusLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: _statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${item.stock} / ${item.minStock} min.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: _statusColor),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Details grid
                      _DetailCard(
                        children: [
                          _DetailRow(
                            label: 'Tipo',
                            value: item.type == InventoryItemType.product
                                ? 'Producto'
                                : 'Material',
                          ),
                          _DetailRow(
                            label: 'Precio',
                            value:
                                '\$${item.price.toStringAsFixed(2)}',
                          ),
                          _DetailRow(
                            label: 'Stock actual',
                            value: '${item.stock} ${item.unit}',
                          ),
                          _DetailRow(
                            label: 'Stock mínimo',
                            value: '${item.minStock} ${item.unit}',
                          ),
                          if (item.supplier != null)
                            _DetailRow(
                              label: 'Proveedor',
                              value: item.supplier!,
                              isLast: true,
                            ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxxl),

                      PagatePrimaryButton(
                        label: 'Actualizar Stock',
                        leadingIcon: Icons.edit_rounded,
                        onPressed: () => _showUpdateStockDialog(context),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          label: const Text(
                            'Eliminar Item',
                            style: TextStyle(color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _showUpdateStockDialog(final BuildContext context) async {
    final controller = TextEditingController(text: item.stock.toString());

    await showDialog<void>(
      context: context,
      builder: (final dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Actualizar stock',
          style: TextStyle(color: AppColors.textPrimaryDark),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimaryDark),
          decoration: InputDecoration(
            hintText: 'Nuevo stock',
            hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
            filled: true,
            fillColor: AppColors.surfaceDarkSecondary,
            border: OutlineInputBorder(
              borderRadius: AppRadius.lgBorder,
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final stock = int.tryParse(controller.text.trim());
              if (stock == null || stock < 0) {
                AppFeedback.showMessage(
                  context,
                  'Ingresa una cantidad válida de stock.',
                );
                return;
              }

              await context.read<InventoryProvider>().updateStock(
                    itemId: item.id,
                    newStock: stock,
                  );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              AppFeedback.showMessage(context, 'Stock actualizado.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _confirmDelete(final BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (final dialogContext) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text(
              'Eliminar item',
              style: TextStyle(color: AppColors.textPrimaryDark),
            ),
            content: Text(
              '¿Seguro que quieres eliminar ${item.name}?',
              style: const TextStyle(color: AppColors.textSecondaryDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !context.mounted) return;

    await context.read<InventoryProvider>().deleteItem(item.id);
    if (!context.mounted) return;
    AppFeedback.showMessage(context, 'Item eliminado.');
    Navigator.pop(context);
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(final BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(children: children),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(final BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(
              height: 1,
              color: AppColors.borderDark,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
        ],
      );
}

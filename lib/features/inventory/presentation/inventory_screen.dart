import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/inventory_item.dart';
import '../../../shared/providers/inventory_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Inventory', subtitle: 'Stock on hand for the materials the pricing/BOM engine consumes.'),
          Expanded(
            child: AsyncValueView(
              value: inventoryAsync,
              onRetry: () => ref.invalidate(inventoryNotifierProvider),
              builder: (items) {
                if (items.isEmpty) {
                  return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No inventory items', message: 'Stock items appear here once added.');
                }
                final lowStock = items.where((i) => i.isBelowMinimum).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lowStock > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Text('$lowStock item(s) below minimum stock', style: const TextStyle(color: AppColors.warning)),
                        ]),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) => _InventoryTile(item: items[index]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends ConsumerWidget {
  final InventoryItem item;
  const _InventoryTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.isBelowMinimum ? AppColors.warningSurface : AppColors.successSurface,
          child: Icon(
            item.isBelowMinimum ? Icons.warning_amber_rounded : Icons.check_rounded,
            color: item.isBelowMinimum ? AppColors.warning : AppColors.success,
            size: 18,
          ),
        ),
        title: Text(item.name),
        subtitle: Text('${item.sku} · ${item.currentStock.toStringAsFixed(0)} / min ${item.minimumStock.toStringAsFixed(0)} ${item.unit}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              onPressed: () => ref.read(inventoryNotifierProvider.notifier).adjustStock(item, -1),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              onPressed: () => ref.read(inventoryNotifierProvider.notifier).adjustStock(item, 1),
            ),
          ],
        ),
      ),
    );
  }
}

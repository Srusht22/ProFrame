import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/inventory_item.dart';
import 'notification_notifier.dart';

class InventoryNotifier extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() {
    return ref.watch(appRepositoriesProvider).inventory.getAll();
  }

  Future<void> adjustStock(InventoryItem item, double delta) async {
    await ref.read(appRepositoriesProvider).inventory.adjustStock(item.id, delta);
    final updated = item.copyWith(currentStock: item.currentStock + delta, updatedAt: DateTime.now());
    state = AsyncData([
      for (final i in state.valueOrNull ?? const <InventoryItem>[])
        if (i.id == item.id) updated else i,
    ]);
    if (updated.isBelowMinimum) {
      await ref.read(notificationNotifierProvider.notifier).notify(
            type: NotificationType.lowInventory,
            title: 'Low stock: ${updated.name}',
            body:
                'Current stock (${updated.currentStock.toStringAsFixed(0)} ${updated.unit}) is below the minimum (${updated.minimumStock.toStringAsFixed(0)} ${updated.unit}).',
            relatedEntityId: updated.id,
          );
    }
  }

  Future<void> save(InventoryItem item) async {
    await ref.read(appRepositoriesProvider).inventory.save(item);
    final list = [...state.valueOrNull ?? const <InventoryItem>[]];
    final index = list.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    state = AsyncData(list);
  }
}

final inventoryNotifierProvider = AsyncNotifierProvider<InventoryNotifier, List<InventoryItem>>(
  InventoryNotifier.new,
);

final lowStockCountProvider = Provider<int>((ref) {
  final list = ref.watch(inventoryNotifierProvider).valueOrNull ?? const [];
  return list.where((i) => i.isBelowMinimum).length;
});

import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalInventoryRepository implements InventoryRepository {
  final JsonCollectionStore<InventoryItem> _store;

  LocalInventoryRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<InventoryItem>(
          keyValueStore: keyValueStore,
          collectionKey: 'inventory',
          toJson: (i) => i.toJson(),
          fromJson: InventoryItem.fromJson,
        );

  @override
  Future<List<InventoryItem>> getAll() => _store.readAll();

  @override
  Future<void> save(InventoryItem item) async {
    final all = await _store.readAll();
    final index = all.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      all[index] = item;
    } else {
      all.add(item);
    }
    await _store.writeAll(all);
  }

  @override
  Future<void> adjustStock(String id, double deltaQuantity) async {
    final all = await _store.readAll();
    final index = all.indexWhere((i) => i.id == id);
    if (index < 0) return;
    all[index] = all[index].copyWith(
      currentStock: all[index].currentStock + deltaQuantity,
      updatedAt: DateTime.now(),
    );
    await _store.writeAll(all);
  }
}

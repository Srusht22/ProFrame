import '../../domain/entities/manufacturing_order.dart';
import '../../domain/repositories/manufacturing_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalManufacturingRepository implements ManufacturingRepository {
  final JsonCollectionStore<ManufacturingOrder> _store;

  LocalManufacturingRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<ManufacturingOrder>(
          keyValueStore: keyValueStore,
          collectionKey: 'manufacturing_orders',
          toJson: (m) => m.toJson(),
          fromJson: ManufacturingOrder.fromJson,
        );

  @override
  Future<List<ManufacturingOrder>> getAll() => _store.readAll();

  @override
  Future<ManufacturingOrder?> getByOrderId(String orderId) async {
    final all = await _store.readAll();
    for (final m in all) {
      if (m.orderId == orderId) return m;
    }
    return null;
  }

  @override
  Future<void> save(ManufacturingOrder manufacturingOrder) async {
    final all = await _store.readAll();
    final index = all.indexWhere((m) => m.id == manufacturingOrder.id);
    if (index >= 0) {
      all[index] = manufacturingOrder;
    } else {
      all.add(manufacturingOrder);
    }
    await _store.writeAll(all);
  }
}

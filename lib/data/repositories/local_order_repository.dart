import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';
import '../local/sequence_counter.dart';

class LocalOrderRepository implements OrderRepository {
  final JsonCollectionStore<Order> _store;
  final SequenceCounter _sequence;
  final String _prefix;

  LocalOrderRepository(IKeyValueStore keyValueStore, {String prefix = 'ORD'})
      : _prefix = prefix,
        _sequence = SequenceCounter(keyValueStore),
        _store = JsonCollectionStore<Order>(
          keyValueStore: keyValueStore,
          collectionKey: 'orders',
          toJson: (o) => o.toJson(),
          fromJson: Order.fromJson,
        );

  @override
  Future<List<Order>> getAll() => _store.readAll();

  @override
  Future<Order?> getById(String id) async {
    final all = await _store.readAll();
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> save(Order order) async {
    final all = await _store.readAll();
    final index = all.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      all[index] = order;
    } else {
      all.add(order);
    }
    await _store.writeAll(all);
  }

  @override
  Future<String> nextOrderNumber() => _sequence.next(_prefix);
}

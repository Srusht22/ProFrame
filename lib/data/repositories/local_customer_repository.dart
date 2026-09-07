import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalCustomerRepository implements CustomerRepository {
  final JsonCollectionStore<Customer> _store;

  LocalCustomerRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<Customer>(
          keyValueStore: keyValueStore,
          collectionKey: 'customers',
          toJson: (c) => c.toJson(),
          fromJson: Customer.fromJson,
        );

  @override
  Future<List<Customer>> getAll() => _store.readAll();

  @override
  Future<Customer?> getById(String id) async {
    final all = await _store.readAll();
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> save(Customer customer) async {
    final all = await _store.readAll();
    final index = all.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      all[index] = customer;
    } else {
      all.add(customer);
    }
    await _store.writeAll(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _store.readAll();
    all.removeWhere((c) => c.id == id);
    await _store.writeAll(all);
  }
}

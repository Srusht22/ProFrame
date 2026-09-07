import '../../core/utils/id_generator.dart';
import '../../domain/configuration/product_configuration.dart';
import '../../domain/repositories/configuration_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalConfigurationRepository implements ConfigurationRepository {
  final JsonCollectionStore<ProductConfiguration> _store;
  final JsonCollectionStore<ProductConfiguration> _templateStore;

  LocalConfigurationRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<ProductConfiguration>(
          keyValueStore: keyValueStore,
          collectionKey: 'configurations',
          toJson: (c) => c.toJson(),
          fromJson: ProductConfiguration.fromJson,
        ),
        _templateStore = JsonCollectionStore<ProductConfiguration>(
          keyValueStore: keyValueStore,
          collectionKey: 'configuration_templates',
          toJson: (c) => c.toJson(),
          fromJson: ProductConfiguration.fromJson,
        );

  @override
  Future<List<ProductConfiguration>> getAll() => _store.readAll();

  @override
  Future<List<ProductConfiguration>> getByProject(String projectId) async {
    final all = await _store.readAll();
    return all.where((c) => c.projectId == projectId).toList();
  }

  @override
  Future<ProductConfiguration?> getById(String id) async {
    final all = await _store.readAll();
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> save(ProductConfiguration configuration) async {
    final all = await _store.readAll();
    final index = all.indexWhere((c) => c.id == configuration.id);
    if (index >= 0) {
      all[index] = configuration;
    } else {
      all.add(configuration);
    }
    await _store.writeAll(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _store.readAll();
    all.removeWhere((c) => c.id == id);
    await _store.writeAll(all);
  }

  @override
  Future<ProductConfiguration> duplicate(String id) async {
    final all = await _store.readAll();
    final original = all.firstWhere((c) => c.id == id);
    final copy = original.copyWith(
      name: '${original.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final withNewId = ProductConfiguration.fromJson({...copy.toJson(), 'id': IdGenerator.generate()});
    all.add(withNewId);
    await _store.writeAll(all);
    return withNewId;
  }

  @override
  Future<List<ProductConfiguration>> getTemplates() => _templateStore.readAll();

  @override
  Future<void> saveAsTemplate(ProductConfiguration configuration) async {
    final all = await _templateStore.readAll();
    final index = all.indexWhere((c) => c.id == configuration.id);
    if (index >= 0) {
      all[index] = configuration;
    } else {
      all.add(configuration);
    }
    await _templateStore.writeAll(all);
  }
}

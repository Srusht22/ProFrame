import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';
import '../local/sequence_counter.dart';

class LocalProjectRepository implements ProjectRepository {
  final JsonCollectionStore<Project> _store;
  final SequenceCounter _sequence;
  final String _prefix;

  LocalProjectRepository(IKeyValueStore keyValueStore, {String prefix = 'PRJ'})
      : _prefix = prefix,
        _sequence = SequenceCounter(keyValueStore),
        _store = JsonCollectionStore<Project>(
          keyValueStore: keyValueStore,
          collectionKey: 'projects',
          toJson: (p) => p.toJson(),
          fromJson: Project.fromJson,
        );

  @override
  Future<List<Project>> getAll() => _store.readAll();

  @override
  Future<Project?> getById(String id) async {
    final all = await _store.readAll();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> save(Project project) async {
    final all = await _store.readAll();
    final index = all.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      all[index] = project;
    } else {
      all.add(project);
    }
    await _store.writeAll(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _store.readAll();
    all.removeWhere((p) => p.id == id);
    await _store.writeAll(all);
  }

  @override
  Future<String> nextProjectNumber() => _sequence.next(_prefix);
}

import '../../domain/auth/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalUserRepository implements UserRepository {
  final JsonCollectionStore<AppUser> _store;

  LocalUserRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<AppUser>(
          keyValueStore: keyValueStore,
          collectionKey: 'users',
          toJson: (u) => u.toJson(),
          fromJson: AppUser.fromJson,
        );

  @override
  Future<List<AppUser>> getAll() => _store.readAll();

  @override
  Future<AppUser?> getById(String id) async {
    final all = await _store.readAll();
    for (final u in all) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<void> save(AppUser user) async {
    final all = await _store.readAll();
    final index = all.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      all[index] = user;
    } else {
      all.add(user);
    }
    await _store.writeAll(all);
  }
}

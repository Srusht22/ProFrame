import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalNotificationRepository implements NotificationRepository {
  final JsonCollectionStore<AppNotification> _store;

  LocalNotificationRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<AppNotification>(
          keyValueStore: keyValueStore,
          collectionKey: 'notifications',
          toJson: (n) => n.toJson(),
          fromJson: AppNotification.fromJson,
        );

  @override
  Future<List<AppNotification>> getAll() async {
    final all = await _store.readAll();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<void> add(AppNotification notification) async {
    final all = await _store.readAll();
    all.add(notification);
    await _store.writeAll(all);
  }

  @override
  Future<void> markRead(String id) async {
    final all = await _store.readAll();
    final index = all.indexWhere((n) => n.id == id);
    if (index >= 0) {
      all[index] = all[index].copyWith(isRead: true);
      await _store.writeAll(all);
    }
  }

  @override
  Future<void> markAllRead() async {
    final all = await _store.readAll();
    await _store.writeAll(all.map((n) => n.copyWith(isRead: true)).toList());
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/app_notification.dart';

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.watch(appRepositoriesProvider).notifications.getAll();
  }

  Future<void> notify({
    required NotificationType type,
    required String title,
    required String body,
    String? relatedEntityId,
  }) async {
    final notification = AppNotification(
      id: IdGenerator.generate(),
      type: type,
      title: title,
      body: body,
      relatedEntityId: relatedEntityId,
      createdAt: DateTime.now(),
    );
    await ref.read(appRepositoriesProvider).notifications.add(notification);
    state = AsyncData([notification, ...state.valueOrNull ?? const []]);
  }

  Future<void> markRead(String id) async {
    await ref.read(appRepositoriesProvider).notifications.markRead(id);
    state = AsyncData([
      for (final n in state.valueOrNull ?? const <AppNotification>[])
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);
  }

  Future<void> markAllRead() async {
    await ref.read(appRepositoriesProvider).notifications.markAllRead();
    state = AsyncData([
      for (final n in state.valueOrNull ?? const <AppNotification>[]) n.copyWith(isRead: true),
    ]);
  }
}

final notificationNotifierProvider = AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(
  NotificationNotifier.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationNotifierProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});

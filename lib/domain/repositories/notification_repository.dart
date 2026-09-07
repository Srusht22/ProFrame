import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getAll();
  Future<void> add(AppNotification notification);
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

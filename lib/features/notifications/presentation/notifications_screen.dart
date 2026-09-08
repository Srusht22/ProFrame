import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../shared/providers/notification_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationNotifierProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: AsyncValueView(
        value: notificationsAsync,
        onRetry: () => ref.invalidate(notificationNotifierProvider),
        builder: (items) {
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'You are all caught up.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxs),
            itemBuilder: (context, index) {
              final n = items[index];
              return Card(
                color: n.isRead ? null : AppColors.brandCream.withValues(alpha: 0.25),
                child: ListTile(
                  leading: Icon(_iconFor(n.type), color: AppColors.brandDarkGreen),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Text(n.body),
                  trailing: Text(_relativeTime(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => ref.read(notificationNotifierProvider.notifier).markRead(n.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.quotationAccepted:
        return Icons.check_circle_outline_rounded;
      case NotificationType.quotationRejected:
        return Icons.cancel_outlined;
      case NotificationType.lowInventory:
        return Icons.inventory_2_outlined;
      case NotificationType.newOrder:
        return Icons.local_shipping_outlined;
      case NotificationType.manufacturingCompleted:
        return Icons.precision_manufacturing_outlined;
      case NotificationType.qualityControlFailed:
        return Icons.error_outline_rounded;
      case NotificationType.projectDeadline:
        return Icons.event_outlined;
      case NotificationType.general:
        return Icons.info_outline_rounded;
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

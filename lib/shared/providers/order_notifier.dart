import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/quotation.dart';
import 'audit_log_notifier.dart';
import 'auth_notifier.dart';
import 'manufacturing_notifier.dart';
import 'notification_notifier.dart';
import 'quotation_notifier.dart';

class OrderNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() {
    return ref.watch(appRepositoriesProvider).orders.getAll();
  }

  /// Spec §23/§68: only an accepted, validated quotation may become an
  /// order, and doing so immediately opens the first manufacturing stage.
  Future<Order> convertFromQuotation(Quotation quotation) async {
    final orderNumber = await ref.read(appRepositoriesProvider).orders.nextOrderNumber();
    final user = ref.read(currentUserProvider);
    final order = Order.fromQuotation(
      id: IdGenerator.generate(),
      orderNumber: orderNumber,
      quotation: quotation,
      createdByUserId: user?.id ?? 'system',
    );
    await ref.read(appRepositoriesProvider).orders.save(order);
    state = AsyncData([...state.value ?? const [], order]);

    if (quotation.status != QuotationStatus.accepted) {
      await ref.read(quotationNotifierProvider.notifier).updateStatus(quotation, QuotationStatus.accepted);
    }

    await ref.read(manufacturingNotifierProvider.notifier).createForOrder(order);

    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.create,
          entityType: 'Order',
          entityId: order.id,
          entityLabel: order.orderNumber,
          actingUser: user,
        );
    await ref.read(notificationNotifierProvider.notifier).notify(
          type: NotificationType.newOrder,
          title: 'New order created',
          body: '${order.orderNumber} was created from ${quotation.quoteNumber}.',
          relatedEntityId: order.id,
        );
    return order;
  }

  Future<void> updateStatus(Order order, OrderStatus status) async {
    final updated = order.copyWith(status: status);
    await ref.read(appRepositoriesProvider).orders.save(updated);
    state = AsyncData([
      for (final o in state.value ?? const <Order>[])
        if (o.id == order.id) updated else o,
    ]);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.statusChange,
          entityType: 'Order',
          entityId: order.id,
          entityLabel: order.orderNumber,
          previousValue: order.status.label,
          newValue: status.label,
          actingUser: ref.read(currentUserProvider),
        );
  }
}

final orderNotifierProvider = AsyncNotifierProvider<OrderNotifier, List<Order>>(OrderNotifier.new);

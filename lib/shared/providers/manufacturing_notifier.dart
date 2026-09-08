import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/manufacturing_order.dart';
import '../../domain/entities/order.dart';
import 'notification_notifier.dart';

class ManufacturingNotifier extends AsyncNotifier<List<ManufacturingOrder>> {
  @override
  Future<List<ManufacturingOrder>> build() {
    return ref.watch(appRepositoriesProvider).manufacturing.getAll();
  }

  Future<ManufacturingOrder> createForOrder(Order order) async {
    final mo = ManufacturingOrder(
      id: IdGenerator.generate(),
      moNumber: 'MO-${order.orderNumber.split('-').skip(1).join('-')}',
      orderId: order.id,
      projectId: order.projectId,
      stage: ManufacturingStage.productionOrder,
      qcChecklist: QcCheckItem.standardChecklist(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(appRepositoriesProvider).manufacturing.save(mo);
    state = AsyncData([...state.value ?? const [], mo]);
    return mo;
  }

  Future<void> advanceStage(ManufacturingOrder mo) async {
    final next = mo.stage.next;
    if (next == null) return;
    final updated = mo.copyWith(stage: next);
    await ref.read(appRepositoriesProvider).manufacturing.save(updated);
    state = AsyncData([
      for (final m in state.value ?? const <ManufacturingOrder>[])
        if (m.id == mo.id) updated else m,
    ]);
    if (next == ManufacturingStage.completed) {
      await ref.read(notificationNotifierProvider.notifier).notify(
            type: NotificationType.manufacturingCompleted,
            title: 'Manufacturing completed',
            body: '${mo.moNumber} finished production.',
            relatedEntityId: mo.id,
          );
    }
  }

  Future<void> updateQcResult(ManufacturingOrder mo, String checkId, QcResult result, {String? note}) async {
    final updatedChecklist = [
      for (final c in mo.qcChecklist)
        if (c.id == checkId) c.copyWith(result: result, note: note) else c,
    ];
    final updated = mo.copyWith(qcChecklist: updatedChecklist);
    await ref.read(appRepositoriesProvider).manufacturing.save(updated);
    state = AsyncData([
      for (final m in state.value ?? const <ManufacturingOrder>[])
        if (m.id == mo.id) updated else m,
    ]);
    if (result == QcResult.fail) {
      await ref.read(notificationNotifierProvider.notifier).notify(
            type: NotificationType.qualityControlFailed,
            title: 'Quality control failed',
            body: '${mo.moNumber} failed check: ${updatedChecklist.firstWhere((c) => c.id == checkId).label}',
            relatedEntityId: mo.id,
          );
    }
  }
}

final manufacturingNotifierProvider = AsyncNotifierProvider<ManufacturingNotifier, List<ManufacturingOrder>>(
  ManufacturingNotifier.new,
);

final manufacturingByOrderProvider = Provider.family<ManufacturingOrder?, String>((ref, orderId) {
  final all = ref.watch(manufacturingNotifierProvider).value ?? const [];
  for (final m in all) {
    if (m.orderId == orderId) return m;
  }
  return null;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/quotation.dart';
import 'audit_log_notifier.dart';
import 'auth_notifier.dart';
import 'notification_notifier.dart';

class QuotationNotifier extends AsyncNotifier<List<Quotation>> {
  @override
  Future<List<Quotation>> build() {
    return ref.watch(appRepositoriesProvider).quotations.getAll();
  }

  Future<String> nextQuoteNumber() => ref.read(appRepositoriesProvider).quotations.nextQuoteNumber();

  Future<void> save(Quotation quotation, {required bool isNew}) async {
    await ref.read(appRepositoriesProvider).quotations.save(quotation);
    final list = [...state.valueOrNull ?? const <Quotation>[]];
    final index = list.indexWhere((q) => q.id == quotation.id);
    if (index >= 0) {
      list[index] = quotation;
    } else {
      list.add(quotation);
    }
    state = AsyncData(list);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: isNew ? AuditAction.create : AuditAction.update,
          entityType: 'Quotation',
          entityId: quotation.id,
          entityLabel: quotation.quoteNumber,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<void> updateStatus(Quotation quotation, QuotationStatus status) async {
    final updated = quotation.copyWith(status: status);
    await save(updated, isNew: false);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.statusChange,
          entityType: 'Quotation',
          entityId: quotation.id,
          entityLabel: quotation.quoteNumber,
          previousValue: quotation.status.label,
          newValue: status.label,
          actingUser: ref.read(currentUserProvider),
        );
    if (status == QuotationStatus.accepted) {
      await ref.read(notificationNotifierProvider.notifier).notify(
            type: NotificationType.quotationAccepted,
            title: 'Quotation accepted',
            body: '${quotation.quoteNumber} was accepted by the customer.',
            relatedEntityId: quotation.id,
          );
    } else if (status == QuotationStatus.rejected) {
      await ref.read(notificationNotifierProvider.notifier).notify(
            type: NotificationType.quotationRejected,
            title: 'Quotation rejected',
            body: '${quotation.quoteNumber} was rejected by the customer.',
            relatedEntityId: quotation.id,
          );
    }
  }
}

final quotationNotifierProvider = AsyncNotifierProvider<QuotationNotifier, List<Quotation>>(
  QuotationNotifier.new,
);

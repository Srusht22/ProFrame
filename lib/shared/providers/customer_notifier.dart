import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/customer.dart';
import 'audit_log_notifier.dart';
import 'auth_notifier.dart';

class CustomerNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() {
    return ref.watch(appRepositoriesProvider).customers.getAll();
  }

  Future<void> save(Customer customer, {required bool isNew}) async {
    await ref.read(appRepositoriesProvider).customers.save(customer);
    final list = [...state.value ?? const <Customer>[]];
    final index = list.indexWhere((c) => c.id == customer.id);
    if (index >= 0) {
      list[index] = customer;
    } else {
      list.add(customer);
    }
    state = AsyncData(list);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: isNew ? AuditAction.create : AuditAction.update,
          entityType: 'Customer',
          entityId: customer.id,
          entityLabel: customer.fullName,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<void> delete(Customer customer) async {
    await ref.read(appRepositoriesProvider).customers.delete(customer.id);
    state = AsyncData((state.value ?? const []).where((c) => c.id != customer.id).toList());
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.delete,
          entityType: 'Customer',
          entityId: customer.id,
          entityLabel: customer.fullName,
          actingUser: ref.read(currentUserProvider),
        );
  }
}

final customerNotifierProvider = AsyncNotifierProvider<CustomerNotifier, List<Customer>>(
  CustomerNotifier.new,
);

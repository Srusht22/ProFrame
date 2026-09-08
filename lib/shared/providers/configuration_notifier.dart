import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/configuration/product_configuration.dart';
import '../../domain/entities/audit_log_entry.dart';
import 'audit_log_notifier.dart';
import 'auth_notifier.dart';

/// All configured door/window items across every project — the single
/// source of truth the configurator, 2D/3D views, pricing, BOM, cutting
/// list and quotations all read from (spec §83).
class ConfigurationNotifier extends AsyncNotifier<List<ProductConfiguration>> {
  @override
  Future<List<ProductConfiguration>> build() {
    return ref.watch(appRepositoriesProvider).configurations.getAll();
  }

  Future<void> save(ProductConfiguration configuration, {required bool isNew}) async {
    await ref.read(appRepositoriesProvider).configurations.save(configuration);
    final list = [...state.value ?? const <ProductConfiguration>[]];
    final index = list.indexWhere((c) => c.id == configuration.id);
    if (index >= 0) {
      list[index] = configuration;
    } else {
      list.add(configuration);
    }
    state = AsyncData(list);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: isNew ? AuditAction.create : AuditAction.update,
          entityType: 'ProductConfiguration',
          entityId: configuration.id,
          entityLabel: configuration.name,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<void> delete(ProductConfiguration configuration) async {
    await ref.read(appRepositoriesProvider).configurations.delete(configuration.id);
    state = AsyncData((state.value ?? const []).where((c) => c.id != configuration.id).toList());
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.delete,
          entityType: 'ProductConfiguration',
          entityId: configuration.id,
          entityLabel: configuration.name,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<ProductConfiguration> duplicate(ProductConfiguration configuration) async {
    final copy = await ref.read(appRepositoriesProvider).configurations.duplicate(configuration.id);
    state = AsyncData([...state.value ?? const [], copy]);
    return copy;
  }
}

final configurationNotifierProvider =
    AsyncNotifierProvider<ConfigurationNotifier, List<ProductConfiguration>>(
  ConfigurationNotifier.new,
);

final configurationsByProjectProvider = Provider.family<List<ProductConfiguration>, String>(
  (ref, projectId) {
    final all = ref.watch(configurationNotifierProvider).value ?? const [];
    return all.where((c) => c.projectId == projectId).toList();
  },
);

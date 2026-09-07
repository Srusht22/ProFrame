import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/entities/audit_log_entry.dart';

class AuditLogNotifier extends AsyncNotifier<List<AuditLogEntry>> {
  @override
  Future<List<AuditLogEntry>> build() {
    return ref.watch(appRepositoriesProvider).auditLog.getAll();
  }

  /// Appends one entry and refreshes the in-memory list. Called by every
  /// other notifier after a mutating repository call — see spec §30: every
  /// create/update/delete should leave a trail of who/what/when.
  Future<void> log({
    required AuditAction action,
    required String entityType,
    required String entityId,
    String? entityLabel,
    String? previousValue,
    String? newValue,
    AppUser? actingUser,
  }) async {
    final entry = AuditLogEntry(
      id: IdGenerator.generate(),
      userId: actingUser?.id ?? 'system',
      userName: actingUser?.fullName ?? 'System',
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      previousValue: previousValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    );
    await ref.read(appRepositoriesProvider).auditLog.append(entry);
    state = AsyncData([entry, ...state.valueOrNull ?? const []]);
  }
}

final auditLogNotifierProvider = AsyncNotifierProvider<AuditLogNotifier, List<AuditLogEntry>>(
  AuditLogNotifier.new,
);

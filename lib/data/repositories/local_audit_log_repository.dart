import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/audit_log_repository.dart';
import '../local/json_collection_store.dart';
import '../local/key_value_store.dart';

class LocalAuditLogRepository implements AuditLogRepository {
  final JsonCollectionStore<AuditLogEntry> _store;

  LocalAuditLogRepository(IKeyValueStore keyValueStore)
      : _store = JsonCollectionStore<AuditLogEntry>(
          keyValueStore: keyValueStore,
          collectionKey: 'audit_log',
          toJson: (e) => e.toJson(),
          fromJson: AuditLogEntry.fromJson,
        );

  @override
  Future<List<AuditLogEntry>> getAll() async {
    final all = await _store.readAll();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  @override
  Future<void> append(AuditLogEntry entry) async {
    final all = await _store.readAll();
    all.add(entry);
    // Keep the log bounded for a local demo store.
    if (all.length > 500) {
      all.removeRange(0, all.length - 500);
    }
    await _store.writeAll(all);
  }
}

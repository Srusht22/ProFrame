import '../entities/audit_log_entry.dart';

abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getAll();
  Future<void> append(AuditLogEntry entry);
}

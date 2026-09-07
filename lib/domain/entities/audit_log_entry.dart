enum AuditAction { create, update, delete, statusChange, login, logout }

/// One immutable audit trail row: who changed what, from what to what,
/// when. Written by repositories on every mutating call — never
/// hand-assembled inside a widget — so the log stays trustworthy.
class AuditLogEntry {
  final String id;
  final String userId;
  final String userName;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final String? entityLabel;
  final String? previousValue;
  final String? newValue;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.entityLabel,
    this.previousValue,
    this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'action': action.name,
        'entityType': entityType,
        'entityId': entityId,
        'entityLabel': entityLabel,
        'previousValue': previousValue,
        'newValue': newValue,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Unknown',
        action: AuditAction.values.firstWhere(
          (e) => e.name == json['action'],
          orElse: () => AuditAction.update,
        ),
        entityType: json['entityType'] as String? ?? '',
        entityId: json['entityId'] as String? ?? '',
        entityLabel: json['entityLabel'] as String?,
        previousValue: json['previousValue'] as String?,
        newValue: json['newValue'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

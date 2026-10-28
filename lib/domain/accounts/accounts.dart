/// Who is signed in, and what the backend says about the factory: workers,
/// invitations, requests and notifications.
///
/// **Nothing here decides anything.** These are what the backend answered,
/// read into Dart so the screens can show them. Every rule — who is an owner,
/// which factory they are in, the three-worker limit, which designs a worker
/// may see, who may approve what — is kept by the database
/// (`supabase/migrations/`), against the signed session, and a client that
/// changed any of these values would change only what it shows itself.
library;

import '../model/elements.dart';
import '../pricing/pricing_access.dart';

/// The two kinds of account.
enum AccountRole {
  /// Signed up publicly; has a factory of their own.
  owner,

  /// Invited by an owner into their factory.
  labour;

  static AccountRole? of(Object? name) =>
      values.where((r) => r.name == name).firstOrNull;
}

enum AccountStatus {
  active,
  suspended;

  static AccountStatus of(Object? name) =>
      name == 'suspended' ? suspended : active;
}

/// The signed-in user, as the backend has them.
class Account implements Authority {
  final String userId;
  final String factoryId;
  final String factoryName;
  final AccountRole role;
  final String name;
  final String login;
  final AccountStatus status;

  const Account({
    required this.userId,
    required this.factoryId,
    required this.factoryName,
    required this.role,
    required this.name,
    required this.login,
    required this.status,
  });

  bool get isOwner => role == AccountRole.owner;
  bool get isActive => status == AccountStatus.active;

  /// What a labour account may do on the device: look at the design it has
  /// open. Everything else it does is a request the owner decides.
  static const labourCapabilities = {Capability.designsView};

  @override
  String get label => name;

  /// What the application offers this account. The backend decides again
  /// on every call, so this only shapes the screens.
  @override
  bool can(Capability capability) =>
      isActive && (isOwner || labourCapabilities.contains(capability));

  static Account? fromJson(Map<String, Object?> json) {
    final role = AccountRole.of(json['role']);
    if (role == null) return null;
    return Account(
      userId: '${json['user_id']}',
      factoryId: '${json['factory_id']}',
      factoryName: '${json['factory_name'] ?? ''}',
      role: role,
      name: '${json['name'] ?? ''}',
      login: '${json['login'] ?? ''}',
      status: AccountStatus.of(json['status']),
    );
  }
}

/// One of the owner's workers.
class Worker {
  final String userId;
  final String name;
  final String login;
  final AccountStatus status;
  final int assigned;
  final int pending;
  final DateTime? createdAt;

  const Worker({
    required this.userId,
    required this.name,
    required this.login,
    required this.status,
    this.assigned = 0,
    this.pending = 0,
    this.createdAt,
  });

  bool get isActive => status == AccountStatus.active;

  static Worker fromJson(Map<String, Object?> json) => Worker(
    userId: '${json['user_id']}',
    name: '${json['name'] ?? ''}',
    login: '${json['login'] ?? ''}',
    status: AccountStatus.of(json['status']),
    assigned: _int(json['assigned']),
    pending: _int(json['pending']),
    createdAt: _date(json['created_at']),
  );
}

/// An invitation still open, holding a seat.
class Invitation {
  final String id;
  final String name;
  final String email;
  final DateTime? expiresAt;

  const Invitation({
    required this.id,
    required this.name,
    required this.email,
    this.expiresAt,
  });

  static Invitation fromJson(Map<String, Object?> json) => Invitation(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    expiresAt: _date(json['expires_at']),
  );
}

/// An invitation just made: its code, shown once.
class InvitationCode {
  final String id;
  final String code;
  final DateTime? expiresAt;

  const InvitationCode({required this.id, required this.code, this.expiresAt});
}

/// Who a design is assigned to.
class Assignment {
  final String designId;
  final String workerId;
  final DateTime? createdAt;

  const Assignment({
    required this.designId,
    required this.workerId,
    this.createdAt,
  });

  static Assignment fromJson(Map<String, Object?> json) => Assignment(
    designId: '${json['design_id']}',
    workerId: '${json['worker_id']}',
    createdAt: _date(json['created_at']),
  );
}

/// A design assigned to the signed-in worker, as the backend gives it —
/// without its prices.
class AssignedDesign {
  final String id;
  final String customerId;
  final String customerName;
  final String name;
  final DesignKind kind;
  final int revision;
  final Map<String, Object?> data;

  const AssignedDesign({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.name,
    required this.kind,
    required this.revision,
    required this.data,
  });

  static AssignedDesign fromJson(Map<String, Object?> json) => AssignedDesign(
    id: '${json['id']}',
    customerId: '${json['customer_id']}',
    customerName: '${json['customer_name'] ?? ''}',
    name: '${json['name'] ?? ''}',
    kind: DesignKind.of(json['category']),
    revision: _int(json['revision']),
    data: (json['data'] as Map?)?.cast<String, Object?>() ?? const {},
  );
}

/// A customer a worker may name in a request: theirs to work for.
class ScopedCustomer {
  final String id;
  final String name;

  const ScopedCustomer({required this.id, required this.name});

  static ScopedCustomer fromJson(Map<String, Object?> json) =>
      ScopedCustomer(id: '${json['id']}', name: '${json['name'] ?? ''}');
}

/// What a worker asks for.
enum RequestKind {
  newDesign('new_design'),
  newCustomerDesign('new_customer_design'),
  designChange('design_change');

  const RequestKind(this.key);
  final String key;

  static RequestKind? of(Object? key) =>
      values.where((k) => k.key == key).firstOrNull;
}

/// Where a request is. Stable names, as the backend keeps them.
enum RequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
  failed;

  static RequestStatus of(Object? name) =>
      values.where((s) => s.name == name).firstOrNull ?? failed;
}

/// A request, as the backend keeps it.
class WorkRequest {
  final String id;
  final RequestKind kind;
  final RequestStatus status;
  final String requestedBy;
  final String? customerId;
  final String? designId;
  final int? baseRevision;
  final Map<String, Object?> payload;
  final String description;
  final DateTime? createdAt;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;
  final String? resultDesignId;
  final String? resultCustomerId;

  const WorkRequest({
    required this.id,
    required this.kind,
    required this.status,
    required this.requestedBy,
    this.customerId,
    this.designId,
    this.baseRevision,
    this.payload = const {},
    this.description = '',
    this.createdAt,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
    this.resultDesignId,
    this.resultCustomerId,
  });

  /// The design's name asked for, or the proposal's.
  String get designName =>
      '${payload['name'] ?? (payload['design'] as Map?)?['name'] ?? ''}';

  /// The category asked for.
  DesignKind? get kindAsked =>
      payload['category'] == null ? null : DesignKind.of(payload['category']);

  /// The new customer asked for.
  Map<String, Object?> get customerAsked =>
      (payload['customer'] as Map?)?.cast<String, Object?>() ?? const {};

  /// The proposed design, for a change.
  Map<String, Object?>? get proposed =>
      (payload['design'] as Map?)?.cast<String, Object?>();

  static WorkRequest? fromJson(Map<String, Object?> json) {
    final kind = RequestKind.of(json['kind']);
    if (kind == null) return null;
    return WorkRequest(
      id: '${json['id']}',
      kind: kind,
      status: RequestStatus.of(json['status']),
      requestedBy: '${json['requested_by']}',
      customerId: json['customer_id'] as String?,
      designId: json['design_id'] as String?,
      baseRevision: json['base_revision'] == null
          ? null
          : _int(json['base_revision']),
      payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const {},
      description: '${json['description'] ?? ''}',
      createdAt: _date(json['created_at']),
      decidedBy: json['decided_by'] as String?,
      decidedAt: _date(json['decided_at']),
      decisionNote: json['decision_note'] as String?,
      resultDesignId: json['result_design_id'] as String?,
      resultCustomerId: json['result_customer_id'] as String?,
    );
  }
}

/// A note to one account.
class AppNotification {
  final String id;
  final String kind;
  final String? requestId;
  final Map<String, Object?> body;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.kind,
    this.requestId,
    this.body = const {},
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  static AppNotification fromJson(Map<String, Object?> json) => AppNotification(
    id: '${json['id']}',
    kind: '${json['kind']}',
    requestId: json['request_id'] as String?,
    body: (json['body'] as Map?)?.cast<String, Object?>() ?? const {},
    createdAt: _date(json['created_at']),
    readAt: _date(json['read_at']),
  );
}

int _int(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s) ?? 0,
  _ => 0,
};

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

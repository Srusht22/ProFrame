import 'dart:convert';

import 'package:proframe/domain/accounts/accounts.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/infrastructure/cloud/backend.dart';

/// The backend's contract, in memory, for the application's own tests.
///
/// It keeps the same rules as the database (`supabase/migrations/`) — who
/// is an owner, the three seats, assigned, asked decided once, one
/// factory never seeing another — so the screens can be tested against
/// them. It is a stand-in and proves nothing about security: the rules
/// themselves are held where they are kept, by
/// `test/backend/backend_security_test.dart` against PostgreSQL.
class FakeBackend implements Backend {
  final users = <String, _User>{};
  final factories = <String, String>{}; // id → name
  final accounts = <String, Account>{};
  final invites = <String, _Invite>{};
  final customers = <String, Map<String, _Row>>{}; // factory → id → row
  final designs = <String, Map<String, _Row>>{};
  final documents = <String, Map<String, _Row>>{};
  final assigned = <({String factory, String design, String worker})>{};
  final asked = <WorkRequest>[];
  final _requestFactory = <String, String>{};
  final notes = <String, List<AppNotification>>{};
  final history = <String, List<Map<String, Object?>>>{};

  /// Whether a new account must confirm its address before signing in.
  bool confirmEmail = false;

  /// Who is signed in, by user id.
  String? current;

  /// A session kept on the device, as `restore` would find it.
  String? kept;

  void Function()? ended;

  @override
  set onSessionEnded(void Function()? callback) => ended = callback;

  /// The session ending by itself, as an expired or revoked one does.
  void expire() {
    current = kept = null;
    ended?.call();
  }

  int _ids = 0;
  String _id(String p) => '$p-${++_ids}';

  // ------------------------------------------------------------- set-up

  /// An owner with a factory, signed in or not.
  String addOwner(
    String email,
    String password, {
    String name = 'Soran',
    String factory = 'Soran workshop',
  }) {
    final id = _id('user');
    final f = _id('factory');
    factories[f] = factory;
    users[email] = _User(id, password);
    accounts[id] = Account(
      userId: id,
      factoryId: f,
      factoryName: factory,
      role: AccountRole.owner,
      name: name,
      login: email,
      status: AccountStatus.active,
    );
    return id;
  }

  /// A worker in [ownerId]'s factory.
  String addWorker(
    String ownerId,
    String email,
    String password, {
    String name = 'Ali',
  }) {
    final o = accounts[ownerId]!;
    final id = _id('user');
    users[email] = _User(id, password);
    accounts[id] = Account(
      userId: id,
      factoryId: o.factoryId,
      factoryName: o.factoryName,
      role: AccountRole.labour,
      name: name,
      login: email,
      status: AccountStatus.active,
    );
    return id;
  }

  /// A customer and a design in [ownerId]'s factory, as an owner's device
  /// would have sent them.
  void seed(
    String ownerId,
    Map<String, Object?> customer,
    Map<String, Object?> design,
  ) {
    final f = accounts[ownerId]!.factoryId;
    customers.putIfAbsent(f, () => {})['${customer['id']}'] = _Row(
      jsonEncode(customer),
    );
    designs.putIfAbsent(f, () => {})['${design['id']}'] = _Row(
      jsonEncode(design),
    );
  }

  Account get _me {
    final a = accounts[current];
    if (current == null) throw BackendError('not_signed_in');
    if (a == null) throw BackendError('no_account');
    if (!a.isActive) throw BackendError('suspended');
    return a;
  }

  Account get _owner {
    final a = _me;
    if (!a.isOwner) throw BackendError('not_owner');
    return a;
  }

  Account get _labour {
    final a = _me;
    if (a.isOwner) throw BackendError('not_labour');
    return a;
  }

  int _seats(String factory) =>
      accounts.values
          .where((a) => a.factoryId == factory && !a.isOwner && a.isActive)
          .length +
      invites.values.where((i) => i.factory == factory && i.open).length;

  void _notify(
    String to,
    String kind,
    String? request,
    Map<String, Object?> body,
  ) => notes
      .putIfAbsent(to, () => [])
      .insert(
        0,
        AppNotification(
          id: _id('note'),
          kind: kind,
          requestId: request,
          body: body,
          createdAt: DateTime.now(),
        ),
      );

  String _ownerOf(String factory) => accounts.values
      .firstWhere((a) => a.factoryId == factory && a.isOwner)
      .userId;

  // ------------------------------------------------------------ sessions

  @override
  Future<String?> restore() async {
    current = kept;
    return kept;
  }

  @override
  Future<LinkSession?> fromLink(Uri link) async => null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final u = users[email.trim().toLowerCase()];
    if (u == null || u.password != password) {
      throw BackendError('invalid_credentials');
    }
    if (u.unconfirmed) throw BackendError('email_not_confirmed');
    current = kept = u.id;
  }

  Future<bool> _signUp(String email, String password, String id) async {
    users[email.trim().toLowerCase()] = _User(
      id,
      password,
      unconfirmed: confirmEmail,
    );
    if (confirmEmail) return true;
    current = kept = id;
    return false;
  }

  @override
  Future<bool> signUpOwner({
    required String name,
    required String factoryName,
    required String email,
    required String password,
  }) async {
    if (users.containsKey(email.trim().toLowerCase())) {
      throw BackendError('user_already_exists');
    }
    final id = _id('user');
    final f = _id('factory');
    factories[f] = factoryName;
    accounts[id] = Account(
      userId: id,
      factoryId: f,
      factoryName: factoryName,
      role: AccountRole.owner,
      name: name.trim(),
      login: email.trim().toLowerCase(),
      status: AccountStatus.active,
    );
    return _signUp(email, password, id);
  }

  @override
  Future<bool> joinAsWorker({
    required String name,
    required String email,
    required String password,
    required String code,
  }) async {
    final e = email.trim().toLowerCase();
    if (users.containsKey(e)) throw BackendError('user_already_exists');
    final invite = invites.values
        .where((i) => i.code == code.trim() && i.open && i.email == e)
        .firstOrNull;
    if (invite == null) throw BackendError('invite_invalid');
    invite.open = false;
    final id = _id('user');
    accounts[id] = Account(
      userId: id,
      factoryId: invite.factory,
      factoryName: factories[invite.factory]!,
      role: AccountRole.labour,
      name: name.trim(),
      login: e,
      status: AccountStatus.active,
    );
    _notify(_ownerOf(invite.factory), 'worker_joined', null, {
      'name': name.trim(),
    });
    return _signUp(email, password, id);
  }

  final recovered = <String>[];

  @override
  Future<void> recover(String email) async => recovered.add(email.trim());

  @override
  Future<void> setPassword(String password) async {}

  @override
  Future<void> signOut() async => current = kept = null;

  @override
  Future<Account?> myAccount() async {
    if (current == null) throw BackendError('not_signed_in');
    return accounts[current];
  }

  // -------------------------------------------------------------- owner

  @override
  Future<List<Worker>> workers() async {
    final o = _owner;
    return [
      for (final a in accounts.values)
        if (a.factoryId == o.factoryId && !a.isOwner)
          Worker(
            userId: a.userId,
            name: a.name,
            login: a.login,
            status: a.status,
            assigned: assigned.where((x) => x.worker == a.userId).length,
            pending: asked
                .where(
                  (r) =>
                      r.requestedBy == a.userId &&
                      r.status == RequestStatus.pending,
                )
                .length,
          ),
    ];
  }

  @override
  Future<List<Invitation>> openInvitations() async {
    final o = _owner;
    return [
      for (final MapEntry(:key, :value) in invites.entries)
        if (value.factory == o.factoryId && value.open)
          Invitation(
            id: key,
            name: value.name,
            email: value.email,
            expiresAt: DateTime(2026, 10, 20),
          ),
    ];
  }

  @override
  Future<InvitationCode> invite({
    required String name,
    required String email,
  }) async {
    final o = _owner;
    final e = email.trim().toLowerCase();
    if (users.containsKey(e)) throw BackendError('email_taken');
    if (_seats(o.factoryId) >= 3) throw BackendError('worker_limit');
    final id = _id('invite');
    final code = 'CODE${_ids}XYZ';
    invites[id] = _Invite(o.factoryId, name, e, code);
    return InvitationCode(
      id: id,
      code: code,
      expiresAt: DateTime(2026, 10, 20),
    );
  }

  @override
  Future<void> revokeInvitation(String id) async {
    final o = _owner;
    final i = invites[id];
    if (i == null || i.factory != o.factoryId) throw BackendError('not_found');
    i.open = false;
  }

  @override
  Future<void> setWorkerActive(String workerId, {required bool active}) async {
    final o = _owner;
    final w = accounts[workerId];
    if (w == null || w.factoryId != o.factoryId || w.isOwner) {
      throw BackendError('not_found');
    }
    if (active && !w.isActive && _seats(o.factoryId) >= 3) {
      throw BackendError('worker_limit');
    }
    accounts[workerId] = Account(
      userId: w.userId,
      factoryId: w.factoryId,
      factoryName: w.factoryName,
      role: w.role,
      name: w.name,
      login: w.login,
      status: active ? AccountStatus.active : AccountStatus.suspended,
    );
  }

  @override
  Future<List<Assignment>> assignments() async {
    final o = _owner;
    return [
      for (final a in assigned)
        if (a.factory == o.factoryId)
          Assignment(designId: a.design, workerId: a.worker),
    ];
  }

  @override
  Future<void> assign(String designId, String workerId) async {
    final o = _owner;
    final w = accounts[workerId];
    if (w == null || w.factoryId != o.factoryId) {
      throw BackendError('not_found');
    }
    if (designs[o.factoryId]?[designId] == null) {
      throw BackendError('not_found');
    }
    if (assigned.add((
      factory: o.factoryId,
      design: designId,
      worker: workerId,
    ))) {
      _notify(workerId, 'design_assigned', null, {'design': designId});
    }
  }

  @override
  Future<void> unassign(String designId, String workerId) async {
    final o = _owner;
    assigned.remove((factory: o.factoryId, design: designId, worker: workerId));
  }

  @override
  Future<List<WorkRequest>> requests() async {
    final me = _me;
    return [
      for (final r in asked.reversed)
        if (me.isOwner
            ? _requestFactory[r.id] == me.factoryId
            : r.requestedBy == me.userId)
          r,
    ];
  }

  @override
  Future<Map<String, Object?>?> requestBase(String requestId) async {
    final o = _owner;
    final r = asked.firstWhere(
      (r) => r.id == requestId && _requestFactory[r.id] == o.factoryId,
      orElse: () => throw BackendError('not_found'),
    );
    final versions = history['${o.factoryId}/${r.designId}'] ?? const [];
    return versions.length >= r.baseRevision!
        ? versions[r.baseRevision! - 1]
        : null;
  }

  WorkRequest _decidable(String id) {
    final o = _owner;
    final r = asked
        .where((r) => r.id == id && _requestFactory[r.id] == o.factoryId)
        .firstOrNull;
    if (r == null) throw BackendError('not_found');
    return r;
  }

  void _replace(WorkRequest r, WorkRequest by) => asked[asked.indexOf(r)] = by;

  WorkRequest _decided(
    WorkRequest r,
    RequestStatus status,
    String note, {
    String? design,
    String? customer,
  }) => WorkRequest(
    id: r.id,
    kind: r.kind,
    status: status,
    requestedBy: r.requestedBy,
    customerId: r.customerId,
    designId: r.designId,
    baseRevision: r.baseRevision,
    payload: r.payload,
    description: r.description,
    createdAt: r.createdAt,
    decidedBy: current,
    decidedAt: DateTime.now(),
    decisionNote: note,
    resultDesignId: design ?? r.resultDesignId,
    resultCustomerId: customer ?? r.resultCustomerId,
  );

  int approvals = 0;

  @override
  Future<({String designId, String customerId})> approveNewDesign(
    String requestId, {
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  }) async {
    final o = _owner;
    final r = _decidable(requestId);
    if (r.status == RequestStatus.approved) {
      return (designId: r.resultDesignId!, customerId: r.resultCustomerId!);
    }
    if (r.status != RequestStatus.pending) {
      throw BackendError('already_decided');
    }
    if (design['customerId'] != r.customerId ||
        design['category'] != r.payload['category']) {
      throw BackendError('invalid');
    }
    designs.putIfAbsent(o.factoryId, () => {})['${design['id']}'] = _Row(
      jsonEncode(design),
    );
    history['${o.factoryId}/${design['id']}'] = [design];
    _replace(
      r,
      _decided(
        r,
        RequestStatus.approved,
        note,
        design: '${design['id']}',
        customer: r.customerId,
      ),
    );
    if (assign) {
      assigned.add((
        factory: o.factoryId,
        design: '${design['id']}',
        worker: r.requestedBy,
      ));
    }
    _notify(r.requestedBy, 'request_approved', r.id, {
      'kind': r.kind.key,
      'note': note,
    });
    approvals++;
    return (designId: '${design['id']}', customerId: r.customerId!);
  }

  @override
  Future<({String designId, String customerId})> approveNewCustomer(
    String requestId, {
    required Map<String, Object?> customer,
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  }) async {
    final o = _owner;
    final r = _decidable(requestId);
    if (r.status == RequestStatus.approved) {
      return (designId: r.resultDesignId!, customerId: r.resultCustomerId!);
    }
    if (r.status != RequestStatus.pending) {
      throw BackendError('already_decided');
    }
    if (design['customerId'] != customer['id']) throw BackendError('invalid');
    customers.putIfAbsent(o.factoryId, () => {})['${customer['id']}'] = _Row(
      jsonEncode(customer),
    );
    designs.putIfAbsent(o.factoryId, () => {})['${design['id']}'] = _Row(
      jsonEncode(design),
    );
    history['${o.factoryId}/${design['id']}'] = [design];
    _replace(
      r,
      _decided(
        r,
        RequestStatus.approved,
        note,
        design: '${design['id']}',
        customer: '${customer['id']}',
      ),
    );
    if (assign) {
      assigned.add((
        factory: o.factoryId,
        design: '${design['id']}',
        worker: r.requestedBy,
      ));
    }
    _notify(r.requestedBy, 'request_approved', r.id, {
      'kind': r.kind.key,
      'note': note,
    });
    approvals++;
    return (designId: '${design['id']}', customerId: '${customer['id']}');
  }

  static const keptKeys = [
    'id',
    'name',
    'category',
    'kind',
    'customer',
    'customerId',
    'createdAt',
    'pricing',
    'completedAs',
  ];

  @override
  Future<({int revision, Map<String, Object?> data})> approveChange(
    String requestId, {
    required String note,
  }) async {
    final o = _owner;
    final r = _decidable(requestId);
    final row = designs[o.factoryId]![r.designId]!;
    if (r.status == RequestStatus.approved) {
      return (
        revision: row.revision,
        data: (jsonDecode(row.value) as Map).cast<String, Object?>(),
      );
    }
    if (r.status != RequestStatus.pending) {
      throw BackendError('already_decided');
    }
    if (row.revision != r.baseRevision) throw BackendError('conflict');
    final was = (jsonDecode(row.value) as Map).cast<String, Object?>();
    final data = {
      for (final MapEntry(:key, :value) in r.proposed!.entries)
        if (!keptKeys.contains(key)) key: value,
      for (final k in keptKeys)
        if (was.containsKey(k)) k: was[k],
    };
    row
      ..value = jsonEncode(data)
      ..revision += 1;
    history.putIfAbsent('${o.factoryId}/${r.designId}', () => [was]).add(data);
    _replace(
      r,
      _decided(
        r,
        RequestStatus.approved,
        note,
        design: r.designId,
        customer: r.customerId,
      ),
    );
    _notify(r.requestedBy, 'request_approved', r.id, {
      'kind': r.kind.key,
      'note': note,
    });
    approvals++;
    return (revision: row.revision, data: data);
  }

  @override
  Future<void> reject(String requestId, {required String note}) async {
    final r = _decidable(requestId);
    if (r.status == RequestStatus.rejected) return;
    if (r.status != RequestStatus.pending) {
      throw BackendError('already_decided');
    }
    _replace(r, _decided(r, RequestStatus.rejected, note));
    _notify(r.requestedBy, 'request_rejected', r.id, {
      'kind': r.kind.key,
      'note': note,
    });
  }

  @override
  Future<FactoryRecords> records() async {
    final o = _owner;
    Map<String, Kept> of(Map<String, _Row>? rows) => {
      for (final MapEntry(:key, :value)
          in (rows ?? const <String, _Row>{}).entries)
        if (!value.deleted) key: Kept(value.value, value.revision),
    };
    return FactoryRecords(
      customers: of(customers[o.factoryId]),
      designs: of(designs[o.factoryId]),
      documents: of(documents[o.factoryId]),
    );
  }

  int _put(Map<String, _Row> rows, String id, String json, int? expected) {
    final row = rows[id];
    if (row == null) {
      rows[id] = _Row(json);
      return 1;
    }
    if (!row.deleted && row.revision != expected) {
      throw BackendError('conflict');
    }
    row
      ..value = json
      ..deleted = false
      ..revision += 1;
    return row.revision;
  }

  @override
  Future<int> putCustomer(String id, String json, int? expected) async => _put(
    customers.putIfAbsent(_owner.factoryId, () => {}),
    id,
    json,
    expected,
  );

  @override
  Future<int> putDesign(String id, String json, int? expected) async {
    final o = _owner;
    final customer = (jsonDecode(json) as Map)['customerId'];
    if (customers[o.factoryId]?[customer] == null) {
      throw BackendError('customer_missing');
    }
    final revision = _put(
      designs.putIfAbsent(o.factoryId, () => {}),
      id,
      json,
      expected,
    );
    final versions = history.putIfAbsent('${o.factoryId}/$id', () => []);
    if (versions.length < revision) {
      versions.add((jsonDecode(json) as Map).cast<String, Object?>());
    }
    return revision;
  }

  @override
  Future<void> deleteDesign(String id) async {
    final o = _owner;
    designs[o.factoryId]?[id]?.deleted = true;
    assigned.removeWhere((a) => a.factory == o.factoryId && a.design == id);
  }

  @override
  Future<void> deleteCustomer(String id) async =>
      customers[_owner.factoryId]?[id]?.deleted = true;

  @override
  Future<int> putDocument(String key, String value, int? expected) async =>
      _put(
        documents.putIfAbsent(_owner.factoryId, () => {}),
        key,
        value,
        expected,
      );

  @override
  Future<void> deleteDocument(String key) async =>
      documents[_owner.factoryId]?.remove(key);

  // ------------------------------------------------------------- labour

  AssignedDesign _assigned(Account me, String id) {
    if (!assigned.contains((
      factory: me.factoryId,
      design: id,
      worker: me.userId,
    ))) {
      throw BackendError('not_assigned');
    }
    final row = designs[me.factoryId]![id]!;
    final data = (jsonDecode(row.value) as Map).cast<String, Object?>()
      ..remove('pricing');
    final customer = customers[me.factoryId]!['${data['customerId']}']!;
    return AssignedDesign(
      id: id,
      customerId: '${data['customerId']}',
      customerName: '${(jsonDecode(customer.value) as Map)['name']}',
      name: '${data['name']}',
      kind: DesignKind.of(data['category']),
      revision: row.revision,
      data: data,
    );
  }

  @override
  Future<List<AssignedDesign>> myDesigns() async {
    final me = _labour;
    return [
      for (final a in assigned)
        if (a.worker == me.userId && a.factory == me.factoryId)
          _assigned(me, a.design),
    ];
  }

  @override
  Future<AssignedDesign> assignedDesign(String id) async =>
      _assigned(_labour, id);

  @override
  Future<List<ScopedCustomer>> myCustomers() async {
    final seen = <String, ScopedCustomer>{};
    for (final d in await myDesigns()) {
      seen[d.customerId] = ScopedCustomer(
        id: d.customerId,
        name: d.customerName,
      );
    }
    return seen.values.toList();
  }

  String _request(
    Account me,
    RequestKind kind,
    String key, {
    String? customer,
    String? design,
    int? base,
    required Map<String, Object?> payload,
    required String description,
  }) {
    final existing = asked
        .where((r) => r.requestedBy == me.userId && r.payload['_key'] == key)
        .firstOrNull;
    if (existing != null) return existing.id;
    final r = WorkRequest(
      id: _id('request'),
      kind: kind,
      status: RequestStatus.pending,
      requestedBy: me.userId,
      customerId: customer,
      designId: design,
      baseRevision: base,
      payload: {...payload, '_key': key},
      description: description,
      createdAt: DateTime.now(),
    );
    asked.add(r);
    _requestFactory[r.id] = me.factoryId;
    _notify(_ownerOf(me.factoryId), 'request_submitted', r.id, {
      'kind': kind.key,
      'by': me.name,
    });
    return r.id;
  }

  @override
  Future<String> requestNewDesign({
    required String customerId,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  }) async {
    final me = _labour;
    if (!(await myCustomers()).any((c) => c.id == customerId)) {
      throw BackendError('customer_out_of_scope');
    }
    return _request(
      me,
      RequestKind.newDesign,
      clientKey,
      customer: customerId,
      payload: {'name': name, 'category': category},
      description: description,
    );
  }

  @override
  Future<String> requestNewCustomer({
    required Map<String, Object?> customer,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  }) async => _request(
    _labour,
    RequestKind.newCustomerDesign,
    clientKey,
    payload: {'customer': customer, 'name': name, 'category': category},
    description: description,
  );

  @override
  Future<String> requestChange({
    required String designId,
    required int baseRevision,
    required Map<String, Object?> proposed,
    required String description,
    required String clientKey,
  }) async {
    final me = _labour;
    final d = _assigned(me, designId);
    return _request(
      me,
      RequestKind.designChange,
      clientKey,
      customer: d.customerId,
      design: designId,
      base: baseRevision,
      payload: {
        'design': {...proposed}..remove('pricing'),
      },
      description: description,
    );
  }

  @override
  Future<void> cancelRequest(String id) async {
    final me = _labour;
    final r = asked
        .where(
          (r) =>
              r.id == id &&
              r.requestedBy == me.userId &&
              r.status == RequestStatus.pending,
        )
        .firstOrNull;
    if (r == null) throw BackendError('not_pending');
    _replace(r, _decided(r, RequestStatus.cancelled, ''));
  }

  // --------------------------------------------------------------- both

  @override
  Future<List<AppNotification>> notifications() async => [
    ...?notes[_me.userId],
  ];

  @override
  Future<void> markRead(String id) async {
    final mine = notes[_me.userId] ?? [];
    for (var i = 0; i < mine.length; i++) {
      final n = mine[i];
      if (n.id == id) {
        mine[i] = AppNotification(
          id: n.id,
          kind: n.kind,
          requestId: n.requestId,
          body: n.body,
          createdAt: n.createdAt,
          readAt: DateTime.now(),
        );
      }
    }
  }

  @override
  Future<Map<String, String>> accountNames() async {
    final me = _me;
    return {
      for (final a in accounts.values)
        if (me.isOwner ? a.factoryId == me.factoryId : a.userId == me.userId)
          a.userId: a.name,
    };
  }

  /// A design as the backend holds it.
  Map<String, Object?>? design(String ownerId, String id) {
    final row = designs[accounts[ownerId]!.factoryId]?[id];
    return row == null || row.deleted
        ? null
        : (jsonDecode(row.value) as Map).cast<String, Object?>();
  }

  int? revisionOf(String ownerId, String id) =>
      designs[accounts[ownerId]!.factoryId]?[id]?.revision;
}

class _User {
  final String id;
  final String password;
  final bool unconfirmed;
  _User(this.id, this.password, {this.unconfirmed = false});
}

class _Invite {
  final String factory;
  final String name;
  final String email;
  final String code;
  bool open = true;
  _Invite(this.factory, this.name, this.email, this.code);
}

class _Row {
  String value;
  int revision = 1;
  bool deleted = false;
  _Row(this.value);
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/accounts/accounts.dart';
import 'backend.dart';

/// Where the backend is, given to the build:
///
/// ```
/// flutter build web --dart-define=PROFRAME_SUPABASE_URL=https://….supabase.co \
///                   --dart-define=PROFRAME_SUPABASE_ANON_KEY=…
/// ```
///
/// The anon key is public by design: it identifies the project and allows
/// nothing that row-level security does not. Without both the application
/// runs on its own, on one device, as before Phase 36.
class BackendConfig {
  final String url;
  final String anonKey;

  const BackendConfig({required this.url, required this.anonKey});

  static BackendConfig? get fromBuild {
    const url = String.fromEnvironment('PROFRAME_SUPABASE_URL');
    const key = String.fromEnvironment('PROFRAME_SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) return null;
    return BackendConfig(
      url: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      anonKey: key,
    );
  }
}

/// The backend, as Supabase serves it: its Auth service for sessions and
/// passwords, and its REST API over the database for everything else.
///
/// Passwords go to the Auth service and nowhere else; they are never kept
/// on the device. The session kept on the device (the provider's access and
/// refresh tokens, as Supabase's own clients keep them) proves who the user
/// is to the backend and nothing more: what they may do is decided there.
class SupabaseBackend implements Backend {
  final BackendConfig config;
  final http.Client _http;

  SupabaseBackend(this.config, {http.Client? client})
    : _http = client ?? http.Client();

  static const sessionKey = 'proframe.cloud.session.v1';

  String? _access;
  String? _refresh;
  DateTime? _expires;

  void Function()? _ended;

  @override
  set onSessionEnded(void Function()? ended) => _ended = ended;

  Map<String, String> get _anon => {
    'apikey': config.anonKey,
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> _authed() async {
    await _fresh();
    final token = _access;
    if (token == null) throw BackendError('not_signed_in');
    return {..._anon, 'Authorization': 'Bearer $token'};
  }

  // ------------------------------------------------------------ sessions

  Future<void> _keep(Map<String, Object?> session) async {
    _access = session['access_token'] as String?;
    _refresh = session['refresh_token'] as String?;
    final inSeconds = session['expires_in'];
    _expires = DateTime.now().add(
      Duration(seconds: inSeconds is num ? inSeconds.toInt() : 3600),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      sessionKey,
      jsonEncode({
        'refresh_token': _refresh,
        'access_token': _access,
        'expires_at': _expires!.toIso8601String(),
      }),
    );
  }

  Future<void> _forget() async {
    _access = _refresh = null;
    _expires = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionKey);
  }

  Future<void> _fresh() async {
    final until = _expires;
    if (_access != null &&
        until != null &&
        until.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return;
    }
    final token = _refresh;
    if (token == null) return;
    final r = await _send(
      () => _http.post(
        Uri.parse('${config.url}/auth/v1/token?grant_type=refresh_token'),
        headers: _anon,
        body: jsonEncode({'refresh_token': token}),
      ),
    );
    if (r.statusCode != 200) {
      await _forget();
      _ended?.call();
      throw BackendError('not_signed_in');
    }
    await _keep(_json(r) as Map<String, Object?>);
  }

  @override
  Future<String?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(sessionKey);
    if (text == null) return null;
    try {
      final kept = jsonDecode(text) as Map<String, Object?>;
      _refresh = kept['refresh_token'] as String?;
      _access = kept['access_token'] as String?;
      _expires = DateTime.tryParse('${kept['expires_at']}');
      await _fresh();
      return _access;
    } on BackendError catch (e) {
      if (e.code == 'network') rethrow;
      return null;
    } on FormatException {
      await _forget();
      return null;
    }
  }

  @override
  Future<LinkSession?> fromLink(Uri link) async {
    final fragment = Uri.splitQueryString(
      link.fragment.startsWith('/') ? '' : link.fragment,
    );
    final access = fragment['access_token'];
    final refresh = fragment['refresh_token'];
    if (access == null || refresh == null) return null;
    await _keep({
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': int.tryParse(fragment['expires_in'] ?? '') ?? 3600,
    });
    return LinkSession(recovery: fragment['type'] == 'recovery');
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final r = await _send(
      () => _http.post(
        Uri.parse('${config.url}/auth/v1/token?grant_type=password'),
        headers: _anon,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    if (r.statusCode != 200) throw _authError(r);
    await _keep(_json(r) as Map<String, Object?>);
  }

  Future<bool> _signUp(
    String email,
    String password,
    Map<String, Object?> data,
  ) async {
    final r = await _send(
      () => _http.post(
        Uri.parse('${config.url}/auth/v1/signup'),
        headers: _anon,
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': data,
        }),
      ),
    );
    if (r.statusCode != 200) {
      final error = _authError(r);
      // The database refusing the new user — an invitation that is not
      // valid for this address — comes back from the Auth service as its
      // own failure to save the user, without the database's reason.
      if (error.code == 'unexpected' && data.containsKey('invite_code')) {
        throw BackendError('invite_invalid');
      }
      throw error;
    }
    final body = _json(r) as Map<String, Object?>;
    if (body['access_token'] is String) {
      await _keep(body);
      return false;
    }
    return true;
  }

  @override
  Future<bool> signUpOwner({
    required String name,
    required String factoryName,
    required String email,
    required String password,
  }) => _signUp(email, password, {
    'name': name.trim(),
    'factory_name': factoryName.trim(),
  });

  @override
  Future<bool> joinAsWorker({
    required String name,
    required String email,
    required String password,
    required String code,
  }) => _signUp(email, password, {
    'name': name.trim(),
    'invite_code': code.trim(),
  });

  @override
  Future<void> recover(String email) async {
    final r = await _send(
      () => _http.post(
        Uri.parse('${config.url}/auth/v1/recover'),
        headers: _anon,
        body: jsonEncode({'email': email.trim()}),
      ),
    );
    if (r.statusCode != 200) throw _authError(r);
  }

  @override
  Future<void> setPassword(String password) async {
    final r = await _send(
      () async => _http.put(
        Uri.parse('${config.url}/auth/v1/user'),
        headers: await _authed(),
        body: jsonEncode({'password': password}),
      ),
    );
    if (r.statusCode != 200) throw _authError(r);
  }

  @override
  Future<void> signOut() async {
    final token = _access;
    if (token != null) {
      try {
        await _http.post(
          Uri.parse('${config.url}/auth/v1/logout'),
          headers: {..._anon, 'Authorization': 'Bearer $token'},
        );
      } on Object {
        // Signed out on the device whatever the network says.
      }
    }
    await _forget();
  }

  @override
  Future<Account?> myAccount() async {
    final rows = await _rpc('my_account') as List<Object?>;
    if (rows.isEmpty) return null;
    return Account.fromJson(rows.first! as Map<String, Object?>);
  }

  // --------------------------------------------------------------- calls

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 30));
    } on BackendError {
      rethrow;
    } on Object {
      throw BackendError('network');
    }
  }

  Object? _json(http.Response r) =>
      r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));

  BackendError _authError(http.Response r) {
    Map<String, Object?> body;
    try {
      body = (_json(r) as Map<String, Object?>?) ?? const {};
    } on Object {
      body = const {};
    }
    final code = '${body['error_code'] ?? body['error'] ?? ''}';
    final said = '${body['msg'] ?? body['error_description'] ?? ''}'
        .toLowerCase();
    if (r.statusCode == 429) return BackendError('rate_limited');
    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' && said.contains('credentials')) {
      return BackendError('invalid_credentials');
    }
    if (code == 'email_not_confirmed' || said.contains('not confirmed')) {
      return BackendError('email_not_confirmed');
    }
    if (code == 'user_already_exists' || said.contains('already registered')) {
      return BackendError('user_already_exists');
    }
    if (code == 'weak_password' || said.contains('password should')) {
      return BackendError('weak_password');
    }
    if (code == 'validation_failed' || said.contains('invalid email')) {
      return BackendError('email_invalid');
    }
    return BackendError('unexpected');
  }

  BackendError _dbError(http.Response r) {
    if (r.statusCode == 401) {
      _ended?.call();
      return BackendError('not_signed_in');
    }
    try {
      final body = _json(r)! as Map<String, Object?>;
      final message = '${body['message'] ?? ''}';
      if (message.startsWith('PF:')) return BackendError(message.substring(3));
      if (body['code'] == '42501') return BackendError('not_owner');
    } on Object {
      // Not the database's own answer.
    }
    return BackendError('unexpected');
  }

  Future<Object?> _rpc(
    String name, [
    Map<String, Object?> params = const {},
  ]) async {
    final r = await _send(
      () async => _http.post(
        Uri.parse('${config.url}/rest/v1/rpc/$name'),
        headers: await _authed(),
        body: jsonEncode(params),
      ),
    );
    if (r.statusCode >= 300) throw _dbError(r);
    return _json(r);
  }

  Future<List<Map<String, Object?>>> _rows(
    String name, [
    Map<String, Object?> params = const {},
  ]) async => [
    for (final row in (await _rpc(name, params) as List<Object?>? ?? const []))
      (row! as Map).cast<String, Object?>(),
  ];

  Future<List<Map<String, Object?>>> _select(String table, String query) async {
    final r = await _send(
      () async => _http.get(
        Uri.parse('${config.url}/rest/v1/$table?$query'),
        headers: await _authed(),
      ),
    );
    if (r.statusCode >= 300) throw _dbError(r);
    return [
      for (final row in _json(r)! as List<Object?>)
        (row! as Map).cast<String, Object?>(),
    ];
  }

  // --------------------------------------------------------------- owner

  @override
  Future<List<Worker>> workers() async => [
    for (final row in await _rows('factory_workers')) Worker.fromJson(row),
  ];

  @override
  Future<List<Invitation>> openInvitations() async => [
    for (final row in await _rows('open_invites')) Invitation.fromJson(row),
  ];

  @override
  Future<InvitationCode> invite({
    required String name,
    required String email,
  }) async {
    final row = (await _rows('invite_worker', {
      'p_name': name,
      'p_email': email,
    })).first;
    return InvitationCode(
      id: '${row['invite_id']}',
      code: '${row['code']}',
      expiresAt: DateTime.tryParse('${row['expires_at']}'),
    );
  }

  @override
  Future<void> revokeInvitation(String id) =>
      _rpc('revoke_invite', {'p_invite': id});

  @override
  Future<void> setWorkerActive(String workerId, {required bool active}) => _rpc(
    'set_worker_status',
    {'p_worker': workerId, 'p_status': active ? 'active' : 'suspended'},
  );

  @override
  Future<List<Assignment>> assignments() async => [
    for (final row in await _rows('factory_assignments'))
      Assignment.fromJson(row),
  ];

  @override
  Future<void> assign(String designId, String workerId) =>
      _rpc('assign_design', {'p_design': designId, 'p_worker': workerId});

  @override
  Future<void> unassign(String designId, String workerId) =>
      _rpc('unassign_design', {'p_design': designId, 'p_worker': workerId});

  @override
  Future<List<WorkRequest>> requests() async => [
    for (final row in await _select(
      'requests',
      'select=*&order=created_at.desc',
    ))
      ?WorkRequest.fromJson(row),
  ];

  @override
  Future<Map<String, Object?>?> requestBase(String requestId) async =>
      (await _rpc('request_base', {'p_request': requestId}) as Map?)
          ?.cast<String, Object?>();

  ({String designId, String customerId}) _made(
    List<Map<String, Object?>> rows,
  ) => (
    designId: '${rows.first['design_id']}',
    customerId: '${rows.first['customer_id']}',
  );

  @override
  Future<({String designId, String customerId})> approveNewDesign(
    String requestId, {
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  }) async => _made(
    await _rows('approve_new_design_request', {
      'p_request': requestId,
      'p_design': design,
      'p_assign': assign,
      'p_note': note,
    }),
  );

  @override
  Future<({String designId, String customerId})> approveNewCustomer(
    String requestId, {
    required Map<String, Object?> customer,
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  }) async => _made(
    await _rows('approve_new_customer_request', {
      'p_request': requestId,
      'p_customer': customer,
      'p_design': design,
      'p_assign': assign,
      'p_note': note,
    }),
  );

  @override
  Future<({int revision, Map<String, Object?> data})> approveChange(
    String requestId, {
    required String note,
  }) async {
    final row = (await _rows('approve_change_request', {
      'p_request': requestId,
      'p_note': note,
    })).first;
    return (
      revision: (row['revision']! as num).toInt(),
      data: (row['data']! as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> reject(String requestId, {required String note}) =>
      _rpc('reject_request', {'p_request': requestId, 'p_note': note});

  @override
  Future<FactoryRecords> records() async {
    Map<String, Kept> of(
      List<Map<String, Object?>> rows,
      String key,
      String value,
    ) => {
      for (final row in rows)
        '${row[key]}': Kept(
          row[value] is String ? row[value]! as String : jsonEncode(row[value]),
          (row['revision']! as num).toInt(),
        ),
    };
    final customers = await _select(
      'customers',
      'select=id,data,revision&deleted_at=is.null',
    );
    final designs = await _select(
      'designs',
      'select=id,data,revision&deleted_at=is.null',
    );
    final documents = await _select(
      'factory_documents',
      'select=key,value,revision',
    );
    return FactoryRecords(
      customers: of(customers, 'id', 'data'),
      designs: of(designs, 'id', 'data'),
      documents: of(documents, 'key', 'value'),
    );
  }

  int _revision(Object? v) => (v! as num).toInt();

  @override
  Future<int> putCustomer(String id, String json, int? expected) async =>
      _revision(
        await _rpc('owner_put_customer', {
          'p_id': id,
          'p_data': jsonDecode(json),
          'p_expected': expected,
        }),
      );

  @override
  Future<int> putDesign(String id, String json, int? expected) async =>
      _revision(
        await _rpc('owner_put_design', {
          'p_id': id,
          'p_data': jsonDecode(json),
          'p_expected': expected,
        }),
      );

  @override
  Future<void> deleteDesign(String id) =>
      _rpc('owner_delete_design', {'p_id': id});

  @override
  Future<void> deleteCustomer(String id) =>
      _rpc('owner_delete_customer', {'p_id': id});

  @override
  Future<int> putDocument(String key, String value, int? expected) async =>
      _revision(
        await _rpc('owner_put_document', {
          'p_key': key,
          'p_value': value,
          'p_expected': expected,
        }),
      );

  @override
  Future<void> deleteDocument(String key) =>
      _rpc('owner_delete_document', {'p_key': key});

  // -------------------------------------------------------------- labour

  @override
  Future<List<AssignedDesign>> myDesigns() async => [
    for (final row in await _rows('my_assigned_designs'))
      AssignedDesign.fromJson(row),
  ];

  @override
  Future<AssignedDesign> assignedDesign(String id) async {
    final rows = await _rows('assigned_design', {'p_id': id});
    if (rows.isEmpty) throw BackendError('not_assigned');
    return AssignedDesign.fromJson(rows.first);
  }

  @override
  Future<List<ScopedCustomer>> myCustomers() async => [
    for (final row in await _rows('my_customers')) ScopedCustomer.fromJson(row),
  ];

  @override
  Future<String> requestNewDesign({
    required String customerId,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  }) async =>
      '${await _rpc('submit_new_design_request', {'p_customer': customerId, 'p_name': name, 'p_category': category, 'p_description': description, 'p_client_key': clientKey})}';

  @override
  Future<String> requestNewCustomer({
    required Map<String, Object?> customer,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  }) async =>
      '${await _rpc('submit_new_customer_request', {'p_customer': customer, 'p_name': name, 'p_category': category, 'p_description': description, 'p_client_key': clientKey})}';

  @override
  Future<String> requestChange({
    required String designId,
    required int baseRevision,
    required Map<String, Object?> proposed,
    required String description,
    required String clientKey,
  }) async =>
      '${await _rpc('submit_change_request', {'p_design': designId, 'p_base_revision': baseRevision, 'p_proposed': proposed, 'p_description': description, 'p_client_key': clientKey})}';

  @override
  Future<void> cancelRequest(String id) =>
      _rpc('cancel_request', {'p_request': id});

  // ---------------------------------------------------------------- both

  @override
  Future<List<AppNotification>> notifications() async => [
    for (final row in await _select(
      'notifications',
      'select=*&order=created_at.desc&limit=100',
    ))
      AppNotification.fromJson(row),
  ];

  @override
  Future<void> markRead(String id) =>
      _rpc('mark_notification_read', {'p_id': id});

  @override
  Future<Map<String, String>> accountNames() async => {
    for (final row in await _select('accounts', 'select=user_id,name'))
      '${row['user_id']}': '${row['name']}',
  };
}

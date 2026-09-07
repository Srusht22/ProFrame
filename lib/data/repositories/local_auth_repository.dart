import '../../domain/auth/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../local/key_value_store.dart';

/// Local/offline auth for the demo build. Checks email/password against a
/// fixed demo credential table (see README → Demo accounts) instead of a
/// real identity provider. Swapping to a backend means replacing [login]'s
/// body with an HTTP call that returns a token — [AuthRepository] and every
/// caller above it stay unchanged.
class LocalAuthRepository implements AuthRepository {
  static const _sessionKey = 'session_user_id';

  final UserRepository userRepository;
  final IKeyValueStore keyValueStore;
  final Map<String, String> demoCredentials;

  /// In-memory-only session used when "remember me" is off, so the session
  /// does not survive an app restart.
  String? _volatileUserId;

  LocalAuthRepository({
    required this.userRepository,
    required this.keyValueStore,
    required this.demoCredentials,
  });

  @override
  Future<AppUser?> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final expectedPassword = demoCredentials[normalizedEmail];
    if (expectedPassword == null || expectedPassword != password) {
      return null;
    }
    final users = await userRepository.getAll();
    AppUser? match;
    for (final u in users) {
      if (u.email.toLowerCase() == normalizedEmail) {
        match = u;
        break;
      }
    }
    if (match == null) return null;

    if (rememberMe) {
      await keyValueStore.write(_sessionKey, match.id);
    } else {
      _volatileUserId = match.id;
    }
    return match;
  }

  @override
  Future<void> logout() async {
    _volatileUserId = null;
    await keyValueStore.delete(_sessionKey);
  }

  @override
  Future<AppUser?> currentUser() async {
    final id = _volatileUserId ?? await keyValueStore.read(_sessionKey);
    if (id == null) return null;
    return userRepository.getById(id);
  }
}

import '../auth/app_user.dart';

/// Session management + credential check. The local implementation checks
/// against seeded demo accounts (see README → Demo accounts); a production
/// backend swap replaces only this class's internals (token issuance,
/// refresh, secure storage) — nothing above this interface changes.
abstract class AuthRepository {
  Future<AppUser?> login({required String email, required String password, bool rememberMe = false});
  Future<void> logout();
  Future<AppUser?> currentUser();
}

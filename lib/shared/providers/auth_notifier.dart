import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/permission.dart';
import '../../domain/entities/audit_log_entry.dart';
import 'audit_log_notifier.dart';

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    return ref.watch(appRepositoriesProvider).auth.currentUser();
  }

  Future<String?> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    final user = await ref.read(appRepositoriesProvider).auth.login(
          email: email,
          password: password,
          rememberMe: rememberMe,
        );
    if (user == null) {
      state = const AsyncData(null);
      return 'Incorrect email or password.';
    }
    state = AsyncData(user);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.login,
          entityType: 'Session',
          entityId: user.id,
          entityLabel: user.fullName,
          actingUser: user,
        );
    return null;
  }

  Future<void> logout() async {
    final user = state.valueOrNull;
    await ref.read(appRepositoriesProvider).auth.logout();
    state = const AsyncData(null);
    if (user != null) {
      await ref.read(auditLogNotifierProvider.notifier).log(
            action: AuditAction.logout,
            entityType: 'Session',
            entityId: user.id,
            entityLabel: user.fullName,
            actingUser: user,
          );
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

/// Synchronous convenience accessor — null while loading/unauthenticated.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authNotifierProvider).valueOrNull;
});

final hasPermissionProvider = Provider.family<bool, Permission>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.can(permission);
});

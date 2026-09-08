import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/permission.dart';

class UserNotifier extends AsyncNotifier<List<AppUser>> {
  @override
  Future<List<AppUser>> build() {
    return ref.watch(appRepositoriesProvider).users.getAll();
  }

  Future<void> updateRole(AppUser user, UserRole role) async {
    final updated = AppUser(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: role,
      avatarInitial: user.avatarInitial,
      isActive: user.isActive,
      createdAt: user.createdAt,
    );
    await ref.read(appRepositoriesProvider).users.save(updated);
    state = AsyncData([
      for (final u in state.value ?? const <AppUser>[])
        if (u.id == user.id) updated else u,
    ]);
  }
}

final userNotifierProvider = AsyncNotifierProvider<UserNotifier, List<AppUser>>(UserNotifier.new);

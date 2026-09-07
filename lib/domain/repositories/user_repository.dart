import '../auth/app_user.dart';

abstract class UserRepository {
  Future<List<AppUser>> getAll();
  Future<AppUser?> getById(String id);
  Future<void> save(AppUser user);
}

import '../entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<Project?> getById(String id);
  Future<void> save(Project project);
  Future<void> delete(String id);
  Future<String> nextProjectNumber();
}

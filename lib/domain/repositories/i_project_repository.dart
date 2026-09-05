import '../configuration/product_configuration.dart';

abstract class IProjectRepository {
  Future<List<ProductConfiguration>> getAllProjects();
  Future<ProductConfiguration?> getProjectById(String id);
  Future<void> saveProject(ProductConfiguration project);
  Future<void> deleteProject(String id);
  Future<ProductConfiguration> duplicateProject(String id, {String? newName});
  Future<List<ProductConfiguration>> getTemplates();
}

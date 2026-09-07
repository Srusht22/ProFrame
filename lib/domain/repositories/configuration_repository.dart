import '../configuration/product_configuration.dart';

abstract class ConfigurationRepository {
  Future<List<ProductConfiguration>> getAll();
  Future<List<ProductConfiguration>> getByProject(String projectId);
  Future<ProductConfiguration?> getById(String id);
  Future<void> save(ProductConfiguration configuration);
  Future<void> delete(String id);
  Future<ProductConfiguration> duplicate(String id);

  /// Saved reusable presets (spec §38 — Project Templates).
  Future<List<ProductConfiguration>> getTemplates();
  Future<void> saveAsTemplate(ProductConfiguration configuration);
}

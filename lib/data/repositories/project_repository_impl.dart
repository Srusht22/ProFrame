import '../../core/utils/id_generator.dart';
import '../../domain/configuration/configuration_options.dart';
import '../../domain/configuration/product_configuration.dart';
import '../../domain/repositories/i_project_repository.dart';
import '../datasources/local_database.dart';

class ProjectRepositoryImpl implements IProjectRepository {
  final LocalDatabase _database;

  ProjectRepositoryImpl({LocalDatabase? database})
      : _database = database ?? LocalDatabase();

  @override
  Future<List<ProductConfiguration>> getAllProjects() async {
    return _database.getProjects();
  }

  @override
  Future<ProductConfiguration?> getProjectById(String id) async {
    final projects = await _database.getProjects();
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProject(ProductConfiguration project) async {
    final projects = await _database.getProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    final updated = project.copyWith(updatedAt: DateTime.now());

    if (index >= 0) {
      projects[index] = updated;
    } else {
      projects.insert(0, updated);
    }

    await _database.saveProjects(projects);
  }

  @override
  Future<void> deleteProject(String id) async {
    final projects = await _database.getProjects();
    projects.removeWhere((p) => p.id == id);
    await _database.saveProjects(projects);
  }

  @override
  Future<ProductConfiguration> duplicateProject(String id, {String? newName}) async {
    final original = await getProjectById(id);
    if (original == null) {
      throw Exception('Project $id not found');
    }

    final now = DateTime.now();
    final duplicate = original.copyWith(
      id: IdGenerator.generate(),
      projectName: newName ?? '${original.projectName} (Copy)',
      createdAt: now,
      updatedAt: now,
    );

    await saveProject(duplicate);
    return duplicate;
  }

  @override
  Future<List<ProductConfiguration>> getTemplates() async {
    final now = DateTime.now();
    return [
      ProductConfiguration(
        id: 'template_sliding_standard',
        projectName: 'Standard 2-Panel Sliding',
        productType: ProductType.window,
        widthMm: 1200,
        heightMm: 1500,
        style: WindowStyle.sliding,
        sections: 2,
        frameColor: FrameColorType.black,
        glassType: GlassType.clear,
        createdAt: now,
        updatedAt: now,
      ),
      ProductConfiguration(
        id: 'template_sliding_large',
        projectName: 'Large 3-Panel Sliding',
        productType: ProductType.window,
        widthMm: 2400,
        heightMm: 1800,
        style: WindowStyle.sliding,
        sections: 3,
        frameColor: FrameColorType.anthraciteGray,
        glassType: GlassType.tintedGray,
        createdAt: now,
        updatedAt: now,
      ),
      ProductConfiguration(
        id: 'template_fixed_panoramic',
        projectName: 'Panoramic Fixed Glass',
        productType: ProductType.window,
        widthMm: 1800,
        heightMm: 1600,
        style: WindowStyle.fixed,
        sections: 1,
        frameColor: FrameColorType.black,
        glassType: GlassType.reflectiveBlue,
        handleType: HandleType.none,
        createdAt: now,
        updatedAt: now,
      ),
      ProductConfiguration(
        id: 'template_casement_bathroom',
        projectName: 'Privacy Casement Window',
        productType: ProductType.window,
        widthMm: 600,
        heightMm: 900,
        style: WindowStyle.casement,
        sections: 1,
        frameColor: FrameColorType.white,
        glassType: GlassType.frostedPrivacy,
        handleType: HandleType.leverHandle,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

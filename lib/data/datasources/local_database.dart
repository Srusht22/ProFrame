import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/configuration/configuration_options.dart';
import '../../domain/configuration/product_configuration.dart';

class LocalDatabase {
  static const String _projectsKey = 'proframe_saved_projects_v1';
  static const String _initializedKey = 'proframe_initialized_seed_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<ProductConfiguration>> getProjects() async {
    final prefs = await _prefs;
    await _ensureSeedData(prefs);

    final rawJson = prefs.getString(_projectsKey);
    if (rawJson == null || rawJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list
          .map((item) => ProductConfiguration.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveProjects(List<ProductConfiguration> projects) async {
    final prefs = await _prefs;
    final jsonList = projects.map((p) => p.toJson()).toList();
    await prefs.setString(_projectsKey, jsonEncode(jsonList));
  }

  Future<void> _ensureSeedData(SharedPreferences prefs) async {
    final isInit = prefs.getBool(_initializedKey) ?? false;
    if (isInit) return;

    final now = DateTime.now();
    final seedProjects = [
      ProductConfiguration(
        id: IdGenerator.generate(),
        projectName: 'Customer Ahmed • Living Room',
        productType: ProductType.window,
        widthMm: 1400.0,
        heightMm: 1600.0,
        depthMm: 50.0,
        style: WindowStyle.sliding,
        sections: 2,
        frameColor: FrameColorType.black,
        glassType: GlassType.clear,
        handleType: HandleType.standardPull,
        handleColor: FrameColorType.black,
        openingDirection: OpeningDirection.left,
        showDimensions: true,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
      ),
      ProductConfiguration(
        id: IdGenerator.generate(),
        projectName: 'Villa Master Bedroom #102',
        productType: ProductType.window,
        widthMm: 2200.0,
        heightMm: 1800.0,
        depthMm: 60.0,
        style: WindowStyle.sliding,
        sections: 3,
        frameColor: FrameColorType.anthraciteGray,
        glassType: GlassType.tintedGray,
        handleType: HandleType.standardPull,
        handleColor: FrameColorType.black,
        openingDirection: OpeningDirection.bothSlide,
        showDimensions: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      ProductConfiguration(
        id: IdGenerator.generate(),
        projectName: 'Office Kitchen Vent Window',
        productType: ProductType.window,
        widthMm: 800.0,
        heightMm: 900.0,
        depthMm: 50.0,
        style: WindowStyle.casement,
        sections: 1,
        frameColor: FrameColorType.white,
        glassType: GlassType.frostedPrivacy,
        handleType: HandleType.leverHandle,
        handleColor: FrameColorType.white,
        openingDirection: OpeningDirection.left,
        showDimensions: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    final jsonList = seedProjects.map((p) => p.toJson()).toList();
    await prefs.setString(_projectsKey, jsonEncode(jsonList));
    await prefs.setBool(_initializedKey, true);
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../configuration/configuration_options.dart';
import '../configuration/product_configuration.dart';
import 'product_definition.dart';
import 'window_definition.dart';

class DoorDefinition extends ProductDefinition {
  const DoorDefinition()
      : super(
          type: ProductType.door,
          title: 'Hinged Door',
          description: 'Single and double leaf aluminum hinged entry and interior doors',
          icon: Icons.door_front_door_rounded,
          isAvailable: true,
        );

  @override
  DimensionRange get widthLimits => const DimensionRange(minMm: 600, maxMm: 2400, defaultMm: 950);
  @override
  DimensionRange get heightLimits => const DimensionRange(minMm: 1800, maxMm: 3000, defaultMm: 2150);
  @override
  DimensionRange get depthLimits => const DimensionRange(minMm: 45, maxMm: 150, defaultMm: 70);
  @override
  int get minSections => 1;
  @override
  int get maxSections => 4;
  @override
  List<WindowStyle> get supportedStyles => [WindowStyle.casement, WindowStyle.doubleHinged];
  @override
  List<FrameColorType> get supportedColors => FrameColorType.values;
  @override
  List<GlassType> get supportedGlassTypes => GlassType.values;
  @override
  List<HandleType> get supportedHandles => [
        HandleType.leverHandle,
        HandleType.modernBar,
        HandleType.lockAndKey,
        HandleType.standardPull,
      ];

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    return ProductConfiguration(
      id: 'door_${DateTime.now().millisecondsSinceEpoch}',
      projectName: projectName.isNotEmpty ? projectName : 'Standard Entry Door',
      productType: ProductType.door,
      widthMm: 950,
      heightMm: 2150,
      depthMm: 70,
      style: WindowStyle.casement,
      sections: 1,
      frameColor: FrameColorType.anthraciteGray,
      glassType: GlassType.clear,
      handleType: HandleType.leverHandle,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String? validate(ProductConfiguration config) {
    if (config.widthMm < widthLimits.minMm || config.widthMm > widthLimits.maxMm) {
      return 'Width must be between ${widthLimits.minMm.toInt()} and ${widthLimits.maxMm.toInt()} mm';
    }
    if (config.heightMm < heightLimits.minMm || config.heightMm > heightLimits.maxMm) {
      return 'Height must be between ${heightLimits.minMm.toInt()} and ${heightLimits.maxMm.toInt()} mm';
    }
    return null;
  }
}

class SlidingDoorDefinition extends ProductDefinition {
  const SlidingDoorDefinition()
      : super(
          type: ProductType.slidingDoor,
          title: 'Sliding Patio Door',
          description: 'Multi-panel patio and pocket heavy duty sliding glass doors',
          icon: Icons.sensor_door_rounded,
          isAvailable: true,
        );

  @override
  DimensionRange get widthLimits => const DimensionRange(minMm: 1400, maxMm: 6000, defaultMm: 2400);
  @override
  DimensionRange get heightLimits => const DimensionRange(minMm: 1900, maxMm: 3200, defaultMm: 2200);
  @override
  DimensionRange get depthLimits => const DimensionRange(minMm: 60, maxMm: 160, defaultMm: 85);
  @override
  int get minSections => 2;
  @override
  int get maxSections => 6;
  @override
  List<WindowStyle> get supportedStyles => [WindowStyle.sliding, WindowStyle.bifold];
  @override
  List<FrameColorType> get supportedColors => FrameColorType.values;
  @override
  List<GlassType> get supportedGlassTypes => GlassType.values;
  @override
  List<HandleType> get supportedHandles => [
        HandleType.flushLatch,
        HandleType.modernBar,
        HandleType.standardPull,
        HandleType.lockAndKey,
      ];

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    return ProductConfiguration(
      id: 'slider_${DateTime.now().millisecondsSinceEpoch}',
      projectName: projectName.isNotEmpty ? projectName : 'Patio Sliding Door',
      productType: ProductType.slidingDoor,
      widthMm: 2400,
      heightMm: 2200,
      depthMm: 85,
      style: WindowStyle.sliding,
      sections: 2,
      frameColor: FrameColorType.black,
      glassType: GlassType.reflectiveBlue,
      handleType: HandleType.flushLatch,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String? validate(ProductConfiguration config) {
    if (config.widthMm < widthLimits.minMm || config.widthMm > widthLimits.maxMm) {
      return 'Width must be between ${widthLimits.minMm.toInt()} and ${widthLimits.maxMm.toInt()} mm';
    }
    if (config.heightMm < heightLimits.minMm || config.heightMm > heightLimits.maxMm) {
      return 'Height must be between ${heightLimits.minMm.toInt()} and ${heightLimits.maxMm.toInt()} mm';
    }
    return null;
  }
}

class PartitionDefinition extends ProductDefinition {
  const PartitionDefinition()
      : super(
          type: ProductType.partition,
          title: 'Glass Partition / Wall',
          description: 'Floor-to-ceiling office walls and architectural glass dividers',
          icon: Icons.grid_view_rounded,
          isAvailable: true,
        );

  @override
  DimensionRange get widthLimits => const DimensionRange(minMm: 1000, maxMm: 10000, defaultMm: 3000);
  @override
  DimensionRange get heightLimits => const DimensionRange(minMm: 1800, maxMm: 4000, defaultMm: 2600);
  @override
  DimensionRange get depthLimits => const DimensionRange(minMm: 40, maxMm: 120, defaultMm: 50);
  @override
  int get minSections => 1;
  @override
  int get maxSections => 10;
  @override
  List<WindowStyle> get supportedStyles => [WindowStyle.fixed, WindowStyle.casement, WindowStyle.sliding];
  @override
  List<FrameColorType> get supportedColors => FrameColorType.values;
  @override
  List<GlassType> get supportedGlassTypes => GlassType.values;
  @override
  List<HandleType> get supportedHandles => [HandleType.none, HandleType.leverHandle, HandleType.modernBar];

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    return ProductConfiguration(
      id: 'part_${DateTime.now().millisecondsSinceEpoch}',
      projectName: projectName.isNotEmpty ? projectName : 'Office Glass Wall',
      productType: ProductType.partition,
      widthMm: 3000,
      heightMm: 2600,
      depthMm: 50,
      style: WindowStyle.fixed,
      sections: 3,
      frameColor: FrameColorType.black,
      glassType: GlassType.clear,
      handleType: HandleType.none,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String? validate(ProductConfiguration config) => null;
}

class CabinetDefinition extends ProductDefinition {
  const CabinetDefinition()
      : super(
          type: ProductType.cabinet,
          title: 'Display Cabinet',
          description: 'Industrial aluminum and glass cabinetry and storage units',
          icon: Icons.kitchen_rounded,
          isAvailable: true,
        );

  @override
  DimensionRange get widthLimits => const DimensionRange(minMm: 400, maxMm: 3000, defaultMm: 1200);
  @override
  DimensionRange get heightLimits => const DimensionRange(minMm: 400, maxMm: 2400, defaultMm: 1400);
  @override
  DimensionRange get depthLimits => const DimensionRange(minMm: 150, maxMm: 600, defaultMm: 350);
  @override
  int get minSections => 1;
  @override
  int get maxSections => 6;
  @override
  List<WindowStyle> get supportedStyles => [WindowStyle.casement, WindowStyle.sliding];
  @override
  List<FrameColorType> get supportedColors => FrameColorType.values;
  @override
  List<GlassType> get supportedGlassTypes => GlassType.values;
  @override
  List<HandleType> get supportedHandles => [HandleType.standardPull, HandleType.flushLatch];

  @override
  ProductConfiguration createDefaultConfiguration(String projectName) {
    return ProductConfiguration(
      id: 'cab_${DateTime.now().millisecondsSinceEpoch}',
      projectName: projectName.isNotEmpty ? projectName : 'Storage Cabinet',
      productType: ProductType.cabinet,
      widthMm: 1200,
      heightMm: 1400,
      depthMm: 350,
      style: WindowStyle.casement,
      sections: 2,
      frameColor: FrameColorType.anodizedSilver,
      glassType: GlassType.frostedPrivacy,
      handleType: HandleType.standardPull,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  String? validate(ProductConfiguration config) => null;
}

class ProductRegistry {
  static const _customTypesPrefsKey = 'proframe_custom_product_types';

  static final Map<String, ProductDefinition> _registry = {
    ProductType.window.id: const WindowDefinition(),
    ProductType.door.id: const DoorDefinition(),
    ProductType.slidingDoor.id: const SlidingDoorDefinition(),
    ProductType.partition.id: const PartitionDefinition(),
    ProductType.cabinet.id: const CabinetDefinition(),
  };

  static List<ProductDefinition> getAll() => _registry.values.toList();

  static ProductDefinition get(ProductType type) {
    return _registry[type.id] ??
        CustomProductDefinition(
          type: type,
          title: type.label,
          description: type.description,
          icon: Icons.category_rounded,
        );
  }

  static void register(ProductDefinition definition) {
    _registry[definition.type.id] = definition;
    _saveCustomTypes();
  }

  static void unregister(String typeId) {
    _registry.remove(typeId);
    _saveCustomTypes();
  }

  static Future<void> loadCustomTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customTypesPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final type = ProductType.fromJson(item);
            final def = CustomProductDefinition(
              type: type,
              title: type.label,
              description: type.description,
              icon: Icons.category_rounded,
              widthLimits: DimensionRange(
                minMm: (item['minWidth'] as num?)?.toDouble() ?? 300,
                maxMm: (item['maxWidth'] as num?)?.toDouble() ?? 6000,
                defaultMm: (item['defaultWidth'] as num?)?.toDouble() ?? 1200,
              ),
              heightLimits: DimensionRange(
                minMm: (item['minHeight'] as num?)?.toDouble() ?? 300,
                maxMm: (item['maxHeight'] as num?)?.toDouble() ?? 4000,
                defaultMm: (item['defaultHeight'] as num?)?.toDouble() ?? 1500,
              ),
              minSections: (item['minSections'] as num?)?.toInt() ?? 1,
              maxSections: (item['maxSections'] as num?)?.toInt() ?? 10,
            );
            _registry[type.id] = def;
          }
        }
      }
    } catch (e) {
      debugPrint('[ProductRegistry] Error loading custom types: $e');
    }
  }

  static Future<void> _saveCustomTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customDefs = _registry.values.where((d) => d.type.isCustom).map((d) {
        return {
          'id': d.type.id,
          'label': d.type.label,
          'icon': d.type.icon,
          'description': d.type.description,
          'isCustom': true,
          'minWidth': d.widthLimits.minMm,
          'maxWidth': d.widthLimits.maxMm,
          'defaultWidth': d.widthLimits.defaultMm,
          'minHeight': d.heightLimits.minMm,
          'maxHeight': d.heightLimits.maxMm,
          'defaultHeight': d.heightLimits.defaultMm,
          'minSections': d.minSections,
          'maxSections': d.maxSections,
        };
      }).toList();
      await prefs.setString(_customTypesPrefsKey, jsonEncode(customDefs));
    } catch (e) {
      debugPrint('[ProductRegistry] Error saving custom types: $e');
    }
  }
}

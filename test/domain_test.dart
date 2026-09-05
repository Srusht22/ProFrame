import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/units/unit_converter.dart';
import 'package:proframe/domain/configuration/configuration_options.dart';
import 'package:proframe/domain/configuration/product_configuration.dart';
import 'package:proframe/domain/products/product_definition.dart';
import 'package:proframe/domain/products/product_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('UnitConverter Tests', () {
    test('Converts canonical mm to other units accurately', () {
      expect(LengthUnit.mm.fromCanonicalMm(1200.0), 1200.0);
      expect(LengthUnit.cm.fromCanonicalMm(1200.0), 120.0);
      expect(LengthUnit.meter.fromCanonicalMm(1200.0), 1.2);
      expect(LengthUnit.inch.fromCanonicalMm(25.4), 1.0);
    });

    test('Converts units back to canonical mm', () {
      expect(LengthUnit.cm.toCanonicalMm(120.0), 1200.0);
      expect(LengthUnit.meter.toCanonicalMm(1.5), 1500.0);
      expect(LengthUnit.inch.toCanonicalMm(10.0), 254.0);
    });

    test('Formats dimensions correctly', () {
      expect(LengthUnit.mm.format(1200.0), '1200 mm');
      expect(LengthUnit.cm.format(1200.0), '120 cm');
      expect(LengthUnit.meter.format(1200.0), '1.20 m');
      expect(LengthUnit.inch.format(254.0), '10.0 in');
    });
  });

  group('ProductConfiguration Serialization Tests', () {
    final now = DateTime.now();
    final config = ProductConfiguration(
      id: 'test-win-101',
      projectName: 'Master Bedroom Slider',
      productType: ProductType.window,
      widthMm: 1500,
      heightMm: 1200,
      depthMm: 70,
      style: WindowStyle.sliding,
      sections: 3,
      frameColor: FrameColorType.anthraciteGray,
      glassType: GlassType.tintedGray,
      handleType: HandleType.flushLatch,
      handleColor: FrameColorType.black,
      openingDirection: OpeningDirection.left,
      showDimensions: true,
      notes: 'Heavy duty soundproof glass',
      createdAt: now,
      updatedAt: now,
    );

    test('Serializes to JSON and deserializes back without data loss', () {
      final json = config.toJson();
      final restored = ProductConfiguration.fromJson(json);

      expect(restored.id, config.id);
      expect(restored.projectName, config.projectName);
      expect(restored.productType, ProductType.window);
      expect(restored.widthMm, 1500);
      expect(restored.heightMm, 1200);
      expect(restored.sections, 3);
      expect(restored.style, WindowStyle.sliding);
      expect(restored.frameColor, FrameColorType.anthraciteGray);
      expect(restored.glassType, GlassType.tintedGray);
      expect(restored.handleType, HandleType.flushLatch);
      expect(restored.showDimensions, isTrue);
      expect(restored.notes, 'Heavy duty soundproof glass');
    });

    test('Generates correct 3D engine params payload', () {
      final params = config.to3DParams();
      expect(params['productType'], 'window');
      expect(params['width'], 1500);
      expect(params['height'], 1200);
      expect(params['sections'], 3);
      expect(params['style'], 'sliding');
      expect(params['frameColor'], 'anthraciteGray');
      expect(params['glassType'], 'tintedGray');
      expect(params['handleType'], 'flushLatch');
    });

    test('Formatted dimensions string is correct', () {
      expect(config.formattedDimensions(), '1500 mm × 1200 mm');
      expect(config.formattedDimensions(LengthUnit.meter), '1.50 m × 1.20 m');
    });
  });

  group('Dynamic & Unlimited Product Types Tests', () {
    test('Can register and look up custom product types at runtime', () {
      const customType = ProductType(
        id: 'balustrade_101',
        label: 'Glass Balustrade',
        icon: '🪜',
        description: 'Frameless glass balcony railing',
        isCustom: true,
      );

      const def = CustomProductDefinition(
        type: customType,
        title: 'Glass Balustrade',
        description: 'Frameless glass balcony railing',
        icon: Icons.stairs_rounded,
        widthLimits: DimensionRange(minMm: 800, maxMm: 8000, defaultMm: 2000),
        heightLimits: DimensionRange(minMm: 900, maxMm: 1400, defaultMm: 1100),
      );

      ProductRegistry.register(def);

      final retrieved = ProductRegistry.get(customType);
      expect(retrieved.title, 'Glass Balustrade');
      expect(retrieved.widthLimits.minMm, 800);
      expect(retrieved.heightLimits.maxMm, 1400);

      final newConfig = retrieved.createDefaultConfiguration('Balcony Railing #1');
      expect(newConfig.productType.id, 'balustrade_101');
      expect(newConfig.widthMm, 2000);
      expect(newConfig.heightMm, 1100);

      final json = newConfig.toJson();
      final restored = ProductConfiguration.fromJson(json);
      expect(restored.productType.id, 'balustrade_101');
      expect(restored.productType.isCustom, isTrue);
    });

    test('Validates custom dimension boundaries', () {
      const customType = ProductType(
        id: 'skylight_99',
        label: 'Skylight',
        icon: '☀️',
        description: 'Roof glass hatch',
        isCustom: true,
      );

      const def = CustomProductDefinition(
        type: customType,
        title: 'Skylight',
        description: 'Roof glass hatch',
        icon: Icons.wb_sunny_rounded,
        widthLimits: DimensionRange(minMm: 600, maxMm: 2000, defaultMm: 1000),
        heightLimits: DimensionRange(minMm: 600, maxMm: 2000, defaultMm: 1000),
      );

      final validConfig = def.createDefaultConfiguration('Roof Hatch');
      expect(def.validate(validConfig), isNull);

      final invalidWidth = validConfig.copyWith(widthMm: 2500);
      expect(def.validate(invalidWidth), isNotNull);
    });
  });
}

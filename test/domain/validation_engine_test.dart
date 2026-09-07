import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/configuration/config_enums.dart';
import 'package:proframe/domain/configuration/configuration_value_objects.dart';
import 'package:proframe/domain/configuration/dimension_limits.dart';
import 'package:proframe/domain/configuration/product_configuration.dart';
import 'package:proframe/domain/services/validation_engine.dart';

void main() {
  const engine = ValidationEngine();

  ProductConfiguration baseDoor({
    double? widthMm,
    double? heightMm,
    DoorType doorType = DoorType.exterior,
  }) {
    final now = DateTime.now();
    final limits = ProductLimits.forDoor(doorType);
    return ProductConfiguration(
      id: 'validation-test',
      name: 'Validation test door',
      category: ProductCategory.door,
      doorType: doorType,
      widthMm: widthMm ?? limits.width.defaultMm,
      heightMm: heightMm ?? limits.height.defaultMm,
      wallOpeningWidthMm: (widthMm ?? limits.width.defaultMm) + 20,
      wallOpeningHeightMm: (heightMm ?? limits.height.defaultMm) + 20,
      frame: FrameSpec(frameDepthMm: limits.frameDepth.defaultMm),
      hardware: const HardwareSpec(lockType: LockType.standardCylinder),
      createdAt: now,
      updatedAt: now,
    );
  }

  group('dimension range rule', () {
    test('accepts a width/height within the product type limits', () {
      final result = engine.validate(baseDoor());
      expect(result.errors, isEmpty);
    });

    test('rejects a width below the minimum for the product type', () {
      final limits = ProductLimits.forDoor(DoorType.exterior);
      final result = engine.validate(baseDoor(widthMm: limits.width.minMm - 50));
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'widthMm'), isTrue);
    });

    test('rejects a height above the maximum for the product type', () {
      final limits = ProductLimits.forDoor(DoorType.exterior);
      final result = engine.validate(baseDoor(heightMm: limits.height.maxMm + 500));
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'heightMm'), isTrue);
    });
  });

  group('wall opening rule', () {
    test('errors when the wall opening is smaller than the unit', () {
      final now = DateTime.now();
      final config = baseDoor().copyWith(wallOpeningWidthMm: 500, createdAt: now, updatedAt: now);
      final result = engine.validate(config);
      expect(result.errors.any((e) => e.field == 'wallOpeningWidthMm'), isTrue);
    });
  });

  group('glass thickness rule', () {
    test('rejects tempered glass thinner than the minimum', () {
      final now = DateTime.now();
      final config = baseDoor().copyWith(
        glass: const GlassSpec(type: GlassType.tempered, thicknessMm: 3),
        createdAt: now,
        updatedAt: now,
      );
      final result = engine.validate(config);
      expect(result.errors.any((e) => e.field == 'glass.thicknessMm'), isTrue);
    });

    test('accepts tempered glass at or above the minimum', () {
      final now = DateTime.now();
      final config = baseDoor().copyWith(
        glass: const GlassSpec(type: GlassType.tempered, thicknessMm: 6),
        createdAt: now,
        updatedAt: now,
      );
      final result = engine.validate(config);
      expect(result.errors.any((e) => e.field == 'glass.thicknessMm'), isFalse);
    });
  });

  group('glazing pane consistency rule', () {
    test('double glazed requires exactly 2 panes', () {
      final now = DateTime.now();
      final config = baseDoor().copyWith(
        glass: const GlassSpec(type: GlassType.doubleGlazed, thicknessMm: 20, panesCount: 1),
        createdAt: now,
        updatedAt: now,
      );
      final result = engine.validate(config);
      expect(result.errors.any((e) => e.field == 'glass.panesCount'), isTrue);
    });
  });

  group('door security hardware rule (warning, not error)', () {
    test('an exterior door without a lock is a warning', () {
      final now = DateTime.now();
      final config = baseDoor().copyWith(
        hardware: const HardwareSpec(lockType: LockType.none),
        createdAt: now,
        updatedAt: now,
      );
      final result = engine.validate(config);
      expect(result.warnings.any((w) => w.field == 'hardware.lockType'), isTrue);
      // A missing lock should never block saving/quoting on its own.
      expect(result.errors.any((e) => e.field == 'hardware.lockType'), isFalse);
    });
  });

  group('section width physical rule', () {
    test('rejects too many sections for a narrow window', () {
      final now = DateTime.now();
      final window = ProductConfiguration(
        id: 'w-narrow',
        name: 'Narrow window',
        category: ProductCategory.window,
        windowType: WindowType.sliding,
        widthMm: 700,
        heightMm: 1200,
        wallOpeningWidthMm: 720,
        wallOpeningHeightMm: 1220,
        sections: 6,
        createdAt: now,
        updatedAt: now,
      );
      final result = engine.validate(window);
      expect(result.errors.any((e) => e.field == 'sections'), isTrue);
    });
  });
}

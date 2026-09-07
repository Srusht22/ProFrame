import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/configuration/config_enums.dart';
import 'package:proframe/domain/configuration/configuration_value_objects.dart';
import 'package:proframe/domain/configuration/product_configuration.dart';
import 'package:proframe/domain/pricing/pricing_rules.dart';
import 'package:proframe/domain/services/manufacturing_engine.dart';

void main() {
  const engine = ManufacturingEngine();

  ProductConfiguration door1000x2100({int sections = 1}) {
    final now = DateTime.now();
    return ProductConfiguration(
      id: 'd1',
      name: 'Test door',
      category: ProductCategory.door,
      doorType: DoorType.exterior,
      widthMm: 1000,
      heightMm: 2100,
      frame: const FrameSpec(frameThicknessMm: 45),
      leaf: const LeafSpec(),
      panel: const PanelSpec(type: PanelType.glass),
      hardware: const HardwareSpec(hingeCount: 3),
      sections: sections,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('generateCuttingList', () {
    test('head/sill match width, jambs match height', () {
      final lines = engine.generateCuttingList(door1000x2100());

      final head = lines.firstWhere((l) => l.component == 'Outer Frame — Head');
      expect(head.lengthMm, 1000);
      expect(head.quantity, 1);

      final jamb = lines.firstWhere((l) => l.component == 'Outer Frame — Jamb');
      expect(jamb.lengthMm, 2100);
      expect(jamb.quantity, 2);
    });

    test('a door never produces a mullion line even with a stray sections value', () {
      final lines = engine.generateCuttingList(door1000x2100(sections: 4));
      expect(lines.where((l) => l.component.contains('Mullion')), isEmpty);
    });

    test('window sections produce exactly sections-1 mullions', () {
      final now = DateTime.now();
      final window = ProductConfiguration(
        id: 'w1',
        name: 'Test window',
        category: ProductCategory.window,
        windowType: WindowType.sliding,
        widthMm: 1800,
        heightMm: 1200,
        sections: 3,
        createdAt: now,
        updatedAt: now,
      );
      final lines = engine.generateCuttingList(window);
      final mullion = lines.firstWhere((l) => l.component == 'Mullion (vertical)');
      expect(mullion.quantity, 2);
      expect(mullion.lengthMm, 1200);
    });

    test('threshold and door jamb lines only appear when configured', () {
      final now = DateTime.now();
      final withExtras = door1000x2100().copyWith(
        frame: const FrameSpec(hasThreshold: true, hasDoorJamb: true),
        createdAt: now,
        updatedAt: now,
      );
      final lines = engine.generateCuttingList(withExtras);
      expect(lines.any((l) => l.component == 'Threshold'), isTrue);
      expect(lines.any((l) => l.component == 'Door Jamb'), isTrue);

      final withoutExtras = engine.generateCuttingList(door1000x2100());
      expect(withoutExtras.any((l) => l.component == 'Threshold'), isFalse);
      expect(withoutExtras.any((l) => l.component == 'Door Jamb'), isFalse);
    });
  });

  group('generateBom', () {
    const rules = PricingRules();

    test('frame BOM quantity matches the perimeter in meters', () {
      final bom = engine.generateBom(door1000x2100(), rules);
      final frameLine = bom.firstWhere((l) => l.partNumber.startsWith('FRM-'));
      // perimeter = 2*(1.0 + 2.1) = 6.2 m
      expect(frameLine.quantity, closeTo(6.2, 1e-9));
      expect(frameLine.totalPrice, closeTo(frameLine.quantity * frameLine.unitPrice, 1e-9));
    });

    test('hinge line quantity matches the configured hinge count', () {
      final bom = engine.generateBom(door1000x2100(), rules);
      final hinges = bom.firstWhere((l) => l.partNumber == 'HNG-STD');
      expect(hinges.quantity, 3);
    });

    test('lock/closer lines are omitted when set to none', () {
      final now = DateTime.now();
      final config = door1000x2100().copyWith(
        hardware: const HardwareSpec(lockType: LockType.none, doorCloser: DoorCloserType.none),
        createdAt: now,
        updatedAt: now,
      );
      final bom = engine.generateBom(config, rules);
      expect(bom.any((l) => l.partNumber.startsWith('LCK-')), isFalse);
      expect(bom.any((l) => l.partNumber.startsWith('CLS-')), isFalse);
    });
  });
}

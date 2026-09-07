import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/configuration/config_enums.dart';
import 'package:proframe/domain/configuration/configuration_value_objects.dart';
import 'package:proframe/domain/configuration/product_configuration.dart';
import 'package:proframe/domain/pricing/pricing_rules.dart';
import 'package:proframe/domain/services/pricing_engine.dart';

ProductConfiguration _window({
  double widthMm = 1000,
  double heightMm = 1000,
  int sections = 1,
  int quantity = 1,
  FrameMaterial material = FrameMaterial.aluminum,
  GlassType glassType = GlassType.clear,
  FrameColor frameColor = FrameColor.black,
  bool weatherSealing = false,
}) {
  final now = DateTime.now();
  return ProductConfiguration(
    id: 'test',
    name: 'Test window',
    category: ProductCategory.window,
    windowType: WindowType.fixed,
    widthMm: widthMm,
    heightMm: heightMm,
    quantity: quantity,
    frame: FrameSpec(material: material),
    panel: const PanelSpec(type: PanelType.glass),
    glass: GlassSpec(type: glassType),
    hardware: const HardwareSpec(hingeCount: 0, handleModel: HandleModel.none, lockType: LockType.none),
    finish: FinishSpec(frameColor: frameColor),
    accessories: AccessoryOptions(weatherSealing: weatherSealing),
    sections: sections,
    createdAt: now,
    updatedAt: now,
  );
}

/// A pricing table with every multiplier zeroed except the base material
/// rates, so the arithmetic is trivial to verify by hand.
const _zeroedRules = PricingRules(
  framePricePerMeter: {
    FrameMaterial.aluminum: 10.0,
    FrameMaterial.upvc: 10.0,
    FrameMaterial.wood: 10.0,
    FrameMaterial.steel: 10.0,
  },
  glassPricePerSqm: {
    GlassType.clear: 20.0,
    GlassType.frosted: 20.0,
    GlassType.tinted: 20.0,
    GlassType.tempered: 20.0,
    GlassType.laminated: 20.0,
    GlassType.doubleGlazed: 20.0,
    GlassType.tripleGlazed: 20.0,
    GlassType.custom: 20.0,
  },
  panelPricePerSqm: {PanelType.solid: 20.0, PanelType.glass: 20.0, PanelType.decorative: 20.0},
  hingePriceEach: 1.0,
  handleBasePrice: 5.0,
  lockPrice: {
    LockType.none: 0,
    LockType.standardCylinder: 0,
    LockType.multiPointLock: 0,
    LockType.mortiseKeyLock: 0,
    LockType.smartLock: 0,
  },
  doorCloserPrice: {
    DoorCloserType.none: 0,
    DoorCloserType.standard: 0,
    DoorCloserType.concealed: 0,
    DoorCloserType.floorSpring: 0,
  },
  accessoryFlatPrice: 0,
  mosquitoNetPricePerSqm: 0,
  sealPricePerMeter: 0,
  laborMode: LaborMode.percentageOfMaterials,
  laborPercent: 0,
  finishMultiplier: {
    FrameColor.white: 1.0,
    FrameColor.black: 1.0,
    FrameColor.darkGreen: 1.0,
    FrameColor.woodFinish: 1.0,
    FrameColor.anthracite: 1.0,
    FrameColor.silver: 1.0,
    FrameColor.bronze: 1.0,
    FrameColor.custom: 1.0,
  },
  wastePercent: 0,
  overheadPercent: 0,
  profitPercent: 0,
);

void main() {
  group('PricingEngine — zeroed rules (exact arithmetic)', () {
    test('unit price is exactly frame + glass materials with every multiplier off', () {
      // 1m x 1m window: perimeter = 2*(1+1) = 4m @ $10/m = $40 frame.
      // Area = 1 m² @ $20/m² = $20 glass. No hardware/accessories/labor/waste/
      // overhead/profit -> unit price should be exactly $60.
      final config = _window(widthMm: 1000, heightMm: 1000);
      final breakdown = const PricingEngine(_zeroedRules).calculate(config);

      expect(breakdown.materialsSubtotal, closeTo(60.0, 1e-9));
      expect(breakdown.labor, 0);
      expect(breakdown.finishing, 0);
      expect(breakdown.waste, 0);
      expect(breakdown.overhead, 0);
      expect(breakdown.profit, 0);
      expect(breakdown.unitPrice, closeTo(60.0, 1e-9));
      expect(breakdown.lineTotal, closeTo(60.0, 1e-9));
    });

    test('line total multiplies the unit price by quantity', () {
      final config = _window(widthMm: 1000, heightMm: 1000, quantity: 3);
      final breakdown = const PricingEngine(_zeroedRules).calculate(config);

      expect(breakdown.unitPrice, closeTo(60.0, 1e-9));
      expect(breakdown.lineTotal, closeTo(180.0, 1e-9));
    });

    test('profit percent is applied on top of the cost subtotal', () {
      final rules = _zeroedRules.copyWith(profitPercent: 0.5);
      final config = _window(widthMm: 1000, heightMm: 1000);
      final breakdown = PricingEngine(rules).calculate(config);

      expect(breakdown.subtotal, closeTo(60.0, 1e-9));
      expect(breakdown.profit, closeTo(30.0, 1e-9));
      expect(breakdown.unitPrice, closeTo(90.0, 1e-9));
    });

    test('waste percent compounds on materials + labor + finishing only', () {
      final rules = _zeroedRules.copyWith(wastePercent: 0.1);
      final config = _window(widthMm: 1000, heightMm: 1000);
      final breakdown = PricingEngine(rules).calculate(config);

      expect(breakdown.waste, closeTo(6.0, 1e-9)); // 60 * 0.1
      expect(breakdown.unitPrice, closeTo(66.0, 1e-9));
    });

    test('overhead percent is applied after waste is added', () {
      final rules = _zeroedRules.copyWith(wastePercent: 0.1, overheadPercent: 0.1);
      final config = _window(widthMm: 1000, heightMm: 1000);
      final breakdown = PricingEngine(rules).calculate(config);

      // materialsLaborFinishing = 60, waste = 6 -> overhead = (60+6)*0.1 = 6.6
      expect(breakdown.overhead, closeTo(6.6, 1e-9));
      expect(breakdown.subtotal, closeTo(72.6, 1e-9));
    });

    test('frame cost scales linearly with perimeter', () {
      final small = const PricingEngine(_zeroedRules).calculate(_window(widthMm: 1000, heightMm: 1000));
      final large = const PricingEngine(_zeroedRules).calculate(_window(widthMm: 2000, heightMm: 1000));

      // Perimeter grows from 4m to 6m -> frame cost from $40 to $60; glass
      // area grows from 1m² to 2m² -> glass cost from $20 to $40.
      expect(large.materialsSubtotal - small.materialsSubtotal, closeTo(40.0, 1e-9));
    });

    test('sections only add mullion cost for windows, never for doors', () {
      final windowRules = _zeroedRules.copyWith(framePricePerMeter: {
        for (final m in FrameMaterial.values) m: 10.0,
      });

      final windowConfig = _window(widthMm: 1000, heightMm: 1000, sections: 3);
      final windowBreakdown = PricingEngine(windowRules).calculate(windowConfig);

      final now = DateTime.now();
      final doorConfig = ProductConfiguration(
        id: 'door-sections-test',
        name: 'Door with stray sections value',
        category: ProductCategory.door,
        doorType: DoorType.interior,
        widthMm: 1000,
        heightMm: 1000,
        frame: const FrameSpec(material: FrameMaterial.aluminum),
        panel: const PanelSpec(type: PanelType.glass),
        glass: const GlassSpec(),
        hardware: const HardwareSpec(hingeCount: 0, handleModel: HandleModel.none, lockType: LockType.none),
        // A door should never price mullions even if `sections` was left at
        // a stale non-1 value — only ProductCategory.window does.
        sections: 3,
        createdAt: now,
        updatedAt: now,
      );
      final doorBreakdown = PricingEngine(windowRules).calculate(doorConfig);

      // Window: perimeter 4m + 2 mullions * 1m height = 6m of frame.
      final windowFrameLine = windowBreakdown.materialLines.firstWhere((l) => l.label == 'Frame');
      expect(windowFrameLine.amount, closeTo(60.0, 1e-9)); // 6m * $10

      // Door: perimeter alone, no mullions added despite sections=3.
      final doorFrameLine = doorBreakdown.materialLines.firstWhere((l) => l.label == 'Frame');
      expect(doorFrameLine.amount, closeTo(40.0, 1e-9)); // 4m * $10
    });
  });

  group('PricingEngine — default (placeholder) rules', () {
    test('produces a positive, itemized breakdown for a realistic door', () {
      final now = DateTime.now();
      final config = ProductConfiguration(
        id: 'door-1',
        name: 'Entry door',
        category: ProductCategory.door,
        doorType: DoorType.exterior,
        widthMm: 1000,
        heightMm: 2100,
        wallOpeningWidthMm: 1020,
        wallOpeningHeightMm: 2120,
        frame: const FrameSpec(),
        leaf: const LeafSpec(),
        panel: const PanelSpec(type: PanelType.glass),
        glass: const GlassSpec(),
        hardware: const HardwareSpec(),
        finish: const FinishSpec(),
        createdAt: now,
        updatedAt: now,
      );
      final breakdown = const PricingEngine(PricingRules()).calculate(config);

      expect(breakdown.materialLines, isNotEmpty);
      expect(breakdown.materialsSubtotal, greaterThan(0));
      expect(breakdown.unitPrice, greaterThan(breakdown.subtotal)); // profit > 0
      expect(breakdown.subtotal, greaterThan(breakdown.materialsSubtotal)); // labor+waste+overhead > 0
      // Every material line amount should sum to the reported subtotal.
      final sumOfLines = breakdown.materialLines.fold<double>(0, (s, l) => s + l.amount);
      expect(sumOfLines, closeTo(breakdown.materialsSubtotal, 1e-6));
    });
  });
}

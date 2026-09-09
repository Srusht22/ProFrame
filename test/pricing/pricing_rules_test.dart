import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/pricing/pricing_engine.dart';
import 'package:proframe/features/pricing/pricing_rules.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/shared/models/design_region.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';

OpeningModel window() => OpeningModel(
      id: 'w',
      kind: OpeningKind.window,
      widthMm: 1500,
      heightMm: 1400,
      regions: [DesignRegion(id: 'c0', rect: Box2.fromLTWH(0, 0, 1500, 1400))],
    );

void main() {
  group('rates are editable and survive a save', () {
    test('one rate can be changed without disturbing the others', () {
      const rules = PricingRules();
      final edited = rules.withFrameRate(FrameMaterial.aluminium, 21.5);

      expect(edited.framePerMetre[FrameMaterial.aluminium], 21.5);
      expect(edited.framePerMetre[FrameMaterial.upvc],
          rules.framePerMetre[FrameMaterial.upvc]);
      expect(edited.sashPerMetre, rules.sashPerMetre);
    });

    test('a full round-trip through JSON keeps every rate', () {
      final rules = const PricingRules(currencySymbol: '€')
          .withFrameRate(FrameMaterial.steel, 33.0)
          .withGlassRate(GlassType.lowE, 88.5)
          .withPanelRate(PanelMaterial.mdf, 41.0)
          .copyWith(hingeEach: 6.75, wasteRate: 0.12);

      final restored = PricingRules.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(rules.toJson())) as Map),
      );

      expect(restored.currencySymbol, '€');
      expect(restored.framePerMetre[FrameMaterial.steel], 33.0);
      expect(restored.glassPerSquareMetre[GlassType.lowE], 88.5);
      expect(restored.panelPerSquareMetre[PanelMaterial.mdf], 41.0);
      expect(restored.hingeEach, 6.75);
      expect(restored.wasteRate, 0.12);
    });

    test('an edited rate really changes the price', () {
      final before = const PricingEngine().price(window()).total;
      final after = PricingEngine(
        rules: const PricingRules().withFrameRate(FrameMaterial.aluminium, 40),
      ).price(window()).total;

      expect(after, greaterThan(before));
    });
  });

  group('a damaged settings file cannot break pricing', () {
    test('missing keys fall back to the shipped rates', () {
      final restored = PricingRules.fromJson(const {'currencySymbol': '£'});

      expect(restored.currencySymbol, '£');
      expect(restored.framePerMetre, const PricingRules().framePerMetre);
      expect(restored.labourPerSquareMetre, const PricingRules().labourPerSquareMetre);
    });

    test('junk values are ignored rather than producing a nonsense price', () {
      final restored = PricingRules.fromJson(const {
        'currencySymbol': '',
        'hingeEach': 'free',
        'wasteRate': -1,
        'framePerMetre': {'aluminium': 'lots', 'upvc': 12.5, 'nonsense': 9},
      });

      expect(restored.currencySymbol, const PricingRules().currencySymbol);
      expect(restored.hingeEach, const PricingRules().hingeEach);
      expect(restored.wasteRate, const PricingRules().wasteRate);
      expect(restored.framePerMetre[FrameMaterial.aluminium],
          const PricingRules().framePerMetre[FrameMaterial.aluminium]);
      expect(restored.framePerMetre[FrameMaterial.upvc], 12.5);
      expect(const PricingEngine().price(window()).total, greaterThan(0));
    });
  });
}

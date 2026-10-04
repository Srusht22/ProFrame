import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import '../mixed_door_and_window_test.dart' as mixed;
import 'a_sliding_design_test.dart' as sliding;
import 'an_unknown_category_test.dart' show keptAs, sloped;
import 'geometry_normalizer_test.dart' show pen;

// The pricing engine, held on the design's own geometry and a price list
// whose every figure the test chooses. `zero` prices nothing; each test
// gives one or two things a price and requires exactly what that makes —
// so a figure is checked against the geometry it came from, not against a
// number the engine happened to give.

const engine = PricingEngine();

/// Every category, material, glass, panel, piece and leaf priced at
/// nothing — present, so nothing is missing, and free, so nothing is
/// charged until a test says.
final zero = PriceList(
  currency: 'T',
  profiles: {
    for (final m in [MaterialKind.upvc, MaterialKind.aluminium])
      m: const ProfileRate(framePerMetre: 0, sashPerMetre: 0, barPerMetre: 0),
  },
  glassPerM2: {for (final g in GlassLook.values) g: 0},
  customGlassPerM2: 0,
  panelPerM2: {for (final p in PanelColour.values) p: 0},
  customPanelPerM2: 0,
  hardwareEach: {for (final h in HardwareKind.values) h: 0},
  leafEach: {for (final l in LeafRate.values) l: 0},
  categories: {
    for (final k in DesignKind.categories)
      k.name: CategoryRate(k.label, const LabourRate()),
  },
  installation: const InstallationRate(),
);

PriceList withProfile(
  PriceList list,
  MaterialKind m, {
  double frame = 0,
  double sash = 0,
  double bar = 0,
  List<ColourRate> colours = const [],
  double special = 0,
}) => list.copyWith(
  profiles: {
    ...list.profiles,
    m: ProfileRate(
      framePerMetre: frame,
      sashPerMetre: sash,
      barPerMetre: bar,
      colours: colours,
      specialColourPercent: special,
    ),
  },
);

/// [d] with its overall width and height said to be given.
Design given(Design d) => d.copyWith(
  measured: {...?d.measured, Measurements.widthKey, Measurements.heightKey},
);

/// A 100 × 200 cm frame drawn on the sheet, with a `>` in it, of [kind].
Design door({DesignKind kind = DesignKind.door, String id = 'door'}) => given(
  SketchInterpreter.interpret(
    Design.empty(id: id, kind: kind).copyWith(
      name: 'Basement Door',
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(1000, 0),
            Vec2(1000, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          pen('mark', chevron(const Vec2(500, 1000))),
        ],
      ),
    ),
  ).design,
);

/// [d] with a line drawn inside its opening 45 % down it, and the lower
/// pane made a panel of [colour].
Design glassOverPanel(Design d, {PanelColour colour = PanelColour.white}) {
  final opening = d.openings.single;
  final box = d.sectionById(opening.sectionId)!.outline;
  final out = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(box.centroid.x, box.top + box.height * 0.45),
    horizontal: true,
  );
  final low = out
      .childSectionsOf(opening.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return out.withElement(low.copyWith(finish: colour.finish));
}

Design framedIn(Design d, Finish finish) =>
    d.withElement(d.frame!.copyWith(finish: finish));

double totalOf(Design d, PriceList list, {PricingChoices? choices}) {
  final r = engine.price(d, list, choices: choices);
  expect(r.status, PriceStatus.priced, reason: '${r.issues}');
  return r.total!;
}

List<PriceLine> linesOf(Design d, PriceList list) =>
    engine.price(d, list).lines;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what is charged, by category', () {
    test('1. a door: its frame by the metre, its leaf as a door, its '
        'hinges and handle counted', () {
      final d = door();
      final t = PricingTakeoff.of(d);
      expect(t.widthCm, closeTo(100, 1e-9));
      expect(t.heightCm, closeTo(200, 1e-9));
      expect(t.areaM2, closeTo(2, 1e-9), reason: '100 × 200 cm = 2 m²');
      expect(t.frameMetres, closeTo(6, 1e-9));
      expect(t.openings, 1);

      final list = withProfile(
        zero,
        MaterialKind.upvc,
        frame: 10,
      ).copyWith(leafEach: {...zero.leafEach, LeafRate.door: 1000});
      final lines = linesOf(d, list);
      expect(lines.map((l) => l.label), contains('uPVC frame'));
      expect(lines.map((l) => l.label), contains('Door leaf'));
      expect(totalOf(d, list), closeTo(60 + 1000, 1e-6));
    });

    test('2. a window: the same sheet, its leaf charged as a window sash', () {
      final d = door(kind: DesignKind.window, id: 'w');
      final list = zero.copyWith(
        leafEach: {...zero.leafEach, LeafRate.window: 300, LeafRate.door: 1},
      );
      final lines = linesOf(d, list);
      expect(lines.single.label, 'Window sash');
      expect(totalOf(d, list), 300);
    });

    test('3. a sliding set: its panel a sliding panel, the track by the '
        'metre of its width, and the rollers it runs on', () {
      final d = given(sliding.sheet(left: '>'));
      final t = PricingTakeoff.of(d);
      expect(t.leaves.where((l) => l.slides), hasLength(1));
      final list = zero.copyWith(
        leafEach: {...zero.leafEach, LeafRate.sliding: 500},
        trackPerMetre: 10,
        rollerEach: 7,
        rollersPerSlidingPanel: 3,
      );
      final labels = linesOf(d, list).map((l) => l.label).toList();
      expect(
        labels,
        containsAll(['Sliding panel', 'Sliding track', 'Rollers']),
      );
      // 2.4 m of track, one sliding panel on three rollers.
      expect(totalOf(d, list), closeTo(500 + 24 + 21, 1e-6));
      // Three rollers are not two.
      expect(
        totalOf(d, list.copyWith(rollersPerSlidingPanel: 2)),
        closeTo(500 + 24 + 14, 1e-6),
      );
    });

    test('4 & 21. a door & window set: each leaf charged as what it is — '
        'never the whole as one door or one window', () {
      final d = given(mixed.theScreen().copyWith(kind: DesignKind.both));
      final kinds = [for (final o in d.openingsInOrder) d.kindOf(o)];
      expect(kinds, [DesignKind.window, DesignKind.door]);
      final list = zero.copyWith(
        leafEach: {...zero.leafEach, LeafRate.door: 1000, LeafRate.window: 10},
      );
      final leafLines = linesOf(d, list)
          .where((l) => l.unit == PriceUnit.each)
          .map((l) => '${l.label} ${l.amount}')
          .toList();
      expect(
        leafLines,
        unorderedEquals(['Window sash 10.0', 'Door leaf 1000.0']),
      );
      expect(totalOf(d, list), 1010);
      // The door's lock is the door's: a lock rate is charged once.
      final locked = list.copyWith(
        hardwareEach: {...zero.hardwareEach, HardwareKind.lock: 50},
      );
      expect(totalOf(d, locked), 1060);
    });

    test('5 & 22. an angled design: its area the polygon\'s own, never its '
        'box, its sloped joints charged, and nothing squared', () {
      final d = given(sloped());
      final before = jsonEncode(d.toJson());
      final t = PricingTakeoff.of(d);
      // Left 200 cm, right 150, 100 wide: 2 m² of box, 1.75 m² of window.
      expect(t.areaM2, closeTo(1.75, 1e-9));
      expect(d.frame!.outline.width * d.frame!.outline.height / 1e6, 2);
      expect(t.angledJoints, 2);
      expect(t.frameMetres, closeTo(2 + 1.5 + 1 + 1.118034, 1e-5));

      final list = zero.copyWith(
        angledJointEach: 100,
        categories: {
          ...zero.categories,
          'angled': const CategoryRate(
            'Angled',
            LabourRate(perSquareMetre: 1000),
          ),
        },
      );
      expect(totalOf(d, list), closeTo(200 + 1750, 1e-6));
      expect(jsonEncode(d.toJson()), before, reason: 'not squared to price');
    });
  });

  group('material and colour', () {
    test('6 & 7 & 27. the same geometry in uPVC and in aluminium: two prices '
        'where the list prices them differently', () {
      final d = door();
      final pvc = framedIn(
        d,
        const Finish(colour: 0xFFFFFFFF, material: MaterialKind.upvc),
      );
      final alu = framedIn(
        d,
        const Finish(colour: 0xFFFFFFFF, material: MaterialKind.aluminium),
      );
      final a = totalOf(pvc, PriceList.starter);
      final b = totalOf(alu, PriceList.starter);
      expect(a, isNot(b));
      expect(b, greaterThan(a));
      // The geometry is the same: only the frame's finish differs.
      expect(pvc.frame!.outline, alu.frame!.outline);

      // Exactly the profile's price per metre between them.
      final list = withProfile(
        withProfile(zero, MaterialKind.upvc, frame: 10),
        MaterialKind.aluminium,
        frame: 30,
      );
      expect(totalOf(pvc, list), closeTo(60, 1e-6));
      expect(totalOf(alu, list), closeTo(180, 1e-6));
    });

    test(
      '8 & 9 & 27. the same aluminium frame in a standard colour and in '
      'one with a surcharge: different prices, the surcharge its own line',
      () {
        final d = door();
        const white = Finish(
          colour: 0xFFFFFFFF,
          material: MaterialKind.aluminium,
        );
        const anthracite = Finish(
          colour: 0xFF383E42,
          material: MaterialKind.aluminium,
        );
        final a = totalOf(framedIn(d, white), PriceList.starter);
        final b = totalOf(framedIn(d, anthracite), PriceList.starter);
        expect(b, greaterThan(a));

        final list = withProfile(
          zero,
          MaterialKind.aluminium,
          frame: 100,
          colours: const [
            ColourRate('White', 0xFFFFFFFF, ColourGrade.standard, 0),
            ColourRate('Anthracite', 0xFF383E42, ColourGrade.nonStandard, 10),
          ],
          special: 25,
        );
        expect(totalOf(framedIn(d, white), list), closeTo(600, 1e-6));
        expect(totalOf(framedIn(d, anthracite), list), closeTo(660, 1e-6));
        final surcharge = linesOf(framedIn(d, anthracite), list).last;
        expect(surcharge.label, contains('Anthracite'));
        expect(surcharge.label, contains('non-standard'));
        expect(surcharge.unit, PriceUnit.percent);

        // A colour the list does not name is a special colour — the house
        // green of the application's own bars among them.
        const brand = Finish(
          colour: 0xFF013E37,
          material: MaterialKind.aluminium,
        );
        expect(totalOf(framedIn(d, brand), list), closeTo(750, 1e-6));
        expect(
          linesOf(framedIn(d, brand), list).last.label,
          contains('special colour'),
        );
        const cream = Finish(
          colour: 0xFFFFEFB3,
          material: MaterialKind.aluminium,
        );
        expect(totalOf(framedIn(d, cream), list), closeTo(750, 1e-6));
      },
    );

    test('wood-effect uPVC is dearer than white in the starter list', () {
      final d = door();
      const white = Finish(colour: 0xFFFFFFFF, material: MaterialKind.upvc);
      const oak = Finish(colour: 0xFF7B4A2B, material: MaterialKind.upvc);
      expect(
        totalOf(framedIn(d, oak), PriceList.starter),
        greaterThan(totalOf(framedIn(d, white), PriceList.starter)),
      );
    });
  });

  group('glass, panel, hardware, labour, installation, discount', () {
    test('10 & 11. each pane by its own glass or panel, by the square metre '
        'it is cut to — not shared out half and half', () {
      final d = glassOverPanel(door());
      final geometry = DesignGeometry.of(d);
      final parts = Infill.partsOf(d);
      final glass = parts.singleWhere((p) => Infill.isGlass(p.finish));
      final panel = parts.singleWhere((p) => Infill.isPanel(p.finish));
      final glassM2 = geometry.fillOf(glass).area / 1e6;
      final panelM2 = geometry.fillOf(panel).area / 1e6;
      expect(glassM2, isNot(closeTo(panelM2, 0.05)), reason: 'not 50/50');

      final list = zero.copyWith(
        glassPerM2: {...zero.glassPerM2, GlassLook.clear: 100},
        panelPerM2: {...zero.panelPerM2, PanelColour.white: 1000},
      );
      final lines = linesOf(d, list);
      final g = lines.singleWhere((l) => l.label.startsWith('Clear glass'));
      final p = lines.singleWhere((l) => l.label.startsWith('White panel'));
      expect(g.quantity, closeTo(glassM2, 1e-9));
      expect(p.quantity, closeTo(panelM2, 1e-9));
      expect(g.partId, glass.id);
      expect(p.partId, panel.id);
      expect(PricingTakeoff.of(d).glassRegions, 1);
      expect(PricingTakeoff.of(d).panelRegions, 1);
      expect(PricingTakeoff.of(d).dividers, 1);

      // Glass and panel are charged differently, by look and by colour.
      final frosted = d.withElement(
        glass.copyWith(finish: GlassLook.frosted.finish),
      );
      final dearer = list.copyWith(
        glassPerM2: {...list.glassPerM2, GlassLook.frosted: 300},
      );
      expect(
        totalOf(frosted, dearer) - totalOf(d, dearer),
        closeTo(glassM2 * 200, 0.02),
      );
    });

    test('12. ironmongery by the piece: four hinges are not three', () {
      final d = door();
      final list = zero.copyWith(
        hardwareEach: {...zero.hardwareEach, HardwareKind.hinge: 100},
      );
      final hinges = d.hardware.where((h) => h.kind == HardwareKind.hinge);
      final base = totalOf(d, list);
      expect(base, 100.0 * hinges.length);

      Design hung(int count) => OpeningHardware.settle(
        d.withElement(d.openings.single.copyWith(hingeCount: count)),
      );
      expect(totalOf(hung(3), list), 300);
      expect(totalOf(hung(4), list), 400);
      expect(PricingTakeoff.of(hung(4)).hardwareCounts[HardwareKind.hinge], 4);
    });

    test('13. labour: fixed, by area and as a percentage of the materials', () {
      final d = door();
      final list = withProfile(zero, MaterialKind.upvc, frame: 100).copyWith(
        categories: {
          ...zero.categories,
          'door': const CategoryRate(
            'Door',
            LabourRate(fixed: 50, perSquareMetre: 10, percent: 10),
          ),
        },
      );
      final r = engine.price(d, list);
      expect(r.sumOf(PriceGroup.material), closeTo(600, 1e-6));
      // 50 fixed, 2 m² × 10, 10 % of 600.
      expect(r.sumOf(PriceGroup.labour), closeTo(50 + 20 + 60, 1e-6));
      expect(r.total, closeTo(730, 1e-6));
    });

    test('14. installation only where it is asked for, and then its own '
        'group', () {
      final d = door();
      final list = zero.copyWith(
        installation: const InstallationRate(fixed: 100, perSquareMetre: 10),
      );
      final without = engine.price(d, list);
      expect(without.sumOf(PriceGroup.installation), 0);
      expect(without.total, 0);
      expect(d.pricing.installation, isFalse, reason: 'never on by default');
      final fitted = engine.price(
        d,
        list,
        choices: const PricingChoices(installation: true),
      );
      expect(fitted.sumOf(PriceGroup.installation), closeTo(120, 1e-6));
      expect(fitted.total, closeTo(120, 1e-6));
    });

    test('15. a subtotal, a discount and a total — and no discount takes '
        'the total below nothing', () {
      final d = door();
      final list = withProfile(zero, MaterialKind.upvc, frame: 100);
      PriceResult off(Discount discount) =>
          engine.price(d, list, choices: PricingChoices(discount: discount));
      final ten = off(const Discount(percent: 10));
      expect(ten.subtotal, 600);
      expect(ten.discountAmount, 60);
      expect(ten.total, 540);
      expect(off(const Discount(amount: 50)).total, 550);
      expect(off(const Discount(amount: 5000)).total, 0);
      expect(off(const Discount(percent: 150)).total, 0);
      expect(off(const Discount(percent: double.nan)).total, 600);
    });
  });

  group('recalculation', () {
    final list = withProfile(
      zero,
      MaterialKind.upvc,
      frame: 10,
    ).copyWith(glassPerM2: {...zero.glassPerM2, GlassLook.clear: 100});

    test('16 & 17. a new width or height gives a new price', () {
      final d = door();
      final wider = Measurements.apply(d, {Measurements.widthKey: 1200});
      final taller = Measurements.apply(d, {Measurements.heightKey: 2400});
      expect(wider.ok && taller.ok, isTrue);
      // 6 m of frame, then 6.4, then 6.8.
      expect(linesOf(d, list).first.quantity, closeTo(6, 1e-9));
      expect(linesOf(wider.design, list).first.quantity, closeTo(6.4, 1e-9));
      expect(linesOf(taller.design, list).first.quantity, closeTo(6.8, 1e-9));
      expect(totalOf(wider.design, list), greaterThan(totalOf(d, list)));
      expect(totalOf(taller.design, list), greaterThan(totalOf(d, list)));
    });

    test('18 & 19 & 20. material, colour and glass to panel each give a '
        'new price', () {
      final d = door();
      final starter = PriceList.starter;
      final base = totalOf(d, starter);
      final alu = framedIn(
        d,
        d.frame!.finish.copyWith(material: MaterialKind.aluminium),
      );
      expect(totalOf(alu, starter), isNot(base));
      final black = framedIn(d, d.frame!.finish.copyWith(colour: 0xFF1C1C1C));
      expect(totalOf(black, starter), greaterThan(base));
      final pane = Infill.partsOf(d).single;
      final panel = d.withElement(
        pane.copyWith(finish: PanelColour.white.finish),
      );
      expect(totalOf(panel, starter), isNot(base));
    });
  });

  group('what cannot be priced is said, never guessed', () {
    test('23. a category from a later version: price unavailable — never '
        'a window\'s price', () {
      final d = given(sloped());
      for (final saved in <Object?>['future_custom_shape', 'circular', 12345]) {
        final future = Design.fromJson(keptAs(d, saved));
        final r = engine.price(future, PriceList.starter);
        expect(r.status, PriceStatus.unsupportedCategory, reason: '$saved');
        expect(r.total, isNull);
        expect(r.lines, isEmpty);
        expect(r.category, isNot('window'));
        expect(r.issues.single.message, contains('Price unavailable'));
      }
      final none = Design.fromJson(keptAs(d, null, has: false));
      expect(
        engine.price(none, PriceList.starter).status,
        PriceStatus.unsupportedCategory,
      );
    });

    test('a category with no strategy, or no rate, is not priced as '
        'another', () {
      final d = given(sliding.sheet(left: '>'));
      const noSliding = PricingEngine({
        'door': FramedPricing(),
        'window': FramedPricing(),
      });
      expect(
        noSliding.price(d, PriceList.starter).status,
        PriceStatus.unsupportedCategory,
      );
      final noRate = zero.copyWith(
        categories: {...zero.categories}..remove('sliding'),
      );
      expect(engine.price(d, noRate).status, PriceStatus.notConfigured);
    });

    test('a later category is added by registering its strategy and its '
        'rate — nothing else changes', () {
      final d = door();
      final custom = PricingEngine({
        ...PricingEngine.standard,
        'door': _Flat(),
      });
      expect(custom.price(d, zero).total, 1234);
      expect(engine.price(d, zero).total, 0);
    });

    test('24. missing data: a frame material, a glass, a piece of '
        'ironmongery the list has no price for', () {
      final d = door();
      final wood = framedIn(
        d,
        const Finish(colour: 0xFF7B4A2B, material: MaterialKind.wood),
      );
      final r = engine.price(wood, zero);
      expect(r.status, PriceStatus.notConfigured);
      expect(r.total, isNull);
      expect(r.issues.single.message, contains('Wood frame'));

      final noGlass = zero.copyWith(glassPerM2: const {});
      expect(engine.price(d, noGlass).status, PriceStatus.notConfigured);
      final noHinge = zero.copyWith(
        hardwareEach: {...zero.hardwareEach}..remove(HardwareKind.hinge),
      );
      final hinge = engine.price(d, noHinge);
      expect(hinge.status, PriceStatus.notConfigured);
      expect(hinge.issues.single.message, contains('hinge'));

      // Nothing drawn, and no sizes given.
      final empty = Design.empty(id: 'e', kind: DesignKind.door);
      expect(engine.price(empty, zero).status, PriceStatus.nothingToPrice);
      final unsized = door().copyWith(measured: {});
      final asked = engine.price(unsized, zero);
      expect(asked.status, PriceStatus.needsSizes);
      expect(asked.total, isNull);
    });

    test('25. invalid dimensions: no width, no height, not a number — a '
        'state, never NaN, infinity or a negative price', () {
      final d = door();
      for (final outline in [
        const [Vec2(0, 0), Vec2(0, 2000), Vec2(0, 2000), Vec2(0, 0)],
        const [Vec2(0, 0), Vec2(1000, 0), Vec2(1000, 0), Vec2(0, 0)],
        const [Vec2(0, 0), Vec2(double.nan, 0), Vec2(1000, 2000)],
        const [Vec2(0, 0), Vec2(double.infinity, 0), Vec2(1000, 2000)],
      ]) {
        final bad = d.copyWith(
          frame: d.frame!.copyWith(outline: Polygon(outline)),
        );
        final r = engine.price(bad, PriceList.starter);
        expect(r.status, PriceStatus.invalid, reason: '$outline');
        expect(r.total, isNull);
        expect(r.subtotal, 0);
      }
      // Every amount the engine writes is finite and no less than nothing.
      for (final x in [door(), glassOverPanel(door()), given(sloped())]) {
        for (final l in engine.price(x, PriceList.starter).lines) {
          expect(l.amount.isFinite && l.amount >= 0, isTrue, reason: '$l');
        }
      }
    });
  });

  group('kept, and read back', () {
    test('26. the pricing choices are kept with the design, and it is '
        'priced the same after a save and a load', () {
      final d = door().copyWith(
        pricing: const PricingChoices(
          installation: true,
          discount: Discount(percent: 5),
        ),
      );
      final back = Design.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(back.pricing, d.pricing);
      expect(
        engine.price(back, PriceList.starter).total,
        engine.price(d, PriceList.starter).total,
      );
      expect(
        jsonEncode(back.toJson()),
        jsonEncode(d.toJson()),
        reason: 'the same text',
      );
    });

    test('27. a design kept before pricing opens unchanged, with nothing '
        'chosen, and is priced', () {
      final d = door();
      final json = d.toJson();
      expect(json.containsKey('pricing'), isFalse, reason: 'nothing added');
      final old = Design.fromJson(jsonDecode(jsonEncode(json)));
      expect(old.pricing.isNone, isTrue);
      expect(jsonEncode(old.toJson()), jsonEncode(json));
      // One kept before sizes were asked for shows its sizes as it always
      // did, and is priced by them.
      final older = Design.fromJson(
        jsonDecode(jsonEncode({...json}..remove('measured'))),
      );
      expect(older.measured, isNull);
      expect(engine.price(older, PriceList.starter).isPriced, isTrue);
    });

    test('28. pricing reads the design and writes nothing', () {
      for (final d in [
        door(),
        glassOverPanel(door()),
        given(sloped()),
        given(sliding.sheet(left: '>')),
        given(mixed.theScreen().copyWith(kind: DesignKind.both)),
      ]) {
        final before = jsonEncode(d.toJson());
        final frame = d.frame;
        engine.price(d, PriceList.starter);
        engine.price(
          d,
          PriceList.starter,
          choices: const PricingChoices(installation: true),
        );
        PricingTakeoff.of(d);
        expect(jsonEncode(d.toJson()), before);
        expect(identical(d.frame, frame), isTrue);
      }
    });

    test('a price kept on a day stays what it was when the list changes', () {
      final d = door();
      final then = engine.price(d, PriceList.starter);
      final kept = d.copyWith(
        pricing: PricingChoices(
          snapshot: PriceSnapshot(takenAt: DateTime(2026, 10, 4), result: then),
        ),
      );
      final back = Design.fromJson(jsonDecode(jsonEncode(kept.toJson())));
      final dearer = withProfile(
        PriceList.starter,
        MaterialKind.upvc,
        frame: 999999,
      ).copyWith(version: 7);
      final now = engine.price(back, dearer);
      expect(now.total, isNot(then.total));
      expect(back.pricing.snapshot!.result.total, then.total);
      expect(
        jsonEncode(back.pricing.snapshot!.result.toJson()),
        jsonEncode(then.toJson()),
      );
      expect(now.priceListVersion, 7);
    });
  });

  group('the price list, kept and guarded', () {
    test('29. the owner\'s list is kept on the device and read back by a '
        'store opened afresh', () async {
      final store = PriceListStore();
      expect((await store.load()).isStarter, isTrue);
      final mine = withProfile(PriceList.starter, MaterialKind.upvc, frame: 1);
      final kept = await store.save(mine, by: WorkshopRole.owner);
      expect(kept.isStarter, isFalse);
      expect(kept.version, 1);
      final again = await PriceListStore().load();
      expect(jsonEncode(again.toJson()), jsonEncode(kept.toJson()));
      expect(again.profiles[MaterialKind.upvc]!.framePerMetre, 1);
      final second = await store.save(again, by: WorkshopRole.owner);
      expect(second.version, 2);
      // A design priced by the kept list says which list it came from.
      expect(engine.price(door(), second).priceListVersion, 2);
    });

    test('30. staff may price but not change prices: refused, and nothing '
        'written', () async {
      final store = PriceListStore();
      expect(WorkshopRole.staff.canConfigurePrices, isFalse);
      expect(WorkshopRole.staff.canSeePrices, isTrue);
      expect(WorkshopRole.owner.canConfigurePrices, isTrue);
      await expectLater(
        store.save(zero, by: WorkshopRole.staff),
        throwsA(isA<PricingAccessDenied>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
      expect((await store.load()).isStarter, isTrue);
    });

    test('a list that cannot be read is not written over by reading it, '
        'and a figure that is not a price is left out', () async {
      SharedPreferences.setMockInitialValues({PriceListStore.key: '{not json'});
      final store = PriceListStore();
      expect((await store.load()).isStarter, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), '{not json');

      final json = jsonDecode(
        jsonEncode(PriceList.starter.toJson()),
      ) as Map<String, Object?>;
      (json['glassPerM2']! as Map<String, Object?>)['clear'] = -5;
      (json['hardwareEach']! as Map<String, Object?>)['hinge'] = 'cheap';
      (json['categories']! as Map<String, Object?>)['folding'] = {
        'label': 'Folding',
        'labour': {'fixed': 1},
      };
      final read = PriceList.fromJson(jsonDecode(jsonEncode(json)))!;
      expect(read.glassPerM2.containsKey(GlassLook.clear), isFalse);
      expect(read.hardwareEach.containsKey(HardwareKind.hinge), isFalse);
      expect(read.categories['folding']!.labour.fixed, 1);
      expect(engine.price(door(), read).status, PriceStatus.notConfigured);
      expect(PriceList.fromJson('nonsense'), isNull);
      expect(PriceList.fromJson({'currency': ''}), isNull);
    });

    test('the starter list round-trips', () {
      final back = PriceList.fromJson(
        jsonDecode(jsonEncode(PriceList.starter.toJson())),
      )!;
      expect(jsonEncode(back.toJson()), jsonEncode(PriceList.starter.toJson()));
      expect(back.isStarter, isTrue);
      for (final kind in DesignKind.categories) {
        expect(back.categories[kind.name], isNotNull, reason: kind.name);
      }
    });
  });
}

class _Flat extends CategoryPricing {
  const _Flat();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) =>
      sheet.add(PriceGroup.material, 'Everything', 1, PriceUnit.fixed, 1234);
}

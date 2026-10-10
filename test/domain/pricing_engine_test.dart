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
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/measurement.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_migration.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/domain/pricing/profile_category.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import '../mixed_door_and_window_test.dart' as mixed;
import 'a_sliding_design_test.dart' as sliding;
import 'an_unknown_category_test.dart' show keptAs, sloped;
import 'geometry_normalizer_test.dart' show pen;

// The factory's measurement and its price, held on the design's own
// geometry and on price lists whose every figure the test sets. The
// factory measures each kind of geometry on its own — normal profile
// (border and lines) and opening profile by the metre, panel and glass by
// the square metre, ironmongery by the piece — and prices each at its own
// rate. $7 and $12 a metre are the brief's examples, set here; they are
// nowhere in the application.

const engine = PricingEngine();

/// Every category, material, glass, panel and piece present and priced at
/// nothing, so nothing is missing and nothing is charged until a test says.
final zero = PriceList(
  currency: 'USD',
  profiles: {
    MaterialKind.upvc: const ProfileRate(
      normalPerMetre: 0,
      openingPerMetre: 0,
    ),
    // Since Phase 33 aluminium's border and lines are priced by profile
    // category, System and Bend Shoulder, each its own figure.
    MaterialKind.aluminium: const ProfileRate(
      openingPerMetre: 0,
      categories: {
        ProfileCategory.systemAluminium: 0,
        ProfileCategory.bendShoulderAluminium: 0,
      },
    ),
  },
  glassPerM2: {for (final g in GlassLook.values) g: 0},
  customGlassPerM2: 0,
  sealedGlassPerM2: {for (final g in GlassLook.values) g: 0},
  customSealedGlassPerM2: 0,
  panelPerM2: {for (final p in PanelColour.values) p: 0},
  customPanelPerM2: 0,
  hardwareEach: {for (final h in HardwareKind.values) h: 0},
  categories: {
    for (final k in DesignKind.categories)
      k.name: CategoryRate(k.label, const LabourRate()),
  },
  installation: const InstallationRate(),
);

/// A colour a material is sold in, as a test writes it: its name, its
/// swatch, its grade and what it adds on that material.
typedef Sold = ({
  String name,
  int swatch,
  ColourGrade grade,
  ColourSurcharge rate,
});

Sold sold(
  String name,
  int swatch,
  ColourGrade grade, {
  double perMetre = 0,
  double percent = 0,
}) => (
  name: name,
  swatch: swatch,
  grade: grade,
  rate: ColourSurcharge(perMetre: perMetre, percent: percent),
);

/// [list] with [m]'s profile at [normal] and [opening], what any other
/// colour adds on it, and [colours] sold in it — each added to the
/// catalog, or given a rate on [m] where the catalog already has a colour
/// of that name and swatch.
///
/// For a material sold by profile category (aluminium, since Phase 33)
/// [normal] is every category's rate: these tests are about the material,
/// and the categories' own rates are held by
/// `aluminium_categories_and_optional_glass_test`.
PriceList withProfile(
  PriceList list,
  MaterialKind m, {
  double normal = 0,
  double opening = 0,
  List<Sold> colours = const [],
  ColourSurcharge special = const ColourSurcharge(),
}) {
  final catalog = [...list.colours];
  final taken = {for (final c in catalog) c.id};
  for (final c in colours) {
    final at = catalog.indexWhere(
      (e) => e.name == c.name && e.swatch == c.swatch,
    );
    if (at >= 0) {
      catalog[at] = catalog[at].copyWith(
        rates: {...catalog[at].rates, m: c.rate},
      );
    } else {
      catalog.add(
        FactoryColour(
          id: PriceListMigration.idFor(c.name, taken),
          name: c.name,
          swatch: c.swatch,
          grade: c.grade,
          rates: {m: c.rate},
          order: catalog.length,
        ),
      );
    }
  }
  return list.copyWith(
    colours: catalog,
    profiles: {
      ...list.profiles,
      m: ProfileCategory.divides(m)
          ? ProfileRate(
              openingPerMetre: opening,
              categories: {for (final c in ProfileCategory.of(m)) c: normal},
              special: special,
            )
          : ProfileRate(
              normalPerMetre: normal,
              openingPerMetre: opening,
              special: special,
            ),
    },
  );
}

/// The brief's example rates: $7 a metre of normal profile and $12 a metre
/// of opening profile, in uPVC.
final example = withProfile(zero, MaterialKind.upvc, normal: 7, opening: 12);

/// [d] with every size it asks for said to be given — the frame's border,
/// its width and height, and each light's and pane's own — so it is
/// complete enough to price. Nothing in the geometry moves.
Design given(Design d) => d.copyWith(
  measured: {
    ...?d.measured,
    for (final m in Measurements.of(d))
      if (m.asked) m.key,
  },
  // And its profile chosen, as the user chooses it: the frame's finish as
  // it stands, said to be the one.
  profileChosen: true,
  // Since Phase 33 glass is charged only where the user includes it, and
  // an aluminium part only once somebody says whether it is System or Bend
  // Shoulder. These tests are about what a design costs once that is said,
  // so it is said here; the defaults themselves — glass not included, no
  // category guessed — are held by
  // `aluminium_categories_and_optional_glass_test`.
  pricing: d.pricing.copyWith(
    glassPriced: true,
    profileCategory: ProfileCategory.systemAluminium,
  ),
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

/// The brief's acceptance design: a border of 100 + 100 + 200 + 200 cm,
/// one opening of 100 + 200 + 100 + 200 cm, and two lines of 80 cm inside
/// it. Its frame is drawn with no profile of its own, so the opening's
/// region is the border exactly, as the brief's figures have it; the leaf
/// still has its own sash. The pane is a white panel.
Design acceptance() {
  const frame = FrameElement(
    id: 'frame',
    outline: Polygon([
      Vec2(0, 0),
      Vec2(1000, 0),
      Vec2(1000, 2000),
      Vec2(0, 2000),
    ]),
    profileMm: 0,
  );
  var d = SectionBuilder.rebuild(
    Design.empty(
      id: 'acceptance',
      kind: DesignKind.door,
    ).copyWith(name: 'Acceptance door', frame: frame),
  );
  final region = d.sections.single;
  d = OpeningHardware.settle(
    d.copyWith(
      openings: [
        OpeningElement(
          id: 'opening',
          sectionId: region.id,
          mechanism: OpeningMechanism.hingedLeft,
          confirmed: true,
        ),
      ],
    ),
  );
  d = SectionBuilder.rebuild(
    d.copyWith(
      dividers: const [
        DividerElement(
          id: 'line-1',
          a: Vec2(100, 600),
          b: Vec2(900, 600),
          parentId: 'opening',
        ),
        DividerElement(
          id: 'line-2',
          a: Vec2(100, 1400),
          b: Vec2(900, 1400),
          parentId: 'opening',
        ),
      ],
    ),
  );
  final pane = Infill.partsOf(d).single;
  d = d.withElement(pane.copyWith(finish: PanelColour.white.finish));
  return given(d);
}

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
  return given(out.withElement(low.copyWith(finish: colour.finish)));
}

/// The mixed screen: four lights under three mullions, a window and a door
/// each divided glass over a brown panel.
Design screen() => given(mixed.theScreen().copyWith(kind: DesignKind.both));

Design framedIn(Design d, Finish finish) =>
    d.withElement(d.frame!.copyWith(finish: finish));

double perimeter(Polygon p) => p.edges.fold(0, (s, e) => s + e.length);

double totalOf(Design d, PriceList list, {PricingChoices? choices}) {
  final r = engine.price(d, list, choices: choices);
  expect(r.status, PriceStatus.priced, reason: '${r.issues}');
  return r.total!;
}

List<PriceLine> linesOf(Design d, PriceList list) =>
    engine.price(d, list).lines;

PriceLine lineOf(Design d, PriceList list, PriceGroup group) =>
    linesOf(d, list).singleWhere((l) => l.group == group);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the acceptance design: 7.60 m of normal profile, 6.00 m of '
      'opening profile', () {
    test('31. measured and priced exactly as the brief works it out', () {
      final d = acceptance();
      final t = PricingTakeoff.of(d);
      expect(t.border.value, closeTo(6.00, 1e-9), reason: '600 cm');
      expect(t.dividers.value, closeTo(1.60, 1e-9), reason: '80 + 80 cm');
      expect(t.normalProfile.value, closeTo(7.60, 1e-9));
      expect(t.normalProfile.label, '7.600 m');
      expect(t.openingProfile.value, closeTo(6.00, 1e-9));
      expect(t.openingProfile.label, '6.000 m');
      expect(t.totalProfile.label, '13.600 m');

      // $7 and $12 a metre. Since Phase 33 the border and the lines are
      // two lines at the one rate they share, never folded into one; they
      // still come to the 7.60 m and $53.20 the brief works out.
      final normal = linesOf(
        d,
        example,
      ).where((l) => l.group == PriceGroup.normalProfile).toList();
      expect(normal.map((l) => l.part), [ProfilePart.border, ProfilePart.lines]);
      expect(normal.first.label, 'uPVC — Border');
      expect(normal.first.quantity, closeTo(6.00, 1e-9));
      expect(normal.first.amount, 42.00);
      expect(normal.last.label, 'uPVC — Internal lines');
      expect(normal.last.quantity, closeTo(1.60, 1e-9));
      expect(normal.last.amount, 11.20);
      expect(normal.every((l) => l.rate == 7), isTrue);
      expect(normal.fold(0, (sum, l) => sum + l.amountCents), 5320);
      final opening = lineOf(d, example, PriceGroup.openingProfile);
      expect(opening.quantity, closeTo(6.00, 1e-9));
      expect(opening.rate, 12);
      expect(opening.amount, 72.00);
      expect(totalOf(d, example), closeTo(125.20, 1e-9));

      // Then the panel: the leaf's own daylight, inside its 18 mm sash —
      // 96.4 × 196.4 cm — at $30 a square metre.
      final sash = OpeningLeaf.profileFor(d.frame!);
      expect(sash, 18);
      final panelM2 = (1000 - 2 * sash) * (2000 - 2 * sash) / 1e6;
      expect(t.panelArea.value, closeTo(panelM2, 1e-9));
      expect(t.panelArea.label, '1.8933 m²');
      final withPanel = example.copyWith(
        panelPerM2: {...zero.panelPerM2, PanelColour.white: 30},
      );
      final panel = lineOf(d, withPanel, PriceGroup.panel);
      expect(panel.unit, PriceUnit.squareMetre);
      expect(panel.amount, 56.80, reason: '1.893296 m² × 30');
      expect(totalOf(d, withPanel), closeTo(125.20 + 56.80, 1e-9));
      final result = engine.price(d, withPanel);
      expect(result.measurements.normalProfile.label, '7.600 m');
      expect(result.measurements.openingProfile.label, '6.000 m');
      expect(result.measurements.panelArea.label, '1.8933 m²');
      expect(result.measurements.glassArea.label, '0.0000 m²');
    });
  });

  group('measurement', () {
    test('1 & 4. the border is the outline, the opening its own region', () {
      final d = door();
      final t = PricingTakeoff.of(d);
      expect(t.border.value, closeTo(6, 1e-9), reason: '100+100+200+200');
      final daylight = d.frame!.innerOutline;
      expect(t.openingProfile.value, closeTo(perimeter(daylight) / 1000, 5e-4));
      expect(t.openings.single.perimeter, t.openingProfile);
      // An angled border is its own polygon's perimeter.
      final a = given(sloped());
      expect(
        PricingTakeoff.of(a).border.value,
        // To the millimetre it is cut to.
        closeTo(2 + 1.5 + 1 + 1.1180340, 5e-4),
      );
    });

    test('2 & 6 & 27. every bar once, at the length it is cut to — a '
        'mullion between two openings counted once', () {
      final d = screen();
      final t = PricingTakeoff.of(d);
      final divs = t.runs.where((r) => r.use == ProfileUse.divider).toList();
      expect(divs, hasLength(d.dividers.length));
      expect({for (final r in divs) r.id}, hasLength(divs.length));
      final mullions = divs.where((r) => r.openingId == null).toList();
      expect(mullions, hasLength(3));
      // A full-height mullion is cut from the frame's inner face to the
      // other: the daylight's height.
      final inner = d.frame!.innerOutline;
      for (final m in mullions) {
        expect(m.length.value, closeTo(inner.height / 1000, 5e-4));
      }
      // The lines inside the openings are each that opening's, and cut to
      // the sash's daylight.
      final inside = divs.where((r) => r.openingId != null).toList();
      expect(inside, hasLength(2));
      expect(
        {for (final r in inside) r.openingId},
        {for (final o in d.openings) o.id},
      );
      expect(
        t.dividers.value,
        closeTo(divs.fold<double>(0, (s, r) => s + r.length.value), 1e-9),
      );
    });

    test('3 & 8. normal profile is the border and every line; a design '
        'with no lines has the border alone', () {
      final d = screen();
      final t = PricingTakeoff.of(d);
      expect(
        t.normalProfile.value,
        closeTo(t.border.value + t.dividers.value, 1e-12),
      );
      expect(PricingTakeoff.of(door()).dividers, Metres.zero);
    });

    test('5 & 26. several openings each measured once, never with the '
        'lines inside them, and never in the normal profile', () {
      final d = screen();
      final t = PricingTakeoff.of(d);
      expect(t.openings, hasLength(2));
      var sum = 0.0;
      for (final o in d.openingsInOrder) {
        final region = d.sectionById(o.sectionId)!.outline;
        final mine = t.openings.singleWhere((x) => x.id == o.id);
        expect(mine.perimeter.value, closeTo(perimeter(region) / 1000, 5e-4));
        sum += mine.perimeter.value;
      }
      expect(t.openingProfile.value, closeTo(sum, 1e-9));
      // A line drawn inside an opening adds to the normal profile and
      // leaves the opening's perimeter as it was.
      final d2 = DesignEdits.addLineInside(
        d,
        d.openingsInOrder.first.sectionId,
        id: 'more',
        at: d.sectionById(d.openingsInOrder.first.sectionId)!.outline.centroid,
        horizontal: false,
      );
      final t2 = PricingTakeoff.of(d2);
      expect(t2.openingProfile.value, closeTo(t.openingProfile.value, 1e-9));
      expect(t2.normalProfile.value, greaterThan(t.normalProfile.value));
      expect(t2.border.value, t.border.value);
      // Every run is counted once.
      final ids = [for (final r in t2.runs) '${r.use}:${r.id}'];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('7 & 8 & 9 & 10. panel and glass by the area each part is cut to, '
        'summed — never shared out, never invented', () {
      final d = screen();
      final t = PricingTakeoff.of(d);
      final geometry = DesignGeometry.of(d);
      final parts = Infill.partsOf(d);
      final panels = parts.where((p) => Infill.isPanel(p.finish)).toList();
      final glass = parts.where((p) => Infill.isGlass(p.finish)).toList();
      expect(panels, hasLength(2));
      expect(glass, hasLength(4));
      double area(Iterable<SectionElement> p) =>
          p.fold<double>(0, (s, x) => s + geometry.fillOf(x).area / 1e6);
      expect(t.panelArea.value, closeTo(area(panels), 1e-9));
      expect(t.glassArea.value, closeTo(area(glass), 1e-9));
      expect(t.panelRegions, 2);
      expect(t.glassRegions, 4);
      // Not half and half.
      expect(t.glassArea.value, isNot(closeTo(t.panelArea.value, 0.1)));
    });

    test('28. metres and square metres are kept apart — the total profile '
        'holds no area and no count, and each says its own unit', () {
      final t = PricingTakeoff.of(screen());
      final m = t.summary;
      expect(
        m.totalProfile.value,
        closeTo(
          m.normalProfile.value + m.openingProfile.value + m.otherProfile.value,
          1e-12,
        ),
      );
      expect(m.totalProfile.label, endsWith(' m'));
      expect(m.panelArea.label, endsWith(' m²'));
      expect(m.glassArea.label, endsWith(' m²'));
      expect(m.normalProfile, isA<Metres>());
      expect(m.panelArea, isA<SquareMetres>());
      // A length is kept and written to the millimetre.
      expect(Metres(56.8).label, '56.800 m');
      expect(SquareMetres(8.4).label, '8.4000 m²');
    });
  });

  group('material and colour', () {
    test('11 & 12 & 27. the same geometry in uPVC and in aluminium: each '
        'material\'s own normal and opening rates', () {
      final d = acceptance();
      final pvc = framedIn(
        d,
        const Finish(colour: 0xFFFFFFFF, material: MaterialKind.upvc),
      );
      final alu = framedIn(
        d,
        const Finish(colour: 0xFFFFFFFF, material: MaterialKind.aluminium),
      );
      final list = withProfile(
        withProfile(zero, MaterialKind.upvc, normal: 7, opening: 12),
        MaterialKind.aluminium,
        normal: 11,
        opening: 18,
      );
      // The lines inside are uPVC in both: they are bars of their own.
      expect(totalOf(pvc, list), closeTo(7.6 * 7 + 6 * 12, 1e-9));
      expect(totalOf(alu, list), closeTo(6 * 11 + 1.6 * 7 + 6 * 18, 1e-9));
      expect(pvc.frame!.outline, alu.frame!.outline);
      expect(
        totalOf(pvc, PriceList.starter),
        isNot(totalOf(alu, PriceList.starter)),
      );
    });

    test('13 & 14 & 27. a colour adds its own figure, a metre and a share, '
        'and what it adds depends on the material', () {
      final d = door();
      const pvcWhite = Finish(colour: 0xFFFFFFFF, material: MaterialKind.upvc);
      const pvcBlack = Finish(colour: 0xFF1C1C1C, material: MaterialKind.upvc);
      const aluBlack = Finish(
        colour: 0xFF1C1C1C,
        material: MaterialKind.aluminium,
      );
      final list = withProfile(
        withProfile(
          zero,
          MaterialKind.upvc,
          normal: 7,
          colours: [
            sold('White', 0xFFFFFFFF, ColourGrade.standard),
            sold(
              'Black',
              0xFF1C1C1C,
              ColourGrade.nonStandard,
              perMetre: 1,
            ),
          ],
          special: const ColourSurcharge(percent: 50),
        ),
        MaterialKind.aluminium,
        normal: 7,
        colours: [
          sold(
            'Black',
            0xFF1C1C1C,
            ColourGrade.nonStandard,
            perMetre: 2,
            percent: 10,
          ),
        ],
      );
      final white = totalOf(framedIn(d, pvcWhite), list);
      final black = totalOf(framedIn(d, pvcBlack), list);
      final alu = totalOf(framedIn(d, aluBlack), list);
      // The colour is on every metre of profile in it: the border and the
      // opening's, which this list charges nothing for itself.
      final t = PricingTakeoff.of(d);
      final coloured = t.normalProfile.value + t.openingProfile.value;
      double money(double v) => (v * 100).roundToDouble() / 100;
      expect(white, closeTo(6 * 7, 1e-9));
      expect(
        black,
        closeTo(42 + money(coloured * 1), 1e-9),
        reason: 'X + Y a metre',
      );
      expect(alu, closeTo(42 + money(coloured * 2) + 4.2, 1e-9));
      final colour = linesOf(
        framedIn(d, pvcBlack),
        list,
      ).singleWhere((l) => l.group == PriceGroup.colour);
      expect(colour.label, contains('Black'));
      expect(colour.label, contains('non-standard'));
      // A colour the list does not name — the house green among them — is
      // special, at the material's special rate.
      const brand = Finish(colour: 0xFF013E37, material: MaterialKind.upvc);
      expect(totalOf(framedIn(d, brand), list), closeTo(42 * 1.5, 1e-9));
      // Wood effect dearer than white in the starter list.
      const oak = Finish(colour: 0xFF7B4A2B, material: MaterialKind.upvc);
      expect(
        totalOf(framedIn(d, oak), PriceList.starter),
        greaterThan(totalOf(framedIn(d, pvcWhite), PriceList.starter)),
      );
    });
  });

  group('categories', () {
    test('15. a door: border, opening, its leaf\'s glass and its hardware', () {
      final d = door();
      final labels = linesOf(d, PriceList.starter).map((l) => l.group).toSet();
      expect(
        labels,
        containsAll([
          PriceGroup.normalProfile,
          PriceGroup.openingProfile,
          PriceGroup.glass,
          PriceGroup.hardware,
        ]),
      );
      expect(engine.price(d, PriceList.starter).measurements.openings, 1);
    });

    test('16. a window measured as the same sheet', () {
      final w = door(kind: DesignKind.window, id: 'w');
      expect(
        PricingTakeoff.of(w).totalProfile.value,
        closeTo(PricingTakeoff.of(door()).totalProfile.value, 1e-9),
      );
      expect(engine.price(w, PriceList.starter).isPriced, isTrue);
    });

    test('17. a sliding set: its track as other profile, the frame\'s '
        'width once, and the rollers its sliding panel runs on', () {
      final d = given(sliding.sheet(left: '>'));
      final t = PricingTakeoff.of(d);
      expect(t.otherProfile.value, closeTo(2.4, 1e-9));
      expect(
        t.summary.totalProfile.value,
        closeTo(t.normalProfile.value + t.openingProfile.value + 2.4, 1e-9),
      );
      final list = zero.copyWith(
        trackPerMetre: 10,
        rollerEach: 7,
        rollersPerSlidingPanel: 3,
      );
      expect(totalOf(d, list), closeTo(24 + 21, 1e-9));
      expect(
        totalOf(d, list.copyWith(rollersPerSlidingPanel: 2)),
        closeTo(24 + 14, 1e-9),
      );
    });

    test('18. a door & window set: each opening measured and furnished as '
        'its own', () {
      final d = screen();
      final kinds = [for (final o in d.openingsInOrder) d.kindOf(o)];
      expect(kinds, [DesignKind.window, DesignKind.door]);
      final locked = zero.copyWith(
        hardwareEach: {...zero.hardwareEach, HardwareKind.lock: 50},
      );
      expect(totalOf(d, locked), 50, reason: 'the door\'s lock, once');
      expect(PricingTakeoff.of(d).openings, hasLength(2));
    });

    test('19 & 22-angled. an angled design at its own measurements — '
        '1.75 m² inside, never the 2 m² of its box — and nothing squared', () {
      final d = given(sloped());
      final before = jsonEncode(d.toJson());
      final t = PricingTakeoff.of(d);
      expect(t.area.value, closeTo(1.75, 1e-9));
      final raked = d.openings.single;
      final region = d.sectionById(raked.sectionId)!.outline;
      expect(t.openingProfile.value, closeTo(perimeter(region) / 1000, 5e-4));
      expect(engine.price(d, PriceList.starter).isPriced, isTrue);
      expect(jsonEncode(d.toJson()), before);
    });

    test('20. a category from a later version: price unavailable, never a '
        'window\'s or a door\'s', () {
      final d = given(sloped());
      for (final saved in <Object?>['future_custom_shape', 'circular', 12345]) {
        final future = Design.fromJson(keptAs(d, saved));
        final r = engine.price(future, PriceList.starter);
        expect(r.status, PriceStatus.unsupportedCategory, reason: '$saved');
        expect(r.total, isNull);
        expect(r.lines, isEmpty);
        expect(r.category, isNot('window'));
        expect(r.category, isNot('door'));
      }
      expect(
        engine
            .price(
              Design.fromJson(keptAs(d, null, has: false)),
              PriceList.starter,
            )
            .status,
        PriceStatus.unsupportedCategory,
      );
    });

    test('a category with no strategy or no rate is not priced as another; '
        'a later one is a strategy registered and nothing else', () {
      final d = given(sliding.sheet(left: '>'));
      const noSliding = PricingEngine({'door': FramedPricing()});
      expect(
        noSliding.price(d, PriceList.starter).status,
        PriceStatus.unsupportedCategory,
      );
      final noRate = zero.copyWith(
        categories: {...zero.categories}..remove('sliding'),
      );
      expect(engine.price(d, noRate).status, PriceStatus.notConfigured);
      final custom = PricingEngine({
        ...PricingEngine.standard,
        'door': const _Flat(),
      });
      expect(custom.price(door(), zero).total, 1234);
    });
  });

  group('one design, and a customer\'s designs', () {
    test(
      '21. a design\'s price is its lines, each a measurement at a rate',
      () {
        final d = glassOverPanel(door());
        final list = example.copyWith(
          // The door's glass is built as a sealed unit, priced at the
          // sealed unit's own rate.
          sealedGlassPerM2: {...zero.sealedGlassPerM2, GlassLook.clear: 25},
          panelPerM2: {...zero.panelPerM2, PanelColour.white: 30},
          hardwareEach: {...zero.hardwareEach, HardwareKind.hinge: 3},
        );
        final r = engine.price(d, list);
        final t = PricingTakeoff.of(d);
        final hinges = t.hardwareCounts[HardwareKind.hinge]!;
        double money(double v) => (v * 100).roundToDouble() / 100;
        expect(
          r.total,
          closeTo(
            money(t.normalProfile.value * 7) +
                money(t.openingProfile.value * 12) +
                money(t.glassArea.value * 25) +
                money(t.panelArea.value * 30) +
                hinges * 3,
            1e-9,
          ),
        );
        for (final l in r.lines) {
          if (l.unit == PriceUnit.percent) continue;
          expect(l.amount, money(l.quantity * l.rate), reason: '$l');
        }
      },
    );

    test('32. three designs of one customer: each its own price and '
        'measurements, the total their sum, and a change to one moving '
        'the total by that one', () {
      final one = framedIn(
        acceptance(),
        const Finish(colour: 0xFFFFFFFF, material: MaterialKind.upvc),
      );
      final two = framedIn(
        glassOverPanel(door(kind: DesignKind.window, id: 'two')),
        const Finish(colour: 0xFF383E42, material: MaterialKind.aluminium),
      );
      final three = framedIn(
        given(sloped(id: 'three')),
        const Finish(colour: 0xFF7B4A2B, material: MaterialKind.upvc),
      );
      final designs = [one, two, three];
      final texts = [for (final d in designs) jsonEncode(d.toJson())];
      final list = PriceList.starter;
      PriceRecord rec(Design d) => PriceRecord.calculate(d, list)!;
      final adam = CustomerPricing.of([
        for (final d in designs) (d, rec(d)),
      ], list);
      expect(adam.designs, hasLength(3));
      expect(adam.isFinal, isTrue);
      final each = [for (final d in designs) engine.price(d, list)];
      expect({for (final r in each) r.total}, hasLength(3));
      expect(
        adam.total,
        closeTo(each.fold<double>(0, (s, r) => s + r.total!), 1e-6),
      );
      // 23. the measurements, summed — metres with metres and square
      // metres with square metres.
      final m = adam.measurements;
      double sum(double Function(MeasurementSummary) f) =>
          each.fold<double>(0, (s, r) => s + f(r.measurements));
      expect(
        m.normalProfile.value,
        closeTo(sum((x) => x.normalProfile.value), 1e-9),
      );
      expect(
        m.openingProfile.value,
        closeTo(sum((x) => x.openingProfile.value), 1e-9),
      );
      expect(
        m.totalProfile.value,
        closeTo(sum((x) => x.totalProfile.value), 1e-9),
      );
      expect(m.panelArea.value, closeTo(sum((x) => x.panelArea.value), 1e-9));
      expect(m.glassArea.value, closeTo(sum((x) => x.glassArea.value), 1e-9));
      for (var i = 0; i < 3; i++) {
        expect(adam.designs[i].state.total, each[i].total);
        expect(jsonEncode(designs[i].toJson()), texts[i]);
      }

      // The second made wider: it alone changes, and the total by it.
      final wider = Measurements.apply(two, {Measurements.widthKey: 1200});
      expect(wider.ok, isTrue);
      final after = CustomerPricing.of([
        (one, rec(one)),
        (wider.design, rec(wider.design)),
        (three, rec(three)),
      ], list);
      final grew = engine.price(wider.design, list).total! - each[1].total!;
      expect(grew, greaterThan(0));
      expect(after.total, closeTo(adam.total! + grew, 1e-6));
      expect(after.designs[0].state.total, each[0].total);
      expect(after.designs[2].state.total, each[2].total);

      // A design that cannot be priced is listed and left out.
      final future = Design.fromJson(keptAs(three, 'future_custom_shape'));
      final some = CustomerPricing.of([
        (one, rec(one)),
        (two, rec(two)),
        (future, null),
      ], list);
      expect(some.isFinal, isFalse);
      expect(some.total, isNull);
      expect(some.cannotBePriced, 1);
      expect(some.pricedSoFar, closeTo(each[0].total! + each[1].total!, 1e-6));
    });
  });

  group('kept, read back and changed', () {
    test('24. the design\'s pricing choices and its measurements come back '
        'from a save and a load as they went', () {
      final d = acceptance().copyWith(
        pricing: const PricingChoices(
          installation: true,
          discount: Discount(percent: 5),
        ),
      );
      final back = Design.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(back.pricing, d.pricing);
      expect(jsonEncode(back.toJson()), jsonEncode(d.toJson()));
      final a = engine.price(d, PriceList.starter);
      final b = engine.price(back, PriceList.starter);
      expect(b.total, a.total);
      expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
      // A kept price keeps its measurements, and a dearer list leaves it be.
      final snap = PriceSnapshot(takenAt: DateTime(2026, 10, 4), result: a);
      final kept = Design.fromJson(
        jsonDecode(
          jsonEncode(
            d.copyWith(pricing: PricingChoices(snapshot: snap)).toJson(),
          ),
        ),
      );
      final dearer = withProfile(
        PriceList.starter,
        MaterialKind.upvc,
        normal: 99,
        opening: 99,
      ).copyWith(version: 7);
      expect(engine.price(kept, dearer).total, isNot(a.total));
      expect(kept.pricing.snapshot!.result.total, a.total);
      expect(
        kept.pricing.snapshot!.result.measurements.normalProfile.label,
        '7.600 m',
      );
    });

    test('25. pricing reads the design and writes nothing', () {
      for (final d in [
        door(),
        acceptance(),
        screen(),
        given(sloped()),
        given(sliding.sheet(left: '>')),
      ]) {
        final before = jsonEncode(d.toJson());
        engine.price(d, PriceList.starter);
        PricingTakeoff.of(d);
        CustomerPricing.of([(d, null), (d, null)], PriceList.starter);
        expect(jsonEncode(d.toJson()), before);
      }
    });

    test('16 & 17 & 29. a new width, height, rate or list each gives a new '
        'price, from the same measurement', () {
      final d = door();
      final wider = Measurements.apply(d, {Measurements.widthKey: 1200});
      final taller = Measurements.apply(d, {Measurements.heightKey: 2400});
      expect(PricingTakeoff.of(wider.design).border.value, closeTo(6.4, 1e-9));
      expect(PricingTakeoff.of(taller.design).border.value, closeTo(6.8, 1e-9));
      final at7 = totalOf(d, example);
      final at8 = totalOf(
        d,
        withProfile(zero, MaterialKind.upvc, normal: 8, opening: 12),
      );
      final t = PricingTakeoff.of(d);
      expect(at8 - at7, closeTo(t.normalProfile.value, 0.011));
      // Glass to panel.
      final pane = Infill.partsOf(d).single;
      final panel = d.withElement(
        pane.copyWith(finish: PanelColour.white.finish),
      );
      expect(
        totalOf(panel, PriceList.starter),
        isNot(totalOf(d, PriceList.starter)),
      );
    });

    test('30. a design kept before pricing opens unchanged and is priced', () {
      // Without the choices `given` makes since Phase 33, so it is a design
      // with no pricing at all, as one kept before pricing was.
      final d = door().copyWith(pricing: PricingChoices.none);
      final json = d.toJson();
      expect(json.containsKey('pricing'), isFalse);
      final old = Design.fromJson(jsonDecode(jsonEncode(json)));
      expect(old.pricing.isNone, isTrue);
      expect(jsonEncode(old.toJson()), jsonEncode(json));
      final older = Design.fromJson(
        jsonDecode(jsonEncode({...json}..remove('measured'))),
      );
      expect(engine.price(older, PriceList.starter).isPriced, isTrue);
    });
  });

  group('what cannot be priced is said, never guessed', () {
    test('missing data: a frame material, a glass, a piece the list has no '
        'price for; nothing drawn; no sizes', () {
      final d = door();
      final wood = framedIn(
        d,
        const Finish(colour: 0xFF7B4A2B, material: MaterialKind.wood),
      );
      final r = engine.price(wood, zero);
      expect(r.status, PriceStatus.notConfigured);
      expect(r.total, isNull);
      expect(r.issues.single.message, contains('Wood profile'));
      expect(
        r.measurements.normalProfile.value,
        closeTo(6, 1e-9),
        reason: 'measured all the same',
      );
      expect(
        // The door's glass is a sealed unit: no sealed rate, no price —
        // never the single-sheet rate in its stead.
        engine.price(d, zero.copyWith(sealedGlassPerM2: const {})).status,
        PriceStatus.notConfigured,
      );
      final noHinge = zero.copyWith(
        hardwareEach: {...zero.hardwareEach}..remove(HardwareKind.hinge),
      );
      expect(engine.price(d, noHinge).issues.single.message, contains('hinge'));
      expect(
        engine.price(Design.empty(id: 'e', kind: DesignKind.door), zero).status,
        PriceStatus.nothingToPrice,
      );
      final asked = engine.price(door().copyWith(measured: {}), zero);
      expect(asked.status, PriceStatus.needsSizes);
      expect(asked.total, isNull);
    });

    test('invalid dimensions: a state, never NaN, infinity or a negative '
        'price', () {
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
      }
      for (final x in [door(), acceptance(), screen(), given(sloped())]) {
        for (final l in engine.price(x, PriceList.starter).lines) {
          expect(l.amount.isFinite && l.amount >= 0, isTrue, reason: '$l');
        }
      }
    });

    test('installation only when chosen; a discount never below nothing', () {
      final d = acceptance();
      final list = example.copyWith(
        installation: const InstallationRate(fixed: 100, perSquareMetre: 10),
      );
      expect(engine.price(d, list).sumOf(PriceGroup.installation), 0);
      final fitted = engine.price(
        d,
        list,
        choices: const PricingChoices(installation: true),
      );
      expect(fitted.sumOf(PriceGroup.installation), closeTo(120, 1e-9));
      PriceResult off(Discount discount) =>
          engine.price(d, example, choices: PricingChoices(discount: discount));
      expect(off(const Discount(percent: 10)).total, closeTo(112.68, 1e-9));
      expect(off(const Discount(amount: 5000)).total, 0);
    });
  });

  group('the price list, kept and guarded', () {
    test('29. the owner\'s list is kept and read back; a design priced by it '
        'says which list', () async {
      final store = PriceListStore();
      expect((await store.load()).isStarter, isTrue);
      final kept = await store.save(example, by: WorkshopRole.owner);
      expect(kept.version, 1);
      final again = await PriceListStore().load();
      expect(jsonEncode(again.toJson()), jsonEncode(kept.toJson()));
      expect(again.profiles[MaterialKind.upvc]!.normalPerMetre, 7);
      expect(again.profiles[MaterialKind.upvc]!.openingPerMetre, 12);
      expect(totalOf(acceptance(), again), closeTo(125.20, 1e-9));
      final second = await store.save(again, by: WorkshopRole.owner);
      expect(engine.price(door(), second).priceListVersion, 2);
    });

    test('staff may price but not change prices', () async {
      final store = PriceListStore();
      expect(WorkshopRole.staff.canConfigurePrices, isFalse);
      expect(WorkshopRole.owner.canConfigurePrices, isTrue);
      await expectLater(
        store.save(zero, by: WorkshopRole.staff),
        throwsA(isA<PricingAccessDenied>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
    });

    test('a list that cannot be read is left alone, a figure that is not a '
        'price is left out, and the starter list round-trips', () async {
      SharedPreferences.setMockInitialValues({PriceListStore.key: '{bad'});
      expect((await PriceListStore().load()).isStarter, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), '{bad');

      final json = jsonDecode(
        jsonEncode(PriceList.starter.toJson()),
      ) as Map<String, Object?>;
      (json['glassPerM2']! as Map<String, Object?>)['clear'] = -5;
      (json['sealedGlassPerM2']! as Map<String, Object?>)['clear'] = -5;
      final read = PriceList.fromJson(json)!;
      expect(read.glassPerM2.containsKey(GlassLook.clear), isFalse);
      expect(read.sealedGlassPerM2.containsKey(GlassLook.clear), isFalse);
      expect(engine.price(door(), read).status, PriceStatus.notConfigured);

      final back = PriceList.fromJson(
        jsonDecode(jsonEncode(PriceList.starter.toJson())),
      )!;
      expect(jsonEncode(back.toJson()), jsonEncode(PriceList.starter.toJson()));
      for (final kind in DesignKind.categories) {
        expect(back.categories[kind.name], isNotNull, reason: kind.name);
      }
    });
  });
}

class _Flat extends CategoryPricing {
  const _Flat();

  @override
  void price(PricingTakeoff takeoff, PriceSheet sheet) => sheet.add(
    PriceGroup.normalProfile,
    'Everything',
    1,
    PriceUnit.fixed,
    1234,
  );
}

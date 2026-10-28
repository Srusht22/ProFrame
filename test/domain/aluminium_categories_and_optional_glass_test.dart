import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/design_pricing.dart';
import 'package:proframe/domain/pricing/extra_charge.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_fields.dart';
import 'package:proframe/domain/pricing/price_readiness.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_category.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/domain/sections/section_builder.dart';

import 'financial_records_test.dart' show pricingOf, usd;
import 'pricing_engine_test.dart'
    show acceptance, door, engine, example, given, zero;

// Phase 33's pricing, on the design's own geometry and on price lists whose
// every figure the test sets:
//
// - aluminium is two profile categories, System and Bend Shoulder, each
//   its own rate, and a part is priced as the category somebody said it
//   is — never one worked out from how the design looks;
// - the border and the lines are measured and charged apart, at the rate
//   they share, and add up to the whole;
// - glass is charged only once the user includes it, off by default,
//   while the geometry goes on saying how much glass there is.

const alu = Finish(colour: 0xFFC0C4C8, material: MaterialKind.aluminium);

/// [list] with aluminium's border and lines at [system] and [bend] a
/// metre, and its opening profile at nothing.
PriceList aluminiumAt(PriceList list, {double? system, double? bend}) =>
    list.copyWith(
      profiles: {
        ...list.profiles,
        MaterialKind.aluminium: ProfileRate(
          openingPerMetre: 0,
          categories: {
            ProfileCategory.systemAluminium: ?system,
            ProfileCategory.bendShoulderAluminium: ?bend,
          },
        ),
      },
    );

/// A 600 × 400 cm aluminium frame with no profile of its own — so every
/// figure is the brief's exactly — and two mullions running its height: a
/// border of 6 + 4 + 6 + 4 m and lines of 4 + 4 m. Nothing opens.
Design brief() {
  const frame = FrameElement(
    id: 'frame',
    outline: Polygon([
      Vec2(0, 0),
      Vec2(6000, 0),
      Vec2(6000, 4000),
      Vec2(0, 4000),
    ]),
    profileMm: 0,
    finish: alu,
  );
  final d = SectionBuilder.rebuild(
    Design.empty(id: 'brief', kind: DesignKind.window).copyWith(
      name: 'Shop front',
      frame: frame,
      dividers: const [
        DividerElement(
          id: 'mullion-1',
          a: Vec2(2000, 0),
          b: Vec2(2000, 4000),
          finish: alu,
        ),
        DividerElement(
          id: 'mullion-2',
          a: Vec2(4000, 0),
          b: Vec2(4000, 4000),
          finish: alu,
        ),
      ],
    ),
  );
  // Complete, with nothing said about its pricing: no category, glass not
  // included — as a new design starts.
  return given(d).copyWith(pricing: PricingChoices.none);
}

/// The frame member of [d] at [placement]: *Head*, *Sill*, *Left jamb*.
String member(Design d, String placement) =>
    d.frameMembers.singleWhere((m) => m.placement == placement).id;

/// [d] with its whole profile said to be [category], then each part in
/// [each] said to be its own.
Design said(
  Design d,
  ProfileCategory? category, [
  Map<String, ProfileCategory> each = const {},
]) {
  var out = DesignPricing.setProfileCategory(
    d,
    category,
    by: WorkshopRole.owner,
  );
  for (final MapEntry(key: part, value: c) in each.entries) {
    out = DesignPricing.setProfileCategory(
      out,
      c,
      part: part,
      by: WorkshopRole.owner,
    );
  }
  return out;
}

List<PriceLine> profileLines(PriceResult r) => [
  for (final l in r.lines)
    if (l.group == PriceGroup.normalProfile) l,
];

PriceLine lineFor(PriceResult r, ProfileCategory? c, ProfilePart part) =>
    profileLines(r).singleWhere((l) => l.category == c && l.part == part);

/// A clear fixed light of exactly 3 m² of glass — 150 × 200 cm in a frame
/// with no profile — and nothing else.
Design threeSquareMetres() {
  const frame = FrameElement(
    id: 'frame',
    outline: Polygon([
      Vec2(0, 0),
      Vec2(1500, 0),
      Vec2(1500, 2000),
      Vec2(0, 2000),
    ]),
    profileMm: 0,
  );
  final d = SectionBuilder.rebuild(
    Design.empty(
      id: 'light',
      kind: DesignKind.window,
    ).copyWith(name: 'Kitchen Window', frame: frame),
  );
  return given(d).copyWith(pricing: PricingChoices.none);
}

/// [list] with clear glass at [rate] a square metre, single sheet and
/// sealed unit alike.
PriceList glassAt(PriceList list, double rate) => list.copyWith(
  glassPerM2: {...list.glassPerM2, GlassLook.clear: rate},
  sealedGlassPerM2: {...list.sealedGlassPerM2, GlassLook.clear: rate},
);

String geometryOf(Design d) {
  final json = d.toJson()
    ..remove('pricing')
    ..remove('updatedAt');
  return jsonEncode(json);
}

void main() {
  group('aluminium is two profile categories, each its own rate', () {
    test('acceptance A: System border 12 m and lines 4 m at 8, Bend Shoulder '
        'border 8 m and lines 4 m at 11 — 96 + 32 + 88 + 44 = 260', () {
      final d0 = brief();
      final d = said(d0, ProfileCategory.systemAluminium, {
        member(d0, 'Left jamb'): ProfileCategory.bendShoulderAluminium,
        member(d0, 'Right jamb'): ProfileCategory.bendShoulderAluminium,
        'mullion-2': ProfileCategory.bendShoulderAluminium,
      });
      final list = aluminiumAt(zero, system: 8, bend: 11);
      final r = engine.price(d, list);
      expect(r.status, PriceStatus.priced, reason: '${r.issues}');

      const sys = ProfileCategory.systemAluminium;
      const bend = ProfileCategory.bendShoulderAluminium;
      final rows = {
        for (final (c, p, metres, rate, amount) in [
          (sys, ProfilePart.border, 12.0, 8.0, 96.0),
          (sys, ProfilePart.lines, 4.0, 8.0, 32.0),
          (bend, ProfilePart.border, 8.0, 11.0, 88.0),
          (bend, ProfilePart.lines, 4.0, 11.0, 44.0),
        ])
          (c, p): (metres, rate, amount),
      };
      for (final MapEntry(key: (c, p), value: (m, rate, amount))
          in rows.entries) {
        final line = lineFor(r, c, p);
        expect(line.quantity, closeTo(m, 1e-9), reason: '${c.label} $p');
        expect(line.unit, PriceUnit.metre);
        expect(line.rate, rate);
        expect(line.amount, amount);
        expect(line.label, '${c.label} — ${p.label}');
      }
      // Four rows, never one unexplained figure; together the whole.
      expect(profileLines(r), hasLength(4));
      expect(r.sumOf(PriceGroup.normalProfile), 260);
      expect(r.total, 260);
      // And the lengths: each part apart, and 28 m together.
      expect(r.measurements.borderLength.value, closeTo(20, 1e-9));
      expect(r.measurements.lineLength.value, closeTo(8, 1e-9));
      expect(r.measurements.normalProfile.value, closeTo(28, 1e-9));
      expect(
        profileLines(r).fold<double>(0, (sum, l) => sum + l.quantity),
        closeTo(28, 1e-9),
      );
    });

    test('changing the System rate never changes the Bend Shoulder rate, '
        'and the other way round', () {
      final d0 = brief();
      final d = said(d0, ProfileCategory.systemAluminium, {
        'mullion-2': ProfileCategory.bendShoulderAluminium,
      });
      final base = engine.price(d, aluminiumAt(zero, system: 8, bend: 11));
      final dearerSystem = engine.price(
        d,
        aluminiumAt(zero, system: 9, bend: 11),
      );
      final dearerBend = engine.price(
        d,
        aluminiumAt(zero, system: 8, bend: 12),
      );
      const sys = ProfileCategory.systemAluminium;
      const bend = ProfileCategory.bendShoulderAluminium;
      expect(lineFor(dearerSystem, sys, ProfilePart.border).rate, 9);
      expect(
        lineFor(dearerSystem, bend, ProfilePart.lines).amount,
        lineFor(base, bend, ProfilePart.lines).amount,
      );
      expect(lineFor(dearerBend, bend, ProfilePart.lines).rate, 12);
      expect(
        lineFor(dearerBend, sys, ProfilePart.border).amount,
        lineFor(base, sys, ProfilePart.border).amount,
      );
      // 24 m of System at one more a metre; 4 m of Bend Shoulder at one more.
      expect(dearerSystem.total! - base.total!, closeTo(24, 1e-9));
      expect(dearerBend.total! - base.total!, closeTo(4, 1e-9));
    });

    test('the price list keeps each category its own figure, edited as its '
        'own field, through a save and a read', () {
      final list = aluminiumAt(zero, system: 8, bend: 11);
      final again = PriceList.fromJson(jsonDecode(jsonEncode(list.toJson())))!;
      final rate = again.profiles[MaterialKind.aluminium]!;
      expect(rate.categories[ProfileCategory.systemAluminium], 8);
      expect(rate.categories[ProfileCategory.bendShoulderAluminium], 11);
      expect(rate.normalPerMetre, isNull, reason: 'no third figure');

      final fields = RateField.of(list);
      final system = fields.singleWhere(
        (f) => f.id == 'profile.aluminium.systemAluminium',
      );
      final bend = fields.singleWhere(
        (f) => f.id == 'profile.aluminium.bendShoulderAluminium',
      );
      expect(system.label, 'System Aluminium');
      expect(bend.label, 'Bend Shoulder Aluminium');
      expect(
        fields.where((f) => f.id == 'profile.aluminium.normal'),
        isEmpty,
        reason: 'aluminium has no single border rate any more',
      );
      final edited = system.write(list, 9.5);
      expect(system.read(edited), 9.5);
      expect(bend.read(edited), 11, reason: 'the other category untouched');
      // Editing the opening rate keeps both categories.
      final opening = fields.singleWhere(
        (f) => f.id == 'profile.aluminium.opening',
      );
      final both = opening.write(edited, 18);
      expect(system.read(both), 9.5);
      expect(bend.read(both), 11);
    });

    test('a category with no rate is not priced — never at the other '
        "category's rate", () {
      final d = said(brief(), ProfileCategory.bendShoulderAluminium);
      final r = engine.price(d, aluminiumAt(zero, system: 8));
      expect(r.isPriced, isFalse);
      expect(
        r.issues.map((i) => i.message),
        contains(
          'The price list has no price for Bend Shoulder Aluminium border '
          'and lines.',
        ),
      );
    });

    test('PVC is priced as it always was, and a category means nothing to '
        'it', () {
      final pvc = door().copyWith(pricing: PricingChoices.none);
      final asSystem = said(pvc, ProfileCategory.systemAluminium);
      final a = engine.price(pvc, example);
      final b = engine.price(asSystem, example);
      expect(a.total, b.total);
      expect(PriceReadiness.of(pvc).isPriceCalculable, isTrue);
      expect(profileLines(a).every((l) => l.category == null), isTrue);
      expect(profileLines(a).single.label, 'uPVC — Border');
      expect(profileLines(a).single.rate, 7);
    });

    test('nobody said which: the design is incomplete and nothing is priced '
        'at either rate', () {
      final d = brief();
      final ready = PriceReadiness.of(d);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.missing.single.kind, PriceRequirementKind.profileCategory);
      expect(
        ready.message,
        'Please choose whether the aluminium profile is System Aluminium or '
        'Bend Shoulder Aluminium to calculate the price.',
      );
      final r = engine.price(d, aluminiumAt(zero, system: 8, bend: 11));
      expect(r.isPriced, isFalse);
      expect(r.lines, isEmpty);

      // One part said and the rest not: those still to say are named.
      final some = said(d, null, {
        member(d, 'Head'): ProfileCategory.systemAluminium,
      });
      final named = PriceReadiness.of(some).missing.single.message;
      expect(named, contains('Sill'));
      expect(named, contains('Line 1'));
      expect(named, isNot(contains('Head')));

      // A design whose only gap is this is opened to choose it, as a
      // material is.
      final state = DesignPriceState.of(d, zero, null);
      expect(state.needsOnlyProfile, isTrue);
    });

    test('saying the whole design clears single parts; a part can then be '
        'said apart, and taken back to follow the design', () {
      final d0 = brief();
      final head = member(d0, 'Head');
      final d = said(d0, null, {head: ProfileCategory.bendShoulderAluminium});
      final all = said(d, ProfileCategory.systemAluminium);
      expect(all.pricing.profileCategoryOf, isEmpty);
      final apart = DesignPricing.setProfileCategory(
        all,
        ProfileCategory.bendShoulderAluminium,
        part: head,
        by: WorkshopRole.owner,
      );
      expect(
        ProfileAllocation.partsOf(apart)
            .singleWhere((p) => p.key == head)
            .category,
        ProfileCategory.bendShoulderAluminium,
      );
      final back = DesignPricing.setProfileCategory(
        apart,
        null,
        part: head,
        by: WorkshopRole.owner,
      );
      expect(
        ProfileAllocation.partsOf(back)
            .singleWhere((p) => p.key == head)
            .category,
        ProfileCategory.systemAluminium,
      );
    });

    test('only somebody who may edit the design says its category', () {
      expect(
        () => DesignPricing.setProfileCategory(
          brief(),
          ProfileCategory.systemAluminium,
          by: const NobodySignedIn(),
        ),
        throwsA(isA<AccessDenied>()),
      );
    });

    test('the category is kept with the design, and moves no geometry', () {
      final d0 = brief();
      final d = said(d0, ProfileCategory.systemAluminium, {
        'mullion-1': ProfileCategory.bendShoulderAluminium,
      });
      final again = Design.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(again.pricing.profileCategory, ProfileCategory.systemAluminium);
      expect(
        again.pricing.profileCategoryOf['mullion-1'],
        ProfileCategory.bendShoulderAluminium,
      );
      expect(geometryOf(again), geometryOf(d0));
    });

    test('an older price list: its single aluminium rate goes to neither '
        'category, and says so', () {
      final old = zero.toJson();
      old['schemaVersion'] = 4;
      (old['profiles']! as Map<String, Object?>)['aluminium'] = {
        'normalPerMetre': 11,
        'openingPerMetre': 18,
      };
      final read = PriceList.fromJson(old)!;
      final rate = read.profiles[MaterialKind.aluminium]!;
      expect(rate.categories, isEmpty);
      expect(rate.normalPerMetre, isNull);
      expect(rate.openingPerMetre, 18);
      expect(read.migratedFrom, 4);
      expect(read.migrationNotes.single, contains('System Aluminium'));
      // uPVC is carried as it was.
      expect(read.profiles[MaterialKind.upvc]!.normalPerMetre, 0);
    });
  });

  group('the border and the lines, measured and charged apart', () {
    test(
      '20 m of border and 8 m of lines at one rate of 7: 140 + 56 = 196',
      () {
        final d = said(brief(), ProfileCategory.systemAluminium);
        final r = engine.price(d, aluminiumAt(zero, system: 7, bend: 7));
        const sys = ProfileCategory.systemAluminium;
        final border = lineFor(r, sys, ProfilePart.border);
        final lines = lineFor(r, sys, ProfilePart.lines);
        expect(border.quantity, closeTo(20, 1e-9));
        expect(border.amount, 140);
        expect(lines.quantity, closeTo(8, 1e-9));
        expect(lines.amount, 56);
        expect(border.rate, lines.rate);
        expect(r.sumOf(PriceGroup.normalProfile), 196);
      },
    );

    test('every segment once: the border is the outline, a line is never '
        'border, and a line inside an opening is a line, never the '
        "opening's perimeter", () {
      final d = acceptance();
      final t = PricingTakeoff.of(d);
      expect(t.border.value, closeTo(6, 1e-9));
      expect(t.dividers.value, closeTo(1.6, 1e-9));
      final summary = t.summary;
      expect(summary.borderLength.value, closeTo(6, 1e-9));
      expect(summary.lineLength.value, closeTo(1.6, 1e-9));
      expect(
        summary.normalProfile.mm,
        summary.borderLength.mm + summary.lineLength.mm,
      );
      expect(summary.openingProfile.value, closeTo(6, 1e-9));
      // Each frame side its own run, and they are the border exactly.
      final sides = t.runs.where((r) => r.use == ProfileUse.border).toList();
      expect(sides, hasLength(4));
      expect({for (final s in sides) s.id}.length, 4);
    });

    test('a measurement kept before the two were apart reads as it was', () {
      final old = {
        'normalProfileM': 7.6,
        'openingProfileM': 6.0,
        'otherProfileM': 0,
        'panelM2': 1.8933,
        'glassM2': 0,
        'hardwarePieces': 6,
        'openings': 1,
      };
      final read = PriceResult.fromJson({
        'status': 'priced',
        'currency': 'USD',
        'category': 'door',
        'measurements': old,
      }).measurements;
      expect(read.normalProfile.value, closeTo(7.6, 1e-9));
      expect(read.splitsBorder, isFalse);
    });
  });

  group('glass is optional, and off until the user includes it', () {
    test('a new design does not include glass', () {
      expect(
        Design.empty(id: 'new', kind: DesignKind.window).pricing.glassPriced,
        isFalse,
      );
      expect(const PricingChoices().glassPriced, isFalse);
    });

    test('acceptance B, a panel-only door: glass not used and nothing '
        'charged; it is priced', () {
      final d = acceptance().copyWith(pricing: PricingChoices.none);
      final r = engine.price(d, glassAt(example, 20));
      expect(r.isPriced, isTrue, reason: '${r.issues}');
      expect(r.sumOf(PriceGroup.glass), 0);
      expect(r.glassState, GlassState.notUsed);
      expect(r.glassState.words, 'Not used');
    });

    test('acceptance B, 3 m² of glass at 20: not included 0, included 60, '
        'not included again 0 — and the geometry never moves', () {
      final d = threeSquareMetres();
      final list = glassAt(zero, 20);
      expect(PricingTakeoff.of(d).glassArea.value, closeTo(3, 1e-9));

      final off = engine.price(d, list);
      expect(off.isPriced, isTrue, reason: '${off.issues}');
      expect(off.sumOf(PriceGroup.glass), 0);
      expect(off.glassState, GlassState.notIncluded);
      expect(off.glassState.words, 'Not included');
      expect(
        off.measurements.glassArea.value,
        closeTo(3, 1e-9),
        reason: 'the area is still said',
      );

      final on = DesignPricing.setGlassPriced(d, true, by: WorkshopRole.owner);
      final priced = engine.price(on, list);
      expect(priced.sumOf(PriceGroup.glass), 60);
      expect(priced.glassState, GlassState.charged);
      expect(priced.total! - off.total!, closeTo(60, 1e-9));

      final offAgain = DesignPricing.setGlassPriced(
        on,
        false,
        by: WorkshopRole.owner,
      );
      expect(engine.price(offAgain, list).sumOf(PriceGroup.glass), 0);
      for (final x in [on, offAgain]) {
        expect(geometryOf(x), geometryOf(d));
      }
    });

    test('a window is not charged glass for being a window', () {
      final d = threeSquareMetres();
      expect(d.kind, DesignKind.window);
      expect(engine.price(d, glassAt(zero, 20)).sumOf(PriceGroup.glass), 0);
    });

    test('included with no measurable glass: nothing made up, and said', () {
      final d = DesignPricing.setGlassPriced(
        acceptance().copyWith(pricing: PricingChoices.none),
        true,
        by: WorkshopRole.owner,
      );
      final r = engine.price(d, glassAt(example, 20));
      expect(r.isPriced, isTrue);
      expect(r.sumOf(PriceGroup.glass), 0);
      expect(r.measurements.glassArea.value, 0);
      expect(r.glassState, GlassState.nothingToCharge);
      expect(r.glassState.words, 'No measurable glass to price');
      expect(Infill.partsOf(d).every((p) => !Infill.isGlass(p.finish)), isTrue);
    });

    test('the switch is kept, read back, and a design kept before it has it '
        'off', () {
      final on = DesignPricing.setGlassPriced(
        threeSquareMetres(),
        true,
        by: WorkshopRole.owner,
      );
      final again = Design.fromJson(jsonDecode(jsonEncode(on.toJson())));
      expect(again.pricing.glassPriced, isTrue);
      final older = on.toJson();
      (older['pricing']! as Map<String, Object?>).remove('glassPriced');
      expect(Design.fromJson(older).pricing.glassPriced, isFalse);
    });

    test('turning it on makes a kept price stale; turning it on asks for '
        'designs.edit', () {
      final d = threeSquareMetres();
      final list = glassAt(zero, 20);
      final record = PriceRecord.calculate(d, list)!;
      final on = DesignPricing.setGlassPriced(d, true, by: WorkshopRole.owner);
      expect(
        DesignPriceState.of(on, list, record).status,
        DesignPriceStatus.needsRecalculation,
      );
      expect(
        () => DesignPricing.setGlassPriced(d, true, by: const NobodySignedIn()),
        throwsA(isA<AccessDenied>()),
      );
    });

    test('glass charged is not charged again as an extra by accident; glass '
        'not included is no duplicate', () {
      final d = threeSquareMetres();
      final list = glassAt(zero, 20);
      final glassExtra = ExtraCharge(
        id: 'EXT-1',
        name: 'Glass',
        category: ExtraCategory.material,
        quantityMilli: 1000,
        unit: 'piece',
        unitPriceCents: 1000,
        currency: 'USD',
        scope: ExtraScope.design,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final off = engine.price(d, list);
      final allowed = DesignPricing.putExtra(
        d,
        glassExtra,
        by: WorkshopRole.owner,
        calculated: off.lines,
        money: usd,
      );
      expect(allowed.problem, isNull);
      final on = DesignPricing.setGlassPriced(d, true, by: WorkshopRole.owner);
      final refused = DesignPricing.putExtra(
        on,
        glassExtra,
        by: WorkshopRole.owner,
        calculated: engine.price(on, list).lines,
        money: usd,
      );
      expect(refused.problem, contains('already calculated'));
      final additional = DesignPricing.putExtra(
        on,
        glassExtra,
        by: WorkshopRole.owner,
        calculated: engine.price(on, list).lines,
        additional: true,
        money: usd,
      );
      expect(additional.problem, isNull);
    });

    test('a quotation keeps the glass as it was: included, its area, its '
        'rate, its cost — whatever the design does after', () {
      final on = DesignPricing.setGlassPriced(
        threeSquareMetres(),
        true,
        by: WorkshopRole.owner,
      );
      final list = glassAt(zero, 20);
      final made = Quotation.build(
        customerId: 'adam',
        customerName: 'Adam',
        chosen: pricingOf([on], list).designs,
        currency: 'USD',
        number: 1,
        now: DateTime(2026, 10, 10),
        by: 'Owner',
        money: usd,
      ).quotation!;
      final kept = Quotation.fromJson(jsonDecode(jsonEncode(made.toJson())))!;
      final result = kept.lines.single.result;
      expect(result.glassPriced, isTrue);
      expect(result.measurements.glassArea.value, closeTo(3, 1e-9));
      final glass = result.lines.singleWhere(
        (l) => l.group == PriceGroup.glass,
      );
      expect(glass.rate, 20);
      expect(glass.amount, 60);
      expect(kept.totalCents, made.totalCents);
      // The design's glass turned off afterwards changes nothing kept.
      final off = DesignPricing.setGlassPriced(
        on,
        false,
        by: WorkshopRole.owner,
      );
      expect(engine.price(off, list).sumOf(PriceGroup.glass), 0);
      expect(
        kept.lines.single.result.lines
            .singleWhere((l) => l.group == PriceGroup.glass)
            .amount,
        60,
      );
    });
  });
}

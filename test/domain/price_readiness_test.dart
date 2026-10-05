import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_readiness.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_sliding_design_test.dart' as sliding;
import 'an_unknown_category_test.dart' show keptAs, sloped;
import 'geometry_normalizer_test.dart' show pen;
import 'payment_history_test.dart' show paid;
import 'pricing_engine_test.dart'
    show acceptance, door, example, framedIn, given, glassOverPanel, zero;

// Whether a design can be priced, said once and read everywhere: the
// engine, the workspace's button, a design's card and its customer's
// total. Then the price the user calculated, kept with what it was
// calculated from — current only while nothing has changed — and the
// customer's total and money, worked out from the designs and never kept.

const engine = PricingEngine();

/// [d] with the size under [key] said to be unknown again.
Design without(Design d, String key) =>
    d.copyWith(measured: {...?d.measured}..remove(key));

/// A price list where each category costs a fixed figure for its making
/// and nothing else, and installation a fixed hundred — so a design's price
/// is a figure the test chose.
final fixed = zero.copyWith(
  categories: {
    ...zero.categories,
    'door': const CategoryRate('Door', LabourRate(fixed: 800)),
    'window': const CategoryRate('Window', LabourRate(fixed: 500)),
    'sliding': const CategoryRate('Sliding', LabourRate(fixed: 700)),
  },
  installation: const InstallationRate(fixed: 100),
);

/// The angled outline drawn crossing itself.
Design bowTie() => SketchInterpreter.interpret(
  Design.empty(id: 'bow', kind: DesignKind.angled).copyWith(
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1200, 2000),
          Vec2(1200, 0),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
      ],
    ),
  ),
).design;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('completeness', () {
    test('a complete design: nothing missing, and the engine prices it', () {
      for (final d in [door(), acceptance(), glassOverPanel(door())]) {
        final ready = PriceReadiness.of(d);
        expect(ready.isPriceCalculable, isTrue, reason: ready.message);
        expect(ready.message, isEmpty);
        expect(engine.price(d, example).isPriced, isTrue);
      }
    });

    test('nothing drawn, and an outline not closed into a frame: '
        'incomplete, the frame named', () {
      final empty = Design.empty(id: 'e', kind: DesignKind.door);
      expect(
        PriceReadiness.of(empty).missing.single.kind,
        PriceRequirementKind.frame,
      );
      final open = empty.copyWith(
        sketch: Sketch(
          strokes: [
            pen('l', const [Vec2(0, 0), Vec2(0, 2000)]),
          ],
        ),
      );
      final ready = PriceReadiness.of(open);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.message, contains('complete the outer frame'));
      expect(engine.price(open, example).total, isNull);
    });

    test('a missing overall size: incomplete, the size named, and no price '
        'at all — never one worked out from the sketch', () {
      final d = without(door(), Measurements.widthKey);
      final ready = PriceReadiness.of(d);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.missing.single.kind, PriceRequirementKind.sizes);
      expect(
        ready.message,
        'Please give the overall width to calculate the '
        'price.',
      );
      final r = engine.price(d, example);
      expect(r.status, PriceStatus.needsSizes);
      expect(r.total, isNull);
      expect(r.lines, isEmpty);
      expect(r.measurements.totalProfile.value, 0);
    });

    test('an opening whose dimensions are not given: incomplete, the '
        'opening named', () {
      // A line drawn inside the opening asks the height of the pane it
      // made; nothing else is unknown.
      final d = door();
      final opening = d.openings.single;
      final box = d.sectionById(opening.sectionId)!.outline;
      final divided = DesignEdits.addLineInside(
        d,
        opening.sectionId,
        id: 'inside',
        at: Vec2(box.centroid.x, box.top + box.height * 0.4),
        horizontal: true,
      );
      final ready = PriceReadiness.of(divided);
      expect(ready.isPriceCalculable, isFalse);
      // The line is a bar, so its thickness is asked too.
      expect(ready.missing.map((m) => m.kind).toSet(), {
        PriceRequirementKind.sizes,
      });
      expect(
        ready.missing.map((m) => m.message),
        containsAll([
          'Please give the bar thickness to calculate the price.',
          'Please complete the dimensions of Opening 1 — Clear glass 1 (its '
              'height) to calculate the price.',
        ]),
      );
      expect(ready.message, endsWith('1 more thing needs completing too.'));
      expect(engine.price(divided, example).total, isNull);
      // Given, it is complete.
      expect(PriceReadiness.of(given(divided)).isPriceCalculable, isTrue);
    });

    test('an opening nobody has said is a door or a window, in a design '
        'begun as holding both: incomplete, that opening named', () {
      final d = door(kind: DesignKind.both);
      final ready = PriceReadiness.of(d);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.missing.single.kind, PriceRequirementKind.openingKind);
      expect(
        ready.message,
        'Please say whether Opening 1 is a door or a window to calculate '
        'the price.',
      );
      final said = d.withElement(
        d.openings.single.copyWith(kind: DesignKind.door),
      );
      expect(PriceReadiness.of(said).isPriceCalculable, isTrue);
    });

    test('what a door is built of not said, and which parts are glass or '
        'panel not said: incomplete, never assumed glass or half and half', () {
      final pending = door().copyWith(construction: Construction.pending);
      expect(
        PriceReadiness.of(pending).missing.single.kind,
        PriceRequirementKind.construction,
      );
      final both = door().copyWith(construction: Construction.both);
      final ready = PriceReadiness.of(both);
      expect(ready.missing.single.kind, PriceRequirementKind.panelOrGlass);
      expect(ready.message, contains('panel/glass selection'));
      expect(engine.price(both, example).total, isNull);
      expect(
        PriceReadiness.of(both.copyWith(partsAsked: true)).isPriceCalculable,
        isTrue,
      );
      for (final c in [Construction.panel, Construction.glass]) {
        expect(
          PriceReadiness.of(door().copyWith(construction: c)).isPriceCalculable,
          isTrue,
        );
      }
    });

    test('geometry that cannot be built: incomplete, the problem said', () {
      final d = bowTie();
      final ready = PriceReadiness.of(d);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.missing.first.kind, PriceRequirementKind.geometry);
      expect(ready.message, startsWith('Please correct the geometry'));
      expect(engine.price(d, example).total, isNull);
    });

    test('a complete angled design is priced at its own geometry — its '
        'polygon\'s own area, never its box\'s', () {
      final d = given(sloped());
      expect(PriceReadiness.of(d).isPriceCalculable, isTrue);
      final r = engine.price(d, example);
      expect(r.isPriced, isTrue);
      final outline = d.frame!.outline;
      final box = outline.width * outline.height / 1e6;
      expect(
        PricingTakeoff.of(d).area.value,
        closeTo(outline.area / 1e6, 1e-9),
      );
      expect(PricingTakeoff.of(d).area.value, lessThan(box - 0.01));
    });

    test('a category this version does not know: unsupported, never a '
        'window, and nothing priced', () {
      final d = Design.fromJson(keptAs(given(sloped()), 'future_shape'));
      expect(d.kind, DesignKind.unsupported);
      final ready = PriceReadiness.of(d);
      expect(
        ready.missing.single.kind,
        PriceRequirementKind.unsupportedCategory,
      );
      final state = DesignPriceState.of(d, example, null);
      expect(state.status, DesignPriceStatus.unsupported);
      expect(state.canCalculate, isFalse);
      expect(state.message, 'Unsupported category. Price unavailable.');
      expect(PriceRecord.calculate(d, example), isNull);
      expect(engine.price(d, example).status, PriceStatus.unsupportedCategory);
    });

    test('a design kept before sizes were asked has nothing outstanding', () {
      final old = Design.fromJson(door().toJson()..remove('measured'));
      expect(old.measured, isNull);
      expect(PriceReadiness.of(old).isPriceCalculable, isTrue);
    });

    test('asking writes nothing to the design', () {
      final d = without(door(), Measurements.heightKey);
      final before = jsonEncode(d.toJson());
      PriceReadiness.of(d);
      DesignPriceState.of(d, example, null);
      expect(jsonEncode(d.toJson()), before);
    });
  });

  group('a kept price, and when it stops being the price', () {
    test('calculated: current while nothing changes — through a save and a '
        'load of the design and of the record', () async {
      final d = door();
      final record = PriceRecord.calculate(d, example)!;
      expect(
        DesignPriceState.of(d, example, null).status,
        DesignPriceStatus.notCalculated,
      );
      final state = DesignPriceState.of(d, example, record);
      expect(state.status, DesignPriceStatus.current);
      expect(state.total, engine.price(d, example).total);

      final reloaded = Design.fromJson(jsonDecode(jsonEncode(d.toJson())));
      final store = PriceRecordStore();
      await store.save(d.id, record);
      final kept = await store.load(d.id);
      expect(kept, isNotNull);
      final again = DesignPriceState.of(reloaded, example, kept);
      expect(again.status, DesignPriceStatus.current);
      expect(again.total, state.total);

      // Renamed, or given to another customer: the same price.
      final renamed = d.copyWith(name: 'Front Entrance Door');
      expect(
        DesignPriceState.of(renamed, example, record).status,
        DesignPriceStatus.current,
      );
    });

    test('43. the geometry changed: the price kept is a previous '
        'calculation, never the price; calculated again, the new one', () {
      final d = door();
      final record = PriceRecord.calculate(d, example)!;
      final wider = Measurements.apply(d, {Measurements.widthKey: 1200}).design;
      final stale = DesignPriceState.of(wider, example, record);
      expect(stale.status, DesignPriceStatus.needsRecalculation);
      expect(stale.total, isNull);
      expect(stale.previous, record.total);
      expect(stale.note, 'Price needs recalculation');
      expect(stale.canCalculate, isTrue);
      final fresh = PriceRecord.calculate(wider, example)!;
      final now = DesignPriceState.of(wider, example, fresh);
      expect(now.status, DesignPriceStatus.current);
      expect(now.total, greaterThan(record.total));
    });

    test('26. a material, a colour, a glass, a panel, ironmongery or an '
        'option changed: the kept price is stale', () {
      final d = glassOverPanel(door());
      final record = PriceRecord.calculate(d, example)!;
      final frame = d.frame!;
      final pane = d.sections.firstWhere(
        (s) => s.parentId != null && Infill.isGlass(s.finish),
      );
      final opening = d.openings.single;
      final changes = {
        'aluminium': d.withElement(
          frame.copyWith(
            finish: frame.finish.copyWith(material: MaterialKind.aluminium),
          ),
        ),
        'a colour': d.withElement(
          frame.copyWith(finish: frame.finish.copyWith(colour: 0xFF383E42)),
        ),
        'a glass': d.withElement(
          pane.copyWith(finish: GlassLook.frosted.finish),
        ),
        'a panel': d.withElement(
          pane.copyWith(finish: PanelColour.brown.finish),
        ),
        'a hinge more': d.withElement(opening.copyWith(hingeCount: 4)),
        'installation': d.copyWith(
          pricing: d.pricing.copyWith(installation: true),
        ),
      };
      for (final MapEntry(key: what, value: changed) in changes.entries) {
        expect(
          DesignPriceState.of(changed, example, record).status,
          DesignPriceStatus.needsRecalculation,
          reason: what,
        );
      }
    });

    test('the price list changed: the kept price is stale', () {
      final d = door();
      final record = PriceRecord.calculate(d, example)!;
      final dearer = example.copyWith(version: example.version + 1);
      expect(
        DesignPriceState.of(d, dearer, record).status,
        DesignPriceStatus.needsRecalculation,
      );
    });

    test('24. a complete design made incomplete: no price, the kept one '
        'shown only as a previous calculation', () {
      final d = door();
      final record = PriceRecord.calculate(d, example)!;
      final broken = without(d, Measurements.heightKey);
      final state = DesignPriceState.of(broken, example, record);
      expect(state.status, DesignPriceStatus.incomplete);
      expect(state.canCalculate, isFalse);
      expect(state.total, isNull);
      expect(state.previous, record.total);
      expect(state.note, 'Price unavailable until design is completed');
      expect(state.message, contains('overall height'));
      // Completed again, it needs no recalculation: nothing it was priced
      // from is different.
      expect(
        DesignPriceState.of(d, example, record).status,
        DesignPriceStatus.current,
      );
    });

    test('a record that cannot be read is no price at all', () async {
      SharedPreferences.setMockInitialValues({
        PriceRecordStore.keyOf('door'): '{not json',
      });
      expect(await PriceRecordStore().load('door'), isNull);
      expect(PriceRecord.fromJson({'inputs': 'x'}), isNull);
    });
  });

  group('a customer\'s total', () {
    final a = door(id: 'a');
    final b = door(kind: DesignKind.window, id: 'b');
    final c = Design.fromJson(
      given(sliding.sheet(left: '>')).toJson()..['id'] = 'c',
    );
    PriceRecord rec(Design d) => PriceRecord.calculate(d, fixed)!;

    test('40. three designs, 800, 500 and 700: 2,000 — and the 500 made '
        '600 and calculated: 2,100, with nothing typed on the customer', () {
      expect(engine.price(a, fixed).total, 800);
      expect(engine.price(b, fixed).total, 500);
      expect(engine.price(c, fixed).total, 700);
      final before = CustomerPricing.of([
        (a, rec(a)),
        (b, rec(b)),
        (c, rec(c)),
      ], fixed);
      expect(before.status, CustomerTotalStatus.isFinal);
      expect(before.total, 2000);

      final b600 = b.copyWith(pricing: b.pricing.copyWith(installation: true));
      // Changed and not yet calculated: the total is not presented as 2,000.
      final changed = CustomerPricing.of([
        (a, rec(a)),
        (b600, rec(b)),
        (c, rec(c)),
      ], fixed);
      expect(changed.status, CustomerTotalStatus.needsRecalculation);
      expect(changed.total, isNull);
      expect(changed.notFinalReason, '1 design needs its price calculated.');

      final after = CustomerPricing.of([
        (a, rec(a)),
        (b600, rec(b600)),
        (c, rec(c)),
      ], fixed);
      expect(after.designs[1].state.total, 600);
      expect(after.total, 2100);
    });

    test('42. one design incomplete: the total is not final, and the sum of '
        'the others is never the total', () {
      final broken = without(c, Measurements.widthKey);
      final pricing = CustomerPricing.of([
        (a, rec(a)),
        (b, rec(b)),
        (broken, null),
      ], fixed);
      expect(pricing.status, CustomerTotalStatus.notFinal);
      expect(pricing.isFinal, isFalse);
      expect(pricing.total, isNull);
      expect(pricing.pricedSoFar, 1300);
      expect(pricing.incomplete, 1);
      expect(pricing.notFinalReason, '1 design is incomplete.');
      final finance = CustomerFinance.of(pricing, paid(500));
      expect(finance.total, isNull);
      expect(finance.due, isNull);
      expect(finance.status, PaymentStatus.pricingIncomplete);
    });

    test('a design deleted leaves the total of the rest; a design added is '
        'in the total once its price is calculated', () {
      final three = CustomerPricing.of([
        (a, rec(a)),
        (b, rec(b)),
        (c, rec(c)),
      ], fixed);
      final two = CustomerPricing.of([(a, rec(a)), (c, rec(c))], fixed);
      expect(two.total, three.total! - 500);
      final d = door(id: 'd');
      final added = CustomerPricing.of([
        (a, rec(a)),
        (c, rec(c)),
        (d, null),
      ], fixed);
      expect(added.status, CustomerTotalStatus.needsRecalculation);
      final calculated = CustomerPricing.of([
        (a, rec(a)),
        (c, rec(c)),
        (d, rec(d)),
      ], fixed);
      expect(calculated.total, 2300);
    });

    test('14. what the designs measure together: metres with metres and '
        'square metres with square metres', () {
      final designs = [a, glassOverPanel(door(id: 'e')), c];
      final pricing = CustomerPricing.of([
        for (final d in designs) (d, PriceRecord.calculate(d, example)),
      ], example);
      final each = [for (final d in designs) engine.price(d, example)];
      double sum(double Function(PriceResult) f) =>
          each.fold(0, (s, r) => s + f(r));
      final m = pricing.measurements;
      expect(
        m.totalProfile.value,
        closeTo(sum((r) => r.measurements.totalProfile.value), 1e-9),
      );
      expect(
        m.totalProfile.value,
        closeTo(
          m.normalProfile.value + m.openingProfile.value + m.otherProfile.value,
          1e-9,
        ),
      );
      expect(
        m.panelArea.value,
        closeTo(sum((r) => r.measurements.panelArea.value), 1e-9),
      );
      expect(
        m.glassArea.value,
        closeTo(sum((r) => r.measurements.glassArea.value), 1e-9),
      );
    });

    test('45. a design of an unknown category keeps the total from being '
        'final, and is never priced', () {
      final future = Design.fromJson(keptAs(given(sloped()), 'future_shape'));
      final pricing = CustomerPricing.of([(a, rec(a)), (future, null)], fixed);
      expect(pricing.cannotBePriced, 1);
      expect(pricing.total, isNull);
      expect(pricing.pricedSoFar, 800);
    });
  });

  group('the customer\'s money', () {
    final a = door(id: 'a');
    final b = door(
      kind: DesignKind.window,
      id: 'b',
    ).copyWith(pricing: const PricingChoices(installation: true));
    final c = Design.fromJson(
      given(sliding.sheet(left: '>')).toJson()..['id'] = 'c',
    );
    final pricing = CustomerPricing.of([
      for (final d in [a, b, c]) (d, PriceRecord.calculate(d, fixed)),
    ], fixed);

    test('41. 2,100 with 1,000 paid: 1,100 due; with 2,100 paid: paid in '
        'full and nothing due', () {
      expect(pricing.total, 2100);
      // Since Phase 30 what was paid is the ledger's, and a customer who
      // still owes something is Outstanding.
      final part = CustomerFinance.of(pricing, paid(1000));
      expect(part.total, 2100);
      expect(part.netPaid, 1000);
      expect(part.due, 1100);
      expect(part.status, PaymentStatus.outstanding);
      expect(part.status.label, 'Outstanding');
      final all = CustomerFinance.of(pricing, paid(2100));
      expect(all.due, 0);
      expect(all.status, PaymentStatus.paidInFull);
      expect(all.status.label, 'Paid in full');
    });

    test('nothing paid: all of it due', () {
      final none = CustomerFinance.of(pricing, PaymentLedger.empty);
      expect(none.due, 2100);
      expect(none.status, PaymentStatus.outstanding);
    });

    // Phase 30 made more than the total credit, by the brief's own words —
    // it is no longer refused. Less than nothing and what is not a number
    // still are, by the ledger (`payment_history_test.dart`).
    test('more than the total is credit; less than nothing, nothing and '
        'what is not a number are refused', () {
      final over = CustomerFinance.of(pricing, paid(2100.01));
      expect(over.due, 0);
      expect(over.credit, 0.01);
      for (final text in ['-1', '0', 'abc', 'NaN']) {
        expect(PaymentLedger.readAmount(text).cents, isNull, reason: text);
      }
    });

    test('a total that fell below what was paid is credit, never a debt '
        'below nothing', () {
      final less = CustomerPricing.of([
        (a, PriceRecord.calculate(a, fixed)),
      ], fixed);
      final over = CustomerFinance.of(less, paid(1500));
      expect(over.status, PaymentStatus.credit);
      expect(over.due, 0);
      expect(over.credit, 700);
    });

    // Since Phase 30 the customer keeps a ledger of payments, not one paid
    // figure; an older customer's figure is read as one legacy payment.
    test('what was paid is kept on the customer as its ledger, and nothing '
        'else money is: an older customer has paid nothing recorded', () {
      final adam = Customer(
        id: 'adam',
        name: 'Adam',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );
      expect(adam.toJson().containsKey('payments'), isFalse);
      expect(Customer.fromJson(adam.toJson()).payments, isEmpty);
      final payer = adam.copyWith(payments: paid(1500).transactions);
      final back = Customer.fromJson(
        jsonDecode(jsonEncode(payer.toJson())) as Map<String, Object?>,
      );
      expect(back.ledger.netPaidCents('USD'), 150000);
      expect(back.toJson().keys, isNot(contains('total')));
      expect(back.toJson().keys, isNot(contains('paid')));
      for (final bad in [-5, 'lots', double.nan]) {
        expect(
          Customer.fromJson({...adam.toJson(), 'paid': bad}).payments,
          isEmpty,
          reason: '$bad',
        );
      }
    });

    test('19. payment touches no design and no price', () {
      final texts = [
        for (final d in [a, b, c]) jsonEncode(d.toJson()),
      ];
      CustomerFinance.of(pricing, paid(1000));
      CustomerFinance.of(pricing, paid(2100));
      for (final (i, d) in [a, b, c].indexed) {
        expect(jsonEncode(d.toJson()), texts[i]);
      }
      expect(pricing.total, 2100);
    });
  });

  test('a design in a frame of another colour is the same completeness', () {
    final d = framedIn(
      door(),
      const Finish(colour: 0xFF383E42, material: MaterialKind.aluminium),
    );
    expect(PriceReadiness.of(d).isPriceCalculable, isTrue);
  });
}

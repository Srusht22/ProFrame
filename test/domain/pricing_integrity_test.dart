import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/default_factory_pricing.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/measurement.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_migration.dart';
import 'package:proframe/domain/pricing/price_readiness.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_sliding_design_test.dart' as sliding;
import 'payment_history_test.dart' show paid;
import 'price_readiness_test.dart' show fixed, without;
import 'pricing_engine_test.dart'
    show door, example, given, glassOverPanel, zero;

// The price can be trusted: never of a drawing nobody is looking at, never
// of a design that is gone, never off by a rounding, and read from the
// workshop's list whatever version kept it.

const engine = PricingEngine();

/// [d] with lines drawn on its sheet since it was last read.
Design drawnOn(Design d) => d.copyWith(sketchUnread: true);

/// A list as the first engine kept it (schema 1), written out the way its
/// `toJson` wrote it — frame, sash and bar by the metre, a colour by a
/// percentage, a price per leaf and per angled joint.
Map<String, Object?> firstEngineList() => {
  'version': 4,
  'currency': 'IQD',
  'profiles': {
    'upvc': {
      'framePerMetre': 9000,
      'sashPerMetre': 11000,
      'barPerMetre': 8000,
      'colours': [
        {
          'name': 'White',
          'colour': 0xFFFFFFFF,
          'grade': 'standard',
          'surchargePercent': 0,
        },
        {
          'name': 'Oak effect',
          'colour': 0xFF7B4A2B,
          'grade': 'nonStandard',
          'surchargePercent': 15,
        },
      ],
      'specialColourPercent': 25,
    },
  },
  'glassPerM2': {'clear': 30000, 'frosted': 36000},
  'customGlassPerM2': 42000,
  'panelPerM2': {'white': 33000},
  'customPanelPerM2': 40000,
  'hardwareEach': {'hinge': 4000, 'lever': 15000, 'lock': 20000},
  'leafEach': {'door': 25000, 'window': 12000},
  'trackPerMetre': 7000,
  'rollerEach': 3000,
  'rollersPerSlidingPanel': 2,
  'angledJointEach': 5000,
  'categories': {
    'door': {
      'label': 'Door',
      'labour': {'fixed': 10000, 'perSquareMetre': 0, 'percent': 5},
    },
  },
  'installation': {'fixed': 20000, 'perSquareMetre': 8000},
};

// Since Phase 31 the store asks who records money (`by:`); these record as
// the device with no staff accounts, which may (`WorkshopRole.staff`).
// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('30. a drawing changed since it was read is never priced', () {
    test('drawn on and not read: not price-ready, the engine prices '
        'nothing, and it says to Read first', () {
      final d = drawnOn(door());
      final ready = PriceReadiness.of(d);
      expect(ready.isPriceCalculable, isFalse);
      expect(ready.missing.single.kind, PriceRequirementKind.notRead);
      expect(
        ready.message,
        'The drawing has changes that have not been read. Please Read the '
        'drawing before calculating the price.',
      );
      final r = engine.price(d, example);
      expect(r.status, PriceStatus.notRead);
      expect(r.total, isNull);
      expect(r.lines, isEmpty);
      expect(PriceRecord.calculate(d, example), isNull);
    });

    test('a price calculated before the drawing changed is a previous '
        'calculation, not the price — on the card too — until it is read', () {
      final d = door();
      final record = PriceRecord.calculate(d, example)!;
      final state = DesignPriceState.of(drawnOn(d), example, record);
      expect(state.status, DesignPriceStatus.incomplete);
      expect(state.notRead, isTrue);
      expect(state.canCalculate, isFalse);
      expect(state.total, isNull);
      expect(state.previous, record.total);
      expect(state.label, 'Drawing not read');
      expect(state.note, 'Price unavailable until drawing is read');
      // Read, and nothing it was priced from changed: the price again.
      expect(
        DesignPriceState.of(d, example, record).status,
        DesignPriceStatus.current,
      );
    });

    test('the flag is the design\'s own: saved, read back, and nothing '
        'written while it is not set', () {
      final unread = drawnOn(door());
      final json = jsonDecode(jsonEncode(unread.toJson())) as Map;
      expect(json['sketchUnread'], isTrue);
      expect(Design.fromJson(json).sketchUnread, isTrue);
      expect(door().toJson().containsKey('sketchUnread'), isFalse);
    });
  });

  test('31. a width changed makes the kept price stale; calculated again, '
      'the new width is the new price', () {
    final d = door();
    final record = PriceRecord.calculate(d, example)!;
    final wider = Measurements.apply(d, {Measurements.widthKey: 1200}).design;
    expect(
      DesignPriceState.of(wider, example, record).status,
      DesignPriceStatus.needsRecalculation,
    );
    final again = PriceRecord.calculate(wider, example)!;
    expect(
      again.result.measurements.normalProfile.mm,
      greaterThan(record.result.measurements.normalProfile.mm),
    );
    expect(again.total, greaterThan(record.total));
  });

  group('32. a deleted design takes its price with it', () {
    test('its record is gone, the others\' stay, and the customer total '
        'is the rest', () async {
      final people = CustomerStore();
      final adam = await people.create(name: 'Adam', by: WorkshopRole.owner);
      final store = DesignStore(customers: people);
      final records = PriceRecordStore();
      final a = door(id: 'a');
      final b = door(kind: DesignKind.window, id: 'b');
      final c = door(id: 'c');
      for (final d in [a, b, c]) {
        await store.save(d.copyWith(customerId: adam.id), by: WorkshopRole.owner);
        await records.save(d.id, PriceRecord.calculate(d, fixed)!);
      }
      final prefs = await SharedPreferences.getInstance();
      final otherKeys = {
        for (final k in prefs.getKeys())
          if (!k.contains('.b') && k != DesignStore.indexKey) k: prefs.get(k),
      };

      await store.remove('b', by: WorkshopRole.owner);
      expect(await store.load('b'), isNull);
      expect(await records.load('b'), isNull);
      expect(prefs.getString(PriceRecordStore.keyOf('b')), isNull);
      expect(await records.load('a'), isNotNull);
      expect(await records.load('c'), isNotNull);
      // Nothing else on the device changed.
      for (final MapEntry(:key, :value) in otherKeys.entries) {
        expect(prefs.get(key), value, reason: key);
      }

      final kept = (await store.page(customerId: adam.id)).items;
      final pricing = CustomerPricing.of([
        for (final s in kept)
          ((await store.load(s.id))!, await records.load(s.id)),
      ], fixed);
      expect(pricing.designs.map((d) => d.designId).toSet(), {'a', 'c'});
      expect(pricing.total, 1600);
    });
  });

  group('33. a price list kept by an earlier version', () {
    test('the first engine\'s list is migrated: what has a place carried '
        'at the same figure, what has none named, nothing made up', () {
      final json = firstEngineList();
      expect(PriceListMigration.schemaOf(json), 1);
      final list = PriceList.fromJson(json)!;
      expect(list.migratedFrom, 1);
      expect(list.currency, 'IQD');
      expect(list.version, 4);
      final upvc = list.profiles[MaterialKind.upvc]!;
      expect(upvc.normalPerMetre, 9000, reason: 'frame → normal profile');
      expect(upvc.openingPerMetre, 11000, reason: 'sash → opening profile');
      expect(
        list.colourFor(MaterialKind.upvc, 0xFF7B4A2B).surcharge.percent,
        15,
      );
      expect(
        list.colourFor(MaterialKind.upvc, 0xFF7B4A2B).surcharge.perMetre,
        0,
      );
      expect(
        list.colourFor(MaterialKind.upvc, 0xFF123456).surcharge.percent,
        25,
      );
      expect(list.glassPerM2, {
        GlassLook.clear: 30000,
        GlassLook.frosted: 36000,
      });
      expect(list.customGlassPerM2, 42000);
      // Glass priced every pane then, so a sealed unit's rate is that rate.
      expect(list.sealedGlassPerM2, list.glassPerM2);
      expect(list.customSealedGlassPerM2, 42000);
      expect(list.panelPerM2, {PanelColour.white: 33000});
      expect(list.hardwareEach[HardwareKind.lever], 15000);
      expect(list.trackPerMetre, 7000);
      expect(list.rollerEach, 3000);
      expect(list.rollersPerSlidingPanel, 2);
      expect(list.categories['door']!.labour.percent, 5);
      expect(list.installation.fixed, 20000);
      final notes = list.migrationNotes.join(' ');
      expect(notes, contains('bar rate (8000'));
      expect(notes, contains('door 25000'));
      expect(notes, contains('angled joint (5000)'));
    });

    test('a factory-model list kept before sealed units had a rate prices '
        'them at the glass rate it had', () {
      final json =
          jsonDecode(jsonEncode(DefaultFactoryPricing.list.toJson()))
                as Map<String, Object?>
            ..remove('schemaVersion')
            ..remove('sealedGlassPerM2')
            ..remove('customSealedGlassPerM2');
      expect(PriceListMigration.schemaOf(json), 2);
      final list = PriceList.fromJson(json)!;
      expect(list.migratedFrom, 2);
      expect(list.sealedGlassPerM2, DefaultFactoryPricing.list.glassPerM2);
      expect(list.profiles, isNotEmpty);
      expect(
        list.profiles[MaterialKind.upvc]!.normalPerMetre,
        DefaultFactoryPricing.list.profiles[MaterialKind.upvc]!.normalPerMetre,
      );
    });

    test('the current list reads as itself, with no migration', () {
      final list = PriceList.fromJson(
        jsonDecode(jsonEncode(DefaultFactoryPricing.list.toJson())),
      )!;
      expect(list.migratedFrom, isNull);
      expect(list.migrationNotes, isEmpty);
      expect(
        DefaultFactoryPricing.list.toJson()['schemaVersion'],
        PriceList.schemaVersion,
      );
    });

    test('on the device: the old list is read from where the first engine '
        'kept it, reading writes nothing, and once kept by the owner it is '
        'the current schema and reloads as itself', () async {
      SharedPreferences.setMockInitialValues({
        PriceListStore.legacyKey: jsonEncode(firstEngineList()),
      });
      final store = PriceListStore();
      final read = await store.load();
      expect(read.isStarter, isFalse);
      expect(read.migratedFrom, 1);
      expect(read.profiles[MaterialKind.upvc]!.normalPerMetre, 9000);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
      expect(
        prefs.getString(PriceListStore.legacyKey),
        jsonEncode(firstEngineList()),
      );

      final kept = await store.save(read, by: WorkshopRole.owner);
      expect(kept.migratedFrom, isNull);
      final stored = jsonDecode(
        prefs.getString(PriceListStore.key)!,
      ) as Map<String, Object?>;
      expect(stored['schemaVersion'], PriceList.schemaVersion);
      final again = await store.load();
      expect(again.migratedFrom, isNull);
      expect(again.profiles[MaterialKind.upvc]!.openingPerMetre, 11000);
      expect(again.sealedGlassPerM2[GlassLook.clear], 30000);
      expect(again.version, 5);
    });
  });

  test('13 & 14. the example rates are written in one place, and the '
      'engine reads whatever list it is given', () {
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (RegExp(r'normalPerMetre:\s*7\b').hasMatch(text) ||
          RegExp(r'openingPerMetre:\s*12\b').hasMatch(text)) {
        hits.add(file.path);
      }
    }
    expect(hits, ['lib/domain/pricing/default_factory_pricing.dart']);
    expect(identical(PriceList.starter, DefaultFactoryPricing.list), isTrue);
    // Another list, another price: nothing in the engine is the example.
    final d = door();
    final dearer = example.copyWith(
      profiles: {
        MaterialKind.upvc: const ProfileRate(
          normalPerMetre: 20,
          openingPerMetre: 30,
        ),
      },
    );
    expect(
      engine.price(d, dearer).total,
      greaterThan(engine.price(d, example).total!),
    );
  });

  group('34. lengths are exact: what is written adds up', () {
    test('20.98 + 14.23 is 35.21', () {
      final sum = Metres(20.98) + Metres(14.23);
      expect(sum.mm, 35210);
      expect(sum.value, 35.21);
      expect(sum.label, '35.210 m');
    });

    test('rows of fractions of a metre sum to the total written, to the '
        'millimetre', () {
      final rows = [
        Metres.ofMm(20975.4),
        Metres.ofMm(14234.6),
        Metres.ofMm(0.4),
        Metres.ofMm(1999.5),
      ];
      final total = rows.fold(Metres.zero, (a, b) => a + b);
      final written = rows.fold<double>(
        0,
        (a, r) => a + double.parse(r.label.split(' ').first),
      );
      expect(
        double.parse(total.label.split(' ').first),
        closeTo(written, 1e-9),
      );
    });

    test('on a real design, normal and opening profile as written add to '
        'the total profile as written', () {
      for (final d in [
        door(),
        glassOverPanel(door()),
        given(sliding.sheet(left: '>')),
      ]) {
        final m = PricingTakeoff.of(d).summary;
        double read(Metres x) => double.parse(x.label.split(' ').first);
        expect(
          read(m.normalProfile) + read(m.openingProfile) + read(m.otherProfile),
          closeTo(read(m.totalProfile), 1e-9),
        );
      }
    });
  });

  group('35. money is whole cents, added as cents', () {
    test('10.10 + 20.20 is 30.30, not 30.299999…', () {
      expect(Money.cents(10.10) + Money.cents(20.20), 3030);
      expect(Money.of(Money.cents(10.10) + Money.cents(20.20)), 30.30);
      expect(Money.cents(0.105), 11, reason: 'half a cent rounds up');
      expect(Money.cents(7.6 * 7), 5320);
    });

    test('a design\'s total is exactly the sum of its lines as written', () {
      for (final d in [
        door(),
        glassOverPanel(door()),
        given(sliding.sheet(left: '>')),
      ]) {
        final r = engine.price(d, PriceList.starter);
        expect(r.isPriced, isTrue, reason: '${r.issues}');
        final written = r.lines.fold<int>(
          0,
          (sum, l) =>
              sum + (double.parse(l.amount.toStringAsFixed(2)) * 100).round(),
        );
        expect(r.totalCents, written);
        for (final group in PriceGroup.values) {
          final cents = r.lines
              .where((l) => l.group == group)
              .fold<int>(0, (s, l) => s + l.amountCents);
          expect(Money.cents(r.sumOf(group)), cents);
        }
      }
    });

    test('a customer\'s total is the sum of the designs\' totals as cents', () {
      final designs = [door(id: 'a'), glassOverPanel(door(id: 'b'))];
      final pricing = CustomerPricing.of([
        for (final d in designs)
          (d, PriceRecord.calculate(d, PriceList.starter)),
      ], PriceList.starter);
      expect(
        pricing.totalCents,
        designs.fold<int>(
          0,
          (s, d) => s + engine.price(d, PriceList.starter).totalCents!,
        ),
      );
    });
  });

  group('36. a sealed glazing unit has its own rate', () {
    test('2.00 m² of sealed glass at X a square metre is 2.00 × X, and '
        'never the single-sheet rate', () {
      final d = door();
      final glass = Infill.partsOf(d).single;
      expect(PricingTakeoff.sealedUnitsOf(d), contains(glass.id));
      final area = PricingTakeoff.of(d).glassArea;
      const x = 55.0;
      final list = zero.copyWith(
        glassPerM2: {...zero.glassPerM2, GlassLook.clear: 25},
        sealedGlassPerM2: {...zero.sealedGlassPerM2, GlassLook.clear: x},
      );
      final line = engine
          .price(d, list)
          .lines
          .singleWhere((l) => l.group == PriceGroup.glass);
      expect(line.label, 'Sealed unit — Clear glass');
      expect(line.rate, x);
      expect(line.amountCents, Money.cents(area.value * x));
      // With its rate an even 2 m², the arithmetic is the brief's own.
      expect(Money.cents(2.00 * x), 11000);
    });

    test('glass the solid builds as a single sheet — a panel in a track too '
        'thin for a cavity — is priced at the glass rate', () {
      final d = sliding.fitted(
        given(sliding.sheet(left: '>')),
        (o) => o.copyWith(pleatedScreen: true),
      );
      expect(PricingTakeoff.of(d).regions.where((r) => r.sealed), isEmpty);
      final list = zero.copyWith(
        glassPerM2: {...zero.glassPerM2, GlassLook.clear: 25},
        sealedGlassPerM2: {...zero.sealedGlassPerM2, GlassLook.clear: 55},
      );
      final line = engine
          .price(d, list)
          .lines
          .singleWhere((l) => l.group == PriceGroup.glass);
      expect(line.label, 'Clear glass');
      expect(line.rate, 25);
    });

    test('a sealed unit with no rate of its own is not priced — never at '
        'the single-sheet rate in its stead', () {
      final r = engine.price(door(), zero.copyWith(sealedGlassPerM2: const {}));
      expect(r.status, PriceStatus.notConfigured);
      expect(
        r.issues.single.message,
        'The price list has no price for sealed unit — clear glass.',
      );
    });
  });

  group('37. the roller rule: each sliding panel runs on the list\'s '
      'number of rollers, a fixed panel on none', () {
    int rollers(Design d, PriceList list) => engine
        .price(d, list)
        .lines
        .where((l) => l.label == 'Rollers')
        .fold(0, (s, l) => s + l.quantity.round());

    final list = example.copyWith(rollerEach: 4);

    test('one panel sliding beside a fixed one: 2', () {
      expect(rollers(given(sliding.sheet(left: '>')), list), 2);
    });

    test('two sliding between two fixed: 4', () {
      final d = given(sliding.fourPanels());
      expect(
        d.openings.where((o) => o.mechanism.slideEdge != null),
        hasLength(2),
      );
      expect(rollers(d, list), 4);
    });

    test('three a panel on the list: 3 and 6', () {
      final three = list.copyWith(rollersPerSlidingPanel: 3);
      expect(rollers(given(sliding.sheet(left: '>')), three), 3);
      expect(rollers(given(sliding.fourPanels()), three), 6);
    });
  });

  group('38. a customer\'s total, against what has changed', () {
    final a = door(id: 'a');
    final b = door(kind: DesignKind.window, id: 'b');
    final c = given(
      Design.fromJson(sliding.sheet(left: '>').toJson()..['id'] = 'c'),
    );
    PriceRecord rec(Design d) => PriceRecord.calculate(d, fixed)!;

    test('800 + 500 + 700 = 2,000; B changed and recalculated, the new '
        'figure; C made incomplete, not final', () {
      expect(
        CustomerPricing.of([
          (a, rec(a)),
          (b, rec(b)),
          (c, rec(c)),
        ], fixed).total,
        2000,
      );
      final b2 = b.copyWith(pricing: const PricingChoices(installation: true));
      final stale = CustomerPricing.of([
        (a, rec(a)),
        (b2, rec(b)),
        (c, rec(c)),
      ], fixed);
      expect(stale.status, CustomerTotalStatus.needsRecalculation);
      expect(stale.total, isNull);
      expect(
        CustomerPricing.of([
          (a, rec(a)),
          (b2, rec(b2)),
          (c, rec(c)),
        ], fixed).total,
        2100,
      );
      final cBroken = without(c, Measurements.widthKey);
      final notFinal = CustomerPricing.of([
        (a, rec(a)),
        (b2, rec(b2)),
        (cBroken, rec(c)),
      ], fixed);
      expect(notFinal.status, CustomerTotalStatus.notFinal);
      expect(notFinal.total, isNull);
      expect(notFinal.notFinalReason, '1 design is incomplete.');
    });

    test('a design drawn on and not read keeps the total from being final', () {
      final pricing = CustomerPricing.of([
        (a, rec(a)),
        (drawnOn(b), rec(b)),
      ], fixed);
      expect(pricing.total, isNull);
      expect(pricing.pricedSoFar, 800);
    });
  });

  group('39. payment', () {
    // Since Phase 30 the paid figure is a ledger of payments; more than the
    // total is credit, no longer refused.
    test('2,000 with 500 paid: 1,500 due; the payment survives a save and a '
        'load', () async {
      final a = door(id: 'a');
      final b = door(kind: DesignKind.window, id: 'b');
      final c = given(
        Design.fromJson(sliding.sheet(left: '>').toJson()..['id'] = 'c'),
      );
      final pricing = CustomerPricing.of([
        for (final d in [a, b, c]) (d, PriceRecord.calculate(d, fixed)),
      ], fixed);
      final finance = CustomerFinance.of(pricing, paid(500));
      expect(finance.total, 2000);
      expect(finance.due, 1500);
      expect(finance.dueCents, 150000);
      expect(finance.status, PaymentStatus.outstanding);

      final people = CustomerStore();
      final adam = await people.create(name: 'Adam', by: WorkshopRole.owner);
      final payment = paid(500).transactions.single;
      await people.record(
        PaymentTransaction.fromJson(payment.toJson(), customerId: adam.id)!, by: WorkshopRole.staff,
      );
      final back = await CustomerStore().load(adam.id);
      expect(back!.ledger.netPaidCents('USD'), 50000);
      expect(CustomerFinance.of(pricing, back.ledger).due, 1500);
      expect(
        Customer.fromJson(back.toJson()).ledger.netPaidCents('USD'),
        50000,
      );
    });
  });
}

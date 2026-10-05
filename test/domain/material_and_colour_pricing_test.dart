import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/default_factory_pricing.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/measurement.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_fields.dart';
import 'package:proframe/domain/pricing/price_readiness.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_selection.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/owner_access_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'an_unknown_category_test.dart' show keptAs, sloped;
import 'pricing_engine_test.dart'
    show door, engine, given, glassOverPanel, sold, withProfile, zero;

// A design's price follows what it is made of — the material of its
// profile and its colour — read from the factory's price list, which only
// the owner changes. Nothing here is a figure in the application: every
// rate is the test's own.

const white = 0xFFFFFFFF;
const black = 0xFF1C1C1C;

/// A factory list: uPVC 7 and 12 a metre, aluminium 11 and 18, and black
/// adding [blackPerMetre] a metre on either, white adding nothing.
PriceList factory({double blackPerMetre = 1.5}) {
  final colours = [
    sold('White', white, ColourGrade.standard),
    sold(
      'Black',
      black,
      ColourGrade.nonStandard,
      perMetre: blackPerMetre,
    ),
  ];
  return withProfile(
    withProfile(
      zero,
      MaterialKind.upvc,
      normal: 7,
      opening: 12,
      colours: colours,
    ),
    MaterialKind.aluminium,
    normal: 11,
    opening: 18,
    colours: colours,
  );
}

/// [d] made in [material] and [colour], as chosen on its price sheet.
Design madeIn(Design d, MaterialKind material, int colour) =>
    ProfileSelection.choose(d, material: material, colour: colour);

double totalOf(Design d, PriceList list) {
  final r = engine.price(d, list);
  expect(r.isPriced, isTrue, reason: '${r.issues}');
  return r.total!;
}

/// The profile [d] measures in all, in metres.
double profileMetres(Design d) {
  final m = PricingTakeoff.of(d).summary;
  return m.normalProfile.value + m.openingProfile.value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('38. uPVC and aluminium are priced at their own rates', () {
    test('the same geometry in each: different prices, each at its own '
        'material\'s normal and opening rate', () {
      final list = factory();
      final pvc = madeIn(door(), MaterialKind.upvc, white);
      final alu = madeIn(door(), MaterialKind.aluminium, white);
      expect(
        jsonEncode(pvc.frame!.outline.toJson()),
        jsonEncode(alu.frame!.outline.toJson()),
        reason: 'one geometry',
      );
      final a = engine.price(pvc, list);
      final b = engine.price(alu, list);
      expect(a.total, isNot(b.total));
      double rateOf(PriceResult r, PriceGroup g) =>
          r.lines.singleWhere((l) => l.group == g).rate;
      expect(rateOf(a, PriceGroup.normalProfile), 7);
      expect(rateOf(a, PriceGroup.openingProfile), 12);
      expect(rateOf(b, PriceGroup.normalProfile), 11);
      expect(rateOf(b, PriceGroup.openingProfile), 18);
      expect(
        b.lines.firstWhere((l) => l.group == PriceGroup.normalProfile).label,
        'Normal profile — Aluminium',
      );
      // Exactly the difference the rates make on the metres measured.
      final m = PricingTakeoff.of(pvc).summary;
      expect(
        b.total! - a.total!,
        closeTo(m.normalProfile.value * 4 + m.openingProfile.value * 6, 0.011),
      );
    });

    test('rates the same: prices the same — the price is the list\'s, not '
        'the material\'s name', () {
      final same = withProfile(
        withProfile(zero, MaterialKind.upvc, normal: 9, opening: 13),
        MaterialKind.aluminium,
        normal: 9,
        opening: 13,
      );
      expect(
        totalOf(madeIn(door(), MaterialKind.upvc, white), same),
        totalOf(madeIn(door(), MaterialKind.aluminium, white), same),
      );
    });
  });

  group('39. a colour is priced by the list', () {
    test('white the base, black adding its configured figure a metre; set '
        'to the same, the same', () {
      final list = factory(blackPerMetre: 1.5);
      final whiteDoor = madeIn(door(), MaterialKind.aluminium, white);
      final blackDoor = madeIn(door(), MaterialKind.aluminium, black);
      final base = totalOf(whiteDoor, list);
      expect(
        totalOf(blackDoor, list),
        closeTo(base + profileMetres(blackDoor) * 1.5, 0.011),
      );
      final colourLine = engine
          .price(blackDoor, list)
          .lines
          .singleWhere((l) => l.group == PriceGroup.colour);
      expect(colourLine.label, startsWith('Black Aluminium'));
      expect(colourLine.rate, 1.5);

      final equal = factory(blackPerMetre: 0);
      expect(totalOf(blackDoor, equal), totalOf(whiteDoor, equal));
    });

    test('a colour the list does not name takes the material\'s special '
        'figure — nothing is made up for it', () {
      final list = withProfile(
        zero,
        MaterialKind.upvc,
        normal: 7,
        opening: 12,
        special: const ColourSurcharge(perMetre: 3),
      );
      final teal = madeIn(door(), MaterialKind.upvc, 0xFF117777);
      final line = engine
          .price(teal, list)
          .lines
          .singleWhere((l) => l.group == PriceGroup.colour);
      expect(line.rate, 3);
      expect(ProfileSelection.of(teal).colourName(list), 'Custom');
    });
  });

  group('the profile is chosen, never assumed', () {
    test('a frame in the stock finish nobody chose: not selected, not '
        'priced, and said why', () {
      final d = door().copyWith(profileChosen: false);
      expect(d.frame!.finish, Finish.frameDefault);
      final s = ProfileSelection.of(d);
      expect(s.isChosen, isFalse);
      expect(s.materialName, 'Not selected');
      expect(s.colourName(DefaultFactoryPricing.list), 'Not selected');
      final ready = PriceReadiness.of(d);
      expect(ready.missing.single.kind, PriceRequirementKind.profile);
      expect(
        ready.message,
        'Please choose the material and colour of the profile to calculate '
        'the price.',
      );
      expect(engine.price(d, factory()).isPriced, isFalse);
      final state = DesignPriceState.of(d, factory(), null);
      expect(state.needsOnlyProfile, isTrue);
      expect(state.canCalculate, isFalse);
    });

    test('a frame someone put in another finish — in any version — is that '
        'finish: it is read, not invented', () {
      final d = door().copyWith(profileChosen: false);
      final painted = d.copyWith(
        frame: d.frame!.copyWith(
          finish: const Finish(colour: black, material: MaterialKind.aluminium),
        ),
      );
      final s = ProfileSelection.of(painted);
      expect(s.material, MaterialKind.aluminium);
      expect(s.colour, black);
      expect(s.colourName(factory()), 'Black');
      expect(PriceReadiness.of(painted).isPriceCalculable, isTrue);
    });

    test('no frame: nothing to choose', () {
      expect(
        ProfileSelection.of(Design.empty(id: 'x', kind: DesignKind.door)),
        ProfileSelection.notChosen,
      );
    });

    test('choosing puts the finish on the frame and on the bars in the '
        'frame\'s finish, keeps a bar of its own, and moves nothing', () {
      final d = glassOverPanel(door());
      final own = d.dividers.first.copyWith(
        finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.wood),
      );
      final mixed = given(d.withElement(own)).copyWith(profileChosen: false);
      final chosen = madeIn(mixed, MaterialKind.aluminium, black);
      expect(chosen.profileChosen, isTrue);
      expect(
        chosen.frame!.finish,
        const Finish(colour: black, material: MaterialKind.aluminium),
      );
      expect(
        chosen.dividers.singleWhere((b) => b.id == own.id).finish,
        own.finish,
      );
      String shapeOf(Design x) => jsonEncode([
        x.frame!.outline.toJson(),
        for (final b in x.dividers) [b.id, b.a.x, b.a.y, b.b.x, b.b.y],
        for (final s in x.sections) [s.id, s.outline.toJson(), s.finish],
        for (final o in x.openings) o.toJson(),
        x.measured?.toList(),
      ]);
      expect(shapeOf(chosen), shapeOf(mixed));
    });

    test('kept in the file, and read back', () {
      final d = madeIn(door(), MaterialKind.aluminium, black);
      final back = Design.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(back.profileChosen, isTrue);
      expect(ProfileSelection.of(back), ProfileSelection.of(d));
      expect(
        door().copyWith(profileChosen: false).toJson(),
        isNot(contains('profileChosen')),
      );
    });
  });

  test('15. a price says the profile it was priced in, and keeps saying it '
      'once kept', () {
    final list = factory();
    final d = madeIn(door(), MaterialKind.aluminium, black);
    final record = PriceRecord.calculate(d, list)!;
    final profile = record.result.profile!;
    expect(profile.material, 'aluminium');
    expect(profile.materialLabel, 'Aluminium');
    expect(profile.colour, black);
    expect(profile.colourName, 'Black');
    final back = PriceRecord.fromJson(jsonDecode(jsonEncode(record.toJson())))!;
    expect(back.result.profile!.colourName, 'Black');
    expect(back.result.priceListVersion, list.version);
  });

  group('41. an area is written precisely enough to check its line', () {
    test('1.4296 m² × 45.00 = 64.33, where 1.43 m² would read as 64.35', () {
      final area = SquareMetres(1.429612);
      expect(area.label, '1.4296 m²');
      final cents = Money.cents(area.value * 45);
      expect(cents, 6433, reason: 'the amount is of the exact area');
      expect(Money.cents(1.43 * 45), 6435, reason: 'two places mislead');
      expect(Money.cents(1.4296 * 45), cents, reason: 'four places agree');
    });

    test('on real designs, every glass and panel line\'s area as written '
        'times its rate is its amount, to the cent', () {
      for (final d in [
        madeIn(door(), MaterialKind.upvc, white),
        madeIn(glassOverPanel(door()), MaterialKind.aluminium, black),
      ]) {
        final r = engine.price(d, DefaultFactoryPricing.list);
        expect(r.isPriced, isTrue, reason: '${r.issues}');
        final areas = r.lines.where((l) => l.unit == PriceUnit.squareMetre);
        expect(areas, isNotEmpty);
        for (final l in areas) {
          final written = double.parse(
            SquareMetres(l.quantity).label.split(' ').first,
          );
          expect(
            (Money.cents(written * l.rate) - l.amountCents).abs(),
            lessThanOrEqualTo(1),
            reason: '${l.label}: $written × ${l.rate} against ${l.amount}',
          );
          // And the amount is never worked out from what is written.
          expect(l.amountCents, Money.cents(l.quantity * l.rate));
        }
      }
    });
  });

  group('42. prices left behind by deletes are swept, and nothing else', () {
    test('a design\'s price stays, an orphan goes, everything else as it '
        'was', () async {
      final people = CustomerStore();
      final adam = await people.create(name: 'Adam');
      final store = DesignStore(customers: people);
      final records = PriceRecordStore();
      final a = given(madeIn(door(id: 'a'), MaterialKind.upvc, white));
      await store.save(a.copyWith(customerId: adam.id));
      final record = PriceRecord.calculate(a, factory())!;
      await records.save('a', record);
      await records.save('b', record); // no design b kept
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('proframe.something-else', 'kept');
      final before = {
        for (final k in prefs.getKeys())
          if (k != PriceRecordStore.keyOf('b')) k: prefs.get(k),
      };

      expect(await store.sweepOrphanPrices(), ['b']);
      expect(await records.load('a'), isNotNull);
      expect(prefs.getString(PriceRecordStore.keyOf('b')), isNull);
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
      expect(await store.sweepOrphanPrices(), isEmpty, reason: 'once');
    });

    test('a design whose index line cannot be read keeps its price; an '
        'index that cannot be read sweeps nothing', () async {
      final store = DesignStore();
      final records = PriceRecordStore();
      final a = given(madeIn(door(id: 'a'), MaterialKind.upvc, white));
      await store.save(a);
      final record = PriceRecord.calculate(a, factory())!;
      await records.save('a', record);
      await records.save('gone', record);
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getString(DesignStore.indexKey)!;

      // The design's own record stands, its line of the index does not.
      await prefs.setString(DesignStore.indexKey, '[]');
      expect(await store.sweepOrphanPrices(), ['gone']);
      expect(await records.load('a'), isNotNull);

      await records.save('gone', record);
      await prefs.setString(DesignStore.indexKey, 'not json');
      expect(await DesignStore().sweepOrphanPrices(), isEmpty);
      expect(await records.load('gone'), isNotNull);
      await prefs.setString(DesignStore.indexKey, index);
    });
  });

  group('43. the factory\'s rates are the owner\'s, kept and used', () {
    test('the owner changes uPVC\'s rate; it is kept, read back, and a uPVC '
        'design is priced by it', () async {
      final store = PriceListStore();
      final list = await store.load();
      final field = RateField.of(list)
          .singleWhere((f) => f.id == 'profile.upvc.normal');
      expect(field.read(list), 7);
      final kept = await store.save(
        field.write(list, 9.5),
        by: WorkshopRole.owner,
      );
      expect(kept.isStarter, isFalse);
      final again = await PriceListStore().load();
      expect(again.profiles[MaterialKind.upvc]!.normalPerMetre, 9.5);

      final d = madeIn(door(), MaterialKind.upvc, white);
      final line = engine
          .price(d, again)
          .lines
          .singleWhere((l) => l.group == PriceGroup.normalProfile);
      expect(line.rate, 9.5);
      // Everything priced by the list before is to be recalculated.
      final old = PriceRecord.calculate(d, list)!;
      expect(
        DesignPriceState.of(d, again, old).status,
        DesignPriceStatus.needsRecalculation,
      );
    });

    test('staff cannot keep a list, and nothing is written', () async {
      final store = PriceListStore();
      final list = await store.load();
      await expectLater(
        store.save(list, by: WorkshopRole.staff),
        throwsA(isA<PricingAccessDenied>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
    });

    // Since the colour catalog (Phase 29) a named colour's rates are edited
    // as that colour (`ColourCatalog`), each change a version of its own,
    // so they are no longer flat fields: every other figure still is, and
    // the catalog comes back untouched by writing them.
    test('every figure of the list is a field or a colour of its catalog, '
        'and writing each back as it reads drops nothing', () {
      final list = DefaultFactoryPricing.list;
      var again = list;
      final fields = RateField.of(list);
      for (final f in fields) {
        again = f.write(again, f.read(list));
      }
      expect(jsonEncode(again.toJson()), jsonEncode(list.toJson()));
      final ids = {for (final f in fields) f.id};
      expect(ids.length, fields.length, reason: 'each figure once');
      expect(
        jsonEncode([for (final c in again.colours) c.toJson()]),
        jsonEncode([for (final c in list.colours) c.toJson()]),
      );
      expect(list.colourById('colour-black')!.rateFor(MaterialKind.aluminium),
          isNotNull);
      for (final id in [
        'profile.upvc.normal',
        'profile.aluminium.opening',
        'colour.aluminium.special.metre',
        'colour.upvc.special.percent',
        'glass.single.clear',
        'glass.sealed.clear',
        'panel.white',
        'hardware.hinge',
        'sliding.rollersPerPanel',
        'installation.area',
        'labour.door.percent',
      ]) {
        expect(ids, contains(id));
      }
    });

    test('an optional figure left empty is not priced; a figure below '
        'nothing, or a part roller, is refused', () {
      final list = DefaultFactoryPricing.list;
      final fields = {for (final f in RateField.of(list)) f.id: f};
      final noSealedClear = fields['glass.sealed.clear']!.write(list, null);
      expect(noSealedClear.sealedGlassPerM2[GlassLook.clear], isNull);
      expect(
        fields['glass.sealed.custom']!.write(list, null).customSealedGlassPerM2,
        isNull,
      );
      expect(fields['profile.upvc.normal']!.problemWith(null), isNotNull);
      expect(fields['profile.upvc.normal']!.problemWith(-1), isNotNull);
      expect(fields['sliding.rollersPerPanel']!.problemWith(2.5), isNotNull);
      expect(fields['glass.single.clear']!.problemWith(null), isNull);
    });
  });

  test('44. PVC white priced; made aluminium, the kept price is stale and '
      'the new one aluminium\'s; made black, black\'s', () {
    final list = factory(blackPerMetre: 2);
    final pvc = madeIn(door(), MaterialKind.upvc, white);
    final first = PriceRecord.calculate(pvc, list)!;

    final alu = madeIn(pvc, MaterialKind.aluminium, white);
    final stale = DesignPriceState.of(alu, list, first);
    expect(stale.status, DesignPriceStatus.needsRecalculation);
    expect(stale.total, isNull, reason: 'never the old figure as the price');
    expect(stale.previous, first.total);
    final second = PriceRecord.calculate(alu, list)!;
    expect(second.total, greaterThan(first.total));
    expect(second.result.profile!.material, 'aluminium');

    final blackAlu = madeIn(alu, MaterialKind.aluminium, black);
    expect(
      DesignPriceState.of(blackAlu, list, second).status,
      DesignPriceStatus.needsRecalculation,
    );
    final third = PriceRecord.calculate(blackAlu, list)!;
    expect(
      third.total,
      closeTo(second.total + profileMetres(blackAlu) * 2, 0.011),
    );
    expect(third.result.profile!.colourName, 'Black');
  });

  test('32. a customer\'s total moves by exactly what one design\'s new '
      'material costs', () {
    final list = factory();
    final front = madeIn(door(id: 'front'), MaterialKind.aluminium, black);
    final kitchen = madeIn(
      door(kind: DesignKind.window, id: 'kitchen'),
      MaterialKind.upvc,
      white,
    );
    final basement = madeIn(
      door(id: 'basement'),
      MaterialKind.aluminium,
      white,
    );
    CustomerPricing total(List<Design> ds) => CustomerPricing.of([
      for (final d in ds) (d, PriceRecord.calculate(d, list)),
    ], list);
    final before = total([front, kitchen, basement]);
    final kitchenAlu = madeIn(kitchen, MaterialKind.aluminium, white);
    final after = total([front, kitchenAlu, basement]);
    expect(
      after.total! - before.total!,
      closeTo(totalOf(kitchenAlu, list) - totalOf(kitchen, list), 1e-9),
    );
    final row = after.designs.singleWhere((d) => d.designId == 'kitchen');
    expect(row.profile.material, MaterialKind.aluminium);
    expect(row.colourName, 'White');
    expect(row.kind, DesignKind.window);
  });

  test('34. a category this version does not know is not priced, whatever '
      'it is made of', () {
    final unknown = Design.fromJson(keptAs(sloped(), 'future_custom_shape'));
    expect(unknown.isUnsupported, isTrue);
    final r = engine.price(unknown, factory());
    expect(r.isPriced, isFalse);
    expect(r.status, PriceStatus.unsupportedCategory);
  });

  test('35. an angled design changes price with its material, at its own '
      'polygon\'s measurements', () {
    final angled = given(sloped()).copyWith(profileChosen: true);
    final list = factory();
    final pvc = madeIn(angled, MaterialKind.upvc, white);
    final alu = madeIn(angled, MaterialKind.aluminium, white);
    expect(
      PricingTakeoff.of(pvc).summary.toJson(),
      PricingTakeoff.of(alu).summary.toJson(),
    );
    expect(totalOf(alu, list), greaterThan(totalOf(pvc, list)));
  });

  group('the owner\'s PIN', () {
    test('set once, checked, and kept only as a salted hash', () async {
      final store = OwnerAccessStore();
      expect(await store.hasPin(), isFalse);
      expect(await store.setPin('12'), isFalse, reason: 'too short');
      expect(await store.setPin('2468'), isTrue);
      expect(await store.hasPin(), isTrue);
      expect(await store.setPin('1357'), isFalse, reason: 'already set');
      expect(await store.verify('2468'), isTrue);
      expect(await store.verify('1357'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OwnerAccessStore.key), isNot(contains('2468')));
    });
  });
}

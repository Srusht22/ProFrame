import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/colour_catalog.dart';
import 'package:proframe/domain/pricing/default_factory_pricing.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_list_migration.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_selection.dart';
import 'package:proframe/domain/pricing/takeoff.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'an_unknown_category_test.dart' show keptAs;
import 'pricing_engine_test.dart' show door, engine, withProfile, zero;

// Phase 29: the factory's colour catalog. Each colour has an id of its own,
// the materials it is sold in and a rate on each; the owner adds, edits,
// renames and retires colours, each a version of the list; and a price is
// always looked up by material and colour together. Every rate here is the
// test's own.

const pvc = MaterialKind.upvc;
const alu = MaterialKind.aluminium;
const black = 0xFF1C1C1C;
const oak = 0xFFB8862B;
const grey = 0xFF4A4F55;

/// A list selling both materials at 10 a metre, normal and opening, with
/// an empty catalog and [special] for any other colour.
PriceList base({ColourSurcharge special = const ColourSurcharge()}) =>
    withProfile(
      withProfile(zero, pvc, normal: 10, opening: 10, special: special),
      alu,
      normal: 10,
      opening: 10,
      special: special,
    );

ColourDraft draft(
  String name,
  int swatch,
  Map<MaterialKind, double?> perMetre, {
  double percent = 0,
}) => ColourDraft(
  name: name,
  swatch: swatch,
  rates: {
    for (final e in perMetre.entries)
      e.key: e.value == null
          ? null
          : ColourSurcharge(perMetre: e.value!, percent: percent),
  },
);

/// [list] with [d] added; fails the test where it is refused.
PriceList added(PriceList list, ColourDraft d) {
  final r = ColourCatalog.add(list, d);
  expect(r.problems, isEmpty);
  return r.list!;
}

String idOf(PriceList list, String name) =>
    list.colours.singleWhere((c) => c.name == name).id;

/// The door, its profile chosen as [m] in the catalog's colour [id].
Design chosen(PriceList list, MaterialKind m, String id) {
  final c = list.colourById(id)!;
  return ProfileSelection.choose(
    door(),
    material: m,
    colour: c.swatch,
    colourId: id,
  );
}

List<PriceLine> colourLines(PriceResult r) =>
    r.lines.where((l) => l.group == PriceGroup.colour).toList();

/// What every metre of the door's profile is.
double metresOf(Design d) {
  final m = PricingTakeoff.of(d).summary;
  return m.normalProfile.value + m.openingProfile.value;
}

/// [d] as JSON with every finish and the profile's own fields taken out —
/// what is left is its geometry and everything else about it.
Object? geometryOf(Design d) {
  Object? strip(Object? v) => switch (v) {
    final Map<String, Object?> m => {
      for (final e in m.entries)
        if (!const {
          'finish',
          'profileChosen',
          'profileColourId',
          'updatedAt',
        }.contains(e.key))
          e.key: strip(e.value),
    },
    final List<Object?> l => [for (final x in l) strip(x)],
    _ => v,
  };
  return strip(jsonDecode(jsonEncode(d.toJson())));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('40. a rate changed is a new version; the old price keeps the old', () {
    test('Black on aluminium \$1 a metre in version 1, then \$2 in version '
        '2: the price calculated before keeps \$1 and version 1, and a new '
        'calculation uses \$2 and version 2', () async {
      final store = PriceListStore();
      final v1 = await store.save(
        added(base().copyWith(version: 0), draft('Black', black, {alu: 1})),
        by: WorkshopRole.owner,
      );
      expect(v1.version, 1);
      final id = idOf(v1, 'Black');
      final d = chosen(v1, alu, id);
      final record = PriceRecord.calculate(d, v1)!;
      final records = PriceRecordStore();
      await records.save(d.id, record);
      final keptText = jsonEncode(record.toJson());
      expect(colourLines(record.result).single.rate, 1);
      expect(record.result.priceListVersion, 1);

      final edit = ColourCatalog.update(
        v1,
        id,
        draft('Black', black, {alu: 2}),
      );
      expect(edit.problems, isEmpty);
      final v2 = await store.save(edit.list!, by: WorkshopRole.owner);
      expect(v2.version, 2);
      expect(v2.colourById(id)!.rateFor(alu)!.perMetre, 2);

      // The price kept is exactly as it was calculated.
      final old = (await records.load(d.id))!;
      expect(jsonEncode(old.toJson()), keptText);
      expect(colourLines(old.result).single.rate, 1);
      expect(old.result.priceListVersion, 1);
      expect(old.result.profile!.colourId, id);
      expect(old.result.profile!.colourRate!.perMetre, 1);
      // It is a previous calculation now, never repriced behind anybody.
      final state = DesignPriceState.of(d, v2, old);
      expect(state.status, DesignPriceStatus.needsRecalculation);
      expect(state.previous, old.result.total);

      final now = engine.price(d, v2);
      expect(colourLines(now).single.rate, 2);
      expect(now.priceListVersion, 2);
      expect(now.profile!.colourRate!.perMetre, 2);
      expect(
        now.total! - old.result.total!,
        closeTo(metresOf(d), 0.011),
        reason: 'a dollar more on every metre of profile, and nothing else',
      );
    });
  });

  group('41. a colour added is kept and sold on each material at its own '
      'rate', () {
    test('Golden Oak, PVC \$2 and aluminium \$3: kept, read back, offered for '
        'both, each priced at its own rate', () async {
      final store = PriceListStore();
      final kept = await store.save(
        added(base(), draft('Golden Oak', oak, {pvc: 2, alu: 3})),
        by: WorkshopRole.owner,
      );
      final again = await PriceListStore().load();
      expect(
        jsonEncode([for (final c in again.colours) c.toJson()]),
        jsonEncode([for (final c in kept.colours) c.toJson()]),
      );
      final goldenOak = again.colours.single;
      expect(goldenOak.id, 'colour-golden-oak');
      expect(goldenOak.active, isTrue);
      expect(goldenOak.materials, [pvc, alu]);
      expect(again.offeredFor(pvc).map((c) => c.name), ['Golden Oak']);
      expect(again.offeredFor(alu).map((c) => c.name), ['Golden Oak']);

      final asPvc = engine.price(chosen(again, pvc, goldenOak.id), again);
      final asAlu = engine.price(chosen(again, alu, goldenOak.id), again);
      expect(colourLines(asPvc).single.rate, 2);
      expect(colourLines(asAlu).single.rate, 3);
      expect(
        colourLines(asPvc).single.label,
        'Golden Oak uPVC (non-standard '
        'colour)',
      );
      expect(asPvc.profile!.colourName, 'Golden Oak');
      expect(asAlu.profile!.colourId, 'colour-golden-oak');
    });
  });

  group('42. a colour sold in one material only', () {
    test('Silver is aluminium only: offered for aluminium and not for PVC; '
        'a PVC design in it is asked for a PVC colour and not priced', () {
      final list = added(base(), draft('Silver', 0xFF9C9C9C, {alu: 0.5}));
      final silver = idOf(list, 'Silver');
      expect(list.offeredFor(alu).map((c) => c.id), [silver]);
      expect(list.offeredFor(pvc), isEmpty);

      final onAlu = chosen(list, alu, silver);
      expect(engine.price(onAlu, list).isPriced, isTrue);
      // Made PVC: the colour goes with it, and is not sold in PVC.
      final onPvc = ProfileSelection.choose(
        onAlu,
        material: pvc,
        colour: 0xFF9C9C9C,
        colourId: silver,
      );
      final r = engine.price(onPvc, list);
      expect(r.isPriced, isFalse);
      expect(r.total, isNull);
      expect(
        r.issues.first.message,
        'Please select a colour available for uPVC.',
      );
      final state = DesignPriceState.of(onPvc, list, null);
      expect(state.status, DesignPriceStatus.incomplete);
      expect(state.needsColour, isTrue);
      expect(state.needsOnlyProfile, isTrue, reason: 'chosen on the sheet');
      expect(state.message, 'Please select a colour available for uPVC.');
      // Nothing was chosen in its stead.
      expect(onPvc.profileColourId, silver);
      expect(onPvc.frame!.finish.colour, 0xFF9C9C9C);
    });
  });

  group('43. a colour sold in a material with no rate on it', () {
    test('Special Blue has a PVC rate only: on aluminium it says colour '
        'pricing is not configured, and borrows no other rate', () {
      final special = base(special: const ColourSurcharge(perMetre: 9));
      const blue = FactoryColour(
        id: 'colour-special-blue',
        name: 'Special Blue',
        swatch: 0xFF2255AA,
        rates: {pvc: ColourSurcharge(perMetre: 1.25), alu: null},
      );
      final list = special.copyWith(colours: [blue]);
      final onPvc = engine.price(chosen(list, pvc, blue.id), list);
      expect(colourLines(onPvc).single.rate, 1.25);

      final onAluDesign = chosen(list, alu, blue.id);
      final onAlu = engine.price(onAluDesign, list);
      expect(onAlu.isPriced, isFalse);
      expect(onAlu.total, isNull);
      expect(
        onAlu.issues.single.message,
        'Colour pricing is not configured for Aluminium.',
      );
      final state = DesignPriceState.of(onAluDesign, list, null);
      expect(state.status, DesignPriceStatus.unavailable);
      expect(state.message, 'Colour pricing is not configured for Aluminium.');
      // Nor by its swatch, painted rather than chosen: still that colour.
      final painted = ProfileSelection.choose(
        door(),
        material: alu,
        colour: blue.swatch,
      );
      expect(
        engine.price(painted, list).issues.single.message,
        'Colour pricing is not configured for Aluminium.',
      );

      // The editor never keeps a colour so.
      final refused = ColourCatalog.add(
        base(),
        draft('Special Blue', 0xFF2255AA, {pvc: 1.25, alu: null}),
      );
      expect(refused.list, isNull);
      expect(
        refused.problems[ColourCatalog.rateField(alu)],
        'Aluminium colour rate is required for a colour that applies to '
        'Aluminium.',
      );
    });

    test('any other colour is only for a colour the catalog does not name', () {
      final list = added(
        base(special: const ColourSurcharge(perMetre: 9)),
        draft('Black', black, {pvc: 1}),
      );
      // Unnamed: the special rate.
      final custom = ProfileSelection.choose(
        door(),
        material: pvc,
        colour: 0xFF123456,
      );
      final line = colourLines(engine.price(custom, list)).single;
      expect(line.rate, 9);
      expect(line.label, 'Special colour uPVC (special colour)');
      // Named: its own rate, never the special one.
      expect(
        colourLines(engine.price(chosen(list, pvc, idOf(list, 'Black')), list))
            .single
            .rate,
        1,
      );
    });
  });

  group('44. a retired colour', () {
    test('Bronze retired: not offered, the design kept and still named and '
        'priced, its old price untouched', () {
      final v1 = added(base(), draft('Bronze', 0xFF6B4E2E, {pvc: 1.5}));
      final bronze = idOf(v1, 'Bronze');
      final d = chosen(v1, pvc, bronze);
      final designText = jsonEncode(d.toJson());
      final record = PriceRecord.calculate(d, v1)!;
      final recordText = jsonEncode(record.toJson());

      final v2 = ColourCatalog.retire(v1, bronze);
      expect(v2.colourById(bronze)!.active, isFalse);
      expect(v2.colours.length, v1.colours.length, reason: 'never removed');
      expect(v2.offeredFor(pvc), isEmpty);
      expect(jsonEncode(d.toJson()), designText, reason: 'nothing cascades');
      expect(ProfileSelection.of(d).colourName(v2), 'Bronze');
      // Recalculated: still priced at Bronze's rate.
      final again = engine.price(d, v2);
      expect(colourLines(again).single.rate, 1.5);
      expect(again.profile!.colourName, 'Bronze');
      expect(jsonEncode(record.toJson()), recordText);
      expect(
        DesignPriceState.of(d, v2, record).status,
        DesignPriceStatus.needsRecalculation,
      );
    });

    test('retired and no longer priced on the material: please select an '
        'active colour — never another colour in its stead', () {
      final list = added(
        added(base(), draft('Bronze', 0xFF6B4E2E, {pvc: 1.5, alu: 2})),
        draft('Brown', 0xFF6B4E2E, {alu: 1}),
      );
      final bronze = idOf(list, 'Bronze');
      final d = chosen(list, alu, bronze);
      final retired = ColourCatalog.retire(list, bronze);
      final narrowed = retired.copyWith(
        colours: [
          for (final c in retired.colours)
            c.id == bronze ? c.copyWith(rates: {pvc: c.rateFor(pvc)}) : c,
        ],
      );
      final r = engine.price(d, narrowed);
      expect(r.isPriced, isFalse);
      expect(
        r.issues.first.message,
        'Colour pricing unavailable — please select an active colour.',
      );
      expect(DesignPriceState.of(d, narrowed, null).needsColour, isTrue);
      // Brown has the very same swatch and is sold on aluminium: it is not
      // put in Bronze's place.
      expect(r.lines.where((l) => l.label.startsWith('Brown')), isEmpty);
    });

    test('a retired colour is brought back only while its name is free', () {
      var list = added(base(), draft('Bronze', 0xFF6B4E2E, {pvc: 1.5}));
      final bronze = idOf(list, 'Bronze');
      list = ColourCatalog.retire(list, bronze);
      // A retired colour does not hold its name against a new one, and the
      // new one has an id of its own.
      list = added(list, draft('Bronze', 0xFF7A5A33, {pvc: 1.6}));
      expect(list.colours.map((c) => c.id), [bronze, '$bronze-2']);
      final back = ColourCatalog.restore(list, bronze);
      expect(back.list, isNull);
      expect(back.problems[ColourCatalog.nameField], contains('Bronze'));
      list = ColourCatalog.retire(list, '$bronze-2');
      expect(
        ColourCatalog.restore(list, bronze).list!.colourById(bronze)!.active,
        isTrue,
      );
    });
  });

  group('45. a colour renamed is the same colour', () {
    test('Dark Grey → Anthracite Grey: the same id, every design shows the '
        'new name, the price kept says the old one', () {
      final v1 = added(base(), draft('Dark Grey', grey, {pvc: 1, alu: 1.5}));
      final id = idOf(v1, 'Dark Grey');
      final d = chosen(v1, alu, id);
      final record = PriceRecord.calculate(d, v1)!;
      final r = ColourCatalog.update(
        v1,
        id,
        draft('  Anthracite Grey  ', grey, {pvc: 1, alu: 1.5}),
      );
      expect(r.problems, isEmpty);
      final v2 = r.list!;
      expect(v2.colours.single.id, id);
      expect(v2.colours.single.name, 'Anthracite Grey', reason: 'trimmed');
      expect(ProfileSelection.of(d).colourName(v2), 'Anthracite Grey');
      expect(engine.price(d, v2).profile!.colourName, 'Anthracite Grey');
      expect(engine.price(d, v2).profile!.colourId, id);
      expect(record.result.profile!.colourName, 'Dark Grey');
      expect(record.result.profile!.colourId, id);
      expect(colourLines(record.result).single.label, startsWith('Dark Grey'));
    });
  });

  group('46. nothing is deleted', () {
    test('every edit keeps every colour; a design names its colour by id, '
        'and an id the list does not have is never matched to another '
        'colour', () {
      var list = added(base(), draft('Black', black, {pvc: 1}));
      final id = idOf(list, 'Black');
      final d = chosen(list, pvc, id);
      final designText = jsonEncode(d.toJson());
      list = ColourCatalog.retire(list, id);
      list = ColourCatalog.update(
        list,
        id,
        draft('Jet', black, {pvc: 2}),
      ).list!;
      list = added(list, draft('Black', black, {pvc: 3}));
      expect(list.colours.length, 2);
      expect(list.colourById(id)!.name, 'Jet');
      expect(jsonEncode(d.toJson()), designText);

      // A list from elsewhere that lacks the colour: the design is asked
      // for an active colour, and the new Black with the same swatch is
      // not taken for it.
      final elsewhere = list.copyWith(
        colours: [
          for (final c in list.colours)
            if (c.id != id) c,
        ],
      );
      final r = engine.price(d, elsewhere);
      expect(r.isPriced, isFalse);
      expect(
        r.issues.first.message,
        'Colour pricing unavailable — please select an active colour.',
      );
      expect(
        ProfileSelection.of(d).colourName(elsewhere),
        'Black',
        reason: 'named by its swatch, never Unknown',
      );
    });
  });

  group('47. colour is never geometry', () {
    test('choosing, renaming, retiring and re-rating a colour move nothing '
        'in the design', () {
      var list = added(base(), draft('Golden Oak', oak, {pvc: 2, alu: 3}));
      final id = idOf(list, 'Golden Oak');
      final before = door();
      final d = ProfileSelection.choose(
        before,
        material: pvc,
        colour: oak,
        colourId: id,
      );
      expect(geometryOf(d), geometryOf(before));
      expect(d.frame!.finish, const Finish(colour: oak, material: pvc));
      final asAlu = ProfileSelection.choose(
        d,
        material: alu,
        colour: oak,
        colourId: id,
      );
      expect(geometryOf(asAlu), geometryOf(before));
      final text = jsonEncode(asAlu.toJson());
      list = ColourCatalog.update(
        list,
        id,
        draft('Oak', oak, {pvc: 5, alu: 6}),
      ).list!;
      list = ColourCatalog.retire(list, id);
      expect(jsonEncode(asAlu.toJson()), text);
      expect(
        jsonEncode(PricingTakeoff.of(asAlu).summary.toJson()),
        jsonEncode(PricingTakeoff.of(before).summary.toJson()),
      );
    });
  });

  group('48. what a colour adds is charged once', () {
    test('\$200 of profile and 10% for its colour come to \$220', () {
      final d0 = door();
      final m = metresOf(d0);
      final rate = 200 / m;
      final list0 = withProfile(
        withProfile(zero, pvc, normal: rate, opening: rate),
        alu,
        normal: rate,
        opening: rate,
      );
      final list = added(list0, draft('Black', black, {pvc: 0}, percent: 10));
      final r = engine.price(chosen(list, pvc, idOf(list, 'Black')), list);
      expect(
        r.sumOf(PriceGroup.normalProfile) + r.sumOf(PriceGroup.openingProfile),
        closeTo(200, 0.011),
      );
      expect(colourLines(r), hasLength(1));
      expect(r.sumOf(PriceGroup.colour), closeTo(20, 0.011));
      expect(r.total, closeTo(220, 0.021));
    });

    test('\$20 by the metre is charged on every metre once', () {
      final d0 = door();
      final m = metresOf(d0);
      final list0 = withProfile(
        withProfile(zero, pvc, normal: 200 / m, opening: 200 / m),
        alu,
      );
      final list = added(list0, draft('Black', black, {pvc: 20 / m}));
      final r = engine.price(chosen(list, pvc, idOf(list, 'Black')), list);
      final line = colourLines(r).single;
      expect(line.quantity, closeTo(m, 1e-9));
      expect(r.sumOf(PriceGroup.colour), closeTo(20, 0.011));
      expect(r.total, closeTo(220, 0.021));
    });
  });

  group('the owner\'s edits are checked', () {
    test('a name is needed, and trimmed', () {
      for (final name in ['', '   ']) {
        final r = ColourCatalog.add(base(), draft(name, black, {pvc: 1}));
        expect(r.list, isNull);
        expect(r.problems[ColourCatalog.nameField], 'Colour name is required.');
      }
      expect(
        added(base(), draft(' Black ', black, {pvc: 1})).colours.single.name,
        'Black',
      );
    });

    test('two active colours on one material are never called the same; on '
        'different materials they may be', () {
      final list = added(base(), draft('Black', black, {pvc: 1}));
      final same = ColourCatalog.add(list, draft('black ', black, {pvc: 2}));
      expect(same.list, isNull);
      expect(
        same.problems[ColourCatalog.nameField],
        'An active colour is already called Black for uPVC.',
      );
      final other = ColourCatalog.add(list, draft('Black', black, {alu: 2}));
      expect(other.problems, isEmpty);
      expect(other.list!.colours.map((c) => c.id), [
        'colour-black',
        'colour-black-2',
      ]);
      // Renaming onto a name taken on the same material is refused too.
      final grey2 = added(list, draft('Grey', grey, {pvc: 1}));
      expect(
        ColourCatalog.update(
          grey2,
          idOf(grey2, 'Grey'),
          draft('Black', grey, {pvc: 1}),
        ).problems,
        contains(ColourCatalog.nameField),
      );
    });

    test('at least one material; a rate on every one; no rate below nothing; '
        'words that are not a figure refused', () {
      final none = ColourCatalog.add(base(), draft('Black', black, {}));
      expect(
        none.problems[ColourCatalog.materialsField],
        'Choose at least one material.',
      );
      final neg = ColourCatalog.add(base(), draft('Black', black, {pvc: -1}));
      expect(
        neg.problems[ColourCatalog.rateField(pvc)],
        'A rate cannot be below nothing.',
      );
      final missing = ColourCatalog.add(
        base(),
        draft('Black', black, {pvc: 1, alu: null}),
      );
      expect(
        missing.problems[ColourCatalog.rateField(alu)],
        'Aluminium colour rate is required for a colour that applies to '
        'Aluminium.',
      );
      expect(ColourCatalog.readRate('abc').problem, 'Enter a figure.');
      expect(
        ColourCatalog.readRate('-2').problem,
        'A rate cannot be below '
        'nothing.',
      );
      expect(ColourCatalog.readRate(' 1.5 ').value, 1.5);
      expect(ColourCatalog.readRate('').value, isNull);
      expect(ColourCatalog.readRate('').problem, isNull);
      // A material the list prices no profile in is not offered.
      final wood = ColourCatalog.add(
        base(),
        draft('Black', black, {MaterialKind.wood: 1}),
      );
      expect(wood.problems, contains(ColourCatalog.materialsField));
    });

    test('staff cannot keep a colour, and nothing is written', () async {
      final list = added(base(), draft('Black', black, {pvc: 1}));
      await expectLater(
        PriceListStore().save(list, by: WorkshopRole.staff),
        throwsA(isA<PricingAccessDenied>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
    });
  });

  group('kept and read back', () {
    test('a colour round-trips: id, name, swatch, grade, materials, rates, '
        'retired, order', () {
      const c = FactoryColour(
        id: 'colour-x',
        name: 'X',
        swatch: 0xFF010203,
        grade: ColourGrade.standard,
        rates: {pvc: ColourSurcharge(perMetre: 1.5, percent: 4), alu: null},
        active: false,
        order: 7,
      );
      final back = FactoryColour.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(jsonEncode(back.toJson()), jsonEncode(c.toJson()));
      expect(back.active, isFalse);
      expect(back.rateFor(alu), isNull);
      expect(back.appliesTo(alu), isTrue);
      expect(
        back.rateFor(pvc),
        const ColourSurcharge(perMetre: 1.5, percent: 4),
      );
    });

    test(
      'an entry that cannot be read is passed over; a second entry with '
      'an id already taken is too; a rate that is not a price is no rate',
      () {
        final json = DefaultFactoryPricing.list.toJson()
          ..['colours'] = [
            {
              'id': 'colour-a',
              'name': 'A',
              'swatch': 1,
              'rates': {
                'upvc': {'perMetre': -3},
                'aluminium': {'perMetre': 2},
              },
            },
            {
              'id': 'colour-a',
              'name': 'A again',
              'swatch': 2,
              'rates': <String, Object?>{},
            },
            {'name': 'no id', 'swatch': 3},
            'not a colour',
          ];
        final list = PriceList.fromJson(jsonDecode(jsonEncode(json)))!;
        expect(list.colours.map((c) => c.name), ['A']);
        expect(list.colours.single.appliesTo(pvc), isTrue);
        expect(list.colours.single.rateFor(pvc), isNull);
        expect(list.colours.single.rateFor(alu)!.perMetre, 2);
      },
    );

    test(
      'add, edit and retire each survive a reload, each a version',
      () async {
        final store = PriceListStore();
        var list = await store.save(
          added(base(), draft('Golden Oak', oak, {pvc: 2, alu: 3})),
          by: WorkshopRole.owner,
        );
        final v = list.version;
        final id = idOf(list, 'Golden Oak');
        list = await store.save(
          ColourCatalog.update(list, id, draft('Oak', oak, {pvc: 2.5})).list!,
          by: WorkshopRole.owner,
        );
        expect(list.version, v + 1);
        list = await store.save(
          ColourCatalog.retire(list, id),
          by: WorkshopRole.owner,
        );
        expect(list.version, v + 2);
        final again = await PriceListStore().load();
        final c = again.colourById(id)!;
        expect(c.name, 'Oak');
        expect(c.materials, [pvc]);
        expect(c.rateFor(pvc)!.perMetre, 2.5);
        expect(c.active, isFalse);
        expect(again.version, v + 2);
      },
    );
  });

  group('a list kept before the catalog', () {
    /// The example list as Phase 28 kept it: schema 3, each material's
    /// colours under it, matched by value.
    Map<String, Object?> phase28Starter() {
      final now = DefaultFactoryPricing.list.toJson();
      Map<String, Object?> colourOf(
        String name,
        int swatch,
        String grade, [
        double perMetre = 0,
      ]) => {
        'name': name,
        'colour': swatch,
        'grade': grade,
        'surcharge': {if (perMetre != 0) 'perMetre': perMetre},
      };
      final profiles = now['profiles']! as Map<String, Object?>;
      return {
        ...now..remove('colours'),
        'schemaVersion': 3,
        'version': 4,
        'isStarter': false,
        'profiles': {
          'upvc': {
            ...profiles['upvc']! as Map<String, Object?>,
            'colours': [
              colourOf('White', 0xFFFFFFFF, 'standard'),
              colourOf('Off white', 0xFFF3F4F2, 'standard'),
              colourOf('Cream', 0xFFD8D5CC, 'nonStandard', 0.8),
              colourOf('Grey', 0xFF6E7472, 'nonStandard', 1),
              colourOf('Graphite', 0xFF3A3A38, 'nonStandard', 1),
              colourOf('Black', 0xFF1C1C1C, 'nonStandard', 1),
              colourOf('Oak effect', 0xFF7B4A2B, 'nonStandard', 1.5),
              colourOf('Walnut effect', 0xFF4A2F1E, 'nonStandard', 1.5),
            ],
          },
          'aluminium': {
            ...profiles['aluminium']! as Map<String, Object?>,
            'colours': [
              colourOf('Silver', 0xFF9C9C9C, 'standard'),
              colourOf('White', 0xFFFFFFFF, 'standard'),
              colourOf('Off white', 0xFFF3F4F2, 'standard'),
              colourOf('Black', 0xFF1C1C1C, 'nonStandard', 1),
              colourOf('Anthracite', 0xFF383E42, 'nonStandard', 1),
              colourOf('Graphite', 0xFF3A3A38, 'nonStandard', 1),
              colourOf('Oak effect', 0xFF7B4A2B, 'nonStandard', 2),
            ],
          },
        },
      };
    }

    test(
      'Phase 28\'s list becomes one catalog: each colour once, a rate on '
      'every material it was sold in at the figure it had, nothing added',
      () {
        final json =
            jsonDecode(jsonEncode(phase28Starter())) as Map<String, Object?>;
        expect(PriceListMigration.schemaOf(json), 3);
        final list = PriceList.fromJson(json)!;
        expect(list.migratedFrom, 3);
        expect(list.version, 4);
        expect(list.migrationNotes.join(), contains('one catalog'));
        // The same catalog, ids and order as the example list is written in.
        expect(
          jsonEncode([for (final c in list.colours) c.toJson()]),
          jsonEncode([
            for (final c in DefaultFactoryPricing.list.colours) c.toJson(),
          ]),
        );
        // Sold where it was sold, and nowhere else.
        expect(list.colourById('colour-silver')!.materials, [alu]);
        expect(list.colourById('colour-cream')!.materials, [pvc]);
        expect(
          list.colourById('colour-oak-effect')!.rateFor(pvc)!.perMetre,
          1.5,
        );
        expect(list.colourById('colour-oak-effect')!.rateFor(alu)!.perMetre, 2);
        // A design priced by value before is priced the same.
        final d = ProfileSelection.choose(door(), material: alu, colour: black);
        expect(colourLines(engine.price(d, list)).single.rate, 1);
        // Reading wrote nothing — there was nothing to write to.
        expect(json['schemaVersion'], 3);
      },
    );

    test('two colours that differ in name keep apart; what any other colour '
        'adds stays each material\'s own', () {
      final json = phase28Starter();
      final profiles = json['profiles']! as Map<String, Object?>;
      ((profiles['aluminium']! as Map<String, Object?>)['colours']!
              as List<Object?>)
          .add({
            'name': 'Jet',
            'colour': 0xFF1C1C1C,
            'grade': 'nonStandard',
            'surcharge': {'percent': 5},
          });
      final list = PriceList.fromJson(jsonDecode(jsonEncode(json)))!;
      expect(list.colourById('colour-black')!.materials, [pvc, alu]);
      expect(list.colourById('colour-jet')!.materials, [alu]);
      expect(list.colourById('colour-jet')!.rateFor(alu)!.percent, 5);
      expect(list.profiles[pvc]!.special.perMetre, 2.5);
      expect(list.profiles[alu]!.special.perMetre, 3);
    });

    test('a price kept before the catalog still reads, unchanged', () {
      final d = ProfileSelection.choose(door(), material: pvc, colour: black);
      final record = PriceRecord.calculate(d, DefaultFactoryPricing.list)!;
      final json =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>;
      final result = json['result']! as Map<String, Object?>;
      (result['profile']! as Map<String, Object?>)
        ..remove('colourId')
        ..remove('colourRate');
      final read = PriceRecord.fromJson(json)!;
      expect(read.result.profile!.colourName, 'Black');
      expect(read.result.profile!.colourId, isNull);
      expect(read.result.total, record.result.total);
    });
  });

  group('designs from before', () {
    test('the stock finish is still not chosen; a painted frame is priced '
        'by its value, as in Phase 28; a choice keeps its id', () {
      final list = DefaultFactoryPricing.list;
      // The stock finish nobody chose (the helper's door says it was).
      final stock = door().copyWith(profileChosen: false);
      expect(ProfileSelection.of(stock).isChosen, isFalse);
      expect(ProfileSelection.of(stock).colourName(list), 'Not selected');
      final painted = ProfileSelection.choose(
        door(),
        material: pvc,
        colour: black,
      );
      expect(painted.profileColourId, isNull);
      expect(ProfileSelection.of(painted).colourName(list), 'Black');
      expect(colourLines(engine.price(painted, list)).single.rate, 1);
      expect(
        ProfileSelection.of(painted).catalogColourIn(list)!.id,
        'colour-black',
      );
      final picked = chosen(list, pvc, 'colour-black');
      final back = Design.fromJson(jsonDecode(jsonEncode(picked.toJson())));
      expect(back.profileColourId, 'colour-black');
      expect(painted.toJson().containsKey('profileColourId'), isFalse);
    });

    test('an unsupported category stays unsupported', () {
      final d = Design.fromJson(keptAs(door(), 'future_custom_shape'));
      final state = DesignPriceState.of(d, DefaultFactoryPricing.list, null);
      expect(state.status, DesignPriceStatus.unsupported);
    });
  });
}

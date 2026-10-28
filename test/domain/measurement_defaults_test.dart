import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurement_defaults.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/measurement_defaults_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The user's words: *a button on the first page to fill the frame border,
// the bar thickness, the width of the lines and the other things for each
// type — PVC or aluminium — and the default price for each type and each
// colour of each type, but separate them from the default measurements,
// because we don't want to fill these every time; the admin may change one
// for a specific design in its measurements.*
//
// The defaults are the factory's figures, one set a kind of profile, kept
// apart from the price list so setting them reprices nothing.

const upvc = ProfileDefaults(borderMm: 60, barMm: 50, depthMm: 70);
const aluminium = ProfileDefaults(borderMm: 45, barMm: 40, depthMm: 55);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing is said until the factory says it', () {
    expect(MeasurementDefaults.none.of(MaterialKind.upvc).isEmpty, isTrue);
    expect(MeasurementDefaults.none.said(MaterialKind.values), isEmpty);
  });

  test('one set a kind of profile, read back as kept', () {
    final d = MeasurementDefaults.none
        .withMaterial(MaterialKind.upvc, upvc)
        .withMaterial(MaterialKind.aluminium, aluminium);
    final back = MeasurementDefaults.fromJson(
      jsonDecode(jsonEncode(d.toJson())),
    );
    expect(back.of(MaterialKind.upvc), upvc);
    expect(back.of(MaterialKind.aluminium), aluminium);
    expect(back.said(MaterialKind.values), [
      MaterialKind.upvc,
      MaterialKind.aluminium,
    ]);
  });

  test('a figure that is not a size is no figure, and an unknown material '
      'is passed over', () {
    final back = MeasurementDefaults.fromJson({
      'schemaVersion': 1,
      'materials': {
        'upvc': {'borderMm': -5, 'barMm': 'wide', 'depthMm': 70},
        'plutonium': {'borderMm': 60},
      },
    });
    expect(back.of(MaterialKind.upvc), const ProfileDefaults(depthMm: 70));
    expect(back.byMaterial.keys, [MaterialKind.upvc]);
    expect(MeasurementDefaults.fromJson('nonsense'), MeasurementDefaults.none);
  });

  test('typed in centimetres, in either set of digits', () {
    expect(MeasurementDefaults.readCm('6'), 60);
    expect(MeasurementDefaults.readCm('4,5'), 45);
    expect(MeasurementDefaults.readCm('٤٫٥'), 45);
    expect(MeasurementDefaults.readCm(''), isNull);
    expect(MeasurementDefaults.readCm('0'), MeasurementDefaults.invalid);
    expect(MeasurementDefaults.readCm('x'), MeasurementDefaults.invalid);
  });

  test('kept on the device by the owner; refused to anybody else, with '
      'nothing written', () async {
    final store = MeasurementDefaultsStore();
    final d = MeasurementDefaults.none.withMaterial(MaterialKind.upvc, upvc);
    await expectLater(
      store.save(d, by: WorkshopRole.staff),
      throwsA(isA<AccessDenied>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MeasurementDefaultsStore.key), isNull);

    final kept = await store.save(d, by: WorkshopRole.owner);
    expect(kept.of(MaterialKind.upvc), upvc);
    expect((await store.load()).of(MaterialKind.upvc), upvc);
  });

  test('apart from the prices: keeping them touches no price list', () async {
    final store = MeasurementDefaultsStore();
    await store.save(
      MeasurementDefaults.none.withMaterial(MaterialKind.aluminium, aluminium),
      by: WorkshopRole.owner,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {MeasurementDefaultsStore.key});
    // The starter list knows nothing of them.
    expect(PriceList.starter.toJson().toString(), isNot(contains('borderMm')));
  });
}

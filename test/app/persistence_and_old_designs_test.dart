import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_under_stair_design_test.dart' as under;
import '../domain/the_solid_is_the_canonical_geometry_test.dart' as solid;
import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'designs_are_kept_for_their_customer_test.dart' as kept;
import 'new_design.dart';
import 'opening_an_existing_design_test.dart' show pressOpen;
import 'pause_and_take_it_back_test.dart' as sheet;
import 'reopening_keeps_the_category_test.dart' show facetsOf, textOf;
import 'the_designs_screen_test.dart' as screen;

// Everything a design is, kept: its category, its canonical geometry, its
// sizes and drawn dimensions, its openings, the lines inside them, what
// every part is made of, its handles and hinges, whose it is, its id and
// its name. Each of the five categories is made through the screens, given
// all of that, saved with the Save button, the app closed, opened again
// from nothing but the device, and the design opened from its card — and
// it is required back exactly, field by field and as a whole.
//
// And designs kept by older versions: they load; reading the store gives
// one kept before customers its customer by adding that one field and
// touching nothing else in its record; and a list of designs kept by the
// oldest version is moved over without losing an entry, even one this
// version cannot read.

const laptop = Size(1280, 860);

const anthracite = Finish(colour: 0xFF383E42, material: MaterialKind.aluminium);
const silver = Finish(colour: 0xFFC3C7C9, material: MaterialKind.steel);
const black = Finish(colour: 0xFF1C1C1C, material: MaterialKind.steel);

/// The hand-drawn window with a leaning side, a transom, a mullion and a
/// mark in the lower left, for every standard category.
Sketch standardSheet() => Sketch(
  strokes: [
    sheet.pen('outline', const [
      Vec2(0, 0),
      Vec2(1200, 0),
      Vec2(1260, 1500),
      Vec2(0, 1500),
      Vec2(0, 0),
    ]),
    sheet.pen('transom', const [Vec2(0, 500), Vec2(1200, 500)]),
    sheet.pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
    sheet.pen('mark', sheet.chevron(const Vec2(300, 1000))),
  ],
);

/// [begun] — the design the screens began, with its id, its customer, its
/// name and its category — drawn, read and given everything a design can
/// be given.
Design furnish(Design begun) {
  final sheetOf = begun.kind == DesignKind.angled
      ? under.drawn().sketch
      : standardSheet();
  var d = Measurements.keepAfterReading(
    begun,
    SketchInterpreter.interpret(begun.copyWith(sketch: sheetOf)).design,
  );
  d = solid.said(d, begun.kind.leafDefault ?? DesignKind.window);
  // A line inside the opening: glass above it, a white panel below.
  d = solid.divided(d);
  // The frame anthracite aluminium.
  d = d.withElement(d.frame!.copyWith(finish: anthracite));
  // A sliding panel with its pleated screen, where there is one.
  if (begun.kind.slides) {
    d = OpeningHardware.settle(
      d.copyWith(
        openings: [for (final o in d.openings) o.copyWith(pleatedScreen: true)],
      ),
    );
  }
  // The handle silver and the hinges black.
  d = d.copyWith(
    hardware: [
      for (final h in d.hardware)
        h.copyWith(finish: h.kind == HardwareKind.hinge ? black : silver),
    ],
  );
  // A dimension drawn along the sill, and every size given.
  final o = d.frame!.outline;
  d = d.copyWith(
    dimensions: [
      DimensionElement(
        id: 'sill-figure',
        a: Vec2(o.left, o.bottom),
        b: Vec2(o.right, o.bottom),
        offsetMm: 150,
      ),
    ],
  );
  d = Measurements.apply(d, {
    for (final m in Measurements.of(d))
      if (m.asked) m.key: m.currentMm(d),
  }).design;
  return d;
}

/// Puts away anything the screens ask over the design — the sizes, what a
/// leaf is — as a user in a hurry would.
Future<void> putQuestionsAway(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    final notNow = find.text('Not now').hitTestable();
    if (notNow.evaluate().isEmpty) return;
    await tester.tap(notNow.first);
    await tester.pumpAndSettle();
  }
}

/// Each named part of [d], as text, for the field-by-field comparison.
Map<String, String> fieldsOf(Design d) => {
  'category': d.kind.name,
  'design id': d.id,
  'design name': d.name,
  'customer id': '${d.customerId}',
  'geometry': jsonEncode({
    'frame': d.frame!.toJson(),
    'sections': [for (final s in d.sections) s.toJson()['outline']],
  }),
  'sizes': jsonEncode([...?d.measured]..sort()),
  'dimensions': jsonEncode([for (final x in d.dimensions) x.toJson()]),
  'figures': [
    for (final c in DimensionChains.of(d))
      for (final r in c.runs) '${r.of.name} ${r.fromMm} ${r.toMm}',
  ].join('; '),
  'openings': jsonEncode([for (final x in d.openings) x.toJson()]),
  'dividers': jsonEncode([for (final x in d.dividers) x.toJson()]),
  'materials': jsonEncode({
    'frame': d.frame!.finish.toJson(),
    for (final s in d.sections) s.id: s.finish.toJson(),
    for (final b in d.dividers) b.id: b.finish.toJson(),
  }),
  'handles': jsonEncode([
    for (final h in d.hardware)
      if (h.kind.isHandle) h.toJson(),
  ]),
  'hinges': jsonEncode([
    for (final h in d.hardware)
      if (h.kind == HardwareKind.hinge) h.toJson(),
  ]),
};

Future<Map<String, String>> deviceNow(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys()) key: jsonEncode(prefs.get(key)),
      };
    }))!;

const cards = {
  'DOOR': DesignKind.door,
  'WINDOW': DesignKind.window,
  'SLIDING': DesignKind.sliding,
  'DOOR & WINDOW': DesignKind.both,
  'ANGLED / ASYMMETRICAL': DesignKind.angled,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('create → save → close → reopen', () {
    for (final MapEntry(key: card, value: kind) in cards.entries) {
      testWidgets('$card: everything it is, back exactly', (tester) async {
        // Create: Adam, then a design of this category, through the
        // screens.
        var c = await screen.openTheApp(tester, size: laptop);
        await kept.newCustomer(tester, 'Adam');
        await tester.tap(
          find.byKey(CustomerScreen.newDesignButton).hitTestable().first,
        );
        await tester.pumpAndSettle();
        await nameTheDesign(tester, 'Kept ${kind.label}');
        await chooseDesign(tester, card);
        final begun = c.read(workspaceProvider).design;
        expect(begun.kind, kind);

        // Drawn, read and given everything.
        final controller = c.read(workspaceProvider.notifier);
        controller.state = controller.state.copyWith(design: furnish(begun));
        await tester.pumpAndSettle();
        await putQuestionsAway(tester);

        // Save.
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        final saved = c.read(workspaceProvider).design;
        expect(saved.id, begun.id);
        expect(saved.name, 'Kept ${kind.label}');
        expect(saved.customerId, isNotNull);
        expect(saved.openings, hasLength(1));
        expect(saved.dividers.where((b) => b.parentId != null), hasLength(1));
        expect(saved.hardware.where((h) => h.kind.isHandle), isNotEmpty);
        expect(
          saved.hardware.where((h) => h.kind == HardwareKind.hinge),
          kind.slides ? isEmpty : isNotEmpty,
        );
        expect(saved.dimensions, hasLength(1));
        expect(saved.measured, isNotEmpty);
        if (kind == DesignKind.angled) {
          expect(saved.frame!.outline.corners, hasLength(5));
        }

        // Close: the app gone, nothing carried over but the device.
        c = await kept.reopenTheApp(tester);

        // Reopen: Adam, the card, Open.
        await customers.toCustomers(tester);
        await page.openCustomer(tester, 'Adam');
        await pressOpen(tester, saved.id);
        await tester.pumpAndSettle();
        await putQuestionsAway(tester);
        final opened = c.read(workspaceProvider).design;

        final before = fieldsOf(saved), after = fieldsOf(opened);
        for (final field in before.keys) {
          expect(after[field], before[field], reason: '$card: $field');
        }
        expect(textOf(opened), textOf(saved), reason: '$card: the whole');
        expect(
          facetsOf(MeshBuilder.build(opened)),
          facetsOf(MeshBuilder.build(saved)),
          reason: '$card: the same solid',
        );
      });
    }
  });

  group('designs kept by older versions', () {
    /// A design as an older version kept it: its category as `kind`, no
    /// customer, no sizes, no construction, an opening that says nothing
    /// of what it is, ironmongery naming the section it is on rather than
    /// the opening — and a key this version has never heard of.
    Map<String, Object?> anOldRecord(String id, DesignKind kind) {
      final made = OpeningHardware.settle(
        solid.said(
          kind == DesignKind.angled
              ? SketchInterpreter.interpret(under.drawn().copyWith(name: id))
                    .design
              : SketchInterpreter.interpret(
                  Design.empty(
                    id: id,
                    kind: kind,
                  ).copyWith(name: id, sketch: standardSheet()),
                ).design,
          DesignKind.window,
        ),
      );
      final opening = made.openings.single;
      final map = jsonDecode(jsonEncode(made.toJson())) as Map<String, Object?>;
      map
        ..['id'] = id
        ..['kind'] = map.remove('category')
        ..remove('customer')
        ..remove('customerId')
        ..remove('measured')
        ..remove('construction')
        ..['aKeyFromSomewhereElse'] = {'kept': true};
      map['openings'] = [
        for (final o in map['openings']! as List<Object?>)
          {...(o! as Map<String, Object?>)}..remove('kind'),
      ];
      map['hardware'] = [
        for (final h in map['hardware']! as List<Object?>)
          {...(h! as Map<String, Object?>), 'parentId': opening.sectionId},
      ];
      return map;
    }

    Future<void> keepOld(Map<String, Object?> record) async {
      final prefs = await SharedPreferences.getInstance();
      final design = Design.fromJson(record);
      await prefs.setString(
        '${DesignStore.designKeyPrefix}${design.id}',
        jsonEncode(record),
      );
      final index = prefs.getString(DesignStore.indexKey);
      await prefs.setString(
        DesignStore.indexKey,
        jsonEncode([
          ...?(index == null ? null : jsonDecode(index) as List<Object?>),
          DesignSummary.of(design).toJson(),
        ]),
      );
    }

    test(
      'every category loads, as itself, with its geometry as kept',
      () async {
        for (final kind in DesignKind.values) {
          final record = anOldRecord('old-${kind.name}', kind);
          final design = Design.fromJson(record);
          expect(design.kind, kind);
          expect(
            jsonEncode(design.frame!.toJson()),
            jsonEncode(record['frame']),
            reason: '${kind.name}: the frame as kept',
          );
          expect(
            jsonEncode([for (final d in design.dividers) d.toJson()]),
            jsonEncode(record['dividers']),
          );
          // The ironmongery's older words mean the same thing.
          for (final h in design.hardware) {
            expect(
              design.openingHolding(h.parentId)?.id,
              design.openings.single.id,
              reason: '${h.id} is the opening\'s',
            );
          }
          expect(design.customerId, isNull);
          expect(design.measured, isNull, reason: 'sizes shown as they were');
          MeshBuilder.build(design);
        }
      },
    );

    test('reading the store gives an old design its customer by adding that '
        'one field — every other key of its record exactly as it was — and '
        'reading it again writes nothing', () async {
      final record = anOldRecord('old-door', DesignKind.door)
        ..['customer'] = 'Hawre';
      await keepOld(record);
      final store = DesignStore(customers: CustomerStore());
      final listed = await store.page();
      expect(listed.items.single.customerId, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      final key = '${DesignStore.designKeyPrefix}old-door';
      final after = jsonDecode(prefs.getString(key)!) as Map<String, Object?>;
      final added = after.keys.toSet().difference(record.keys.toSet());
      expect(added, {'customerId'});
      expect(
        jsonEncode({...after}..remove('customerId')),
        jsonEncode(record),
        reason:
            'nothing else in the record touched — not even a key this '
            'version does not know',
      );
      expect(after['customerId'], listed.items.single.customerId);

      // Read again, and opened: nothing more is written.
      final text = prefs.getString(key);
      await DesignStore(customers: CustomerStore()).page();
      final loaded = await DesignStore().load('old-door');
      expect(prefs.getString(key), text);
      expect(loaded!.kind, DesignKind.door);
      expect(loaded.customer, 'Hawre');
    });

    test('an angled design kept by an older version loads raked, and is '
        'never squared by being listed or opened', () async {
      final record = anOldRecord('old-angled', DesignKind.angled);
      await keepOld(record);
      await DesignStore(customers: CustomerStore()).page();
      final loaded = (await DesignStore().load('old-angled'))!;
      expect(loaded.kind, DesignKind.angled);
      expect(loaded.frame!.outline.corners, hasLength(5));
      expect(jsonEncode(loaded.frame!.toJson()), jsonEncode(record['frame']));
    });

    test('the oldest list of designs is moved over without losing an entry '
        '— one this version cannot read is kept exactly as it was', () async {
      final readable = jsonEncode(anOldRecord('oldest', DesignKind.window));
      const unreadable = '{"id": "broken", "this is": "not a design"}';
      const notEvenJson = 'not json at all';
      SharedPreferences.setMockInitialValues({
        DesignStore.legacyKey: [readable, unreadable, notEvenJson],
      });
      final listed = await DesignStore(customers: CustomerStore()).page();
      expect([for (final s in listed.items) s.id], ['oldest']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(DesignStore.legacyKey), isNull);
      expect(prefs.getStringList(DesignStore.legacyUnreadKey), [
        unreadable,
        notEvenJson,
      ]);
      final moved = jsonDecode(
        prefs.getString('${DesignStore.designKeyPrefix}oldest')!,
      ) as Map<String, Object?>;
      expect(
        jsonEncode({...moved}..remove('customerId')),
        readable,
        reason: 'moved whole',
      );
    });

    testWidgets('on the real app: an old design is found under its customer, '
        'opens as itself, and is not rewritten by being looked at', (
      tester,
    ) async {
      final record = anOldRecord('old-window', DesignKind.window)
        ..['customer'] = 'Hawre';
      await tester.runAsync(() => keepOld(record));

      final c = await screen.openTheApp(tester, size: laptop);
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Hawre');
      final device = await deviceNow(tester);
      await pressOpen(tester, 'old-window');
      await tester.pumpAndSettle();
      await putQuestionsAway(tester);

      final opened = c.read(workspaceProvider).design;
      expect(opened.kind, DesignKind.window);
      expect(jsonEncode(opened.frame!.toJson()), jsonEncode(record['frame']));
      for (final view in [
        WorkspaceView.plan,
        WorkspaceView.model,
        WorkspaceView.draw,
      ]) {
        c.read(workspaceProvider.notifier).showView(view);
        await tester.pumpAndSettle();
      }
      expect(await deviceNow(tester), device, reason: 'nothing written');
    });
  });
}

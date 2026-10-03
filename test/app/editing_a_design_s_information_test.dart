import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/design_information_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'one_design_two_views_test.dart' as views;
import 'opening_an_existing_design_test.dart' as existing;
import 'the_designs_screen_test.dart' as screen;

// Adam → Basement Door → Edit information → "Basement Door - New PVC" →
// Save. The same design, by its id, now called that: its category still
// its own, and its drawing, sizes, lines, openings, the division inside the
// opening, the glass and the panel, what the technical drawing draws and
// what the solid builds all exactly as they were. No design is made.

const phone = Size(390, 844);
const laptop = Size(1280, 860);
const renamed = 'Basement Door - New PVC';

/// Adam's basement door as `opening_an_existing_design_test` keeps it —
/// drawn, marked, divided inside the opening, glass over panel, every size
/// given — with a measurement drawn on the sheet as well; his kitchen
/// window; and Sara's garden door.
Future<({String adamId, Design door})> keepAdam() async {
  final kept = await existing.keepAdam();
  final store = DesignStore();
  final door = await store.save(
    kept.door.copyWith(
      dimensions: const [
        DimensionElement(
          id: 'dim-width',
          a: Vec2(0, 2300),
          b: Vec2(1600, 2300),
          statedMm: 1600,
        ),
      ],
    ),
  );
  return (adamId: kept.adam.id, door: door);
}

/// Every design as the device holds it, by id.
Future<Map<String, String>> everyStored(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(DesignStore.designKeyPrefix))
            key.substring(DesignStore.designKeyPrefix.length): prefs.getString(
              key,
            )!,
      };
    }))!;

Design parse(String text) =>
    Design.fromJson(jsonDecode(text) as Map<String, Object?>);

/// Everything about [design] but its name and when it was last edited —
/// which are the only two things renaming may change.
String allButTheName(Design design) {
  final json = jsonDecode(jsonEncode(design.toJson())) as Map<String, Object?>
    ..remove('name')
    ..remove('updatedAt');
  return jsonEncode(json);
}

/// That [after] is [before] renamed to [name] and nothing else: the same
/// id, customer and category; the same drawing, lines, openings, internal
/// divisions, materials and sizes; the same technical drawing and the same
/// solid.
Future<void> onlyTheNameChanged(
  WidgetTester tester,
  Design before,
  Design after,
  String name,
) async {
  expect(after.name, name);
  expect(after.id, before.id);
  expect(after.customerId, before.customerId);
  expect(after.category, before.category);
  expect(allButTheName(after), allButTheName(before));
  // And piece by piece, so a failure says what was lost.
  String json(Object? o) => jsonEncode(o);
  expect(json(after.sketch.toJson()), json(before.sketch.toJson()));
  expect(json(after.frame?.toJson()), json(before.frame?.toJson()));
  expect(
    json([for (final d in after.dividers) d.toJson()]),
    json([for (final d in before.dividers) d.toJson()]),
    reason: 'lines and internal divisions',
  );
  expect(
    json([for (final s in after.sections) s.toJson()]),
    json([for (final s in before.sections) s.toJson()]),
    reason: 'sections, their glass and their panels',
  );
  expect(
    json([for (final o in after.openings) o.toJson()]),
    json([for (final o in before.openings) o.toJson()]),
  );
  expect(
    json([for (final h in after.hardware) h.toJson()]),
    json([for (final h in before.hardware) h.toJson()]),
  );
  expect(
    json([for (final d in after.dimensions) d.toJson()]),
    json([for (final d in before.dimensions) d.toJson()]),
  );
  expect(after.measured, before.measured);
  expect(after.widthMm, before.widthMm);
  expect(after.heightMm, before.heightMm);
  expect(views.modelled(after), views.modelled(before), reason: '3D');
  // A design with nothing drawn yet has no technical drawing to compare.
  if (before.frame != null) {
    final cad = await tester.runAsync(
      () async => (await views.drawn(before), await views.drawn(after)),
    );
    expect(cad!.$2, cad.$1, reason: 'the technical drawing');
  }
}

Future<void> editOnAdamsPage(WidgetTester tester, String id) async {
  final edit = find.byKey(CustomerDesignCard.editKey(id));
  await tester.scrollUntilVisible(
    edit.hitTestable(),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(edit.hitTestable());
  await tester.pumpAndSettle();
  expect(find.byType(DesignInformationScreen), findsOneWidget);
}

String typedName(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(DesignInformationScreen.nameField))
    .controller!
    .text;

Future<void> typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(DesignInformationScreen.nameField), name);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(DesignInformationScreen.saveButton);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> toAdam(WidgetTester tester) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Basement Door → Edit information → "$renamed" → Save: the '
      'same design renamed, and nothing else about it changed', (tester) async {
    final kept = await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everyStored(tester);
    final door = parse(before['basement-door']!);
    // There is everything to lose.
    expect(door.frame, isNotNull);
    expect(door.openings, hasLength(1));
    expect(door.dividers.where((d) => d.parentId != null), isNotEmpty);
    expect(
      door.sections.map((s) => s.finish.material).toSet(),
      containsAll([MaterialKind.frostedGlass, MaterialKind.panel]),
    );
    expect(door.measured, isNotEmpty);
    expect(door.dimensions, hasLength(1));
    expect(door.hardware, isNotEmpty);

    await toAdam(tester);
    await editOnAdamsPage(tester, 'basement-door');
    // The design's information as it is: its name, and its category shown.
    expect(typedName(tester), 'Basement Door');
    expect(
      tester
          .widget<Text>(find.byKey(DesignInformationScreen.categoryText))
          .data,
      'Door',
    );
    await typeName(tester, '  $renamed ');
    await save(tester);

    // Back on Adam's page, the card says the new name.
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.text(renamed), findsOneWidget);
    expect(find.text('Basement Door'), findsNothing);

    // No design was made or lost, and every other one is byte for byte.
    final after = await everyStored(tester);
    expect(after.keys.toSet(), before.keys.toSet());
    for (final id in before.keys.where((id) => id != 'basement-door')) {
      expect(after[id], before[id], reason: id);
    }
    final now = parse(after['basement-door']!);
    await onlyTheNameChanged(tester, door, now, renamed);
    expect(now.customerId, kept.adamId);
    expect(now.category, DesignKind.door);

    // It lasts: the app closed and opened again, and the design opened.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final c = await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    expect(find.text(renamed), findsOneWidget);
    final open = find
        .byKey(CustomerDesignCard.openKey('basement-door'))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
    final inHand = c.read(workspaceProvider).design;
    await onlyTheNameChanged(tester, door, inHand, renamed);
  });

  testWidgets('the category stays with a window renamed too', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = parse((await everyStored(tester))['kitchen-window']!);
    await toAdam(tester);
    await editOnAdamsPage(tester, 'kitchen-window');
    expect(
      tester
          .widget<Text>(find.byKey(DesignInformationScreen.categoryText))
          .data,
      'Window',
    );
    await typeName(tester, 'Kitchen Window - Tilt');
    await save(tester);
    final after = parse((await everyStored(tester))['kitchen-window']!);
    expect(after.category, DesignKind.window);
    await onlyTheNameChanged(tester, before, after, 'Kitchen Window - Tilt');
  });

  testWidgets('a name is needed: an empty one or one of only spaces is '
      'refused with a reason, and turning back changes nothing', (
    tester,
  ) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everyStored(tester);
    await toAdam(tester);
    await editOnAdamsPage(tester, 'basement-door');

    for (final empty in const ['', '    ']) {
      await typeName(tester, empty);
      await save(tester);
      expect(find.byType(DesignInformationScreen), findsOneWidget);
      expect(find.byKey(DesignInformationScreen.problemText), findsOneWidget);
    }
    // Typing takes the message away.
    await typeName(tester, 'Something');
    expect(find.byKey(DesignInformationScreen.problemText), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.text('Basement Door'), findsOneWidget);
    expect(await everyStored(tester), before);
  });

  testWidgets('in the drawing: the design\'s own panel → Edit information '
      'renames the design in hand, and it is kept renamed', (tester) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: laptop);
    final before = await everyStored(tester);
    final door = parse(before['basement-door']!);
    await toAdam(tester);
    final open = find
        .byKey(CustomerDesignCard.openKey('basement-door'))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    // Sizes are all given, so nothing stands over the drawing.
    expect(find.byType(WorkspaceScreen), findsOneWidget);

    final edit = find.byKey(InspectorPanel.editInformationKey);
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(typedName(tester), 'Basement Door');
    await typeName(tester, renamed);
    await save(tester);

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final inHand = c.read(workspaceProvider).design;
    await onlyTheNameChanged(tester, door, inHand, renamed);
    expect(
      find.descendant(
        of: find.byKey(InspectorPanel.identityKey),
        matching: find.text(renamed),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final after = await everyStored(tester);
    expect(after.keys.toSet(), before.keys.toSet());
    await onlyTheNameChanged(
      tester,
      door,
      parse(after['basement-door']!),
      renamed,
    );
  });

  test('the store renames by id and refuses an empty name', () async {
    final kept = await keepAdam();
    final store = DesignStore();
    expect(await store.retitle('basement-door', '   '), isNull);
    expect(await store.retitle('nothing-kept', renamed), isNull);
    final done = await store.retitle('basement-door', ' $renamed ');
    expect(done!.id, 'basement-door');
    expect(done.name, renamed);
    expect(allButTheName(done), allButTheName(kept.door));
    expect(await store.count(), 3);
  });

  testWidgets('it fits a phone, a tablet and a laptop', (tester) async {
    await keepAdam();
    for (final size in const [Size(360, 740), phone, Size(820, 1180), laptop]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      await toAdam(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'cards at $size');
      await editOnAdamsPage(tester, 'basement-door');
      await typeName(tester, '');
      await save(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'form at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}

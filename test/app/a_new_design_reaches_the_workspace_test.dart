import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/new_design_setup.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;

// Adam → New Design → "Basement Door" → Door → the drawing workspace. The
// workspace is the existing one, and it is given the design the setup
// made: its id, Adam's id, its name and its category. It knows which design
// it is editing, shows it, and every edit made there — drawing, reading,
// keeping — is an edit to that design and no other.

/// From the designs list to Adam's New Design, named, category chosen, and
/// into the workspace.
Future<void> intoTheWorkspace(
  WidgetTester tester, {
  String name = 'Basement Door',
  String card = 'DOOR',
}) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  await tester.tap(find.byKey(CustomerScreen.newDesignButton).hitTestable());
  await tester.pumpAndSettle();
  await nameTheDesign(tester, name);
  await chooseDesign(tester, card);
  expect(find.byType(WorkspaceScreen), findsOneWidget);
}

Future<Map<String, Design>> everyKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final store = DesignStore();
      final all = await store.page(limit: 1000);
      return {for (final s in all.items) s.id: (await store.load(s.id))!};
    }))!;

Finder inIdentity(String text) => find.descendant(
  of: find.byKey(InspectorPanel.identityKey),
  matching: find.text(text),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the workspace receives the new design\'s id, customer, name '
      'and category, and shows which design it is editing', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(1280, 860));
    final before = await everyKept(tester);
    await intoTheWorkspace(tester);

    final identity = c.read(workspaceProvider).design.identity;
    expect(before.keys, isNot(contains(identity.id)), reason: 'a new design');
    expect(identity.customerId, kept['Adam']!.id);
    expect(identity.name, 'Basement Door');
    expect(identity.category, DesignKind.door);

    // The workspace says which design it is: its name at the top, and on
    // the design's own panel the name, the category and the customer.
    expect(find.text('Basement Door'), findsWidgets);
    expect(find.byKey(InspectorPanel.identityKey), findsOneWidget);
    expect(inIdentity('Basement Door'), findsOneWidget);
    expect(inIdentity('Door'), findsOneWidget);
    expect(inIdentity('Adam'), findsOneWidget);

    // And the design kept for it is the same design.
    await tester.pump(WorkspaceScreen.keepAfter);
    final stored = await tester.runAsync(() => DesignStore().load(identity.id));
    expect(stored!.identity, identity);
  });

  for (final (card, kind, name) in const [
    ('DOOR', DesignKind.door, 'Basement Door'),
    ('WINDOW', DesignKind.window, 'Kitchen Window'),
    ('SLIDING', DesignKind.sliding, 'Third Floor Sliding'),
    ('DOOR & WINDOW', DesignKind.both, 'Front Entrance'),
  ]) {
    testWidgets('$card: the workspace edits "$name", a ${kind.label}, '
        'Adam\'s', (tester) async {
      final kept = await customers.keepThreeCustomers();
      final c = await screen.openTheApp(tester, size: const Size(1280, 860));
      await intoTheWorkspace(tester, name: name, card: card);
      final identity = c.read(workspaceProvider).design.identity;
      expect(identity.name, name);
      expect(identity.category, kind);
      expect(identity.customerId, kept['Adam']!.id);
      expect(inIdentity(kind.label), findsOneWidget);
    });
  }

  testWidgets('drawing in the workspace, reading it and leaving it are all '
      'edits to that one design — nothing else is made or touched', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(1280, 860));
    final before = await everyKept(tester);
    await intoTheWorkspace(tester, name: 'Kitchen Window', card: 'WINDOW');
    final identity = c.read(workspaceProvider).design.identity;

    // The existing drawing, worked the existing way: strokes on the sheet,
    // read into a frame, a mullion and two leaves.
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    await notNowToSizes(tester);
    final drawn = c.read(workspaceProvider).design;
    expect(drawn.identity, identity, reason: 'reading keeps who it is');
    expect(drawn.frame, isNotNull);
    expect(drawn.openings, hasLength(2));

    // Leaving keeps it — under its own id, as itself.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    final after = await everyKept(tester);
    expect(after.keys.toSet().difference(before.keys.toSet()), {identity.id});
    for (final MapEntry(:key, :value) in before.entries) {
      expect(jsonEncode(after[key]!.toJson()), jsonEncode(value.toJson()));
    }
    final stored = after[identity.id]!;
    expect(stored.identity, identity);
    expect(
      jsonEncode(stored.sketch.toJson()),
      jsonEncode(drawn.sketch.toJson()),
    );
    expect(stored.openings, hasLength(2));

    // Opened again from its card, it is the same design in the workspace.
    final open = find
        .byKey(CustomerDesignCard.openKey(identity.id))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).design.identity, identity);
    expect(inIdentity('Kitchen Window'), findsOneWidget);
  });

  test('the drawing engine reads a design begun by the setup exactly as it '
      'reads any other', () {
    final adam = Customer(
      id: 'customer-adam',
      name: 'Adam',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );
    final at = DateTime(2026, 3, 1, 9);
    final begun = NewDesignSetup.forCustomer(adam)
        .withName('Basement Door')
        .withKind(DesignKind.door)
        .begin(id: 'd', now: at);
    final plain = Design.empty(
      id: 'd',
      kind: DesignKind.door,
      name: 'Other',
      now: at,
    );
    // The same sheet the workspace test draws: an outline, a mullion and a
    // mark in each light.
    final strokes = [
      sheet.pen('outline', const [
        Vec2(0, 0),
        Vec2(2400, 0),
        Vec2(2400, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      sheet.pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
      sheet.pen('k1', sheet.chevron(const Vec2(600, 1050))),
      sheet.pen('k2', sheet.chevron(const Vec2(1800, 1050))),
    ];
    Map<String, Object?> geometryOf(Design design) {
      final read = SketchInterpreter.interpret(
        design.copyWith(sketch: Sketch(strokes: strokes)),
      ).design;
      final json = read.toJson()
        ..removeWhere(
          (k, _) => const {
            'name',
            'customer',
            'customerId',
            'updatedAt',
            'createdAt',
            'construction',
            'measured',
          }.contains(k),
        );
      return jsonDecode(jsonEncode(json)) as Map<String, Object?>;
    }

    expect(geometryOf(begun), geometryOf(plain));
    expect(begun.identity.name, 'Basement Door');
  });
}

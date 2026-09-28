import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// Adam → New Design → Basement Door → Category: Door. After the name, the
// category — Door, Window, Sliding, Door & Window, in that order — and only
// for a new design. It is saved into the design as its category, and it
// builds nothing: no line, no frame, no opening, no template.

const cards = ['DOOR', 'WINDOW', 'SLIDING', 'DOOR & WINDOW'];

Future<void> toAdamsCategories(
  WidgetTester tester, {
  String name = 'Basement Door',
}) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  await tester.tap(find.byKey(CustomerScreen.newDesignButton).hitTestable());
  await tester.pumpAndSettle();
  await nameTheDesign(tester, name);
  expect(find.byType(StartScreen), findsOneWidget);
}

VoidCallback? startDrawing(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(StartScreen.startLabel),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .onPressed;

/// The design as it was kept, as the stored JSON says it.
Future<Map<String, Object?>> storedJson(WidgetTester tester, String id) async =>
    (await tester.runAsync(() async {
      final design = await DesignStore().load(id);
      return jsonDecode(jsonEncode(design!.toJson())) as Map<String, Object?>;
    }))!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the four categories, in the user\'s order', () {
    expect(
      [for (final (kind, _) in StartScreen.choices) kind],
      [DesignKind.door, DesignKind.window, DesignKind.sliding, DesignKind.both],
    );
    expect(
      [for (final (kind, _) in StartScreen.choices) kind.label],
      ['Door', 'Window', 'Sliding', 'Door & window'],
    );
  });

  testWidgets('after the design name come the four categories — Door, '
      'Window, Sliding, Door & Window — and none chosen', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await toAdamsCategories(tester);

    // One above another on a phone, in that order.
    final tops = [
      for (final card in cards) tester.getTopLeft(find.text(card)).dy,
    ];
    expect(tops, [...tops]..sort(), reason: 'in the order $cards');
    expect(tops.toSet(), hasLength(4));
    // Nothing is chosen for the user.
    expect(startDrawing(tester), isNull);
    expect(find.text('Choose a type to continue'), findsOneWidget);
  });

  testWidgets('the four stand in a row, in the same order, where there is '
      'room', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(1440, 900));
    await toAdamsCategories(tester);
    final lefts = [
      for (final card in cards) tester.getTopLeft(find.text(card)).dx,
    ];
    expect(lefts, [...lefts]..sort());
    expect(lefts.toSet(), hasLength(4));
  });

  for (final (card, kind) in const [
    ('DOOR', DesignKind.door),
    ('WINDOW', DesignKind.window),
    ('SLIDING', DesignKind.sliding),
    ('DOOR & WINDOW', DesignKind.both),
  ]) {
    testWidgets('$card is saved into the design as its category, with '
        'nothing built', (tester) async {
      final kept = await customers.keepThreeCustomers();
      final c = await screen.openTheApp(tester, size: const Size(390, 844));
      await toAdamsCategories(tester);
      await chooseDesign(tester, card);
      expect(find.byType(WorkspaceScreen), findsOneWidget);

      final made = c.read(workspaceProvider).design;
      expect(made.category, kind);
      expect(made.name, 'Basement Door');
      expect(made.customerId, kept['Adam']!.id);

      // No geometry of any kind: no drawing, no frame, no line, no
      // section, no opening, no hardware, no figure — no template.
      expect(made.sketch.strokes, isEmpty);
      expect(made.frame, isNull);
      expect(made.dividers, isEmpty);
      expect(made.sections, isEmpty);
      expect(made.openings, isEmpty);
      expect(made.hardware, isEmpty);
      expect(made.dimensions, isEmpty);
      expect(made.texts, isEmpty);
      expect(made.arrows, isEmpty);

      // Saved into the design model: id, customerId, name, category.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      final json = await storedJson(tester, made.id);
      expect(json['id'], made.id);
      expect(json['customerId'], kept['Adam']!.id);
      expect(json['name'], 'Basement Door');
      expect(json['category'], kind.name);
      expect(json.containsKey('kind'), isFalse, reason: 'said once');
      // The list's own index says the same.
      final summary = await tester.runAsync(
        () => DesignStore().page(customerId: kept['Adam']!.id),
      );
      expect(summary!.items.singleWhere((s) => s.id == made.id).kind, kind);
    });
  }

  testWidgets('a second tap moves the choice; what is saved is the last one '
      'chosen', (tester) async {
    await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await toAdamsCategories(tester, name: 'Kitchen Window');
    await tester.ensureVisible(find.text('DOOR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DOOR'));
    await tester.pumpAndSettle();
    await chooseDesign(tester, 'WINDOW');
    expect(c.read(workspaceProvider).design.category, DesignKind.window);
  });

  testWidgets('an existing design never comes here: it opens as itself, '
      'its category as it was kept', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    // adam-3 is Adam's Third Floor Sliding.
    final open = find.byKey(CustomerDesignCard.openKey('adam-3')).hitTestable();
    await tester.scrollUntilVisible(open, 100);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
    final design = c.read(workspaceProvider).design;
    expect(design.id, 'adam-3');
    expect(design.category, DesignKind.sliding);
    expect(design.customerId, kept['Adam']!.id);
  });

  test('a design saved before the category had its name still loads as '
      'what it was', () {
    for (final kind in DesignKind.values) {
      final older = Design.empty(id: 'd', kind: kind, name: 'Old').toJson()
        ..remove('category')
        ..['kind'] = kind.name;
      final back = Design.fromJson(jsonDecode(jsonEncode(older)));
      expect(back.category, kind);
      expect(back.toJson()['category'], kind.name);
    }
    for (final kind in DesignKind.values) {
      final summary =
          DesignSummary.of(Design.empty(id: 'd', kind: kind, name: 'Old'))
              .toJson()
            ..remove('category')
            ..['kind'] = kind.name;
      expect(DesignSummary.fromJson(summary).kind, kind);
    }
  });
}

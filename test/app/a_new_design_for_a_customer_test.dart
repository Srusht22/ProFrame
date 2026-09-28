import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/new_design_setup.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// Adam → + New Design. A new design process, not a design: it knows it is
// Adam's and nothing else. No category is chosen for the user, no name is
// made up, none of Adam's designs is opened or copied, and nothing is kept
// until the setup is finished — turning back leaves Adam with exactly the
// designs he had.

/// Every design kept, as its JSON, by id.
Future<Map<String, String>> everyKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final store = DesignStore();
      final all = await store.page(limit: 1000);
      return {
        for (final s in all.items)
          s.id: jsonEncode((await store.load(s.id))!.toJson()),
      };
    }))!;

Future<void> pressNewDesign(WidgetTester tester) async {
  final button = find.byKey(CustomerScreen.newDesignButton).hitTestable();
  await tester.tap(button.first);
  await tester.pumpAndSettle();
}

/// New Design, then the design's name: on to the choice of category.
Future<void> toTheChoice(WidgetTester tester, String name) async {
  await pressNewDesign(tester);
  await nameTheDesign(tester, name);
}

NewDesignSetup setupShown(WidgetTester tester) =>
    tester.widget<StartScreen>(find.byType(StartScreen)).setup;

VoidCallback? startDrawing(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(StartScreen.startLabel),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .onPressed;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the setup itself', () {
    final adam = Customer(
      id: 'customer-adam',
      name: 'Adam',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    test('begun for Adam, it knows Adam and nothing else', () {
      final setup = NewDesignSetup.forCustomer(adam);
      expect(setup.customerId, adam.id);
      expect(setup.customer, 'Adam');
      expect(setup.kind, isNull, reason: 'no category chosen for the user');
      expect(setup.name, isNull, reason: 'no name made up');
      expect(setup.isComplete, isFalse);
    });

    test('it cannot become a design before it is named and its category '
        'chosen', () {
      final setup = NewDesignSetup.forCustomer(adam);
      expect(() => setup.begin(id: 'd'), throwsStateError);
      expect(
        () => setup.withName('Basement Door').begin(id: 'd'),
        throwsStateError,
      );
      expect(
        () => setup.withKind(DesignKind.door).begin(id: 'd'),
        throwsStateError,
      );
    });

    test('named and chosen, the design is Adam\'s, called what he said, of '
        'that category, and nothing drawn', () {
      for (final kind in DesignKind.values) {
        final design = NewDesignSetup.forCustomer(adam)
            .withName('Basement Door')
            .withKind(kind)
            .begin(id: 'd-${kind.name}');
        expect(design.customerId, adam.id);
        expect(design.customer, 'Adam');
        expect(design.kind, kind);
        expect(design.name, 'Basement Door');
        expect(design.shownName, 'Basement Door');
        expect(design.sketch.strokes, isEmpty);
        expect(design.frame, isNull);
        expect(design.dividers, isEmpty);
        expect(design.openings, isEmpty);
        expect(design.measured, isEmpty, reason: 'no size guessed');
        expect(
          design.construction,
          kind.asksConstruction ? Construction.pending : isNull,
        );
      }
    });

    test('a name the user typed is the name, and survives the category', () {
      final setup = const NewDesignSetup(customerId: 'c')
          .withName('  Basement Door ');
      expect(
        setup.withKind(DesignKind.door).begin(id: 'd').name,
        'Basement Door',
      );
    });
  });

  testWidgets('1, 2 — New Design on Adam\'s page starts a new design '
      'process that knows it is Adam\'s', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    await pressNewDesign(tester);

    // The first step is the design's name, and it knows it is Adam's.
    final naming = tester.widget<DesignNameScreen>(
      find.byType(DesignNameScreen),
    );
    expect(naming.setup.customerId, kept['Adam']!.id);
    expect(naming.setup.name, isNull);
    await nameTheDesign(tester, 'Basement Door');

    expect(find.byType(StartScreen), findsOneWidget);
    final setup = setupShown(tester);
    expect(setup.customerId, kept['Adam']!.id);
    expect(setup.customer, 'Adam');
    expect(setup.kind, isNull);
    expect(setup.name, 'Basement Door');
    // Nothing is chosen for the user, so there is nothing to start yet.
    expect(startDrawing(tester), isNull);
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('3, 4 — it opens none of Adam\'s designs, copies none, and '
      'keeps nothing until the setup is finished', (tester) async {
    await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final before = await everyKept(tester);
    final inHand = c.read(workspaceProvider).design.id;

    await toTheChoice(tester, 'Basement Door');
    // Not a design: no drawing is open, and none of Adam's is in hand.
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(c.read(workspaceProvider).design.id, inHand);
    expect(before.keys, isNot(contains(inHand)));
    expect(await everyKept(tester), before, reason: 'nothing kept yet');

    // Choosing a card is still the setup: nothing kept.
    await tester.ensureVisible(find.text('WINDOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WINDOW'));
    await tester.pumpAndSettle();
    expect(startDrawing(tester), isNotNull);
    expect(await everyKept(tester), before);

    // Turning back, through the name, leaves Adam exactly as he was.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(await everyKept(tester), before);
    expect(find.text('Customer · 4 designs'), findsOneWidget);
  });

  testWidgets('finished, the setup makes one new design of Adam\'s — the '
      'name given and the category chosen, nothing copied — and comes back '
      'to his page', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final before = await everyKept(tester);

    await toTheChoice(tester, 'Front Entrance Door');
    await chooseDesign(tester, 'DOOR');
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final made = c.read(workspaceProvider).design;
    expect(before.keys, isNot(contains(made.id)), reason: 'a new design');
    expect(made.customerId, kept['Adam']!.id);
    expect(made.kind, DesignKind.door);
    expect(made.name, 'Front Entrance Door');
    expect(find.text('Front Entrance Door'), findsOneWidget);
    expect(made.sketch.strokes, isEmpty, reason: 'nothing copied into it');
    expect(made.frame, isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    final after = await everyKept(tester);
    // Every design Adam had, untouched, and exactly one more.
    for (final MapEntry(:key, :value) in before.entries) {
      expect(after[key], value, reason: key);
    }
    expect(after.keys.toSet().difference(before.keys.toSet()), {made.id});
    expect(find.text('Customer · 5 designs'), findsOneWidget);
    // Nobody else was given it.
    final ofSara = await tester.runAsync(
      () => DesignStore().page(customerId: kept['Sara']!.id),
    );
    expect(ofSara!.items.map((s) => s.id), ['sara-0']);
  });

  testWidgets('a customer with no designs starts the same way, and the '
      'design is theirs', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Karwan');
    await toTheChoice(tester, 'Third Floor Sliding');
    expect(setupShown(tester).customerId, kept['Karwan']!.id);
    await chooseDesign(tester, 'SLIDING');
    final made = c.read(workspaceProvider).design;
    expect(made.customerId, kept['Karwan']!.id);
    expect(made.kind, DesignKind.sliding);
    expect(made.name, 'Third Floor Sliding');
  });

  testWidgets('the designs list\'s own New Design goes the same way: who it '
      'is for, then its own name', (tester) async {
    final c = await screen.openTheApp(tester);
    await toTheCategories(tester, customer: 'Dilan', design: 'Kitchen Window');
    expect(setupShown(tester).customerId, isNull);
    expect(setupShown(tester).kind, isNull);
    await chooseDesign(tester, 'WINDOW');
    final made = c.read(workspaceProvider).design;
    expect(made.name, 'Kitchen Window');
    expect(made.customer, 'Dilan');
    // Kept under the customer that name stands for.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final kept = await tester.runAsync(() => DesignStore().load(made.id));
    expect(kept!.customerId, isNotNull);
  });

  testWidgets('it fits a phone, a tablet and a laptop', (tester) async {
    await customers.keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      await screen.openTheApp(tester, size: size);
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      await pressNewDesign(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'name at $size');
      await nameTheDesign(tester, 'Basement Door');
      expect(page.overflowing(tester), isEmpty, reason: 'choice at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
  });
}

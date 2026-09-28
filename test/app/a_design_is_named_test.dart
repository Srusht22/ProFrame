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
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// Adam → New Design → Design name. A new design is called what the user
// calls it — Basement Door, Front Entrance Door, Kitchen Window, Third Floor
// Sliding — and never Adam, who is who it is for, and never a name the
// application made up. The name is required: an empty one is refused with a
// message saying so, and nothing goes on until there is one. It is kept as
// the design's, trimmed, and never on the customer.

Future<void> toAdamsNewDesign(WidgetTester tester) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  await tester.tap(find.byKey(CustomerScreen.newDesignButton).hitTestable());
  await tester.pumpAndSettle();
  expect(find.byType(DesignNameScreen), findsOneWidget);
}

String fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(DesignNameScreen.nameField))
    .controller!
    .text;

Future<void> pressContinue(WidgetTester tester) async {
  await tester.tap(find.byKey(DesignNameScreen.continueButton));
  await tester.pumpAndSettle();
}

Future<int> keptDesigns(WidgetTester tester) async =>
    (await tester.runAsync(() => DesignStore().count()))!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the name, in the setup', () {
    final adam = Customer(
      id: 'customer-adam',
      name: 'Adam',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    test('an empty name is a problem, said in words', () {
      for (final empty in ['', ' ', '   ', '\t', ' \n ']) {
        final problem = NewDesignSetup.nameProblem(empty);
        expect(problem, isNotNull, reason: '"$empty"');
        expect(problem, contains('name'));
      }
    });

    test('the user\'s own names are taken exactly, trimmed either side', () {
      for (final name in [
        'Basement Door',
        'Front Entrance Door',
        'Kitchen Window',
        'Third Floor Sliding',
      ]) {
        expect(NewDesignSetup.nameProblem(name), isNull);
        final named = NewDesignSetup.forCustomer(adam).withName('  $name\t ');
        expect(named.name, name);
      }
      // Inside the name is the user's, spacing and all.
      expect(
        NewDesignSetup.forCustomer(adam).withName(' Kitchen  Window ').name,
        'Kitchen  Window',
      );
    });

    test('an empty name cannot get into a setup, nor a setup without one '
        'into a design', () {
      final setup = NewDesignSetup.forCustomer(adam);
      expect(() => setup.withName('   '), throwsArgumentError);
      expect(setup.isNamed, isFalse);
      expect(
        () => setup.withKind(DesignKind.door).begin(id: 'd'),
        throwsStateError,
      );
    });

    test('the customer\'s name is never the design\'s, by either route', () {
      expect(NewDesignSetup.forCustomer(adam).name, isNull);
      expect(NewDesignSetup.forPerson('Adam').name, isNull);
      expect(NewDesignSetup.forPerson(' Adam ').customer, 'Adam');
    });

    test('nothing is numbered: Door 1 is a name only when it is typed', () {
      final named = NewDesignSetup.forCustomer(adam)
          .withName('Door 1')
          .withKind(DesignKind.door)
          .begin(id: 'd');
      expect(named.name, 'Door 1');
    });

    test('the name is kept with the design, through a save and a load', () {
      final design = NewDesignSetup.forCustomer(adam)
          .withName('Basement Door')
          .withKind(DesignKind.door)
          .begin(id: 'd');
      final back = Design.fromJson(jsonDecode(jsonEncode(design.toJson())));
      expect(back.name, 'Basement Door');
      expect(back.customer, 'Adam');
    });
  });

  testWidgets('Adam → New Design asks the design\'s name first, with the '
      'field empty — never Adam', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await toAdamsNewDesign(tester);

    expect(find.text('Design name'), findsWidgets);
    expect(fieldText(tester), isEmpty, reason: 'nothing offered, not Adam');
    expect(find.byType(StartScreen), findsNothing);
    // Who it is for is shown as who it is for.
    expect(find.text('Adam'), findsOneWidget);
    expect(find.byKey(DesignNameScreen.problemText), findsNothing);
  });

  testWidgets('an empty name is refused with a clear message, and nothing '
      'goes on until there is a name', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    final before = await keptDesigns(tester);
    await toAdamsNewDesign(tester);

    for (final empty in ['', '    ']) {
      await tester.enterText(find.byKey(DesignNameScreen.nameField), empty);
      await tester.pump();
      await pressContinue(tester);
      expect(find.byType(DesignNameScreen), findsOneWidget);
      expect(find.byType(StartScreen), findsNothing);
      expect(find.byKey(DesignNameScreen.problemText), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(DesignNameScreen.problemText)).data,
        NewDesignSetup.nameProblem(empty),
      );
    }
    // The keyboard's own done does the same.
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsNothing);

    // Typing takes the message away.
    await tester.enterText(find.byKey(DesignNameScreen.nameField), 'B');
    await tester.pump();
    expect(find.byKey(DesignNameScreen.problemText), findsNothing);
    expect(page.overflowing(tester), isEmpty);
    expect(await keptDesigns(tester), before, reason: 'nothing kept');
  });

  testWidgets('a name typed with spaces either side is kept trimmed, as the '
      'design\'s and never the customer\'s', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await toAdamsNewDesign(tester);
    await tester.enterText(
      find.byKey(DesignNameScreen.nameField),
      '   Basement Door  ',
    );
    await tester.pump();
    await pressContinue(tester);

    expect(find.byType(StartScreen), findsOneWidget);
    final setup = tester.widget<StartScreen>(find.byType(StartScreen)).setup;
    expect(setup.name, 'Basement Door');
    expect(setup.customerId, kept['Adam']!.id);
    // Both shown on the choice: who it is for, and what it is called.
    expect(find.text('Adam'), findsOneWidget);
    expect(find.text('Basement Door'), findsOneWidget);

    await chooseDesign(tester, 'DOOR');
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final made = c.read(workspaceProvider).design;
    expect(made.name, 'Basement Door');
    expect(made.customer, 'Adam');
    expect(made.customerId, kept['Adam']!.id);
    expect(find.text('Basement Door'), findsOneWidget, reason: 'its title');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final stored = await tester.runAsync(() => DesignStore().load(made.id));
    expect(stored!.name, 'Basement Door');

    // The customer is exactly who they were: no design name on them, and
    // no customer made of the design's name.
    final people = await tester.runAsync(() async {
      final store = CustomerStore();
      final all = await store.page(limit: 100);
      return [for (final s in all.items) (await store.load(s.id))!];
    });
    final adam = people!.singleWhere((p) => p.id == kept['Adam']!.id);
    expect(jsonEncode(adam.toJson()), jsonEncode(kept['Adam']!.toJson()));
    expect(jsonEncode(adam.toJson()), isNot(contains('Basement Door')));
    expect(people.map((p) => p.name), isNot(contains('Basement Door')));
    expect(people, hasLength(3));

    // And the card on Adam's page is called by it.
    await tester.scrollUntilVisible(
      find.byKey(CustomerScreen.designKey(made.id)),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byKey(CustomerScreen.designKey(made.id)),
        matching: find.text('Basement Door'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('each design is called exactly what the user typed, and none '
      'is numbered for them', (tester) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Karwan');
    final made = <String, String>{};
    for (final (name, card) in [
      ('Basement Door', 'DOOR'),
      ('Front Entrance Door', 'DOOR'),
      ('Kitchen Window', 'WINDOW'),
      ('Third Floor Sliding', 'SLIDING'),
    ]) {
      await tester.tap(
        find.byKey(CustomerScreen.newDesignButton).hitTestable().first,
      );
      await tester.pumpAndSettle();
      await nameTheDesign(tester, name);
      await chooseDesign(tester, card);
      made[c.read(workspaceProvider).design.id] = name;
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
    final ofKarwan = await tester.runAsync(
      () => DesignStore().page(customerId: kept['Karwan']!.id),
    );
    expect({for (final s in ofKarwan!.items) s.id: s.name}, made);
    for (final s in ofKarwan.items) {
      expect(s.name, isNot(matches(RegExp(r'^(Door|Window|Design) \d+$'))));
      expect(s.name, isNot('Karwan'));
    }
  });

  testWidgets('back from the choice keeps the name typed; back from the name '
      'keeps nothing', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    final before = await keptDesigns(tester);
    await toAdamsNewDesign(tester);
    await nameTheDesign(tester, 'Kitchen Window');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DesignNameScreen), findsOneWidget);
    expect(fieldText(tester), 'Kitchen Window');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(await keptDesigns(tester), before);
  });

  testWidgets('the designs list asks for the design\'s name too, after who '
      'it is for', (tester) async {
    final c = await screen.openTheApp(tester);
    await tester.tap(find.text('New Design').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-design-customer')),
      'Adam',
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignNameScreen), findsOneWidget);
    expect(fieldText(tester), isEmpty, reason: 'not the person typed');
    await pressContinue(tester);
    expect(find.byKey(DesignNameScreen.problemText), findsOneWidget);
    await nameTheDesign(tester, 'Front Entrance Door');
    await chooseDesign(tester, 'DOOR');
    final made = c.read(workspaceProvider).design;
    expect(made.name, 'Front Entrance Door');
    expect(made.customer, 'Adam');
  });

  testWidgets('it fits a phone, a tablet and a laptop, message and all', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      await screen.openTheApp(tester, size: size);
      await toAdamsNewDesign(tester);
      await pressContinue(tester);
      expect(find.byKey(DesignNameScreen.problemText), findsOneWidget);
      expect(page.overflowing(tester), isEmpty, reason: 'at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
  });
}

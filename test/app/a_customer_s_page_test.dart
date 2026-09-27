import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/new_customer_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// A customer's page. Adam is a person who owns designs, not a design:
//
// Adam
//   Customer information — phone, address, notes
// DESIGNS
//   Basement Door
//   Front Entrance Door
//   Kitchen Window
//   Third Floor Sliding
//   + New Design
//
// Opening Adam asks nothing, begins nothing and opens no drawing. Door,
// window or sliding is asked only when New Design is pressed.

Future<void> openCustomer(WidgetTester tester, String name) async {
  await tester.tap(customers.cardOf(name));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
}

Future<int> keptDesigns(WidgetTester tester) async =>
    (await tester.runAsync(() => DesignStore().count()))!;

List<String> rows(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(CustomerScreen),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'customer-design-',
                  ),
            ),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring(
      'customer-design-'.length,
    ),
];

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opening Adam shows Adam — his information, then his designs '
      'and New Design — and asks, begins and draws nothing', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    final before = await keptDesigns(tester);
    await openCustomer(tester, 'Adam');

    // Adam, as a customer.
    expect(find.text('Customer information'), findsOneWidget);
    for (final label in ['Phone', 'Address', 'Notes']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('+964 750 123 4567'), findsOneWidget);
    expect(find.text('Customer · 4 designs'), findsOneWidget);

    // Then his designs, each by its own name and kind.
    expect(find.text('Designs'), findsOneWidget);
    final seen = <String>{};
    for (final name in [
      'Basement Door',
      'Front Entrance Door',
      'Kitchen Window',
      'Third Floor Sliding',
    ]) {
      await tester.scrollUntilVisible(find.text(name), 100);
      expect(find.text(name), findsOneWidget);
      seen.addAll(rows(tester));
    }
    expect(seen, hasLength(4));
    expect(
      find.descendant(
        of: find.byKey(CustomerScreen.designKey('adam-3')),
        matching: find.text('Sliding'),
      ),
      findsOneWidget,
    );
    // And New Design.
    expect(find.byKey(CustomerScreen.newDesignButton), findsOneWidget);

    // Nothing was asked, begun or opened on the way in.
    expect(find.byType(StartScreen), findsNothing);
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(await keptDesigns(tester), before);
    expect(overflowing(tester), isEmpty);
  });

  testWidgets('only the customer\'s own designs are on their page', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await openCustomer(tester, 'Sara');
    expect(rows(tester), ['sara-0']);
    expect(find.text('Garden Window'), findsOneWidget);
    expect(find.text('Kitchen Window'), findsNothing);
  });

  testWidgets('a customer with no designs: "No designs yet", and New Design', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await openCustomer(tester, 'Karwan');
    expect(find.text('No designs yet'), findsOneWidget);
    expect(find.byKey(CustomerScreen.newDesignButton), findsOneWidget);
    expect(rows(tester), isEmpty);
    // His information is still there, each missing part said to be.
    expect(find.text('Not given'), findsNWidgets(3));
    expect(find.byType(StartScreen), findsNothing);
    expect(overflowing(tester), isEmpty);
  });

  testWidgets('New Design asks door, window or sliding only now, and the '
      'design begun is the customer\'s and comes back to their page', (
    tester,
  ) async {
    final kept = await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await openCustomer(tester, 'Karwan');

    await tester.tap(find.byKey(CustomerScreen.newDesignButton));
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsOneWidget);
    await chooseDesign(tester, 'WINDOW');
    expect(find.byType(WorkspaceScreen), findsOneWidget);

    final design = c.read(workspaceProvider).design;
    expect(design.customerId, kept['Karwan']!.id);
    expect(design.kind, DesignKind.window);
    expect(design.name, isNot('Karwan'), reason: 'a design, not the person');

    // Back is to Karwan's page, where the design now is.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(
      tester.widget<CustomerScreen>(find.byType(CustomerScreen)).customerId,
      kept['Karwan']!.id,
    );
    expect(rows(tester), [design.id]);
    expect(find.text('No designs yet'), findsNothing);
    expect(find.text('Customer · 1 design'), findsOneWidget);
  });

  testWidgets('a design on the page opens exactly as it was kept', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await openCustomer(tester, 'Adam');
    await tester.tap(find.text('Kitchen Window'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final open = c.read(workspaceProvider).design;
    final kept = await tester.runAsync(() => DesignStore().load(open.id));
    expect(open.name, 'Kitchen Window');
    expect(open.toJson(), kept!.toJson());
  });

  testWidgets('selecting a customer always leads to that customer\'s page — '
      'from the list, from a search, and on saving a new one', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester);
    await customers.toCustomers(tester);

    String shownId() =>
        tester.widget<CustomerScreen>(find.byType(CustomerScreen)).customerId;

    await openCustomer(tester, 'Adam');
    expect(shownId(), kept['Adam']!.id);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await customers.search(tester, 'sara');
    await openCustomer(tester, 'Sara');
    expect(shownId(), kept['Sara']!.id);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CustomersScreen.newCustomerButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(NewCustomerScreen.nameField), 'Dilan');
    await tester.pump();
    await tester.tap(find.byKey(NewCustomerScreen.saveButton));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.text('No designs yet'), findsOneWidget);
    expect(find.byType(StartScreen), findsNothing);
  });

  testWidgets('it fits a phone, a tablet and a laptop', (tester) async {
    await customers.keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      await screen.openTheApp(tester, size: size);
      await customers.toCustomers(tester);
      for (final who in ['Adam', 'Karwan']) {
        await openCustomer(tester, who);
        expect(overflowing(tester), isEmpty, reason: '$who at $size');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
  });
}

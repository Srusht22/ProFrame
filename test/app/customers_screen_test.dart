import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/new_customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'the_designs_screen_test.dart' as screen;

// The customers: everyone the workshop draws for, found by name or phone,
// each showing how many designs are theirs; a new one made with their name,
// phone, address and notes; and tapping one goes to that customer — never to
// a drawing.

final at = DateTime(2026, 3, 1, 9);

/// Adam with four designs, Sara with one, and Karwan with none and no
/// phone number — kept before the app is opened.
Future<Map<String, Customer>> keepThreeCustomers() async {
  final customers = CustomerStore();
  final designs = DesignStore(customers: customers);
  final adam = await customers.create(
    name: 'Adam',
    phone: '+964 750 123 4567',
    now: at,
  );
  final sara = await customers.create(
    name: 'Sara',
    phone: '0770 555 1212',
    now: at.add(const Duration(minutes: 1)),
  );
  final karwan = await customers.create(
    name: 'Karwan',
    now: at.add(const Duration(minutes: 2)),
  );
  final adams = [
    ('Basement Door', DesignKind.door),
    ('Front Entrance Door', DesignKind.door),
    ('Kitchen Window', DesignKind.window),
    ('Third Floor Sliding', DesignKind.sliding),
  ];
  for (final (i, (name, kind)) in adams.indexed) {
    await designs.save(
      Design.empty(
        id: 'adam-$i',
        kind: kind,
        name: name,
        customerId: adam.id,
        now: at,
      ),
    );
  }
  await designs.save(
    Design.empty(
      id: 'sara-0',
      kind: DesignKind.window,
      name: 'Garden Window',
      customerId: sara.id,
      now: at,
    ),
  );
  return {'Adam': adam, 'Sara': sara, 'Karwan': karwan};
}

/// The customers are where the app opens.
Future<void> toCustomers(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.byType(CustomersScreen), findsOneWidget);
}

Finder cardOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(CustomerCard));

List<String> shown(WidgetTester tester) => [
  for (final card in tester.widgetList<CustomerCard>(find.byType(CustomerCard)))
    card.customer.name,
];

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(CustomersScreen.searchField), query);
  await tester.pumpAndSettle();
}

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the app opens on the customers, and with nobody kept the '
      'screen says so and offers a new customer', (tester) async {
    await screen.openTheApp(tester, size: const Size(390, 844));
    await toCustomers(tester);
    expect(find.text('No customers yet'), findsOneWidget);
    expect(find.byKey(CustomersScreen.newCustomerButton), findsOneWidget);
    expect(find.byKey(CustomersScreen.newDesignButton), findsOneWidget);
    // Nowhere to go back to: this is the start.
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('1 — every customer is shown with their name, phone and how '
      'many designs are theirs', (tester) async {
    await keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await toCustomers(tester);

    expect(find.text('3 customers'), findsOneWidget);
    expect(shown(tester), ['Karwan', 'Sara', 'Adam'], reason: 'newest first');
    Finder within(String name, String text) =>
        find.descendant(of: cardOf(name), matching: find.text(text));
    expect(within('Adam', '+964 750 123 4567'), findsOneWidget);
    expect(within('Adam', '4 designs'), findsOneWidget);
    expect(within('Sara', '0770 555 1212'), findsOneWidget);
    expect(within('Sara', '1 design'), findsOneWidget);
    expect(within('Karwan', 'No phone number'), findsOneWidget);
    expect(within('Karwan', 'No designs yet'), findsOneWidget);
    expect(overflowing(tester), isEmpty);
  });

  group('2 — searching updates the list', () {
    testWidgets('by name, whatever the case', (tester) async {
      await keepThreeCustomers();
      await screen.openTheApp(tester);
      await toCustomers(tester);
      await search(tester, 'sAr');
      expect(shown(tester), ['Sara']);
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('by phone number, written the local way or the '
        'international way', (tester) async {
      await keepThreeCustomers();
      await screen.openTheApp(tester);
      await toCustomers(tester);
      await search(tester, '0750');
      expect(shown(tester), ['Adam'], reason: '0750 is +964 750');
      await search(tester, '+964 750 123');
      expect(shown(tester), ['Adam']);
      await search(tester, '555 12');
      expect(shown(tester), ['Sara']);
    });

    testWidgets('nothing found says so, and clearing the search brings '
        'everyone back', (tester) async {
      await keepThreeCustomers();
      await screen.openTheApp(tester);
      await toCustomers(tester);
      await search(tester, 'zzz');
      expect(shown(tester), isEmpty);
      expect(find.text('No customer matches "zzz".'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(shown(tester), hasLength(3));
    });

    testWidgets('a search looks at customers, not inside designs', (
      tester,
    ) async {
      await keepThreeCustomers();
      await screen.openTheApp(tester);
      await toCustomers(tester);
      // Adam's design is called "Kitchen Window"; Adam is not "Kitchen".
      await search(tester, 'Kitchen');
      expect(shown(tester), isEmpty);
    });
  });

  group('3, 4, 5 — a customer is made with name, phone, address and notes', () {
    testWidgets('saved as given, and nothing else made', (tester) async {
      await screen.openTheApp(tester, size: const Size(390, 844));
      await toCustomers(tester);
      await tester.tap(find.byKey(CustomersScreen.newCustomerButton));
      await tester.pumpAndSettle();
      expect(find.byType(NewCustomerScreen), findsOneWidget);

      FilledButton save() =>
          tester.widget<FilledButton>(find.byKey(NewCustomerScreen.saveButton));
      expect(save().onPressed, isNull, reason: 'a customer needs a name');

      await tester.enterText(find.byKey(NewCustomerScreen.nameField), 'Adam');
      await tester.enterText(
        find.byKey(NewCustomerScreen.phoneField),
        '+964 750 123 4567',
      );
      await tester.enterText(
        find.byKey(NewCustomerScreen.addressField),
        'Salim Street 12, Sulaymaniyah',
      );
      await tester.enterText(
        find.byKey(NewCustomerScreen.notesField),
        'Prefers dark frames. Call after 5.',
      );
      await tester.pump();
      expect(save().onPressed, isNotNull);
      expect(overflowing(tester), isEmpty);
      await tester.ensureVisible(find.byKey(NewCustomerScreen.saveButton));
      await tester.tap(find.byKey(NewCustomerScreen.saveButton));
      await tester.pumpAndSettle();

      // Kept, with everything that was given.
      final kept = await tester.runAsync(() async {
        final store = CustomerStore();
        final page = await store.page();
        return store.load(page.items.single.id);
      });
      expect(kept!.name, 'Adam');
      expect(kept.phone, '+964 750 123 4567');
      expect(kept.address, 'Salim Street 12, Sulaymaniyah');
      expect(kept.notes, 'Prefers dark frames. Call after 5.');
      // A customer and no design: nothing was begun for them.
      expect(await tester.runAsync(() => DesignStore().count()), 0);
      expect(find.byType(WorkspaceScreen), findsNothing);

      // Saving goes to the customer's own page.
      expect(find.byType(CustomerScreen), findsOneWidget);
      expect(
        tester.widget<CustomerScreen>(find.byType(CustomerScreen)).customerId,
        kept.id,
      );
      // And the list has them when it is come back to.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(shown(tester), ['Adam']);
      expect(find.text('No designs yet'), findsOneWidget);
    });

    testWidgets('with only a name, the rest left for later', (tester) async {
      await screen.openTheApp(tester);
      await toCustomers(tester);
      await tester.tap(find.byKey(CustomersScreen.newCustomerButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(NewCustomerScreen.nameField), 'Sara');
      await tester.pump();
      await tester.tap(find.byKey(NewCustomerScreen.saveButton));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerScreen), findsOneWidget);
      expect(find.text('Not given'), findsNWidgets(3));
    });
  });

  group('6, 7 — tapping a customer goes to that customer', () {
    testWidgets('their page, with who they are and a place for their '
        'designs — not a drawing', (tester) async {
      final kept = await keepThreeCustomers();
      await screen.openTheApp(tester, size: const Size(390, 844));
      await toCustomers(tester);
      await tester.tap(cardOf('Adam'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceScreen), findsNothing);
      final page = tester.widget<CustomerScreen>(find.byType(CustomerScreen));
      expect(page.customerId, kept['Adam']!.id);
      expect(find.text('+964 750 123 4567'), findsOneWidget);
      expect(find.text('Designs'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Kitchen Window'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kitchen Window'), findsOneWidget);
      expect(overflowing(tester), isEmpty);

      // And back to the customers.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
    });

    testWidgets('a customer found by a search opens the same way', (
      tester,
    ) async {
      final kept = await keepThreeCustomers();
      await screen.openTheApp(tester);
      await toCustomers(tester);
      await search(tester, '0770');
      await tester.tap(cardOf('Sara'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CustomerScreen>(find.byType(CustomerScreen)).customerId,
        kept['Sara']!.id,
      );
    });
  });

  testWidgets('it fits a phone, a tablet and a laptop', (tester) async {
    await keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      await screen.openTheApp(tester, size: size);
      await toCustomers(tester);
      expect(overflowing(tester), isEmpty, reason: 'list at $size');
      await tester.tap(cardOf('Adam'));
      await tester.pumpAndSettle();
      expect(overflowing(tester), isEmpty, reason: 'customer at $size');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CustomersScreen.newCustomerButton));
      await tester.pumpAndSettle();
      expect(overflowing(tester), isEmpty, reason: 'form at $size');
      // Back to the customers for the next size.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);
    }
  });
}

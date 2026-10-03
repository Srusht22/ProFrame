import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/new_customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_designs_as_cards_test.dart' as cards;
import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;

// Adam → New Design → Basement Door → Door → Draw → Save. Leave Adam,
// come back — and leave the app altogether and open it again — and
// Basement Door is still Adam's. Then three more, all four Adam's; and a
// second customer who sees none of them.

const laptop = Size(1280, 860);

/// Customers → New Customer, called [name], saved: their page.
Future<void> newCustomer(WidgetTester tester, String name) async {
  await customers.toCustomers(tester);
  await tester.tap(find.byKey(CustomersScreen.newCustomerButton).first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(NewCustomerScreen.nameField), name);
  await tester.pump();
  await tester.ensureVisible(find.byKey(NewCustomerScreen.saveButton));
  await tester.tap(find.byKey(NewCustomerScreen.saveButton));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
}

/// From the customer's page: New Design, named, of [card], drawn, saved
/// with the Save button, and back to the customer's page.
Future<Design> drawAndSave(
  WidgetTester tester,
  ProviderContainer c, {
  required String name,
  required String card,
}) async {
  await tester.tap(
    find.byKey(CustomerScreen.newDesignButton).hitTestable().first,
  );
  await tester.pumpAndSettle();
  await nameTheDesign(tester, name);
  await chooseDesign(tester, card);
  expect(find.byType(WorkspaceScreen), findsOneWidget);
  // Drawn on the sheet and read, the way the drawing is always made.
  await sheet.twoLeaves(c);
  await tester.pumpAndSettle();
  await notNowToSizes(tester);
  await tester.pumpAndSettle();
  // Any door-or-window question for a Door & window set is waved away:
  // what is being tested is the keeping.
  while (find.text('Not now').hitTestable().evaluate().isNotEmpty) {
    await tester.tap(find.text('Not now').hitTestable().first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('Save'));
  await tester.pumpAndSettle();
  final saved = c.read(workspaceProvider).design;
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
  return saved;
}

/// Leaves the customer's page, back to the customers the app opens on.
Future<void> leaveTheCustomer(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(CustomersScreen), findsOneWidget);
}

/// Closes the app altogether and opens it again, with nothing carried over
/// but what the device kept: a new set of stores reading the same storage,
/// and none of the old screens.
Future<ProviderContainer> reopenTheApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  return screen.openTheApp(tester, size: laptop);
}

Future<Customer> kept(WidgetTester tester, String name) async =>
    (await tester.runAsync(() => CustomerStore().named(name)))!;

/// The names of the designs kept for [customer], read afresh from storage.
Future<Map<String, String>> keptFor(
  WidgetTester tester,
  Customer customer,
) async {
  final found = await tester.runAsync(() async {
    final store = DesignStore();
    final page = await store.page(customerId: customer.id, limit: 100);
    return {for (final s in page.items) s.id: s.name};
  });
  return found!;
}

/// The names on the design cards of the customer's page now open.
Future<Set<String>> namesOnThePage(WidgetTester tester) async {
  final ids = await cards.everyCard(tester);
  return {
    for (final id in ids)
      tester
          .widget<CustomerDesignCard>(
            find.byKey(CustomerScreen.designKey(id), skipOffstage: false),
          )
          .design
          .name,
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the reload test: Adam\'s Basement Door is still his after '
      'leaving him, and after the app is opened again', (tester) async {
    // 1. Create customer Adam.
    var c = await reopenTheApp(tester);
    await newCustomer(tester, 'Adam');
    final adam = await kept(tester, 'Adam');

    // 2. Create Basement Door, drawn. 3. Save.
    final basement = await drawAndSave(
      tester,
      c,
      name: 'Basement Door',
      card: 'DOOR',
    );
    expect(basement.customerId, adam.id);
    expect(find.text('Basement Door'), findsOneWidget);

    // 4. Leave the customer page. 5. Reopen Adam. 6. Basement Door is
    // there.
    await leaveTheCustomer(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    expect(await namesOnThePage(tester), {'Basement Door'});

    // And the app opened again from nothing but what the device kept.
    c = await reopenTheApp(tester);
    await customers.toCustomers(tester);
    expect(
      find.descendant(
        of: customers.cardOf('Adam'),
        matching: find.text('1 design'),
      ),
      findsOneWidget,
    );
    await page.openCustomer(tester, 'Adam');
    expect(await namesOnThePage(tester), {'Basement Door'});
    final reloaded = await tester.runAsync(
      () => DesignStore().load(basement.id),
    );
    expect(reloaded!.customerId, adam.id);
    expect(reloaded.name, 'Basement Door');
    expect(reloaded.category, DesignKind.door);
    // What was drawn was kept with it.
    expect(reloaded.frame, isNotNull);
    expect(reloaded.openings, hasLength(2));
    expect(
      jsonEncode(reloaded.sketch.toJson()),
      jsonEncode(basement.sketch.toJson()),
    );

    // Then three more, from Adam's page.
    for (final (name, card) in const [
      ('Front Entrance Door', 'DOOR'),
      ('Kitchen Window', 'WINDOW'),
      ('Third Floor Sliding', 'SLIDING'),
    ]) {
      await drawAndSave(tester, c, name: name, card: card);
    }
    const four = {
      'Basement Door',
      'Front Entrance Door',
      'Kitchen Window',
      'Third Floor Sliding',
    };
    expect((await keptFor(tester, adam)).values.toSet(), four);
    expect(await keptFor(tester, adam), hasLength(4));

    // All four Adam's — on his page, and in every design's own file.
    await leaveTheCustomer(tester);
    c = await reopenTheApp(tester);
    await customers.toCustomers(tester);
    expect(
      find.descendant(
        of: customers.cardOf('Adam'),
        matching: find.text('4 designs'),
      ),
      findsOneWidget,
    );
    await page.openCustomer(tester, 'Adam');
    expect(await namesOnThePage(tester), four);
    final all = await tester.runAsync(DesignStore().all);
    expect(all, hasLength(4));
    for (final design in all!) {
      expect(design.customerId, adam.id, reason: design.name);
    }
  });

  testWidgets('the isolation test: a second customer sees none of Adam\'s '
      'designs, and Adam none of theirs', (tester) async {
    final c = await reopenTheApp(tester);
    await newCustomer(tester, 'Adam');
    for (final (name, card) in const [
      ('Basement Door', 'DOOR'),
      ('Front Entrance Door', 'DOOR'),
      ('Kitchen Window', 'WINDOW'),
      ('Third Floor Sliding', 'SLIDING'),
    ]) {
      await drawAndSave(tester, c, name: name, card: card);
    }
    await leaveTheCustomer(tester);

    // Another customer: nothing of Adam's on their page.
    await newCustomer(tester, 'Sara');
    expect(find.text('No designs yet'), findsOneWidget);
    expect(await namesOnThePage(tester), isEmpty);
    for (final name in ['Basement Door', 'Kitchen Window']) {
      expect(find.text(name), findsNothing);
    }
    // One of their own.
    await drawAndSave(tester, c, name: 'Garden Window', card: 'WINDOW');
    expect(await namesOnThePage(tester), {'Garden Window'});
    await leaveTheCustomer(tester);

    final adam = await kept(tester, 'Adam');
    final sara = await kept(tester, 'Sara');
    expect((await keptFor(tester, sara)).values, ['Garden Window']);
    expect(await keptFor(tester, adam), hasLength(4));
    expect(
      (await keptFor(tester, adam)).values,
      isNot(contains('Garden Window')),
    );

    // The same after the app is opened again.
    await reopenTheApp(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Sara');
    expect(await namesOnThePage(tester), {'Garden Window'});
    await tester.pageBack();
    await tester.pumpAndSettle();
    await page.openCustomer(tester, 'Adam');
    expect(await namesOnThePage(tester), {
      'Basement Door',
      'Front Entrance Door',
      'Kitchen Window',
      'Third Floor Sliding',
    });
  });

  group('the stores keep everything, however it arrives', () {
    Design design(String id, String customerId) => Design.empty(
      id: id,
      kind: DesignKind.door,
      name: id,
      customerId: customerId,
    );

    test('designs saved at the same moment are all kept', () async {
      final store = DesignStore();
      await Future.wait([
        for (var i = 0; i < 12; i++) store.save(design('d$i', 'c-adam')),
      ]);
      final again = await DesignStore().page(limit: 100);
      expect(again.total, 12);
      expect(again.items.map((s) => s.id).toSet(), {
        for (var i = 0; i < 12; i++) 'd$i',
      });
    });

    test('two stores saving at the same moment lose nothing', () async {
      await Future.wait([
        for (var i = 0; i < 6; i++)
          DesignStore().save(design('d$i', i.isEven ? 'c-adam' : 'c-sara')),
      ]);
      final adams = await DesignStore().page(customerId: 'c-adam');
      final saras = await DesignStore().page(customerId: 'c-sara');
      expect(adams.items.map((s) => s.id).toSet(), {'d0', 'd2', 'd4'});
      expect(saras.items.map((s) => s.id).toSet(), {'d1', 'd3', 'd5'});
    });

    test('a design saved again is one design, not two', () async {
      final store = DesignStore();
      final first = await store.save(design('d', 'c-adam'));
      await Future.wait([
        store.save(first.copyWith(name: 'Basement Door')),
        store.save(first.copyWith(name: 'Basement Door')),
      ]);
      final again = await DesignStore().page();
      expect(again.total, 1);
      expect(again.items.single.name, 'Basement Door');
    });

    test('two designs for a person nobody has made yet make one customer '
        'between them', () async {
      final people = CustomerStore();
      final store = DesignStore(customers: people);
      final kept = await Future.wait([
        for (final id in ['a', 'b'])
          store.save(
            Design.empty(
              id: id,
              kind: DesignKind.window,
              name: id,
              customer: 'Adam',
            ),
          ),
      ]);
      expect(await CustomerStore().count(), 1);
      expect(kept[0].customerId, kept[1].customerId);
      final adams = await DesignStore().page(customerId: kept[0].customerId);
      expect(adams.total, 2);
    });

    test('customers made at the same moment are all kept', () async {
      await Future.wait([
        for (final name in ['Adam', 'Sara', 'Karwan', 'Dilan'])
          CustomerStore().create(name: name),
      ]);
      final all = await CustomerStore().page();
      expect(all.items.map((s) => s.name).toSet(), {
        'Adam',
        'Sara',
        'Karwan',
        'Dilan',
      });
    });
  });
}

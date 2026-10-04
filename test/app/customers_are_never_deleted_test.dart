import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// Deleting a customer is offered only where the application has
// administrative deletion — somebody entitled to remove a customer and
// everything drawn for them. This application has no such thing: no
// administrator, no roles, no permissions. So there is no way to delete a
// customer, by design, and this file keeps it so until there is.
//
// And whatever else happens, the three operations stay apart: deleting a
// design never deletes a customer, editing a customer never deletes a
// design, and nothing deletes a customer silently.

/// Every line under `lib/` that takes something off the device.
List<(String, String)> removals() => [
  for (final file in Directory('lib').listSync(recursive: true))
    if (file is File && file.path.endsWith('.dart'))
      for (final line in file.readAsLinesSync())
        if (line.contains('prefs.remove(')) (file.path, line.trim()),
];

Future<Map<String, Object?>> customersKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(CustomerStore.customerKeyPrefix) ||
              key == CustomerStore.indexKey)
            key: prefs.get(key),
      };
    }))!;

Future<Map<String, Object?>> designsKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(DesignStore.designKeyPrefix) ||
              key == DesignStore.indexKey)
            key: prefs.get(key),
      };
    }))!;

Finder deleting() =>
    find.textContaining(RegExp(r'\b(delete|remove)\b', caseSensitive: false));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing in the application takes a customer off the device — only '
      'a design, and the list of designs kept before customers existed', () {
    final found = removals();
    expect(found, isNotEmpty, reason: 'the scan reads the code');
    for (final (path, line) in found) {
      expect(
        line.contains('_designKey(') || line.contains('legacyKey'),
        isTrue,
        reason: '$path: $line',
      );
      expect(path, endsWith('design_store.dart'), reason: line);
    }
    // And the customers' own store has no way to remove one.
    final store = File('lib/infrastructure/customer_store.dart')
        .readAsStringSync();
    expect(store, isNot(contains('.remove(')));
    expect(store, isNot(contains(RegExp('Future<[^>]*> (delete|remove)'))));
  });

  testWidgets('the customers list and a customer\'s page offer no way to '
      'delete the customer', (tester) async {
    await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    expect(deleting(), findsNothing);
    // Pressing and holding a customer is not a way in to deleting them.
    await tester.longPress(customers.cardOf('Adam'));
    await tester.pumpAndSettle();
    expect(deleting(), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    // Holding a customer is taken as a tap — it opens their page, and
    // nothing more.
    if (find.byType(CustomerScreen).evaluate().isEmpty) {
      await page.openCustomer(tester, 'Adam');
    }
    // On Adam's page, before any design's ⋮ is opened, nothing says delete.
    expect(deleting(), findsNothing);
    expect(find.byType(CustomerScreen), findsOneWidget);
  });

  testWidgets('deleting every one of Adam\'s designs deletes no customer — '
      'Adam, Sara and Karwan are kept byte for byte', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    final before = await customersKept(tester);
    await tester.runAsync(() async {
      final store = DesignStore();
      for (final id in ['adam-0', 'adam-1', 'adam-2', 'adam-3']) {
        await store.remove(id);
      }
    });
    expect(await customersKept(tester), before);
    expect(await tester.runAsync(() => CustomerStore().count()), 3);
    await customers.toCustomers(tester);
    expect(customers.shown(tester), containsAll(['Adam', 'Sara', 'Karwan']));
    await page.openCustomer(tester, 'Adam');
    expect(find.text('No designs yet'), findsOneWidget);
    expect(
      await tester.runAsync(() => CustomerStore().load(kept['Adam']!.id)),
      isA<Customer>(),
    );
  });

  testWidgets('editing Adam\'s information deletes none of his designs, nor '
      'anybody\'s', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    final before = await designsKept(tester);
    await tester.runAsync(
      () => CustomerStore().save(
        kept['Adam']!.copyWith(
          name: 'Adam Karim',
          phone: '',
          address: 'Erbil',
          notes: '',
        ),
      ),
    );
    expect(await designsKept(tester), before);
    final adams = await tester.runAsync(
      () => DesignStore().page(customerId: kept['Adam']!.id),
    );
    expect(adams!.total, 4);
  });

  testWidgets('a whole design lifecycle — made, renamed, copied, deleted — '
      'never takes a customer with it', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    final before = await customersKept(tester);
    await tester.runAsync(() async {
      final store = DesignStore();
      final copy = await store.duplicate('adam-0');
      await store.retitle('adam-1', 'Front Entrance Door - New PVC');
      await store.remove(copy!.id);
      await store.remove('sara-0');
    });
    expect(await customersKept(tester), before);
    expect(
      await tester.runAsync(() => CustomerStore().load(kept['Sara']!.id)),
      isA<Customer>(),
      reason: 'Sara stays with no designs',
    );
    await customers.toCustomers(tester);
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(customers.shown(tester), containsAll(['Adam', 'Sara', 'Karwan']));
  });
}

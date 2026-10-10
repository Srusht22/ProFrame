import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/extra_charges.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/finance_documents.dart';
import 'package:proframe/app/state/access.dart';
import 'package:proframe/domain/model/staff.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/flexible_factory_pricing_test.dart' show factoryList;
import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'financial_records_on_screen_test.dart' show owner, settle;
import 'flexible_pricing_on_screen_test.dart'
    show frontEntranceDoor, openPrice, seedWith, toAdam;
import 'the_designs_screen_test.dart' as screen;

// Phase 33's permissions on the real app: nothing that needs a permission is
// offered until who is at the device is known; **Delete customer** is the
// owner's, deletes only a customer with nothing kept, and says why not
// otherwise; and the discount form has an explicit **None**.

bool enabled(WidgetTester tester, Key key) {
  final w = tester.widget(find.byKey(key));
  return switch (w) {
    final ButtonStyleButton b => b.onPressed != null,
    final FloatingActionButton b => b.onPressed != null,
    _ => throw StateError('$w is not a button'),
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('while the staff are being read nothing that needs a '
      'permission is offered, and a bar says so; once known, it is', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final staff = Completer<List<StaffMember>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffMembersProvider.overrideWith((ref) => staff.future)],
        child: const ProFrameApp(),
      ),
    );
    // Past the launch, without settling: the bar moves while it waits.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(find.byKey(PermissionsLoading.barKey), findsOneWidget);
    expect(enabled(tester, CustomersScreen.newCustomerButton), isFalse);
    expect(enabled(tester, CustomersScreen.newDesignButton), isFalse);

    staff.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(PermissionsLoading.barKey), findsNothing);
    expect(enabled(tester, CustomersScreen.newCustomerButton), isTrue);
    expect(enabled(tester, CustomersScreen.newDesignButton), isTrue);
  });

  testWidgets('Delete customer: not offered to the device with no staff; '
      'the owner deletes a customer with nothing kept, and Undo keeps them '
      'again', (tester) async {
    await tester.runAsync(
      () => CustomerStore().create(name: 'Dilan', by: WorkshopRole.owner),
    );
    final c = await screen.openTheApp(tester, size: const Size(1280, 820));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Dilan');
    expect(find.byKey(CustomerScreen.menuKey), findsNothing);

    owner(c);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerScreen.menuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerScreen.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete Dilan?'), findsOneWidget);
    await tester.tap(find.byKey(CustomerScreen.confirmDeleteKey));
    await settle(tester);
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(find.text('Dilan deleted.'), findsOneWidget);
    expect(await tester.runAsync(() => CustomerStore().named('Dilan')), isNull);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(
      (await tester.runAsync(() => CustomerStore().named('Dilan')))?.name,
      'Dilan',
    );
  });

  testWidgets('a customer with designs is not deleted, and the reason is '
      'said', (tester) async {
    await seedWith(tester, [frontEntranceDoor()], factoryList());
    final c = await toAdam(tester);
    owner(c);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerScreen.menuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerScreen.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerScreen.confirmDeleteKey));
    await settle(tester);
    expect(find.byKey(CustomerScreen.cannotDeleteKey), findsOneWidget);
    Finder said(String words) => find.descendant(
      of: find.byKey(CustomerScreen.cannotDeleteKey),
      matching: find.textContaining(words),
    );
    expect(said('Adam cannot be deleted'), findsOneWidget);
    expect(said('1 design'), findsOneWidget);
    expect(
      (await tester.runAsync(() => CustomerStore().named('Adam')))?.name,
      'Adam',
    );
  });

  testWidgets('the discount form has None: chosen, the figure goes and the '
      'total is the subtotal; applied, a discount in force is taken away', (
    tester,
  ) async {
    await seedWith(tester, [frontEntranceDoor()], factoryList());
    final c = await toAdam(tester);
    owner(c);
    await tester.pumpAndSettle();
    await openPrice(tester, 'acceptance');

    // A discount given first.
    await tester.ensureVisible(find.byKey(ExtraKeys.discount));
    await tester.tap(find.byKey(ExtraKeys.discount));
    await tester.pumpAndSettle();
    expect(find.byKey(DiscountKeys.none), findsOneWidget);
    await tester.tap(find.byKey(DiscountKeys.fixed));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(DiscountKeys.value), '45');
    await tester.tap(find.byKey(DiscountKeys.apply));
    await settle(tester);
    expect(find.text('−45.00 USD'), findsWidgets);

    // Then None.
    await tester.ensureVisible(find.byKey(ExtraKeys.discount));
    await tester.tap(find.byKey(ExtraKeys.discount));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiscountKeys.none));
    await tester.pumpAndSettle();
    expect(find.byKey(DiscountKeys.value), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(DiscountKeys.previewDiscount)).data,
      'None',
    );
    await tester.tap(find.byKey(DiscountKeys.apply));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(ExtraKeys.discountAmount)).data,
      'None',
    );
  });
}

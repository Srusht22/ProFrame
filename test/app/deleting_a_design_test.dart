import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/delete_design.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// Adam → Basement Door → Delete. Asked first, by the design's own name —
// "Delete Basement Door?" — and removed only when the user says so. Adam
// stays, with his phone, his address and his notes, and so do Front
// Entrance Door, Kitchen Window and Third Floor Sliding, byte for byte.
// Deleting a design is not deleting a customer, and nothing here can.

const phone = Size(390, 844);
const laptop = Size(1280, 860);

/// Adam, Sara and Karwan as `keepThreeCustomers` keeps them, Adam given an
/// address and notes as well as his phone.
Future<Map<String, Customer>> keepAdam() async {
  final kept = await customers.keepThreeCustomers();
  final adam = await CustomerStore().save(
    kept['Adam']!.copyWith(
      address: 'Salim Street 12, Sulaymaniyah',
      notes: 'Wants the basement door by May.',
      updatedAt: kept['Adam']!.updatedAt,
    ),
  );
  return {...kept, 'Adam': adam};
}

Future<Map<String, Object?>> everythingKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {for (final key in prefs.getKeys()) key: prefs.get(key)};
    }))!;

String designKey(String id) => '${DesignStore.designKeyPrefix}$id';

List<Object?> indexOf(Map<String, Object?> kept) =>
    jsonDecode(kept[DesignStore.indexKey]! as String) as List<Object?>;

/// That [after] is [before] with the design [id] taken out and nothing
/// else: no customer record, no customer index, no other design and no
/// other line of the design index touched.
void onlyThatDesignWent(
  Map<String, Object?> before,
  Map<String, Object?> after,
  String id,
) {
  expect(after.containsKey(designKey(id)), isFalse, reason: 'it went');
  expect(before.containsKey(designKey(id)), isTrue);
  for (final key in before.keys) {
    if (key == designKey(id) || key == DesignStore.indexKey) continue;
    expect(after[key], before[key], reason: key);
  }
  expect(after.keys.toSet(), before.keys.toSet()..remove(designKey(id)));
  expect(indexOf(after), [
    for (final line in indexOf(before))
      if ((line! as Map<String, Object?>)['id'] != id) line,
  ]);
}

Future<void> toAdam(WidgetTester tester) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
}

/// The ⋮ on the card of Adam's design [id], and Delete on the sheet.
Future<void> askToDelete(WidgetTester tester, String id) async {
  final more = find.byKey(CustomerDesignCard.moreKey(id));
  await tester.scrollUntilVisible(
    more.hitTestable(),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(more.hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey('design-action-${DesignAction.delete.name}')),
  );
  await tester.pumpAndSettle();
  expect(find.byType(DeleteDesignDialog), findsOneWidget);
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(DeleteDesignDialog.confirmKey));
  await tester.pumpAndSettle();
}

/// Back to the top of the customer's page, where who they are is.
Future<void> toTop(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(DeleteDesignDialog), matching: finder);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Adam → Basement Door → ⋮: Open, Edit information and Delete '
      '— and nothing that deletes a customer', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    final more = find.byKey(CustomerDesignCard.moreKey('adam-0'));
    await tester.scrollUntilVisible(
      more.hitTestable(),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(more.hitTestable());
    await tester.pumpAndSettle();
    final sheet = find.byType(DesignActionsSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Basement Door')),
      findsOneWidget,
    );
    for (final label in ['Open', 'Edit information', 'Delete']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    for (final label in ['Rename', 'Duplicate']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsNothing,
      );
    }
    expect(
      find.textContaining(RegExp('delete.*customer', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('the confirmation names the design — "Delete Basement Door?" '
      '— and says what stays; nothing is deleted until it is confirmed', (
    tester,
  ) async {
    final kept = await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    await toAdam(tester);
    await askToDelete(tester, 'adam-0');

    expect(inDialog(find.text('Delete Basement Door?')), findsOneWidget);
    expect(inDialog(find.textContaining('Door · Adam · #')), findsOneWidget);
    expect(
      inDialog(
        find.text(
          'This design will be removed from this device. Adam, their '
          'phone, address and notes, and their other designs stay exactly '
          'as they are.',
        ),
      ),
      findsOneWidget,
    );
    expect(inDialog(find.text('Delete design')), findsOneWidget);
    expect(find.text('Delete Adam?'), findsNothing);
    // Asking is not deleting.
    expect(await everythingKept(tester), before);
    expect(kept['Adam'], isNotNull);
  });

  testWidgets('Cancel, a tap outside and back all keep it', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    await toAdam(tester);

    await askToDelete(tester, 'adam-0');
    await tester.tap(find.byKey(DeleteDesignDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteDesignDialog), findsNothing);

    await askToDelete(tester, 'adam-0');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteDesignDialog), findsNothing);

    await askToDelete(tester, 'adam-0');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteDesignDialog), findsNothing);

    expect(find.byType(CustomerScreen), findsOneWidget);
    await toTop(tester);
    expect(find.text('Customer · 4 designs'), findsOneWidget);
    expect(await everythingKept(tester), before);
  });

  testWidgets('deleting Basement Door removes it and nothing else — Adam, '
      'his phone, address and notes, and his other three designs stay', (
    tester,
  ) async {
    final kept = await keepAdam();
    final adam = kept['Adam']!;
    await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    await toAdam(tester);
    await askToDelete(tester, 'adam-0');
    await confirm(tester);

    // Still on Adam's page, Adam still there, three designs.
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.text('Basement Door deleted'), findsOneWidget);
    await toTop(tester);
    expect(find.text('Customer · 3 designs'), findsOneWidget);
    expect(find.text('+964 750 123 4567'), findsOneWidget);
    expect(find.text('Salim Street 12, Sulaymaniyah'), findsOneWidget);
    expect(find.text('Wants the basement door by May.'), findsOneWidget);
    expect(find.byKey(CustomerScreen.designKey('adam-0')), findsNothing);

    final after = await everythingKept(tester);
    onlyThatDesignWent(before, after, 'adam-0');
    // Adam's record, byte for byte: name, phone, address, notes.
    final record = '${CustomerStore.customerKeyPrefix}${adam.id}';
    expect(after[record], before[record]);
    final kept2 = Customer.fromJson(
      jsonDecode(after[record]! as String) as Map<String, Object?>,
    );
    expect(kept2.name, 'Adam');
    expect(kept2.phone, '+964 750 123 4567');
    expect(kept2.address, 'Salim Street 12, Sulaymaniyah');
    expect(kept2.notes, 'Wants the basement door by May.');
    // His other three designs, and nobody else's, exactly as they were.
    final left = await tester.runAsync(
      () => DesignStore().page(customerId: adam.id),
    );
    expect(left!.items.map((s) => s.name).toSet(), {
      'Front Entrance Door',
      'Kitchen Window',
      'Third Floor Sliding',
    });

    // And so it stays, the app closed and opened again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    await toTop(tester);
    expect(find.text('Customer · 3 designs'), findsOneWidget);
    expect(await everythingKept(tester), after);
  });

  testWidgets('deleting every one of Adam\'s designs leaves Adam, with '
      'nothing drawn for him', (tester) async {
    final kept = await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    await toAdam(tester);
    for (final id in ['adam-0', 'adam-1', 'adam-2', 'adam-3']) {
      await askToDelete(tester, id);
      await confirm(tester);
    }
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.text('No designs yet'), findsOneWidget);
    expect(find.text('Salim Street 12, Sulaymaniyah'), findsOneWidget);
    final after = await everythingKept(tester);
    for (final key in before.keys) {
      if (key.startsWith(CustomerStore.customerKeyPrefix) ||
          key == CustomerStore.indexKey ||
          key == designKey('sara-0')) {
        expect(after[key], before[key], reason: key);
      }
    }
    // Adam is still a customer, found in the list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(customers.shown(tester), contains('Adam'));
    expect(await tester.runAsync(() => CustomerStore().count()), 3);
    expect(
      await tester.runAsync(() => CustomerStore().load(kept['Adam']!.id)),
      isNotNull,
    );
  });

  testWidgets('Undo puts it back whole', (tester) async {
    await keepAdam();
    await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    await toAdam(tester);
    await askToDelete(tester, 'adam-2');
    await confirm(tester);
    expect(find.text('Kitchen Window deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await toTop(tester);
    expect(find.text('Customer · 4 designs'), findsOneWidget);
    final after = await everythingKept(tester);
    expect(after[designKey('adam-2')], before[designKey('adam-2')]);
    for (final key in before.keys) {
      if (key == DesignStore.indexKey) continue;
      expect(after[key], before[key], reason: key);
    }
  });

  testWidgets('from the designs list too, the confirmation names the design, '
      'not the customer', (tester) async {
    final kept = await keepAdam();
    await screen.openTheApp(tester, size: laptop);
    final before = await everythingKept(tester);
    final card = find.byWidgetPredicate(
      (w) => w is DesignCard && w.summary.id == 'adam-0',
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('design-action-${DesignAction.delete.name}')),
    );
    await tester.pumpAndSettle();
    expect(inDialog(find.text('Delete Basement Door?')), findsOneWidget);
    expect(find.text('Delete Adam?'), findsNothing);
    await confirm(tester);
    onlyThatDesignWent(before, await everythingKept(tester), 'adam-0');
    expect(
      await tester.runAsync(() => CustomerStore().load(kept['Adam']!.id)),
      isNotNull,
    );
  });

  testWidgets('it fits a phone, a tablet and a laptop', (tester) async {
    await keepAdam();
    for (final size in const [Size(360, 740), phone, Size(820, 1180), laptop]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      await toAdam(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'cards at $size');
      await askToDelete(tester, 'adam-1');
      expect(page.overflowing(tester), isEmpty, reason: 'dialog at $size');
      await tester.tap(find.byKey(DeleteDesignDialog.cancelKey));
      await tester.pumpAndSettle();
    }
  });
}

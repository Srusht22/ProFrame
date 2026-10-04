import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/design_actions.dart';
import 'package:proframe/app/screens/design_information_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/new_customer_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
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
import 'designs_are_kept_for_their_customer_test.dart' as keeping;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// The whole customer and design workflow, done the way the user does it —
// every step through the screens, nothing put into storage by hand:
//
//   Adam                       phone, address and notes
//   ├── Basement Door          Door
//   ├── Front Entrance Door    Door
//   ├── Kitchen Window         Window
//   └── Third Floor Sliding    Sliding
//
// and then the eight tests of the brief, in order, on one set of data, at a
// phone's width and a laptop's.

const phone = '+964 750 123 4567';
const address = 'Salim Street 12, Sulaymaniyah';
const notes = 'Measure the basement stairwell again.';

/// Everything kept about designs, as the device holds it, by design id.
Future<Map<String, String>> designsKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(DesignStore.designKeyPrefix))
            key.substring(DesignStore.designKeyPrefix.length): prefs.getString(
              key,
            )!,
      };
    }))!;

Design parse(String text) =>
    Design.fromJson(jsonDecode(text) as Map<String, Object?>);

Future<Customer> customerNamed(WidgetTester tester, String name) async =>
    (await tester.runAsync(() => CustomerStore().named(name)))!;

/// The designs kept for [customer], by id and name.
Future<Map<String, String>> designsOf(
  WidgetTester tester,
  Customer customer,
) async => (await tester.runAsync(() async {
  final found = await DesignStore().page(customerId: customer.id, limit: 100);
  return {for (final s in found.items) s.id: s.name};
}))!;

Finder customerPageScroll() => find
    .descendant(
      of: find.byType(CustomerScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> toTop(WidgetTester tester) async {
  tester.state<ScrollableState>(customerPageScroll()).position.jumpTo(0);
  await tester.pumpAndSettle();
}

/// Customers → New Customer, with a phone, an address and notes, saved.
Future<void> newCustomer(
  WidgetTester tester,
  String name, {
  String phone = '',
  String address = '',
  String notes = '',
}) async {
  await tester.tap(find.byKey(CustomersScreen.newCustomerButton).first);
  await tester.pumpAndSettle();
  for (final (key, text) in [
    (NewCustomerScreen.nameField, name),
    (NewCustomerScreen.phoneField, phone),
    (NewCustomerScreen.addressField, address),
    (NewCustomerScreen.notesField, notes),
  ]) {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(key), text);
    await tester.pump();
  }
  await tester.ensureVisible(find.byKey(NewCustomerScreen.saveButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(NewCustomerScreen.saveButton));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
}

/// The id of the design called [name] on the customer's page.
String idOf(Map<String, String> designs, String name) =>
    designs.entries.singleWhere((e) => e.value == name).key;

/// From the customer's page, [id] opened by its card's **Open**.
Future<void> openFromThePage(WidgetTester tester, String id) async {
  await toTop(tester);
  final open = find.byKey(CustomerDesignCard.openKey(id)).hitTestable();
  await tester.scrollUntilVisible(open, 100, scrollable: customerPageScroll());
  await tester.pumpAndSettle();
  await tester.tap(open);
  await tester.pumpAndSettle();
  // A design whose sizes have not been given has them asked for, over the
  // drawing, whenever it is opened — a question about this design, not the
  // start of another. Put away the way a user in a hurry would.
  await notNowToSizes(tester);
}

/// Nothing that begins a design is anywhere on the navigator.
void noNewDesignFlow() {
  expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
  expect(find.byType(DesignNameScreen, skipOffstage: false), findsNothing);
  expect(find.byType(NewDesignScreen, skipOffstage: false), findsNothing);
}

/// Back from the workspace to the customer's page.
Future<void> backToTheCustomer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
}

/// Closes the app altogether and opens it again at [size], with nothing
/// carried over but what the device kept.
Future<ProviderContainer> reopen(WidgetTester tester, Size size) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  return screen.openTheApp(tester, size: size);
}

/// Everything about [design] but its name and when it was last edited.
String allButTheName(Design design) {
  final json = jsonDecode(jsonEncode(design.toJson())) as Map<String, Object?>
    ..remove('name')
    ..remove('updatedAt');
  return jsonEncode(json);
}

Future<void> theWholeWorkflow(WidgetTester tester, Size size) async {
  var c = await screen.openTheApp(tester, size: size);

  // ------------------------------------------------ Adam, and four designs
  await customers.toCustomers(tester);
  await newCustomer(
    tester,
    'Adam',
    phone: phone,
    address: address,
    notes: notes,
  );
  final made = <String, Design>{};
  for (final (name, card) in const [
    ('Basement Door', 'DOOR'),
    ('Front Entrance Door', 'DOOR'),
    ('Kitchen Window', 'WINDOW'),
    ('Third Floor Sliding', 'SLIDING'),
  ]) {
    made[name] = await keeping.drawAndSave(tester, c, name: name, card: card);
  }
  final adam = await customerNamed(tester, 'Adam');
  expect(made.values.map((d) => d.customerId).toSet(), {adam.id});
  expect(made.values.map((d) => d.category).toList(), [
    DesignKind.door,
    DesignKind.door,
    DesignKind.window,
    DesignKind.sliding,
  ]);
  expect(made.values.map((d) => d.id).toSet(), hasLength(4));
  expect(made.values.every((d) => d.frame != null), isTrue, reason: 'drawn');

  // Out of Adam altogether, and the app closed and opened again from
  // nothing but what the device kept.
  c = await reopen(tester, size);
  await customers.toCustomers(tester);

  // ------------------------------------------------------------ TEST 1
  // Open Adam: his information, all four designs as cards, New Design.
  await page.openCustomer(tester, 'Adam');
  expect(find.widgetWithText(AppBar, 'Adam'), findsOneWidget);
  expect(find.text(phone), findsOneWidget);
  expect(find.text(address), findsOneWidget);
  expect(find.text(notes), findsOneWidget);
  expect(find.text('Customer · 4 designs'), findsOneWidget);
  expect(find.byKey(CustomerScreen.newDesignButton), findsOneWidget);
  final onPage = await cards.everyCard(tester);
  final adams = await designsOf(tester, adam);
  expect(onPage, adams.keys.toSet());
  expect(adams.values.toSet(), {
    'Basement Door',
    'Front Entrance Door',
    'Kitchen Window',
    'Third Floor Sliding',
  });
  await toTop(tester);

  // ------------------------------------------------------------ TEST 2
  // Basement Door opens directly, as it was kept; no category asked.
  final basement = idOf(adams, 'Basement Door');
  final kitchen = idOf(adams, 'Kitchen Window');
  var kept = await designsKept(tester);
  await openFromThePage(tester, basement);
  expect(find.byType(WorkspaceScreen), findsOneWidget);
  noNewDesignFlow();
  expect(c.read(workspaceProvider).design.id, basement);
  expect(jsonEncode(c.read(workspaceProvider).design.toJson()), kept[basement]);

  // ------------------------------------------------------------ TEST 3
  // Back to Adam; Kitchen Window opens directly too.
  await backToTheCustomer(tester);
  await openFromThePage(tester, kitchen);
  expect(find.byType(WorkspaceScreen), findsOneWidget);
  noNewDesignFlow();
  expect(c.read(workspaceProvider).design.id, kitchen);
  expect(c.read(workspaceProvider).design.category, DesignKind.window);
  expect(jsonEncode(c.read(workspaceProvider).design.toJson()), kept[kitchen]);
  await backToTheCustomer(tester);
  expect(await designsKept(tester), kept, reason: 'looking changed nothing');

  // ------------------------------------------------------------ TEST 4
  // Garage Door: Adam's, and a fifth design, replacing none of the four.
  await toTop(tester);
  final garage = await keeping.drawAndSave(
    tester,
    c,
    name: 'Garage Door',
    card: 'DOOR',
  );
  expect(garage.customerId, adam.id);
  expect(kept.keys, isNot(contains(garage.id)));
  final withGarage = await designsKept(tester);
  expect(withGarage.keys.toSet(), {...kept.keys, garage.id});
  for (final id in kept.keys) {
    expect(withGarage[id], kept[id], reason: '$id untouched');
  }
  await toTop(tester);
  expect(find.text('Customer · 5 designs'), findsOneWidget);

  // ------------------------------------------------------------ TEST 5
  // Another customer, who sees none of Adam's designs.
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(CustomersScreen), findsOneWidget);
  await newCustomer(tester, 'Sara');
  expect(find.widgetWithText(AppBar, 'Sara'), findsOneWidget);
  expect(find.text('No designs yet'), findsOneWidget);
  expect(find.byType(CustomerDesignCard), findsNothing);
  final sara = await customerNamed(tester, 'Sara');
  expect(await designsOf(tester, sara), isEmpty);
  expect(await designsOf(tester, adam), hasLength(5));
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(customers.shown(tester), containsAll(['Adam', 'Sara']));

  // ------------------------------------------------------------ TEST 6
  // Adam's phone edited; every design as it was.
  await page.openCustomer(tester, 'Adam');
  kept = await designsKept(tester);
  await tester.tap(find.byKey(CustomerScreen.editButton));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(NewCustomerScreen.phoneField),
    '0770 555 1212',
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(NewCustomerScreen.saveButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(NewCustomerScreen.saveButton));
  await tester.pumpAndSettle();
  expect(find.text('0770 555 1212'), findsOneWidget);
  expect(find.text(address), findsOneWidget);
  expect(find.text(notes), findsOneWidget);
  expect(await designsKept(tester), kept);

  // ------------------------------------------------------------ TEST 7
  // Basement Door renamed; its geometry exactly as it was.
  final before = parse(kept[basement]!);
  final edit = find.byKey(CustomerDesignCard.editKey(basement));
  await tester.scrollUntilVisible(
    edit.hitTestable(),
    100,
    scrollable: customerPageScroll(),
  );
  await tester.pumpAndSettle();
  await tester.tap(edit.hitTestable());
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(DesignInformationScreen.nameField),
    'Basement Door - New PVC',
  );
  await tester.pump();
  await tester.tap(find.byKey(DesignInformationScreen.saveButton));
  await tester.pumpAndSettle();
  final renamed = await designsKept(tester);
  final after = parse(renamed[basement]!);
  expect(after.id, basement);
  expect(after.name, 'Basement Door - New PVC');
  expect(after.category, DesignKind.door);
  expect(allButTheName(after), allButTheName(before));
  for (final id in kept.keys.where((id) => id != basement)) {
    expect(renamed[id], kept[id], reason: '$id untouched by the rename');
  }

  // ------------------------------------------------------------ TEST 8
  // Kitchen Window deleted; every other design, and Adam, remain.
  final more = find.byKey(CustomerDesignCard.moreKey(kitchen));
  await tester.scrollUntilVisible(
    more.hitTestable(),
    100,
    scrollable: customerPageScroll(),
  );
  await tester.pumpAndSettle();
  await tester.tap(more.hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey('design-action-${DesignAction.delete.name}')),
  );
  await tester.pumpAndSettle();
  expect(find.text('Delete Kitchen Window?'), findsOneWidget);
  await tester.tap(find.byKey(DeleteDesignDialog.confirmKey));
  await tester.pumpAndSettle();
  final left = await designsKept(tester);
  expect(left.keys.toSet(), renamed.keys.toSet()..remove(kitchen));
  for (final id in left.keys) {
    expect(left[id], renamed[id], reason: '$id untouched by the delete');
  }
  await toTop(tester);
  expect(find.text('Customer · 4 designs'), findsOneWidget);

  // And so it all stays, the app closed and opened again.
  await reopen(tester, size);
  await customers.toCustomers(tester);
  expect(customers.shown(tester), containsAll(['Adam', 'Sara']));
  await page.openCustomer(tester, 'Adam');
  expect(find.text('0770 555 1212'), findsOneWidget);
  expect(find.text(address), findsOneWidget);
  expect(find.text(notes), findsOneWidget);
  expect((await designsOf(tester, adam)).values.toSet(), {
    'Basement Door - New PVC',
    'Front Entrance Door',
    'Third Floor Sliding',
    'Garage Door',
  });
  expect(await designsOf(tester, sara), isEmpty);
  expect(await designsKept(tester), left);
  expect(page.overflowing(tester), isEmpty);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the whole customer and design workflow, on a laptop', (
    tester,
  ) async {
    await theWholeWorkflow(tester, keeping.laptop);
  });

  testWidgets('the whole customer and design workflow, on a phone', (
    tester,
  ) async {
    await theWholeWorkflow(tester, const Size(390, 844));
  });
}

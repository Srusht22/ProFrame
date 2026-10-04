import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/inspector_panel.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/new_customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;

// Adam's page → Edit → his name, phone number, address and notes. They are
// Adam's — the customer record's — and nothing else's: saving changes that
// record and not one byte of any design, his or anybody's. Changing his
// phone leaves Basement Door as it was; changing his address leaves Kitchen
// Window as it was. No design holds a copy of any of it.

const phone = Size(390, 844);
const tablet = Size(820, 1180);
const laptop = Size(1280, 860);

/// [design] with a real drawing read into it: an outline, a mullion and a
/// mark in each light — a frame, a bar, two leaves and their hardware.
Design drawn(Design design) {
  final strokes = [
    sheet.pen('outline', const [
      Vec2(0, 0),
      Vec2(2400, 0),
      Vec2(2400, 2100),
      Vec2(0, 2100),
      Vec2(0, 0),
    ]),
    sheet.pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
    sheet.pen('k1', sheet.chevron(const Vec2(600, 1050))),
    sheet.pen('k2', sheet.chevron(const Vec2(1800, 1050))),
  ];
  return SketchInterpreter.interpret(
    design.copyWith(sketch: Sketch(strokes: strokes)),
  ).design;
}

/// Adam, Sara and Karwan as `keepThreeCustomers` keeps them — and Adam's
/// Basement Door and Kitchen Window drawn, so there is geometry to keep.
Future<Map<String, Customer>> keepAdamWithDrawings() async {
  final kept = await customers.keepThreeCustomers();
  final store = DesignStore();
  for (final id in const ['adam-0', 'adam-2']) {
    await store.save(drawn((await store.load(id))!));
  }
  return kept;
}

/// Everything kept about designs, exactly as the device holds it: every
/// design's own record and the index of them, as the stored text.
Future<Map<String, String>> designsAsStored(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(DesignStore.designKeyPrefix) ||
              key == DesignStore.indexKey)
            key: prefs.getString(key)!,
      };
    }))!;

/// The customer [id]'s record, exactly as the device holds it.
Future<String?> customerAsStored(WidgetTester tester, String id) =>
    tester.runAsync<String?>(() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${CustomerStore.customerKeyPrefix}$id');
    });

Future<Customer> customerKept(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => CustomerStore().load(id)))!;

/// The ids of the designs kept for customer [id].
Future<Set<String>> designsOf(WidgetTester tester, String id) async =>
    (await tester.runAsync(() async {
      final found = await DesignStore().page(customerId: id, limit: 100);
      return {for (final s in found.items) s.id};
    }))!;

/// From the designs to Adam's page, and Edit.
Future<void> editAdam(WidgetTester tester, {String name = 'Adam'}) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, name);
  await pressEdit(tester);
}

Future<void> pressEdit(WidgetTester tester) async {
  final edit = find.byKey(CustomerScreen.editButton);
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await tester.tap(edit.hitTestable());
  await tester.pumpAndSettle();
  expect(find.byType(NewCustomerScreen), findsOneWidget);
}

String typedIn(WidgetTester tester, Key field) =>
    tester.widget<TextField>(find.byKey(field)).controller!.text;

Future<void> type(WidgetTester tester, Key field, String text) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(field), text);
  await tester.pumpAndSettle();
}

VoidCallback? saveButton(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(find.byKey(NewCustomerScreen.saveButton))
    .onPressed;

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(NewCustomerScreen.saveButton);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byType(NewCustomerScreen), findsNothing);
  expect(find.byType(CustomerScreen), findsOneWidget);
}

/// What the customer's page says about them.
Finder onThePage(String text) =>
    find.descendant(of: find.byType(CustomerScreen), matching: find.text(text));

Future<ProviderContainer> reopenTheApp(
  WidgetTester tester, {
  Size size = laptop,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  return screen.openTheApp(tester, size: size);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Edit on Adam\'s page opens his information as it is kept', (
    tester,
  ) async {
    await keepAdamWithDrawings();
    await screen.openTheApp(tester, size: phone);
    await editAdam(tester);
    expect(find.text('Edit Customer'), findsWidgets);
    expect(typedIn(tester, NewCustomerScreen.nameField), 'Adam');
    expect(typedIn(tester, NewCustomerScreen.phoneField), '+964 750 123 4567');
    expect(typedIn(tester, NewCustomerScreen.addressField), '');
    expect(typedIn(tester, NewCustomerScreen.notesField), '');
    expect(find.text('Save changes'), findsOneWidget);
    expect(saveButton(tester), isNotNull);
  });

  testWidgets('name, phone, address and notes are edited and saved — to '
      'Adam\'s record, the same customer, and nowhere else', (tester) async {
    final kept = await keepAdamWithDrawings();
    final adam = kept['Adam']!;
    await screen.openTheApp(tester, size: phone);
    final designsBefore = await designsAsStored(tester);
    final saraBefore = await customerAsStored(tester, kept['Sara']!.id);
    final karwanBefore = await customerAsStored(tester, kept['Karwan']!.id);

    await editAdam(tester);
    await type(tester, NewCustomerScreen.nameField, '  Adam Karim ');
    await type(tester, NewCustomerScreen.phoneField, '0751 222 3344');
    await type(
      tester,
      NewCustomerScreen.addressField,
      'Salim Street 12, Sulaymaniyah',
    );
    await type(
      tester,
      NewCustomerScreen.notesField,
      'Wants the basement door by May.',
    );
    await save(tester);

    // The page says the new information at once.
    expect(onThePage('Adam Karim'), findsWidgets);
    expect(onThePage('0751 222 3344'), findsOneWidget);
    expect(onThePage('Salim Street 12, Sulaymaniyah'), findsOneWidget);
    expect(onThePage('Wants the basement door by May.'), findsOneWidget);
    expect(onThePage('Customer · 4 designs'), findsOneWidget);
    expect(await designsOf(tester, adam.id), {
      'adam-0',
      'adam-1',
      'adam-2',
      'adam-3',
    }, reason: 'his designs still his');

    // Kept on Adam's record: the same customer, trimmed, changed now.
    final now = await customerKept(tester, adam.id);
    expect(now.id, adam.id);
    expect(now.createdAt, adam.createdAt);
    expect(now.name, 'Adam Karim');
    expect(now.phone, '0751 222 3344');
    expect(now.address, 'Salim Street 12, Sulaymaniyah');
    expect(now.notes, 'Wants the basement door by May.');
    expect(now.updatedAt.isAfter(adam.updatedAt), isTrue);

    // Not one byte of any design changed, nor anybody else.
    expect(await designsAsStored(tester), designsBefore);
    expect(await customerAsStored(tester, kept['Sara']!.id), saraBefore);
    expect(await customerAsStored(tester, kept['Karwan']!.id), karwanBefore);

    // And none of it was copied into a design.
    for (final text in (await designsAsStored(tester)).values) {
      for (final said in const [
        '0751',
        '222 3344',
        'Salim Street',
        'Sulaymaniyah',
        'basement door by May',
      ]) {
        expect(text, isNot(contains(said)));
      }
    }

    // It is still so after the app is closed and opened again.
    await reopenTheApp(tester, size: phone);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam Karim');
    expect(onThePage('0751 222 3344'), findsOneWidget);
    expect(onThePage('Salim Street 12, Sulaymaniyah'), findsOneWidget);
    expect(onThePage('Wants the basement door by May.'), findsOneWidget);
    expect(onThePage('Customer · 4 designs'), findsOneWidget);
    expect(await designsOf(tester, adam.id), hasLength(4));
  });

  testWidgets('changing Adam\'s phone does not touch Basement Door; changing '
      'his address does not touch Kitchen Window', (tester) async {
    await keepAdamWithDrawings();
    final c = await screen.openTheApp(tester, size: laptop);
    final before = await designsAsStored(tester);
    const basement = '${DesignStore.designKeyPrefix}adam-0';
    const kitchen = '${DesignStore.designKeyPrefix}adam-2';
    // There is real geometry to lose.
    final basementDoor = Design.fromJson(
      jsonDecode(before[basement]!) as Map<String, Object?>,
    );
    expect(basementDoor.name, 'Basement Door');
    expect(basementDoor.frame, isNotNull);
    expect(basementDoor.openings, hasLength(2));
    expect(basementDoor.hardware, isNotEmpty);

    await editAdam(tester);
    await type(tester, NewCustomerScreen.phoneField, '0770 000 0001');
    await save(tester);
    expect((await designsAsStored(tester))[basement], before[basement]);

    await pressEdit(tester);
    await type(tester, NewCustomerScreen.addressField, 'Bakhtiari, Erbil');
    await save(tester);
    expect((await designsAsStored(tester))[kitchen], before[kitchen]);
    expect(await designsAsStored(tester), before);

    // Opened from his page, Basement Door is exactly the design it was.
    final open = find.byKey(CustomerDesignCard.openKey('adam-0')).hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(
      jsonEncode(c.read(workspaceProvider).design.toJson()),
      jsonEncode(basementDoor.toJson()),
    );
  });

  testWidgets('a name is still needed: emptied, or only spaces, it cannot be '
      'saved and Adam stays as he was', (tester) async {
    final kept = await keepAdamWithDrawings();
    await screen.openTheApp(tester, size: phone);
    final adamBefore = await customerAsStored(tester, kept['Adam']!.id);
    await editAdam(tester);

    await type(tester, NewCustomerScreen.nameField, '');
    expect(saveButton(tester), isNull);
    await type(tester, NewCustomerScreen.nameField, '    ');
    expect(saveButton(tester), isNull);
    expect(await customerAsStored(tester, kept['Adam']!.id), adamBefore);

    // Turning back without saving changes nothing either.
    await type(tester, NewCustomerScreen.phoneField, '0000');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(onThePage('+964 750 123 4567'), findsOneWidget);
    expect(await customerAsStored(tester, kept['Adam']!.id), adamBefore);
  });

  testWidgets('given back an empty phone, address or notes, the page says it '
      'is not given', (tester) async {
    final kept = await keepAdamWithDrawings();
    await screen.openTheApp(tester, size: phone);
    await editAdam(tester);
    await type(tester, NewCustomerScreen.phoneField, '');
    await save(tester);
    expect(onThePage('Not given'), findsNWidgets(3));
    expect((await customerKept(tester, kept['Adam']!.id)).phone, '');
  });

  testWidgets('renamed, Adam is found by his new name — in the customers, in '
      'the designs and in his design\'s own panel — and no design was '
      'rewritten for it', (tester) async {
    final kept = await keepAdamWithDrawings();
    final c = await screen.openTheApp(tester, size: laptop);
    final before = await designsAsStored(tester);
    await editAdam(tester);
    await type(tester, NewCustomerScreen.nameField, 'Adam Karim');
    await save(tester);
    expect(find.widgetWithText(AppBar, 'Adam Karim'), findsOneWidget);

    // The customers list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(customers.shown(tester), contains('Adam Karim'));
    expect(customers.shown(tester), isNot(contains('Adam')));
    await customers.search(tester, 'Karim');
    expect(customers.shown(tester), ['Adam Karim']);
    await customers.search(tester, '');

    // His page, opened from the customers by his name as it is now: his
    // four designs as cards, and only them.
    await tester.tap(customers.cardOf('Adam Karim'));
    await tester.pumpAndSettle();
    expect(find.text('Customer · 4 designs'), findsOneWidget);
    for (final id in ['adam-0', 'adam-1', 'adam-2', 'adam-3']) {
      await tester.scrollUntilVisible(
        find.byKey(CustomerDesignCard.openKey(id)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(await designsAsStored(tester), before);

    // His design's own panel names him as he is now.
    await tester.ensureVisible(
      find.byKey(CustomerDesignCard.openKey('adam-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerDesignCard.openKey('adam-2')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(c.read(workspaceProvider).design.customerId, kept['Adam']!.id);
    expect(
      find.descendant(
        of: find.byKey(InspectorPanel.identityKey),
        matching: find.text('Adam Karim'),
      ),
      findsOneWidget,
    );
    expect(await designsAsStored(tester), before);
  });

  testWidgets('the form fits a phone, a tablet and a laptop', (tester) async {
    await keepAdamWithDrawings();
    for (final size in const [Size(360, 740), phone, tablet, laptop]) {
      await reopenTheApp(tester, size: size);
      await editAdam(tester);
      await type(tester, NewCustomerScreen.notesField, 'A long note. ' * 12);
      expect(customers.overflowing(tester), isEmpty, reason: 'form at $size');
      await save(tester);
      expect(customers.overflowing(tester), isEmpty, reason: 'page at $size');
    }
  });
}

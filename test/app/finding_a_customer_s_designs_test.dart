import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// Adam has 36 designs — 15 doors, 12 windows, 6 sliding and 3 door & window
// sets — and his page has to find one of them. A search by what a design is
// called ("Basement", "Kitchen", "Entrance", "Third Floor") and a chip a
// category (All, Door, Window, Sliding, Door & window). Both only choose
// what is shown: nothing kept changes, and nothing is begun.

const phone = Size(390, 844);
const laptop = Size(1280, 860);

/// Adam's 36 designs by name and category, and Sara's two — one of them a
/// kitchen window too, which Adam's page must never show.
Future<({String adam, String sara})> keepAdamsMany() async {
  final people = CustomerStore();
  final store = DesignStore(customers: people);
  final at = DateTime(2026, 3, 1, 8);
  final adam = await people.create(
    name: 'Adam',
    now: at,
    by: WorkshopRole.owner,
  );
  final sara = await people.create(
    name: 'Sara',
    now: at.add(const Duration(minutes: 1)),
    by: WorkshopRole.owner,
  );
  final adams = <(String, DesignKind)>[
    ('Basement Door', DesignKind.door),
    ('Front Entrance Door', DesignKind.door),
    for (var i = 1; i <= 13; i++) ('Bedroom Door $i', DesignKind.door),
    ('Kitchen Window', DesignKind.window),
    for (var i = 1; i <= 11; i++) ('Living Room Window $i', DesignKind.window),
    ('Third Floor Sliding', DesignKind.sliding),
    for (var i = 1; i <= 5; i++) ('Balcony Sliding $i', DesignKind.sliding),
    for (var i = 1; i <= 3; i++) ('Shop Front $i', DesignKind.both),
  ];
  for (final (i, (name, kind)) in adams.indexed) {
    await store.save(
      Design.empty(
        id: 'adam-$i',
        kind: kind,
        name: name,
        customerId: adam.id,
        now: at.add(Duration(minutes: i)),
      ),
      by: WorkshopRole.owner,
    );
  }
  for (final (i, (name, kind)) in const [
    ('Kitchen Window', DesignKind.window),
    ('Basement Door', DesignKind.door),
  ].indexed) {
    await store.save(
      Design.empty(
        id: 'garden-$i',
        kind: kind,
        name: name,
        customerId: sara.id,
        now: at.add(Duration(hours: 1, minutes: i)),
      ),
      by: WorkshopRole.owner,
    );
  }
  return (adam: adam.id, sara: sara.id);
}

/// Everything the device keeps, as it keeps it.
Future<Map<String, Object?>> everythingKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {for (final key in prefs.getKeys()) key: prefs.get(key)};
    }))!;

Future<void> toAdam(WidgetTester tester) async {
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
}

Future<void> search(WidgetTester tester, String query) async {
  final field = find.byKey(CustomerScreen.searchField);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
}

Future<void> filter(WidgetTester tester, DesignKind? kind) async {
  final chip = find.byKey(CustomerScreen.filterKey(kind));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// The designs the page shows now: every card, read to the end of the list.
Future<List<DesignSummary>> shown(WidgetTester tester) async {
  final seen = <String, DesignSummary>{};
  final scrollable = find
      .descendant(
        of: find.byType(CustomerScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var i = 0; i < 60; i++) {
    for (final card in tester.widgetList<CustomerDesignCard>(
      find.byType(CustomerDesignCard),
    )) {
      seen[card.design.id] = card.design;
    }
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  // Back to the top, where the search and the chips are.
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  return seen.values.toList();
}

Set<String> namesShown(List<DesignSummary> designs) => {
  for (final d in designs) d.name,
};

String chipLabel(WidgetTester tester, DesignKind? kind) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(CustomerScreen.filterKey(kind)),
        matching: find.byType(Text),
      ),
    )
    .data!;

// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a chip a category, each saying how many — All, Door, Window, '
      'Sliding, Door & window', (tester) async {
    await keepAdamsMany();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    expect(find.text('Customer · 36 designs'), findsOneWidget);
    expect(chipLabel(tester, null), 'All  36');
    expect(chipLabel(tester, DesignKind.door), 'Door  15');
    expect(chipLabel(tester, DesignKind.window), 'Window  12');
    expect(chipLabel(tester, DesignKind.sliding), 'Sliding  6');
    expect(chipLabel(tester, DesignKind.both), 'Door & window  3');
    // In the order a design is begun as.
    final lefts = [
      for (final kind in [
        null,
        DesignKind.door,
        DesignKind.window,
        DesignKind.sliding,
        DesignKind.both,
      ])
        tester.getTopLeft(find.byKey(CustomerScreen.filterKey(kind))).dx,
    ];
    expect(lefts, [...lefts]..sort());
    expect(await shown(tester), hasLength(36));
  });

  for (final (kind, count) in const [
    (DesignKind.door, 15),
    (DesignKind.window, 12),
    (DesignKind.sliding, 6),
    (DesignKind.both, 3),
  ]) {
    testWidgets('${kind.label}: only Adam\'s ${kind.label.toLowerCase()} '
        'designs are shown — all $count of them', (tester) async {
      await keepAdamsMany();
      await screen.openTheApp(tester, size: phone);
      await toAdam(tester);
      await filter(tester, kind);
      final designs = await shown(tester);
      expect(find.text('$count of 36'), findsOneWidget);
      expect(designs, hasLength(count));
      expect(designs.map((d) => d.kind).toSet(), {kind});
      expect(designs.every((d) => d.id.startsWith('adam-')), isTrue);
      // All again shows every one.
      await filter(tester, null);
      expect(await shown(tester), hasLength(36));
    });
  }

  testWidgets('searching by name: "Basement", "Kitchen", "Entrance", "Third '
      'Floor" — only Adam\'s, whatever the case', (tester) async {
    await keepAdamsMany();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    for (final (query, found) in const [
      ('Basement', 'Basement Door'),
      ('kitchen', 'Kitchen Window'),
      ('Entrance', 'Front Entrance Door'),
      ('Third Floor', 'Third Floor Sliding'),
      ('  third floor ', 'Third Floor Sliding'),
    ]) {
      await search(tester, query);
      final designs = await shown(tester);
      expect(namesShown(designs), {found}, reason: query);
      expect(designs.single.id, startsWith('adam-'), reason: 'not Sara\'s');
      expect(find.text('1 of 36'), findsOneWidget);
    }
    await search(tester, 'Bedroom');
    expect(await shown(tester), hasLength(13));
    await search(tester, '');
    expect(await shown(tester), hasLength(36));
    expect(find.text('36'), findsOneWidget, reason: 'nothing narrowing it');
  });

  testWidgets('a search and a filter together narrow it by both', (
    tester,
  ) async {
    await keepAdamsMany();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    await search(tester, 'Living Room');
    expect(await shown(tester), hasLength(11));
    await search(tester, 'o');
    await filter(tester, DesignKind.sliding);
    final designs = await shown(tester);
    expect(designs.map((d) => d.kind).toSet(), {DesignKind.sliding});
    expect(namesShown(designs), {
      'Third Floor Sliding',
      for (var i = 1; i <= 5; i++) 'Balcony Sliding $i',
    });
    // Changing the filter keeps the search.
    await filter(tester, DesignKind.both);
    expect(namesShown(await shown(tester)), {
      for (var i = 1; i <= 3; i++) 'Shop Front $i',
    });
  });

  testWidgets('finding nothing says so, and offers every design back — not '
      'a new one', (tester) async {
    await keepAdamsMany();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    await search(tester, 'Garage');
    expect(find.text('No designs match “Garage”'), findsOneWidget);
    expect(find.byType(CustomerDesignCard), findsNothing);
    expect(find.text('0 of 36'), findsOneWidget);
    expect(find.byType(DesignNameScreen), findsNothing);

    await search(tester, 'Shop');
    await filter(tester, DesignKind.door);
    expect(find.text('No designs match “Shop” in Door'), findsOneWidget);

    await tester.tap(find.byKey(CustomerScreen.clearButton));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(find.byType(DesignNameScreen), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(CustomerScreen.searchField))
          .controller!
          .text,
      '',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(CustomerScreen.filterKey(null)))
          .selected,
      isTrue,
    );
    expect(await shown(tester), hasLength(36));
  });

  testWidgets('searching and filtering change nothing that is kept and '
      'begin nothing', (tester) async {
    await keepAdamsMany();
    final c = await screen.openTheApp(tester, size: phone);
    final before = await everythingKept(tester);
    final inHand = c.read(workspaceProvider).design.id;
    await toAdam(tester);
    for (final kind in [
      DesignKind.door,
      DesignKind.window,
      DesignKind.sliding,
      DesignKind.both,
      null,
    ]) {
      await filter(tester, kind);
    }
    await search(tester, 'Kitchen');
    await filter(tester, DesignKind.window);
    await search(tester, 'Garage');
    await search(tester, '');
    expect(await everythingKept(tester), before);
    expect(c.read(workspaceProvider).design.id, inHand, reason: 'none begun');
    expect(find.byType(DesignNameScreen, skipOffstage: false), findsNothing);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
    expect(find.byType(WorkspaceScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('with Window chosen, New Design is still a new design of any '
      'category — the filter chooses nothing for it', (tester) async {
    await keepAdamsMany();
    await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    await filter(tester, DesignKind.window);
    await tester.tap(find.byKey(CustomerScreen.newDesignButton).hitTestable());
    await tester.pumpAndSettle();
    final naming = tester.widget<DesignNameScreen>(
      find.byType(DesignNameScreen),
    );
    expect(naming.setup.kind, isNull);
    expect(naming.setup.name, isNull);
    await nameTheDesign(tester, 'Garage Door');
    final setup = tester.widget<StartScreen>(find.byType(StartScreen)).setup;
    expect(setup.kind, isNull, reason: 'no category chosen for the user');
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('a design found opens as itself', (tester) async {
    await keepAdamsMany();
    final c = await screen.openTheApp(tester, size: phone);
    await toAdam(tester);
    await search(tester, 'Third Floor');
    await tester.tap(find.byType(CustomerDesignCard));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final design = c.read(workspaceProvider).design;
    expect(design.name, 'Third Floor Sliding');
    expect(design.category, DesignKind.sliding);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a category the customer has none of has no chip', (
    tester,
  ) async {
    final people = CustomerStore();
    final karwan = await people.create(name: 'Karwan', by: WorkshopRole.owner);
    await DesignStore(customers: people).save(
      Design.empty(
        id: 'karwan-0',
        kind: DesignKind.door,
        name: 'Gate',
        customerId: karwan.id,
      ),
      by: WorkshopRole.owner,
    );
    await screen.openTheApp(tester, size: phone);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Karwan');
    expect(chipLabel(tester, null), 'All  1');
    expect(chipLabel(tester, DesignKind.door), 'Door  1');
    for (final kind in [
      DesignKind.window,
      DesignKind.sliding,
      DesignKind.both,
    ]) {
      expect(find.byKey(CustomerScreen.filterKey(kind)), findsNothing);
    }
  });

  testWidgets('a customer with no designs has nothing to search', (
    tester,
  ) async {
    await CustomerStore().create(name: 'Dilan', by: WorkshopRole.owner);
    await screen.openTheApp(tester, size: phone);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Dilan');
    expect(find.byKey(CustomerScreen.searchField), findsNothing);
    expect(find.text('No designs yet'), findsOneWidget);
  });

  test('the store narrows one customer\'s designs by name and category and '
      'counts each category', () async {
    final ids = await keepAdamsMany();
    final store = DesignStore();
    expect(await store.kindsOf(ids.adam), {
      DesignKind.door: 15,
      DesignKind.window: 12,
      DesignKind.sliding: 6,
      DesignKind.both: 3,
    });
    final kitchens = await store.page(customerId: ids.adam, query: 'Kitchen');
    expect(kitchens.items.map((s) => s.id), ['adam-15']);
    final windows = await store.page(
      customerId: ids.adam,
      kind: DesignKind.window,
    );
    expect(windows.total, 12);
    // Within one customer the customer's own name is not what is searched.
    expect((await store.page(customerId: ids.sara, query: 'Sara')).total, 0);
    // Across all customers it still is.
    expect((await store.page(query: 'Sara')).total, 2);
    expect((await store.page(query: 'Kitchen')).total, 2);
  });

  testWidgets('it fits a phone, a tablet and a laptop — searching, filtered '
      'and finding nothing', (tester) async {
    await keepAdamsMany();
    for (final size in const [Size(360, 740), phone, Size(820, 1180), laptop]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      await toAdam(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'all at $size');
      await filter(tester, DesignKind.both);
      await search(tester, 'Shop');
      expect(page.overflowing(tester), isEmpty, reason: 'found at $size');
      await search(tester, 'Garage');
      expect(page.overflowing(tester), isEmpty, reason: 'none at $size');
    }
  });
}

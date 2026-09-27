import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/design_preview.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'the_designs_screen_test.dart' as screen;

// A customer's designs, as cards: each design where design.customerId is
// that customer's id, shown by its own picture — the design itself, drawn —
// its name, its category, when it was last edited, and Open. Nobody else's
// design is ever on a customer's page.

/// The ids of the design cards built on the page, in the order they stand.
List<String> cards(WidgetTester tester) {
  final found =
      [
        for (final e in find.byType(CustomerDesignCard).evaluate())
          (
            (e.widget as CustomerDesignCard).design.id,
            tester.getTopLeft(find.byWidget(e.widget)),
          ),
      ]..sort((a, b) {
        final dy = a.$2.dy.compareTo(b.$2.dy);
        return dy != 0 ? dy : a.$2.dx.compareTo(b.$2.dx);
      });
  return [for (final (id, _) in found) id];
}

/// Every card on the page, scrolling down to reach them all.
Future<Set<String>> everyCard(WidgetTester tester) async {
  final seen = <String>{...cards(tester)};
  final scroll = find.descendant(
    of: find.byType(CustomerScreen),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 20; i++) {
    await tester.drag(scroll.first, const Offset(0, -300));
    await tester.pumpAndSettle();
    seen.addAll(cards(tester));
  }
  return seen;
}

Finder inCard(String id, Finder what) => find.descendant(
  of: find.byKey(CustomerScreen.designKey(id)),
  matching: what,
);

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('last edited, as a date and a time', () {
    final now = DateTime(2026, 3, 10, 17, 30);
    test('today, yesterday, and a date before that', () {
      expect(lastEdited(DateTime(2026, 3, 10, 9, 5), now), 'Today, 09:05');
      expect(lastEdited(DateTime(2026, 3, 9, 18, 2), now), 'Yesterday, 18:02');
      expect(lastEdited(DateTime(2026, 3, 1, 9, 14), now), '1 Mar 2026, 09:14');
      expect(
        lastEdited(DateTime(2025, 12, 24, 23, 59), now),
        '24 Dec 2025, 23:59',
      );
    });
  });

  testWidgets('Adam\'s page shows every design of Adam\'s as a card: '
      'name, category, last edited, Open', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');

    final ofAdam = await tester.runAsync(
      () => DesignStore().page(customerId: kept['Adam']!.id, limit: 100),
    );
    final expected = {for (final s in ofAdam!.items) s.id};
    expect(expected, hasLength(4));
    expect(await everyCard(tester), expected);

    for (final (id, name, category) in [
      ('adam-0', 'Basement Door', 'Door'),
      ('adam-1', 'Front Entrance Door', 'Door'),
      ('adam-2', 'Kitchen Window', 'Window'),
      ('adam-3', 'Third Floor Sliding', 'Sliding'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(CustomerScreen.designKey(id)),
        100,
      );
      expect(inCard(id, find.text(name)), findsOneWidget);
      expect(inCard(id, find.text(category)), findsOneWidget);
      expect(inCard(id, find.textContaining('Last edited: ')), findsOneWidget);
      expect(
        inCard(id, find.byKey(CustomerDesignCard.openKey(id))),
        findsOneWidget,
      );
      expect(inCard(id, find.text('Open')), findsOneWidget);
    }
    expect(overflowing(tester), isEmpty);
  });

  testWidgets('the picture on a card is the design itself — drawn from its '
      'own geometry, or the empty sheet where nothing is drawn — and never '
      'a picture of something else', (tester) async {
    final kept = await customers.keepThreeCustomers();
    // One of Adam's designs has a drawing: an outline, a mullion and a mark,
    // read into a frame.
    final drawn = await tester.runAsync(() async {
      final design = screen
          .drawn(
            customer: 'Adam',
            kind: DesignKind.door,
            edited: DateTime(2026, 3, 2),
          )
          .copyWith(customerId: kept['Adam']!.id, name: 'Drawn Door');
      return DesignStore().save(design);
    });
    await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    await tester.scrollUntilVisible(
      find.byKey(CustomerScreen.designKey(drawn!.id)),
      100,
    );

    // The drawn design's card draws that design, as it was kept.
    final painters = [
      for (final paint in tester.widgetList<CustomPaint>(
        inCard(drawn.id, find.byType(CustomPaint)),
      ))
        if (paint.painter case final DesignPreviewPainter p) p,
    ];
    expect(painters, hasLength(1));
    expect(
      jsonEncode(painters.single.design.toJson()),
      jsonEncode(drawn.toJson()),
    );
    expect(inCard(drawn.id, find.byType(DesignPicture)), findsOneWidget);

    // A design with nothing drawn yet says so, and draws nothing.
    await tester.scrollUntilVisible(
      find.byKey(CustomerScreen.designKey('adam-0')),
      100,
    );
    expect(inCard('adam-0', find.text('Nothing drawn yet')), findsOneWidget);
    expect(
      tester
          .widgetList<CustomPaint>(inCard('adam-0', find.byType(CustomPaint)))
          .where((c) => c.painter is DesignPreviewPainter),
      isEmpty,
    );

    // And no picture of anything at all, anywhere on the page.
    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('a different customer sees only their own designs, and '
      'nobody\'s designs are mixed', (tester) async {
    final kept = await customers.keepThreeCustomers();
    // Two more designs each for Adam and Sara, made interleaved, so the
    // most recent designs of the two sit side by side in the store.
    await tester.runAsync(() async {
      final store = DesignStore();
      for (var i = 0; i < 4; i++) {
        final who = i.isEven ? 'Adam' : 'Sara';
        await store.save(
          Design.empty(
            id: 'mixed-$i',
            kind: DesignKind.window,
            name: '$who extra $i',
            customerId: kept[who]!.id,
            now: DateTime(2026, 3, 5, 10, i),
          ),
        );
      }
    });
    await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);

    final everything = (await tester.runAsync(
      () => DesignStore().page(limit: 100),
    ))!;
    for (final who in ['Adam', 'Sara', 'Karwan']) {
      await page.openCustomer(tester, who);
      final shown = await everyCard(tester);
      final theirs = {
        for (final s in everything.items)
          if (s.customerId == kept[who]!.id) s.id,
      };
      expect(shown, theirs, reason: "$who's page");
      for (final id in shown) {
        final card = tester.widget<CustomerDesignCard>(
          find.byKey(CustomerScreen.designKey(id)),
        );
        expect(card.design.customerId, kept[who]!.id);
      }
      if (who == 'Karwan') {
        expect(find.text('No designs yet'), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Open on a card opens that design exactly as kept', (
    tester,
  ) async {
    await customers.keepThreeCustomers();
    final c = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    await tester.scrollUntilVisible(
      find.byKey(CustomerDesignCard.openKey('adam-2')),
      100,
    );
    await tester.tap(find.byKey(CustomerDesignCard.openKey('adam-2')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final open = c.read(workspaceProvider).design;
    expect(open.id, 'adam-2');
    final stored = await tester.runAsync(() => DesignStore().load('adam-2'));
    expect(jsonEncode(open.toJson()), jsonEncode(stored!.toJson()));
  });

  testWidgets('New Design stays in sight beside the cards, and makes a '
      'design only once the user starts one', (tester) async {
    final kept = await customers.keepThreeCustomers();
    await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    expect(find.byKey(CustomerScreen.newDesignButton), findsOneWidget);
    // Still in sight, and still pressable, scrolled down to the last card.
    await tester.scrollUntilVisible(
      find.byKey(CustomerScreen.designKey('adam-0')),
      200,
    );
    expect(
      find.byKey(CustomerScreen.newDesignButton).hitTestable(),
      findsOneWidget,
    );
    final before = await page.keptDesigns(tester);

    // Pressing New Design and turning back makes nothing.
    await tester.tap(find.byKey(CustomerScreen.newDesignButton));
    await tester.pumpAndSettle();
    expect(find.byType(StartScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await page.keptDesigns(tester), before);

    // Starting one makes exactly one, and it is Adam's card.
    await tester.tap(find.byKey(CustomerScreen.newDesignButton));
    await tester.pumpAndSettle();
    await chooseDesign(tester, 'WINDOW');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(await page.keptDesigns(tester), before + 1);
    final shown = await everyCard(tester);
    expect(shown, hasLength(5));
    final ofAdam = (await tester.runAsync(
      () => DesignStore().page(customerId: kept['Adam']!.id, limit: 100),
    ))!;
    expect(shown, {for (final s in ofAdam.items) s.id});
  });

  testWidgets('cards stand in a grid where there is room, one above another '
      'on a phone, and fit every screen', (tester) async {
    await customers.keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      await screen.openTheApp(tester, size: size);
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      expect(overflowing(tester), isEmpty, reason: 'at $size');
      final tops = {
        for (final e in find.byType(CustomerDesignCard).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      final lefts = {
        for (final e in find.byType(CustomerDesignCard).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx,
      };
      if (size.width < 600) {
        expect(lefts, hasLength(1), reason: 'one column at $size');
      } else {
        expect(lefts.length, greaterThan(1), reason: 'a grid at $size');
        expect(tops.length, lessThan(4));
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
  });
}

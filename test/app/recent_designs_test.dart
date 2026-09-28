import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'opening_an_existing_design_test.dart' as existing;
import 'the_designs_screen_test.dart' as screen;

// Where the app opens: Recent Designs — designs, not customers, the most
// recently edited first. Each says who it is for, what it is called, its
// category and when it was last edited:
//
//   Adam                     Adam
//   Basement Door            Kitchen Window
//   Door                     Window
//   Edited …                 Edited …
//
// Tapping one opens that exact design — nothing asked, no New Design, no
// category — and every card is a design actually kept.

const phone = Size(390, 844);
const laptop = Size(1280, 860);

Finder cardFor(String id) =>
    find.byWidgetPredicate((w) => w is DesignCard && w.summary.id == id);

List<String> cardsInOrder(WidgetTester tester) {
  final cards = tester.widgetList<DesignCard>(find.byType(DesignCard)).toList()
    ..sort((a, b) {
      final at = tester.getTopLeft(find.byWidget(a));
      final bt = tester.getTopLeft(find.byWidget(b));
      final dy = at.dy.compareTo(bt.dy);
      return dy != 0 ? dy : at.dx.compareTo(bt.dx);
    });
  return [for (final c in cards) c.summary.id];
}

Finder onCard(String id, String text) =>
    find.descendant(of: cardFor(id), matching: find.text(text));

Future<Map<String, String>> everyStored(WidgetTester tester) async =>
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

void noNewDesignFlow() {
  expect(find.byType(NewDesignScreen, skipOffstage: false), findsNothing);
  expect(find.byType(DesignNameScreen, skipOffstage: false), findsNothing);
  expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
}

Future<void> openCard(WidgetTester tester, String id) async {
  final open = find.byKey(DesignCard.openKey(id));
  await tester.scrollUntilVisible(
    open.hitTestable(),
    100,
    scrollable: find
        .descendant(
          of: find.byType(DesignsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(open.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with nothing kept, a clean empty state — and no design made '
      'up to fill it', (tester) async {
    await screen.openTheApp(tester, size: phone);
    expect(find.byType(DesignCard), findsNothing);
    expect(find.text('No recent designs yet'), findsOneWidget);
    expect(find.text('Create your first design to get started.'), findsOne);
    expect(find.text('Recent Designs'), findsNothing);
    expect(await everyStored(tester), isEmpty);
    expect(page.overflowing(tester), isEmpty);
  });

  for (final size in const [phone, laptop]) {
    testWidgets('at ${size.width.round()} wide, each recent design says who '
        'it is for, what it is called, its category and when it was last '
        'edited — newest first', (tester) async {
      await existing.keepAdam();
      await screen.openTheApp(tester, size: size);
      expect(find.text('Recent Designs'), findsOneWidget);

      // Exactly the designs kept — no more, no fewer — the most recently
      // edited first.
      expect(cardsInOrder(tester), [
        'sara-door',
        'kitchen-window',
        'basement-door',
      ]);
      expect(
        cardsInOrder(tester).toSet(),
        (await everyStored(tester)).keys.toSet(),
      );

      for (final (id, who, name, category) in const [
        ('basement-door', 'Adam', 'Basement Door', 'Door'),
        ('kitchen-window', 'Adam', 'Kitchen Window', 'Window'),
        ('sara-door', 'Sara', 'Garden Door', 'Door'),
      ]) {
        expect(onCard(id, who), findsOneWidget, reason: '$id: customer');
        expect(onCard(id, name), findsOneWidget, reason: '$id: name');
        expect(onCard(id, category), findsOneWidget, reason: '$id: category');
        expect(
          find.descendant(
            of: cardFor(id),
            matching: find.textContaining('Edited'),
          ),
          findsOneWidget,
          reason: '$id: last edited',
        );
      }
      // Two of Adam's designs are two cards, told apart by their names.
      expect(
        find.descendant(
          of: find.byType(DesignCard),
          matching: find.text('Adam'),
        ),
        findsNWidgets(2),
      );
      expect(page.overflowing(tester), isEmpty);
    });
  }

  testWidgets('the time is when the design was last edited, as kept', (
    tester,
  ) async {
    final kept = await existing.keepAdam();
    final store = DesignStore();
    final now = DateTime.now();
    await store.save(
      kept.window.copyWith(updatedAt: now.subtract(const Duration(minutes: 5))),
    );
    await store.save(
      kept.door.copyWith(updatedAt: now.subtract(const Duration(days: 3))),
    );
    await screen.openTheApp(tester, size: phone);
    expect(onCard('kitchen-window', 'Edited 5 minutes ago'), findsOneWidget);
    expect(onCard('basement-door', 'Edited 3 days ago'), findsOneWidget);
    expect(cardsInOrder(tester).first, 'kitchen-window');
  });

  testWidgets('tapping a recent design opens that exact design — no New '
      'Design, no category asked, nothing made', (tester) async {
    await existing.keepAdam();
    final c = await screen.openTheApp(tester, size: phone);
    final before = await everyStored(tester);

    await openCard(tester, 'basement-door');
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    noNewDesignFlow();
    final inHand = c.read(workspaceProvider).design;
    expect(inHand.id, 'basement-door');
    expect(inHand.category, DesignKind.door);
    expect(jsonEncode(inHand.toJson()), before['basement-door']);

    // Back, and nothing was made or changed by looking.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DesignsScreen), findsOneWidget);
    expect(await everyStored(tester), before);

    // A tap anywhere on the card is the same as Open.
    await tester.tap(onCard('kitchen-window', 'Kitchen Window'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    noNewDesignFlow();
    expect(c.read(workspaceProvider).design.id, 'kitchen-window');
    expect(
      jsonEncode(c.read(workspaceProvider).design.toJson()),
      before['kitchen-window'],
    );
  });

  testWidgets('a design edited comes back to the top of Recent Designs', (
    tester,
  ) async {
    await existing.keepAdam();
    final c = await screen.openTheApp(tester, size: laptop);
    expect(cardsInOrder(tester).last, 'basement-door');
    await openCard(tester, 'basement-door');
    c.read(workspaceProvider.notifier).rename('Basement Door - New PVC');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(cardsInOrder(tester).first, 'basement-door');
    expect(onCard('basement-door', 'Basement Door - New PVC'), findsOne);
    expect(onCard('basement-door', 'Edited just now'), findsOneWidget);
  });

  testWidgets('a design removed since the list was read is not opened, and '
      'nothing is begun in its place', (tester) async {
    await existing.keepAdam();
    final c = await screen.openTheApp(tester, size: phone);
    final inHand = c.read(workspaceProvider).design.id;
    await tester.runAsync(() => DesignStore().remove('basement-door'));
    await openCard(tester, 'basement-door');
    expect(find.byType(WorkspaceScreen), findsNothing);
    noNewDesignFlow();
    expect(find.text('Basement Door could not be opened.'), findsOneWidget);
    expect(c.read(workspaceProvider).design.id, inHand);
    expect(cardFor('basement-door'), findsNothing);
    expect((await everyStored(tester)).keys, hasLength(2));
  });

  testWidgets('long names fit a phone, a tablet and a laptop', (tester) async {
    final kept = await existing.keepAdam();
    await DesignStore().save(
      kept.window.copyWith(
        name: 'Kitchen Window over the sink, left of the back door',
      ),
    );
    for (final size in const [Size(360, 740), phone, Size(820, 1180), laptop]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      expect(find.byType(DesignCard), findsNWidgets(3));
      expect(page.overflowing(tester), isEmpty, reason: 'at $size');
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// From the designs screen the app opens on, through **New Design**, to the
/// choice of door, window, both or sliding — the way a user begins a design.
///
/// The form asks one thing, who the design is for, and needs it; [customer]
/// is typed in, or a name that says it is a test's where none is given.
Future<void> toTheCategories(
  WidgetTester tester, {
  String customer = 'Test customer',
}) async {
  await tester.tap(find.text('New Design').first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('new-design-customer')),
    customer,
  );
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

/// On **Choose your design**, picks the card called [card] — `DOOR`,
/// `WINDOW`, `DOOR & WINDOW` or `SLIDING` — and starts drawing: the way a
/// user goes from the choice into the drawing.
///
/// A door and a door & window set are asked, as they start, what they are
/// built of. A test about something else puts that away as a user in a
/// hurry would — **Not now** — unless [answerConstruction] says the test is
/// about that question and will answer it itself.
Future<void> chooseDesign(
  WidgetTester tester,
  String card, {
  bool answerConstruction = false,
}) async {
  await tester.ensureVisible(find.text(card));
  await tester.pumpAndSettle();
  await tester.tap(find.text(card));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start drawing'));
  await tester.pumpAndSettle();
  if (!answerConstruction) await notNowToConstruction(tester);
}

/// Puts away the question of what a new door is built of, if it is asked.
Future<void> notNowToConstruction(WidgetTester tester) async {
  final asked = find.byKey(const ValueKey('construction-panel'));
  if (asked.evaluate().isEmpty) return;
  // On a small phone the card scrolls, as the user would scroll it.
  await tester.ensureVisible(find.text('Not now').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Not now').last);
  await tester.pumpAndSettle();
}

/// Puts the sizes away the way a user does who will give them later:
/// **Not now**. A reading asks for the real size of every part as soon as
/// there is something to measure; a test about something else answers it
/// as a user in a hurry would, and goes on.
Future<void> notNowToSizes(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final notNow = find.descendant(
    of: find.byType(Dialog),
    matching: find.text('Not now'),
  );
  if (notNow.evaluate().isEmpty) return;
  await tester.tap(notNow.first);
  await tester.pumpAndSettle();
}

/// Shows every control, the way a user does who wants more than the simple
/// workspace: **More**, beside the views. The workspace opens simple — see
/// `EverythingShown` — and a test about a control under More gets to it the
/// way the user does.
Future<void> showEverything(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final more = find.byKey(const ValueKey('more-tools'));
  if (more.evaluate().isEmpty) return;
  final simple = find.descendant(of: more, matching: find.text('More'));
  if (simple.evaluate().isEmpty) return;
  await tester.tap(more);
  await tester.pumpAndSettle();
}

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
Future<void> chooseDesign(WidgetTester tester, String card) async {
  await tester.ensureVisible(find.text(card));
  await tester.pumpAndSettle();
  await tester.tap(find.text(card));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start drawing'));
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

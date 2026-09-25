import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// From the designs screen the app opens on, through **New Design**, to the
/// choice of door, window, both or sliding — the way a user begins a design.
///
/// [customer] and [name] are typed into the new design's form where given;
/// otherwise the form is left empty, as a user in a hurry leaves it.
Future<void> toTheCategories(
  WidgetTester tester, {
  String? customer,
  String? name,
}) async {
  await tester.tap(find.text('New Design').first);
  await tester.pumpAndSettle();
  if (customer != null) {
    await tester.enterText(
      find.byKey(const ValueKey('new-design-customer')),
      customer,
    );
  }
  if (name != null) {
    await tester.enterText(find.byKey(const ValueKey('new-design-name')), name);
  }
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

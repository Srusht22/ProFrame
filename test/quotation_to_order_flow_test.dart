import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/di/providers.dart';
import 'package:proframe/data/demo/demo_data_seeder.dart';

import 'app_smoke_test.dart' show InMemoryKeyValueStore;

/// Exercises the commercial chain the whole product is built around:
/// project items -> quotation -> accepted -> order -> manufacturing order.
void main() {
  testWidgets('a project quotation can be created, accepted and converted to an order', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
        child: const ProFrameApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'admin@proframe.demo');
    await tester.enterText(find.byType(TextFormField).last, DemoDataSeeder.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Open a seeded project that already has a configured item.
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Projects')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Skyline Office Fit-Out').first);
    await tester.pumpAndSettle();

    // Create a quotation from its configured items.
    await tester.tap(find.widgetWithText(FilledButton, 'Create quotation'));
    await tester.pumpAndSettle();
    expect(find.text('Create quotation'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Create quotation').last);
    await tester.pumpAndSettle();

    // We land on the new quotation, in Draft.
    expect(find.text('Draft'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Mark as sent'), findsOneWidget);

    // Draft -> Sent -> Accepted.
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as sent'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark accepted'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsWidgets);

    // Accepted -> Order (which also opens a manufacturing order).
    await tester.tap(find.widgetWithText(FilledButton, 'Convert to order'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ORD-'), findsWidgets);
    expect(find.text('Production progress'), findsOneWidget);
    expect(find.textContaining('View manufacturing order MO-'), findsOneWidget);

    // The manufacturing order is real and reachable.
    await tester.tap(find.textContaining('View manufacturing order MO-'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Current stage:'), findsOneWidget);
    expect(find.textContaining('Advance to'), findsWidgets);
  });
}

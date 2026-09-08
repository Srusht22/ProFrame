import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/di/providers.dart';
import 'package:proframe/data/demo/demo_data_seeder.dart';

import 'app_smoke_test.dart' show InMemoryKeyValueStore;

/// Boots the real app (seeded demo data, real repositories, real router) and
/// walks every main destination. Anything that throws during layout — an
/// overflow, a null provider read, a bad route — fails the test.
Future<void> _bootAndSignIn(WidgetTester tester, {Size size = const Size(1600, 1200)}) async {
  tester.view.physicalSize = size;
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
}

Future<void> _openRail(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );
  expect(destination, findsWidgets, reason: 'nav rail should offer a "$label" destination');
  await tester.tap(destination.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every main destination renders without layout or state errors', (tester) async {
    await _bootAndSignIn(tester);

    await _openRail(tester, 'Customers');
    expect(find.text('Ahmed Al-Bayati'), findsOneWidget);

    await _openRail(tester, 'Projects');
    expect(find.textContaining('Bayati Villa'), findsOneWidget);

    await _openRail(tester, 'Quotations');
    expect(find.textContaining('Q-'), findsWidgets);

    await _openRail(tester, 'Orders');
    expect(find.textContaining('ORD-'), findsWidgets);

    await _openRail(tester, 'Manufacturing');
    expect(find.textContaining('MO-'), findsWidgets);

    await _openRail(tester, 'Inventory');
    expect(find.textContaining('Aluminum profile'), findsOneWidget);

    await _openRail(tester, 'Reports');
    expect(find.text('Monthly revenue (last 12 months)'), findsOneWidget);

    await _openRail(tester, 'Settings');
    expect(find.text('Company'), findsOneWidget);

    // Settings tabs: pricing rules, users & roles, preferences.
    await tester.tap(find.text('Pricing rules'));
    await tester.pumpAndSettle();
    expect(find.text('Cost structure (%)'), findsOneWidget);

    await tester.tap(find.text('Users & roles'));
    await tester.pumpAndSettle();
    expect(find.text('admin@proframe.demo'), findsOneWidget);

    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Document numbering'), findsOneWidget);

    // Notifications + audit log (reached outside the rail).
    await tester.tap(find.byIcon(Icons.notifications_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
  });

  testWidgets('project detail opens and lists its configured items and quotations', (tester) async {
    await _bootAndSignIn(tester);
    await _openRail(tester, 'Projects');

    await tester.tap(find.textContaining('Skyline Office Fit-Out').first);
    await tester.pumpAndSettle();

    expect(find.text('Office Entrance Door'), findsWidgets);
    expect(find.textContaining('Configured items'), findsOneWidget);
    expect(find.textContaining('Quotations ('), findsOneWidget);
  });
}

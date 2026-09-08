import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/di/providers.dart';
import 'package:proframe/data/demo/demo_data_seeder.dart';

import 'app_smoke_test.dart' show InMemoryKeyValueStore;

/// Drives the configurator wizard on a phone-sized viewport (the desktop
/// 3-pane layout embeds the WebView-backed 3D viewer, which has no
/// implementation in the widget-test harness). Covers the compact
/// responsive layout end to end: drawer nav, project detail, wizard steps,
/// and live price recalculation.
void main() {
  Future<void> bootAndSignIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 950);
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

  testWidgets('compact layout: drawer navigation works on a phone-sized screen', (tester) async {
    await bootAndSignIn(tester);

    // Phone layout uses an app bar + drawer instead of the rail.
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Projects')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bayati Villa'), findsOneWidget);
  });

  testWidgets('configurator wizard walks its steps and recalculates price live', (tester) async {
    await bootAndSignIn(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Projects')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Faris Apartment').first);
    await tester.pumpAndSettle();

    // Open the configurator for a new window on this project.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add window'));
    await tester.pumpAndSettle();

    // Step 1 — product type.
    expect(find.text('Product type'), findsOneWidget);
    expect(find.text('Window'), findsWidgets);

    // Step 2 — dimensions.
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Dimensions'), findsWidgets);

    // Step 3 — frame & sections.
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Frame & sections'), findsWidgets);

    // Step 4 — panel & glass.
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Panel & glass'), findsWidgets);

    // Step 5 — hardware, 6 — finish, 7 — accessories.
    for (final title in ['Hardware', 'Color & finish', 'Additional options']) {
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
    }
  });

  testWidgets('entered dimensions flow through to the summary price, BOM and cutting list', (tester) async {
    await bootAndSignIn(tester);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Projects')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Faris Apartment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add window'));
    await tester.pumpAndSettle();

    // Step 2 — set an explicit width, which must flow through the whole
    // pipeline (validation -> 2D -> price -> BOM -> cutting list).
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Finished size: 2000 mm'), findsOneWidget);

    // Walk the remaining steps through Preview to Summary & price.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Summary & price'), findsWidgets);
    expect(find.text('Unit price'), findsWidgets);

    // BOM + cutting list live further down the (lazily built) summary list.
    final summaryList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Bill of materials'), 250,
        scrollable: summaryList, maxScrolls: 40);
    expect(find.text('Bill of materials'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cutting list'), 250,
        scrollable: summaryList, maxScrolls: 40);
    expect(find.text('Cutting list'), findsOneWidget);
    expect(find.text('Outer Frame — Head'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/workspace_bars.dart';
import 'package:proframe/app/state/everything_shown.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The user's words: *it is so overwhelming, there are a ton of things. I
// know they are necessary, but the app is used by people who do not know
// much about technology; they want it clear and simple. Use a button to
// show all those icons.*
//
// So the workspace opens with the drawing, the three views and the few
// tools a door is drawn with, and **More** shows everything else. Nothing
// is taken away: every control is one tap off, and the choice is kept.

Future<ProviderContainer> open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  await toTheCategories(tester);
  await chooseDesign(tester, 'WINDOW');
  return container;
}

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it opens simple: a few tools, and More', (tester) async {
    final c = await open(tester);
    expect(c.read(everythingShownProvider), isFalse);
    expect(find.byKey(MoreButton.buttonKey), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // The tools a door is drawn with…
    for (final tool in ['Select', 'Freehand', 'Rectangle', 'Eraser']) {
      expect(find.text(tool), findsWidgets, reason: tool);
    }
    // …and not the rest.
    for (final tool in ['Polyline', 'Dimension', 'Note', 'Arrow']) {
      expect(find.text(tool), findsNothing, reason: tool);
    }
    expect(find.byTooltip('Redo'), findsNothing);
  });

  testWidgets('More shows every tool, and Less puts them away again', (
    tester,
  ) async {
    final c = await open(tester);
    await tester.tap(find.byKey(MoreButton.buttonKey));
    await tester.pumpAndSettle();
    expect(c.read(everythingShownProvider), isTrue);
    expect(find.text('Less'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Dimension'),
      find.byType(Scrollable).last,
      const Offset(-120, 0),
    );
    expect(find.text('Dimension'), findsWidgets);
    expect(find.byTooltip('Redo'), findsOneWidget);

    await tester.tap(find.byKey(MoreButton.buttonKey));
    await tester.pumpAndSettle();
    expect(c.read(everythingShownProvider), isFalse);
    expect(find.text('Dimension'), findsNothing);
  });

  testWidgets('the choice is kept on the device', (tester) async {
    final c = await open(tester);
    await tester.tap(find.byKey(MoreButton.buttonKey));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(EverythingShown.key), isTrue);
    expect(c.read(everythingShownProvider), isTrue);

    // And read back by the next start.
    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(everythingShownProvider);
    await tester.pumpAndSettle();
    expect(next.read(everythingShownProvider), isTrue);
  });

  testWidgets('a tool chosen under More stays on the bar under Less', (
    tester,
  ) async {
    final c = await open(tester);
    await tester.tap(find.byKey(MoreButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Polyline'),
      find.byType(Scrollable).last,
      const Offset(-120, 0),
    );
    await tester.tap(find.text('Polyline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MoreButton.buttonKey));
    await tester.pumpAndSettle();
    expect(c.read(everythingShownProvider), isFalse);
    expect(find.text('Polyline'), findsWidgets);
  });

  for (final size in const [Size(360, 740), Size(820, 1180), Size(1280, 820)]) {
    testWidgets('every view fits, simple and with More, at '
        '${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
      final c = await open(tester, size: size);
      await sheet.twoLeaves(c);
      await notNowToSizes(tester);
      for (final shown in [false, true]) {
        await c.read(everythingShownProvider.notifier).set(shown);
        for (final view in WorkspaceView.values) {
          c.read(workspaceProvider.notifier).showView(view);
          await tester.pumpAndSettle();
          final errors = overflowing(tester);
          expect(errors, isEmpty, reason: '$view $shown\n${errors.join('\n')}');
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/drawing_surface.dart';
import 'package:proframe/app/inspector/alert_layer.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// Two things the user asked for, held on the real app.
//
// **Pause to straighten.** Draw with the pen, rest it — still down — for a
// second, and the line just drawn is straightened where it lies. Keep
// moving, or lift sooner, and the ink is exactly what the hand put down.
//
// **Take it back.** An answer to "Door or Window?" given in a hurry is as
// easy to change as it was to give: a switch for every opening on the
// design's own panel, always one tap away.

Future<ProviderContainer> openTheApp(WidgetTester tester, String card) async {
  await tester.binding.setSurfaceSize(const Size(1280, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(card));
  await tester.pumpAndSettle();
  return container;
}

/// A hand's line across the sheet: level, with a tremor in it.
Future<TestGesture> drawAcross(WidgetTester tester) async {
  final sheet = tester.getRect(find.byType(DrawingSurface));
  final from = sheet.center - Offset(sheet.width * 0.3, 0);
  final gesture = await tester.startGesture(from);
  final random = math.Random(5);
  for (var i = 1; i <= 30; i++) {
    await gesture.moveTo(
      from +
          Offset(sheet.width * 0.6 * i / 30, (random.nextDouble() - 0.5) * 8),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// How far the worst sample of [stroke] lies off the line through its ends.
double wander(Stroke stroke) {
  final a = stroke.samples.first.at;
  final b = stroke.samples.last.at;
  final d = b - a;
  var worst = 0.0;
  for (final sample in stroke.samples) {
    worst = math.max(worst, (d.cross(sample.at - a) / d.length).abs());
  }
  return worst;
}

Stroke lastStroke(ProviderContainer c) =>
    c.read(workspaceProvider).design.sketch.strokes.last;

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at) => [
  Vec2(at.x - 55, at.y - 110),
  Vec2(at.x + 55, at.y),
  Vec2(at.x - 55, at.y + 110),
];

/// Two leaves side by side, neither said to be anything yet.
Future<WorkspaceController> twoLeaves(ProviderContainer c) async {
  final controller = c.read(workspaceProvider.notifier);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
          pen('k1', chevron(const Vec2(600, 1050))),
          pen('k2', chevron(const Vec2(1800, 1050))),
        ],
      ),
    ),
  );
  controller.readDrawing();
  return controller;
}

void main() {
  group('pause to straighten', () {
    testWidgets('resting the pen for a second straightens the line', (
      tester,
    ) async {
      final c = await openTheApp(tester, 'WINDOW');
      final gesture = await drawAcross(tester);

      // Rest, still down.
      await tester.pump(const Duration(milliseconds: 1100));
      await gesture.up();
      await tester.pump();

      final stroke = lastStroke(c);
      expect(
        wander(stroke),
        lessThan(0.01),
        reason: 'every sample on the one straight line',
      );
      expect(
        stroke.samples.length,
        greaterThan(2),
        reason: 'laid down as ink along its length, not as two dots',
      );
    });

    testWidgets('a hand that keeps moving keeps its own line', (tester) async {
      final c = await openTheApp(tester, 'WINDOW');
      final gesture = await drawAcross(tester);
      await gesture.up();
      await tester.pump();

      expect(
        wander(lastStroke(c)),
        greaterThan(1),
        reason: 'nothing straightened that was not asked for',
      );
    });

    testWidgets('a pause shorter than a second is only a pause', (
      tester,
    ) async {
      final c = await openTheApp(tester, 'WINDOW');
      final gesture = await drawAcross(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      expect(wander(lastStroke(c)), greaterThan(1));
    });

    testWidgets('once straight, the line swings to where the pen goes', (
      tester,
    ) async {
      final c = await openTheApp(tester, 'WINDOW');
      final gesture = await drawAcross(tester);
      await tester.pump(const Duration(milliseconds: 1100));
      final before = tester.getRect(find.byType(DrawingSurface));
      await gesture.moveBy(Offset(0, before.height * 0.25));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final stroke = lastStroke(c);
      expect(wander(stroke), lessThan(0.01), reason: 'still one straight line');
      final run = stroke.samples.last.at - stroke.samples.first.at;
      expect(
        run.y.abs(),
        greaterThan(run.x.abs() * 0.2),
        reason: 'its far end followed the pen down',
      );
    });
  });

  group('take it back', () {
    testWidgets('answering leaves nothing at the bottom of the screen', (
      tester,
    ) async {
      // The answer is shown where the opening is shown — on the design's
      // panel, with its switch — and not in a notice across the bottom of
      // the work, which the user asked to be rid of.
      final c = await openTheApp(tester, 'DOOR & WINDOW');
      await twoLeaves(c);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AlertPressable, 'Window'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final design = c.read(workspaceProvider).design;
      expect(design.kindOf(design.openingsInOrder.first), DesignKind.window);
    });

    testWidgets('every opening has its own switch on the design panel', (
      tester,
    ) async {
      final c = await openTheApp(tester, 'DOOR & WINDOW');
      final controller = await twoLeaves(c);
      final order = c.read(workspaceProvider).design.openingsInOrder;
      controller
        ..setOpeningKind(order[0].id, DesignKind.door)
        ..setOpeningKind(order[1].id, DesignKind.window)
        ..select(null);
      await tester.pumpAndSettle();

      expect(find.text('OPENING TYPES'), findsOneWidget);

      // The first leaf was said to be a door by mistake. One tap puts it
      // right, and the other leaf is left exactly as it was.
      final first = find.byKey(ValueKey('kind-switch-${order[0].id}'));
      await tester.ensureVisible(first);
      await tester.tap(
        find.descendant(of: first, matching: find.text('Window')),
      );
      await tester.pumpAndSettle();

      final design = c.read(workspaceProvider).design;
      expect(
        design.kindOf(design.openingById(order[0].id)!),
        DesignKind.window,
      );
      expect(
        design.kindOf(design.openingById(order[1].id)!),
        DesignKind.window,
      );
    });

    testWidgets('tapping the kind already chosen changes nothing', (
      tester,
    ) async {
      final c = await openTheApp(tester, 'DOOR & WINDOW');
      final controller = await twoLeaves(c);
      final order = c.read(workspaceProvider).design.openingsInOrder;
      controller
        ..setOpeningKind(order[0].id, DesignKind.door)
        ..setOpeningKind(order[1].id, DesignKind.window)
        ..select(null);
      await tester.pumpAndSettle();

      final first = find.byKey(ValueKey('kind-switch-${order[0].id}'));
      await tester.ensureVisible(first);
      await tester.tap(find.descendant(of: first, matching: find.text('Door')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final design = c.read(workspaceProvider).design;
      expect(design.kindOf(design.openingById(order[0].id)!), DesignKind.door);
    });
  });
}

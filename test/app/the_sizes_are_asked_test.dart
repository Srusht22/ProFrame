import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/inspector/measure_form.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// On the real app: a drawing is read, and the application asks for the real
// size of every part rather than writing the sketch's guess as a number.
//
// The user's words: *never write any number for width and height as a
// guess — ask the width and height of everything*, and *when we change the
// numbers and apply it, it doesn't change to the new one.*

Future<ProviderContainer> openTheApp(
  WidgetTester tester,
  String card, {
  Size size = const Size(1280, 820),
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
  await chooseDesign(tester, card);
  return container;
}

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey('measure-$key')),
  matching: find.byType(TextField),
);

/// Every size the form asks, given as it reads now — the way a user who
/// measured the drawing exactly as drawn would answer.
Future<void> giveEverySize(
  WidgetTester tester,
  ProviderContainer c, [
  Map<String, String> typed = const {},
]) async {
  final design = c.read(workspaceProvider).design;
  for (final m in Measurements.of(design)) {
    if (!m.asked) continue;
    await tester.enterText(field(m.key), typed[m.key] ?? '50');
  }
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a door is read, and its sizes are asked for — not whether it '
      'is a door', (tester) async {
    final c = await openTheApp(tester, 'DOOR');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();

    expect(
      find.text('Opening type'),
      findsNothing,
      reason: 'a door design is not asked what its leaves are',
    );
    expect(find.byType(MeasureForm), findsOneWidget);
    expect(find.text('Measurements'), findsOneWidget);
    // Every size field starts empty: nothing is offered as a guess.
    final design = c.read(workspaceProvider).design;
    for (final m in Measurements.of(design)) {
      if (!m.asked) continue;
      expect(
        tester.widget<TextField>(field(m.key)).controller!.text,
        isEmpty,
        reason: m.key,
      );
    }
    // And behind it, the drawing writes `?` where a number would be.
    final figures = CadDimensions.of(
      design,
      ViewTransform.fit(design.bounds!, const Size(800, 600)),
      const CadLayers(),
    );
    expect(figures, isNotEmpty);
    expect(figures.where((f) => f.known), isEmpty);
    expect(Measurements.overallOf(design), '? × ? cm');
  });

  testWidgets('the sizes given are the sizes built', (tester) async {
    final c = await openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();

    await giveEverySize(tester, c, {
      Measurements.profileKey: '6',
      Measurements.barsKey: '5',
      Measurements.widthKey: '240',
      Measurements.heightKey: '210',
    });
    expect(find.byType(MeasureForm), findsNothing);

    final design = c.read(workspaceProvider).design;
    expect(Measurements.complete(design), isTrue);
    expect(design.widthMm, closeTo(2400, 0.01));
    expect(design.heightMm, closeTo(2100, 0.01));
    expect(design.frame!.profileMm, closeTo(60, 0.01));
    // Every figure on the drawing is a number again, and none is `?`.
    final figures = CadDimensions.of(
      design,
      ViewTransform.fit(design.bounds!, const Size(800, 600)),
      const CadLayers(),
    );
    expect(figures, isNotEmpty);
    expect(figures.where((f) => !f.known), isEmpty);
    expect(Measurements.overallOf(design), '240 × 210 cm');
  });

  testWidgets('the width is the width and the height the height, and a '
      'reading keeps both', (tester) async {
    final c = await openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    await giveEverySize(tester, c, {
      Measurements.widthKey: '240',
      Measurements.heightKey: '210',
    });
    final controller = c.read(workspaceProvider.notifier);

    // The design's own panel: typing the width changes the width alone.
    controller.setRealWidth(3000);
    await tester.pumpAndSettle();
    var design = c.read(workspaceProvider).design;
    expect(design.widthMm, closeTo(3000, 0.01));
    expect(design.heightMm, closeTo(2100, 0.01));
    controller.setRealHeight(1800);
    await tester.pumpAndSettle();
    design = c.read(workspaceProvider).design;
    expect(design.widthMm, closeTo(3000, 0.01), reason: 'still as typed');
    expect(design.heightMm, closeTo(1800, 0.01));

    // And reading the sheet again puts none of it back.
    controller.readDrawing();
    await tester.pumpAndSettle();
    design = c.read(workspaceProvider).design;
    expect(design.widthMm, closeTo(3000, 0.01));
    expect(design.heightMm, closeTo(1800, 0.01));
    expect(Measurements.complete(design), isTrue);
    expect(
      find.byType(MeasureForm),
      findsNothing,
      reason: 'nothing new to measure, so nothing asked',
    );
  });

  testWidgets('Not now puts it away, and the bar at the top opens it again', (
    tester,
  ) async {
    final c = await openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    await notNowToSizes(tester);
    expect(find.byType(MeasureForm), findsNothing);
    expect(Measurements.complete(c.read(workspaceProvider).design), isFalse);

    await tester.tap(find.byTooltip('Sizes'));
    await tester.pumpAndSettle();
    expect(find.byType(MeasureForm), findsOneWidget);
  });

  testWidgets('in a Door & window design the leaves are asked first, then the '
      'sizes', (tester) async {
    final c = await openTheApp(tester, 'DOOR & WINDOW');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    expect(find.text('Opening type'), findsOneWidget);
    expect(find.byType(MeasureForm), findsNothing);

    for (final opening in c.read(workspaceProvider).design.openingsInOrder) {
      c
          .read(workspaceProvider.notifier)
          .answer(WorkspaceState.openingKindQuestion(opening.id), 'window');
    }
    await tester.pumpAndSettle();
    expect(find.byType(MeasureForm), findsOneWidget);
    final design = c.read(workspaceProvider).design;
    expect(design.kind, DesignKind.both);
  });

  testWidgets('a figure typed on the drawing and applied is the figure', (
    tester,
  ) async {
    // The user's screenshot: the overall height tapped on the technical
    // drawing, 250 typed, Apply pressed — and nothing changed. Apply sat
    // inside the drawing's own pointer handling, so pressing it was first a
    // press on the drawing away from any figure, which put the editor away
    // before the button was let go.
    final c = await openTheApp(tester, 'WINDOW');
    await sheet.twoLeaves(c);
    await tester.pumpAndSettle();
    await giveEverySize(tester, c, {
      Measurements.profileKey: '6',
      Measurements.barsKey: '5',
      Measurements.widthKey: '100',
      Measurements.heightKey: '200',
    });
    expect(c.read(workspaceProvider).design.widthMm, closeTo(1000, 0.01));

    Future<void> typeOver(DimensionOf of, String value) async {
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CadPainter,
      );
      final painter = tester.widget<CustomPaint>(paint).painter! as CadPainter;
      final figure = CadDimensions.of(
        painter.design,
        painter.view,
        painter.layers,
      ).firstWhere((f) => f.of == of);
      final origin = tester.getTopLeft(paint);
      await tester.tapAt(origin + figure.rect.center);
      await tester.pumpAndSettle();
      // The editor's own field: the one beside its Apply.
      final editor = find
          .ancestor(of: find.text('Apply'), matching: find.byType(Column))
          .first;
      await tester.enterText(
        find.descendant(of: editor, matching: find.byType(TextField)),
        value,
      );
      await tester.pump();
      // Held as a finger holds it, so the drawing sees the press a frame
      // before the button sees it let go.
      final press = await tester.startGesture(
        tester.getCenter(find.text('Apply')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await press.up();
      await tester.pumpAndSettle();
    }

    await typeOver(DimensionOf.overallWidth, '150');
    var design = c.read(workspaceProvider).design;
    expect(design.widthMm, closeTo(1500, 0.01));
    expect(design.heightMm, closeTo(2000, 0.01));

    await typeOver(DimensionOf.overallHeight, '250');
    design = c.read(workspaceProvider).design;
    expect(design.heightMm, closeTo(2500, 0.01), reason: 'applied');
    expect(design.widthMm, closeTo(1500, 0.01), reason: 'and only that');
    // Typing a size that was already asked for does not bring the whole
    // form back.
    expect(find.byType(MeasureForm), findsNothing);
  });

  group('it fits the screen it is on', () {
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 820),
    ]) {
      testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}', (
        tester,
      ) async {
        final c = await openTheApp(tester, 'WINDOW', size: size);
        await sheet.twoLeaves(c);
        await tester.pumpAndSettle();
        expect(find.byType(MeasureForm), findsOneWidget);
        final errors = overflowing(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
        expect(tester.takeException(), isNull);
        // Apply is always within reach.
        final apply = tester.getRect(find.text('Apply'));
        expect(apply.bottom, lessThanOrEqualTo(size.height));
        expect(apply.right, lessThanOrEqualTo(size.width));
      });
    }
  });
}

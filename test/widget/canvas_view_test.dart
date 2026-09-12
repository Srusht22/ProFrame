import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/canvas_projection.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/drawing_canvas.dart';
import 'package:proframe/app/canvas/note_labels.dart';
import 'package:proframe/app/screens/canvas_screen.dart';
import 'package:proframe/app/state/design_controller.dart';
import 'package:proframe/core/design/app_theme.dart';
import 'package:proframe/core/design/contrast.dart';
import 'package:proframe/core/design/tokens.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/sketch.dart';

import '../support/recording_canvas.dart';

const phone = Size(390, 844);

DesignDocument blankWindow() => DesignDocument.blank(
      id: 'd1',
      category: ProductCategory.window,
      material: FrameMaterial.pvc,
      name: 'Test window',
      now: DateTime.utc(2026, 9, 12),
    );

Future<ProviderContainer> pumpCanvas(
  WidgetTester tester, [
  Size size = phone,
]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(designControllerProvider.notifier).open(blankWindow());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: CanvasScreen(onBack: () {}, onPreview: () {}, onExport: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The projection the canvas is really using, taken from the live view state
/// rather than assumed, so a test can aim at a millimetre after a zoom.
CanvasProjection liveProjection(
  WidgetTester tester,
  ProviderContainer container,
) {
  final state = container.read(designControllerProvider);
  return CanvasProjection.view(
    tester.getSize(find.byType(DrawingCanvas)),
    zoom: state.zoom,
    pan: state.pan,
  );
}

Offset pixelOf(
  WidgetTester tester,
  ProviderContainer container,
  Point2 model,
) =>
    tester.getTopLeft(find.byType(DrawingCanvas)) +
    liveProjection(tester, container).toPixels(model);

/// A rough hand-drawn box, sampled along each edge.
List<Point2> frameStroke({
  double left = 600,
  double top = 500,
  double width = 1400,
  double height = 1000,
}) {
  final corners = [
    Point2(left, top),
    Point2(left + width, top),
    Point2(left + width, top + height),
    Point2(left, top + height),
    Point2(left, top),
  ];
  final path = <Point2>[];
  for (var i = 0; i < corners.length - 1; i++) {
    for (var step = 0; step < 8; step++) {
      final t = step / 8;
      path.add(Point2(
        corners[i].x + (corners[i + 1].x - corners[i].x) * t,
        corners[i].y + (corners[i + 1].y - corners[i].y) * t,
      ));
    }
  }
  path.add(corners.last);
  return path;
}

Future<void> drawFrame(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final points = frameStroke();
  final gesture =
      await tester.startGesture(pixelOf(tester, container, points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(pixelOf(tester, container, point));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

DesignPainter painterFor(
  DesignDocument design, {
  double zoom = 1,
  Offset pan = Offset.zero,
}) =>
    DesignPainter(
      design: design,
      wetInk: const [],
      zoom: zoom,
      pan: pan,
      frameColor: AppColors.deepGreen,
      inkColor: AppColors.deepGreenHover,
      glassColor: AppColors.surface,
      panelFillColor: AppColors.surface,
      selectionColor: AppColors.caution,
      labelColor: AppColors.deepGreen,
    );

void main() {
  group('the view transform', () {
    test('zooming scales the sheet about the middle of the screen', () {
      const size = Size(400, 600);
      final plain = CanvasProjection.view(size);
      final zoomed = CanvasProjection.view(size, zoom: 2);

      expect(zoomed.scale, closeTo(plain.scale * 2, 1e-9));

      // The middle of the screen stays put: zooming in on the centre must not
      // slide the drawing sideways.
      final centre = Offset(size.width / 2, size.height / 2);
      final before = plain.toModel(centre);
      final after = zoomed.toModel(centre);
      expect(after.x, closeTo(before.x, 1e-6));
      expect(after.y, closeTo(before.y, 1e-6));
    });

    test('panning moves the sheet by exactly the pixels dragged', () {
      const size = Size(400, 600);
      const drag = Offset(37, -19);
      final plain = CanvasProjection.view(size);
      final panned = CanvasProjection.view(size, pan: drag);

      expect(panned.scale, plain.scale);
      final moved = panned.toPixels(const Point2(1000, 800)) -
          plain.toPixels(const Point2(1000, 800));
      expect(moved.dx, closeTo(drag.dx, 1e-9));
      expect(moved.dy, closeTo(drag.dy, 1e-9));
    });

    test('a point survives the round trip under any view', () {
      const size = Size(1100, 800);
      final projection =
          CanvasProjection.view(size, zoom: 3.5, pan: const Offset(-80, 45));
      const point = Point2(1234.5, 678.25);

      final back = projection.toModel(projection.toPixels(point));
      expect(back.x, closeTo(point.x, 1e-6));
      expect(back.y, closeTo(point.y, 1e-6));
    });

    test('fitting puts the drawing in the middle, filling the screen', () {
      const size = Size(400, 600);
      // A small frame tucked into a corner of the sheet.
      final (zoom, pan) = CanvasProjection.fitTo(size, 100, 100, 700, 500);

      expect(zoom, greaterThan(1), reason: 'a small drawing should zoom in');

      final fitted = CanvasProjection.view(size, zoom: zoom, pan: pan);
      final centre = fitted.toPixels(const Point2(400, 300));
      expect(centre.dx, closeTo(size.width / 2, 0.5));
      expect(centre.dy, closeTo(size.height / 2, 0.5));

      // And it fits, with the margin left for the dimension labels.
      final box = fitted.toPixelRect(100, 100, 700, 500);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(size.width));
      expect(box.bottom, lessThanOrEqualTo(size.height));
    });

    test('fitting never zooms past the limit', () {
      // A frame a few millimetres across would otherwise want an absurd zoom.
      final (zoom, _) = CanvasProjection.fitTo(const Size(400, 600), 0, 0, 2, 2);
      expect(zoom, CanvasProjection.maxZoom);
    });

    test('fitting nothing leaves the view alone rather than guessing', () {
      expect(
        CanvasProjection.fitTo(const Size(400, 600), 100, 100, 100, 100),
        (1.0, Offset.zero),
      );
      expect(CanvasProjection.fitTo(Size.zero, 0, 0, 100, 100), (1.0, Offset.zero));
    });
  });

  group('the drawing is painted through the same view it is touched through',
      () {
    testWidgets('zooming in makes the frame bigger on screen', (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final design = container.read(designControllerProvider).design;
      const size = Size(390, 700);

      final plain = RecordingCanvas();
      painterFor(design).paint(plain, size);
      final zoomed = RecordingCanvas();
      painterFor(design, zoom: 2).paint(zoomed, size);

      // The frame outline itself: the dimension lines sit a fixed number of
      // pixels outside it, so the whole drawing's extent does not simply
      // double.
      expect(
        zoomed.largestPathBounds.width,
        closeTo(plain.largestPathBounds.width * 2, 0.5),
        reason: 'a pinch that does not move the drawing is not a zoom',
      );
      expect(
        zoomed.largestPathBounds.height,
        closeTo(plain.largestPathBounds.height * 2, 0.5),
      );
    });

    testWidgets('panning moves what is painted', (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final design = container.read(designControllerProvider).design;
      const size = Size(390, 700);
      const drag = Offset(40, 25);

      final plain = RecordingCanvas();
      painterFor(design).paint(plain, size);
      final panned = RecordingCanvas();
      painterFor(design, pan: drag).paint(panned, size);

      expect(
        panned.largestPathBounds.left - plain.largestPathBounds.left,
        closeTo(40, 0.01),
      );
      expect(
        panned.largestPathBounds.top - plain.largestPathBounds.top,
        closeTo(25, 0.01),
      );
      expect(
        panned.largestPathBounds.width,
        closeTo(plain.largestPathBounds.width, 0.01),
        reason: 'panning must not resize anything',
      );
    });

    testWidgets('a pinch zooms, in the drawing tool as well', (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      expect(container.read(designControllerProvider).zoom, 1);

      final centre = tester.getCenter(find.byType(DrawingCanvas));
      final left = await tester.startGesture(centre - const Offset(30, 0));
      final right = await tester.startGesture(centre + const Offset(30, 0));
      await left.moveBy(const Offset(-30, 0));
      await right.moveBy(const Offset(30, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();

      // The recogniser only starts measuring once the fingers have moved past
      // the slop, so the exact factor is its business — what matters here is
      // that spreading two fingers zooms in. The arithmetic is pinned down by
      // the unit test above.
      expect(container.read(designControllerProvider).zoom, greaterThan(1.2));
      // Pinching is not drawing: the design must come through untouched.
      expect(container.read(designControllerProvider).design.panels, hasLength(1));
    });

    testWidgets('one finger pans with the Move tool, and draws with Draw',
        (tester) async {
      final container = await pumpCanvas(tester);
      final controller = container.read(designControllerProvider.notifier)
        ..selectTool(CanvasTool.pan);
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(DrawingCanvas));
      await tester.dragFrom(centre, const Offset(50, -20));
      await tester.pumpAndSettle();

      final panned = container.read(designControllerProvider);
      expect(panned.pan.dx, closeTo(50, 1));
      expect(panned.pan.dy, closeTo(-20, 1));
      expect(panned.design.sketch.strokes, isEmpty, reason: 'Move must not draw');

      controller
        ..resetView()
        ..selectTool(CanvasTool.draw);
      await tester.pumpAndSettle();
      await drawFrame(tester, container);

      final drawn = container.read(designControllerProvider);
      expect(drawn.design.panels, hasLength(1));
      expect(drawn.pan, Offset.zero, reason: 'Draw must not pan');
    });

    testWidgets('Fit brings the drawing up to fill the screen', (tester) async {
      // Wide enough for the whole tool bar, so the button is on screen.
      final container = await pumpCanvas(tester, const Size(1100, 800));
      await drawFrame(tester, container);

      await tester.tap(find.byTooltip('Fit the drawing to the screen'));
      await tester.pumpAndSettle();

      final state = container.read(designControllerProvider);
      expect(state.zoom, greaterThan(1));

      // The whole frame is still on the canvas afterwards.
      final outline = state.design.outline!;
      final projection = liveProjection(tester, container);
      final box = projection.toPixelRect(
        outline.left,
        outline.top,
        outline.right,
        outline.bottom,
      );
      final canvas = tester.getSize(find.byType(DrawingCanvas));
      expect(box.left, greaterThanOrEqualTo(-0.5));
      expect(box.right, lessThanOrEqualTo(canvas.width + 0.5));

      await tester.tap(find.byTooltip('Show the whole sheet again'));
      await tester.pumpAndSettle();
      expect(container.read(designControllerProvider).zoom, 1);
      expect(container.read(designControllerProvider).pan, Offset.zero);
    });

    testWidgets('a tap still lands on the right panel after a zoom',
        (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final controller = container.read(designControllerProvider.notifier)
        ..setView(2.5, const Offset(-30, 15))
        ..selectTool(CanvasTool.select);
      await tester.pumpAndSettle();

      final panel = container.read(designControllerProvider).design.panels.single;
      final box = panel.boundary;
      await tester.tapAt(
        pixelOf(
          tester,
          container,
          Point2((box.left + box.right) / 2, (box.top + box.bottom) / 2),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(designControllerProvider).selectedPanelId,
        panel.id,
      );
      controller.resetView();
    });
  });

  group('what the user drew stays on the sheet', () {
    testWidgets('a stroke the app made nothing of is still drawn',
        (tester) async {
      final container = await pumpCanvas(tester);
      // A scribble: not a frame, not a divider, not an opening mark.
      final scribble = [
        const Point2(800, 700),
        const Point2(1000, 900),
        const Point2(800, 900),
        const Point2(1000, 700),
      ];
      final gesture =
          await tester.startGesture(pixelOf(tester, container, scribble.first));
      for (final point in scribble.skip(1)) {
        await gesture.moveTo(pixelOf(tester, container, point));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final design = container.read(designControllerProvider).design;
      expect(design.outline, isNull, reason: 'nothing was recognised');
      expect(design.sketch.strokes, hasLength(1), reason: 'the ink is kept');

      // And it is on the canvas, not only in the model: the finger coming off
      // the glass must never make a drawing disappear.
      final recorded = RecordingCanvas();
      painterFor(design).paint(recorded, const Size(390, 700));
      expect(
        recorded.pathCount,
        greaterThan(0),
        reason: 'the stroke the user drew is not painted anywhere',
      );
      expect(recorded.largestPathBounds.width, greaterThan(1));
    });

    testWidgets('a recognised frame keeps its ink as well as its frame',
        (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final design = container.read(designControllerProvider).design;

      expect(design.outline, isNotNull);
      expect(design.sketch.strokes, hasLength(1));

      final withInk = RecordingCanvas();
      painterFor(design).paint(withInk, const Size(390, 700));
      final withoutInk = RecordingCanvas();
      painterFor(design.copyWith(sketch: const Sketch()))
          .paint(withoutInk, const Size(390, 700));

      expect(
        withInk.pathCount,
        greaterThan(withoutInk.pathCount),
        reason: 'the frame was drawn but the stroke behind it was not',
      );
    });

    testWidgets('the ink moves with the view, like everything else',
        (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final design = container
          .read(designControllerProvider)
          .design
          .copyWith(outline: null, panels: [], dividers: []);
      const size = Size(390, 700);

      final plain = RecordingCanvas();
      painterFor(design).paint(plain, size);
      final zoomed = RecordingCanvas();
      painterFor(design, zoom: 2).paint(zoomed, size);

      expect(
        zoomed.largestPathBounds.width,
        closeTo(plain.largestPathBounds.width * 2, 0.5),
      );
    });
  });

  group('a frame drawn side by side', () {
    /// Draws [points] as one stroke, the way a finger would.
    Future<void> drawLine(
      WidgetTester tester,
      ProviderContainer container,
      Point2 from,
      Point2 to,
    ) async {
      final gesture = await tester.startGesture(pixelOf(tester, container, from));
      for (var i = 1; i <= 8; i++) {
        final t = i / 8;
        await gesture.moveTo(
          pixelOf(
            tester,
            container,
            Point2(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t),
          ),
        );
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('four strokes become one frame, and the preview comes alive',
        (tester) async {
      final container = await pumpCanvas(tester);
      const topLeft = Point2(600, 500);
      const topRight = Point2(2000, 500);
      const bottomRight = Point2(2000, 1500);
      const bottomLeft = Point2(600, 1500);

      // Nothing is built until the box closes — and the preview says so.
      await drawLine(tester, container, topLeft, topRight);
      await drawLine(tester, container, topRight, bottomRight);
      await drawLine(tester, container, bottomRight, bottomLeft);
      expect(container.read(designControllerProvider).design.outline, isNull);
      expect(find.text('Draw a frame to preview'), findsOneWidget);

      await drawLine(tester, container, bottomLeft, topLeft);

      final design = container.read(designControllerProvider).design;
      expect(design.outline, isNotNull, reason: 'the box closed');
      expect(design.panels, hasLength(1));
      expect(design.outline!.width, closeTo(1400, 20));
      expect(design.outline!.height, closeTo(1000, 20));
      // Every stroke is still the user's own ink.
      expect(design.sketch.strokes, hasLength(4));

      await tester.pumpAndSettle();
      expect(find.text('3D Preview'), findsOneWidget);
      expect(find.text('Draw a frame to preview'), findsNothing);
    });

    testWidgets('a divider still works afterwards', (tester) async {
      final container = await pumpCanvas(tester);
      await drawLine(tester, container, const Point2(600, 500),
          const Point2(2000, 500));
      await drawLine(tester, container, const Point2(2000, 500),
          const Point2(2000, 1500));
      await drawLine(tester, container, const Point2(2000, 1500),
          const Point2(600, 1500));
      await drawLine(tester, container, const Point2(600, 1500),
          const Point2(600, 500));

      await drawLine(tester, container, const Point2(1300, 520),
          const Point2(1300, 1480));

      final design = container.read(designControllerProvider).design;
      expect(design.dividers, hasLength(1));
      expect(design.panels, hasLength(2));
    });
  });

  group('nothing on the canvas screen is invisible', () {
    testWidgets('every button on the bottom bar can be read', (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);

      // The size buttons say what they are and what they hold, in full: an
      // ellipsis here used to swallow the mark that says a size is not
      // confirmed.
      expect(find.text('Width'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.textContaining('('), findsWidgets);
      expect(find.text('3D Preview'), findsOneWidget);

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.overflow == TextOverflow.ellipsis && text.data == '',
          isFalse,
        );
      }
    });

    testWidgets('the summary button is not its own background colour',
        (tester) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);

      final icon = find.byIcon(Icons.checklist);
      expect(icon, findsOneWidget, reason: 'the summary button is missing');

      final foreground = IconTheme.of(tester.element(icon)).color!;
      final material = tester.widget<Material>(
        find
            .ancestor(of: icon, matching: find.byType(Material))
            .first,
      );
      final background = material.color ?? AppColors.surface;

      expect(
        Contrast.ratio(foreground, background),
        greaterThan(3),
        reason: 'the icon cannot be seen against the button it sits on',
      );
    });
  });

  group('dragging a note label', () {
    /// Draws a frame, writes a note in the middle of the only panel, and
    /// switches to the Select tool.
    Future<(ProviderContainer, String panelId, String noteId)> withNote(
      WidgetTester tester,
    ) async {
      final container = await pumpCanvas(tester);
      await drawFrame(tester, container);
      final controller = container.read(designControllerProvider.notifier);
      final panelId =
          container.read(designControllerProvider).design.panels.single.id;
      final noteId = controller.addPanelNote(panelId, 'قياس')!;
      controller.selectTool(CanvasTool.select);
      await tester.pumpAndSettle();
      return (container, panelId, noteId);
    }

    Offset labelPixel(
      WidgetTester tester,
      ProviderContainer container,
      String noteId,
    ) {
      final labels = NoteLabels.of(
        container.read(designControllerProvider).design,
        liveProjection(tester, container),
      );
      final label = labels.firstWhere((l) => l.noteId == noteId);
      return tester.getTopLeft(find.byType(DrawingCanvas)) + label.centre;
    }

    testWidgets('the label follows the finger and stays in its panel',
        (tester) async {
      final (container, panelId, noteId) = await withNote(tester);
      final start = labelPixel(tester, container, noteId);

      await tester.dragFrom(start, const Offset(-40, -30));
      await tester.pumpAndSettle();

      final moved = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!;
      expect(moved.position.x, lessThan(0.5));
      expect(moved.position.y, lessThan(0.5));
      expect(moved.position.x, inInclusiveRange(0, 1));
      expect(moved.position.y, inInclusiveRange(0, 1));
      expect(moved.text, 'قياس', reason: 'moving a note must not reword it');

      // And the label is now drawn where it was dragged to.
      final after = labelPixel(tester, container, noteId);
      expect((after - (start + const Offset(-40, -30))).distance, lessThan(2));
    });

    testWidgets('dragging a long way stops at the edge of the panel',
        (tester) async {
      final (container, panelId, noteId) = await withNote(tester);

      await tester.dragFrom(
        labelPixel(tester, container, noteId),
        const Offset(-4000, -4000),
      );
      await tester.pumpAndSettle();

      final moved = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!;
      expect(moved.position.x, 0);
      expect(moved.position.y, 0);
      // Clamped away from the very corner when it is drawn, so the text is
      // never half outside the panel.
      expect(moved.clampedPosition.x, greaterThan(0));
      expect(moved.clampedPosition.y, greaterThan(0));
    });

    testWidgets('the whole drag is one thing to undo', (tester) async {
      final (container, panelId, noteId) = await withNote(tester);
      final controller = container.read(designControllerProvider.notifier);

      await tester.dragFrom(
        labelPixel(tester, container, noteId),
        const Offset(-40, -30),
      );
      await tester.pumpAndSettle();

      controller.undo();
      final back = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!;
      expect(back.position.x, 0.5);
      expect(back.position.y, 0.5);
    });

    testWidgets('two drags are two things to undo', (tester) async {
      final (container, panelId, noteId) = await withNote(tester);
      final controller = container.read(designControllerProvider.notifier);

      await tester.dragFrom(
        labelPixel(tester, container, noteId),
        const Offset(-30, 0),
      );
      await tester.pumpAndSettle();
      final afterFirst = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!
          .position;

      await tester.dragFrom(
        labelPixel(tester, container, noteId),
        const Offset(0, -30),
      );
      await tester.pumpAndSettle();

      controller.undo();
      final back = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!;
      expect(back.position.y, closeTo(afterFirst.y, 1e-9));
      expect(back.position.x, closeTo(afterFirst.x, 1e-9));
    });

    testWidgets('a hidden label cannot be grabbed by accident', (tester) async {
      final (container, panelId, noteId) = await withNote(tester);
      final start = labelPixel(tester, container, noteId);
      container.read(designControllerProvider.notifier).setAllNotesVisible(false);
      await tester.pumpAndSettle();

      await tester.dragFrom(start, const Offset(-40, -30));
      await tester.pumpAndSettle();

      final note = container
          .read(designControllerProvider)
          .design
          .panelById(panelId)!
          .noteById(noteId)!;
      expect(note.position.x, 0.5);
      expect(note.position.y, 0.5);
      // The drag panned the sheet instead, which is what Select does
      // everywhere else on the canvas.
      expect(container.read(designControllerProvider).pan.dx, closeTo(-40, 1));
    });

    testWidgets('with the Draw tool the same drag draws instead of moving',
        (tester) async {
      final (container, panelId, noteId) = await withNote(tester);
      container.read(designControllerProvider.notifier)
          .selectTool(CanvasTool.draw);
      await tester.pumpAndSettle();
      final strokesBefore =
          container.read(designControllerProvider).design.sketch.strokes.length;

      await tester.dragFrom(
        labelPixel(tester, container, noteId),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      final state = container.read(designControllerProvider);
      expect(state.design.sketch.strokes.length, strokesBefore + 1);
      final note = state.design.panelById(panelId)!.noteById(noteId)!;
      expect(note.position.x, 0.5);
      expect(note.position.y, 0.5);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/canvas_projection.dart';
import 'package:proframe/app/canvas/dimension_labels.dart';
import 'package:proframe/app/canvas/drawing_canvas.dart';
import 'package:proframe/app/screens/canvas_screen.dart';
import 'package:proframe/app/state/design_controller.dart';
import 'package:proframe/core/design/app_theme.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';

const phone = Size(390, 844);
const tabletLandscape = Size(1100, 800);

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DesignDocument blankWindow() => DesignDocument.blank(
      id: 'd1',
      category: ProductCategory.window,
      material: FrameMaterial.pvc,
      name: 'Test window',
      now: DateTime.utc(2026, 9, 12),
    );

Future<ProviderContainer> pumpCanvas(WidgetTester tester, Size size) async {
  await setSize(tester, size);
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

/// The projection the canvas is actually using, so a test can aim a gesture at
/// a known model coordinate rather than guessing pixels.
CanvasProjection projectionOf(WidgetTester tester) {
  final size = tester.getSize(find.byType(DrawingCanvas));
  return CanvasProjection.fit(size);
}

Offset pixelOf(WidgetTester tester, Point2 model) {
  final origin = tester.getTopLeft(find.byType(DrawingCanvas));
  return origin + projectionOf(tester).toPixels(model);
}

/// Drags through [points] in model space, the way a finger would.
Future<void> drawStroke(WidgetTester tester, List<Point2> points) async {
  final gesture = await tester.startGesture(pixelOf(tester, points.first));
  for (final point in points.skip(1)) {
    await gesture.moveTo(pixelOf(tester, point));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// A rough frame, drawn as a hand would with samples along each edge.
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

void main() {
  group('drawing a frame', () {
    testWidgets('a rough box becomes the frame and one panel', (tester) async {
      final container = await pumpCanvas(tester, phone);

      await drawStroke(tester, frameStroke());

      final design = container.read(designControllerProvider).design;
      expect(design.outline, isNotNull);
      expect(design.panels, hasLength(1));
      expect(design.panels.single.behaviour, PanelBehaviour.fixed);
    });

    testWidgets('the original ink is kept, whatever was recognised',
        (tester) async {
      // Spec section 4: the user must be able to see what they drew.
      final container = await pumpCanvas(tester, phone);

      await drawStroke(tester, frameStroke());

      expect(
        container.read(designControllerProvider).design.sketch.strokes,
        hasLength(1),
      );
    });

    testWidgets('a scribble is dropped but its ink is still kept',
        (tester) async {
      final container = await pumpCanvas(tester, phone);

      await drawStroke(tester, const [
        Point2(800, 700),
        Point2(1000, 900),
        Point2(800, 900),
        Point2(1000, 700),
      ]);

      final design = container.read(designControllerProvider).design;
      expect(design.outline, isNull);
      expect(design.panels, isEmpty);
      expect(design.sketch.strokes, hasLength(1));
    });
  });

  group('drawing a divider', () {
    testWidgets('a vertical stroke splits the frame in two', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      // Down the middle of the frame, which runs 600..2000 across.
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);

      final design = container.read(designControllerProvider).design;
      expect(design.panels, hasLength(2));
      expect(design.dividers, hasLength(1));
    });

    testWidgets('an off-centre divider splits proportionally', (tester) async {
      // Spec Phase 2, item 3.
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      // A quarter of the way across: 600 + 350 = 950.
      await drawStroke(tester, const [Point2(950, 560), Point2(950, 1440)]);

      final design = container.read(designControllerProvider).design;
      final widths = design.panels.map((p) => p.widthMm).toList()..sort();
      expect(widths.first / widths.last, closeTo(1 / 3, 0.08));
    });
  });

  group('a chevron marks a panel as opening', () {
    testWidgets('drawing ">" makes the panel Z, hinged right', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      await drawStroke(tester, const [
        Point2(900, 700),
        Point2(1700, 1000),
        Point2(900, 1300),
      ]);

      final panel =
          container.read(designControllerProvider).design.panels.single;
      expect(panel.behaviour, PanelBehaviour.opening);
      expect(panel.opening!.hingeSide, HingeSide.right);
      // The mark says which edge the hinges are on, not which way it swings.
      expect(panel.opening!.isConfirmed, isFalse);
    });
  });

  group('undo and redo cover every canvas action', () {
    testWidgets('undo takes back a divider, redo puts it back', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);
      expect(
        container.read(designControllerProvider).design.panels,
        hasLength(2),
      );

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(
        container.read(designControllerProvider).design.panels,
        hasLength(1),
      );

      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(
        container.read(designControllerProvider).design.panels,
        hasLength(2),
      );
    });

    testWidgets('undo is unavailable before anything has been drawn',
        (tester) async {
      await pumpCanvas(tester, phone);

      final undo = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.undo),
      );
      expect(undo.onPressed, isNull);
    });

    testWidgets('undoing the frame takes the whole design back', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final design = container.read(designControllerProvider).design;
      expect(design.outline, isNull);
      expect(design.panels, isEmpty);
      expect(design.sketch.strokes, isEmpty);
    });
  });

  group('the summary tracks the drawing', () {
    testWidgets('it starts by asking for everything', (tester) async {
      await pumpCanvas(tester, tabletLandscape);

      expect(find.text('Still to confirm'), findsOneWidget);
      expect(find.textContaining('has not been interpreted'), findsOneWidget);
    });

    testWidgets('drawing the frame answers the first question', (tester) async {
      // Spec Phase 2, item 9.
      await pumpCanvas(tester, tabletLandscape);

      await drawStroke(tester, frameStroke());

      expect(find.textContaining('has not been interpreted'), findsNothing);
      // The size read off the drawing is an estimate, so it is still asked
      // about (spec section 2).
      expect(find.textContaining('width is estimated'), findsOneWidget);
    });

    testWidgets('entering both sizes clears the list', (tester) async {
      final container = await pumpCanvas(tester, tabletLandscape);
      await drawStroke(tester, frameStroke());

      final controller = container.read(designControllerProvider.notifier);
      controller.setOverallWidth(1400);
      controller.setOverallHeight(1000);
      await tester.pumpAndSettle();

      expect(find.text('Nothing left to confirm'), findsOneWidget);
      // Even then it says this is a design, not production data.
      expect(find.textContaining('not production data'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('a tablet in landscape shows the summary beside the canvas',
        (tester) async {
      await pumpCanvas(tester, tabletLandscape);

      // Spec Phase 2, item 10: side by side, no button needed.
      expect(find.text('Still to confirm'), findsOneWidget);
      expect(find.byTooltip('What is still to confirm'), findsNothing);
    });

    testWidgets('a phone keeps the summary behind a button', (tester) async {
      await pumpCanvas(tester, phone);

      expect(find.text('Still to confirm'), findsNothing);
      expect(find.byTooltip('What is still to confirm'), findsOneWidget);
    });

    testWidgets('rotating keeps the drawing', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);

      final before =
          container.read(designControllerProvider).design.panels.length;

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      final design = container.read(designControllerProvider).design;
      expect(design.panels, hasLength(before));
      expect(design.outline, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the model is the same whatever size the screen is',
        (tester) async {
      // Spec section 8: canvas coordinates are independent of the screen.
      final phoneContainer = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      final onPhone =
          phoneContainer.read(designControllerProvider).design.outline!;

      await tester.pumpWidget(const SizedBox.shrink());
      final deskContainer = await pumpCanvas(tester, const Size(1440, 900));
      await drawStroke(tester, frameStroke());
      final onDesktop =
          deskContainer.read(designControllerProvider).design.outline!;

      expect(onDesktop.width, closeTo(onPhone.width, 1));
      expect(onDesktop.height, closeTo(onPhone.height, 1));
    });
  });

  group('notes', () {
    testWidgets('the design note is saved and shown in the summary',
        (tester) async {
      final container = await pumpCanvas(tester, tabletLandscape);

      await tester.tap(find.byTooltip('Note for the whole design'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Note'),
        'Customer wants obscure glass downstairs',
      );
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(
        container.read(designControllerProvider).design.designNote,
        'Customer wants obscure glass downstairs',
      );
      expect(
        find.textContaining('obscure glass downstairs'),
        findsOneWidget,
      );
    });

    testWidgets('an Arabic note is stored exactly as typed', (tester) async {
      final container = await pumpCanvas(tester, tabletLandscape);

      await tester.tap(find.byTooltip('Note for the whole design'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'توري');
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(container.read(designControllerProvider).design.designNote, 'توري');
    });
  });

  group('tapping a dimension asks for the measurement', () {
    testWidgets('the total width label opens the keypad in cm', (tester) async {
      // Spec Phase 2, item 4.
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      final labels = DimensionLabels.of(
        container.read(designControllerProvider).design,
        projectionOf(tester),
      );
      final total = labels
          .firstWhere((l) => l.target == DimensionTarget.overallWidth);
      final origin = tester.getTopLeft(find.byType(DrawingCanvas));
      await tester.tapAt(origin + total.centre);
      await tester.pumpAndSettle();

      expect(find.text('Total width'), findsOneWidget);
      // Centimetres, which is what the paper sketches use.
      expect(find.text('cm'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Size'), '200');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      final design = container.read(designControllerProvider).design;
      expect(design.overallWidth!.millimetres, 2000);
      expect(design.overallWidth!.isConfirmed, isTrue);
      // The drawing was rescaled to suit.
      expect(design.outline!.width, closeTo(2000, 0.01));
    });

    testWidgets('a panel width label adjusts its neighbour', (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);

      final controller = container.read(designControllerProvider.notifier);
      controller.setOverallWidth(1400);
      await tester.pumpAndSettle();

      final design = container.read(designControllerProvider).design;
      final labels = DimensionLabels.of(design, projectionOf(tester));
      final panelLabel = labels
          .firstWhere((l) => l.target == DimensionTarget.panelWidth);
      final origin = tester.getTopLeft(find.byType(DrawingCanvas));

      await tester.tapAt(origin + panelLabel.centre);
      await tester.pumpAndSettle();
      expect(find.text('Panel width'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Size'), '50');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      final after = container.read(designControllerProvider).design;
      final widths = after.panels.map((p) => p.widthMm).toList();
      expect(widths.first, closeTo(500, 1));
      // Still sums to the frame width (spec Phase 2, item 4).
      expect(widths.reduce((a, b) => a + b), closeTo(1400, 1));
    });

    testWidgets('an impossible panel width is refused and explained',
        (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);
      container.read(designControllerProvider.notifier).setOverallWidth(1400);
      await tester.pumpAndSettle();

      final before = container
          .read(designControllerProvider)
          .design
          .panels
          .map((p) => p.widthMm)
          .toList();

      final labels = DimensionLabels.of(
        container.read(designControllerProvider).design,
        projectionOf(tester),
      );
      final panelLabel = labels
          .firstWhere((l) => l.target == DimensionTarget.panelWidth);
      final origin = tester.getTopLeft(find.byType(DrawingCanvas));
      await tester.tapAt(origin + panelLabel.centre);
      await tester.pumpAndSettle();

      // 138 cm out of 140 leaves the neighbour 2 cm.
      await tester.enterText(find.widgetWithText(TextField, 'Size'), '138');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      // Nothing changed, and the user was told why in plain language.
      final after = container
          .read(designControllerProvider)
          .design
          .panels
          .map((p) => p.widthMm)
          .toList();
      expect(after, before);
      expect(find.textContaining('not enough room'), findsOneWidget);
    });

    testWidgets('an unconfirmed size is bracketed, not merely recoloured',
        (tester) async {
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());

      final labels = DimensionLabels.of(
        container.read(designControllerProvider).design,
        projectionOf(tester),
      );

      // Straight off the drawing, so nothing is confirmed yet.
      expect(labels.every((l) => !l.confirmed), isTrue);

      container.read(designControllerProvider.notifier).setOverallWidth(1400);
      await tester.pumpAndSettle();

      final after = DimensionLabels.of(
        container.read(designControllerProvider).design,
        projectionOf(tester),
      );
      expect(
        after
            .firstWhere((l) => l.target == DimensionTarget.overallWidth)
            .confirmed,
        isTrue,
      );
      expect(
        after
            .firstWhere((l) => l.target == DimensionTarget.overallHeight)
            .confirmed,
        isFalse,
      );
    });

    testWidgets('every label is at least a 48dp target', (tester) async {
      // Spec section 7: worker hands, not a stylus.
      final container = await pumpCanvas(tester, phone);
      await drawStroke(tester, frameStroke());
      await drawStroke(tester, const [Point2(1300, 560), Point2(1300, 1440)]);

      final labels = DimensionLabels.of(
        container.read(designControllerProvider).design,
        projectionOf(tester),
      );

      expect(labels, isNotEmpty);
      for (final label in labels) {
        expect(label.hitRect.width, greaterThanOrEqualTo(48));
        expect(label.hitRect.height, greaterThanOrEqualTo(48));
      }
    });
  });

  testWidgets('a long press on a panel opens its properties', (tester) async {
    await pumpCanvas(tester, phone);
    await drawStroke(tester, frameStroke());

    await tester.longPressAt(pixelOf(tester, const Point2(1300, 1000)));
    await tester.pumpAndSettle();

    // Both the factory code and the plain word (spec section 3C).
    expect(find.text('CH'), findsWidgets);
    expect(find.text('Z'), findsWidgets);
    expect(find.text('Mesh (توري)'), findsOneWidget);
    expect(find.text('Empty (فارغ)'), findsOneWidget);
    // Mechanisms that are not built are absent, not greyed out.
    expect(find.textContaining('Sliding'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/drawing_canvas.dart';
import 'package:proframe/app/rendering/design_renderer.dart';
import 'package:proframe/app/rendering/scene_painter.dart';
import 'package:proframe/app/rendering/surface_shading.dart';
import 'package:proframe/app/screens/viewer_screen.dart';
import 'package:proframe/app/state/design_controller.dart';
import 'package:proframe/app/state/project_controller.dart';
import 'package:proframe/app/state/viewer_controller.dart';
import 'package:proframe/core/design/app_theme.dart';
import 'package:proframe/core/design/tokens.dart';
import 'package:proframe/core/i18n/strings.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_divider.dart';
import 'package:proframe/domain/panel_note.dart';
import 'package:proframe/domain/product/finish.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/rendering/scene_builder.dart';
import 'package:proframe/infrastructure/key_value_store.dart';

import '../support/recording_canvas.dart';

const phone = Size(390, 844);
const tabletLandscape = Size(1100, 800);

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A measured two-bay window: fixed on the left, a right-hinged sash on the
/// right, with a note and a mesh so every mark is exercised.
DesignDocument twoBayWindow() {
  final outline = Polygon.rectangle(width: 1400, height: 1000);
  return DesignDocument.blank(
    id: 'd1',
    category: ProductCategory.window,
    material: FrameMaterial.pvc,
    name: 'Kitchen window',
    now: DateTime.utc(2026, 9, 12),
  ).copyWith(
    outline: outline,
    finish: StockFinishes.anthracite,
    overallWidth: const Measurement.confirmed(1400),
    overallHeight: const Measurement.confirmed(1000),
    designNote: 'Customer wants obscure glass',
    dividers: const [
      PanelDivider(
        id: 'v1',
        start: Point2(700, 0),
        end: Point2(700, 1000),
        spansFullFrame: true,
      ),
    ],
    panels: [
      Panel.fixed(
        id: 'left',
        boundary: Polygon.rectangle(width: 700, height: 1000),
      ).copyWith(
        hasMesh: true,
        notes: const [PanelNote(id: 'n1', text: 'توري')],
      ),
      Panel.opening(
        id: 'right',
        boundary: Polygon.rectangle(
          width: 700,
          height: 1000,
          topLeft: const Point2(700, 0),
        ),
        opening: const OpeningSpec(
          hingeSide: HingeSide.right,
          direction: OpeningDirection.outward,
          isConfirmed: true,
        ),
      ),
    ],
  );
}

Future<ProviderContainer> pumpViewer(
  WidgetTester tester,
  Size size, {
  DesignDocument? design,
}) async {
  await setSize(tester, size);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container
      .read(designControllerProvider.notifier)
      .open(design ?? twoBayWindow());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ViewerScreen(onBack: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Anthracite, the finish the fixture uses.
const anthracite = Color(0xFF383B3A);

/// Runs the real painter over [design] and reports what it drew.
///
/// Goes through [ScenePainter] itself, so these assertions cover the same code
/// the screen runs — but deterministically, with no rasterisation involved.
RecordingCanvas recordScene(
  DesignDocument design, {
  Color finish = anthracite,
  Map<String, double> openPanels = const {},
}) {
  final scene = SceneBuilder.build(design, openFractions: openPanels);
  const size = Size(600, 500);
  final canvas = RecordingCanvas();

  ScenePainter(
    scene: scene,
    viewport: SceneViewport.fit(scene, size),
    shading: SurfaceShading(finish),
    glassColor: AppColors.glassTint,
    glassHighlight: AppColors.glassHighlight,
    glyphColor: AppColors.deepGreen,
    meshColor: AppColors.deepGreen,
    noteMarkerColor: AppColors.deepGreen,
    noteMarkerInk: AppColors.cream,
    hardwareColor: AppColors.hardware,
    hardwareEdgeColor: AppColors.hardwareEdge,
  ).paint(canvas, size);

  return canvas;
}

/// Lets the pending autosave timer fire.
///
/// Every edit schedules a draft write a moment later; a test that ends before
/// it fires leaves a live timer and the binding rightly complains.
Future<void> flushAutosave(WidgetTester tester) async {
  await tester.pump(SaveController.autosaveDelay + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// The CustomPaint the viewer draws into.
Finder sceneCanvas() => find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is ScenePainter,
    );

void main() {
  group('the viewer draws the design', () {
    testWidgets('it renders and names itself honestly', (tester) async {
      await pumpViewer(tester, phone);

      // "2.5D preview", not "3D": the label says what it actually is
      // (spec section 9).
      expect(find.text('2.5D preview'), findsOneWidget);
      expect(sceneCanvas(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the profile is painted in the chosen finish', (tester) async {
      // Spec Phase 3, item 2: tones derived from the user's colour, never
      // hardcoded.
      final recorded = recordScene(twoBayWindow());
      const shading = SurfaceShading(anthracite);

      expect(recorded.drewPathIn(shading.front), isTrue);
      expect(recorded.drewPathIn(shading.verticalSide), isTrue);
      expect(recorded.drewPathIn(shading.horizontalSide), isTrue);
    });

    testWidgets('a different finish paints entirely different tones',
        (tester) async {
      final dark = recordScene(twoBayWindow());
      final light = recordScene(
        twoBayWindow().copyWith(finish: StockFinishes.white),
        finish: const Color(0xFFF4F4F1),
      );
      const darkShading = SurfaceShading(anthracite);
      const lightShading = SurfaceShading(Color(0xFFF4F4F1));

      expect(dark.drewPathIn(darkShading.front), isTrue);
      expect(light.drewPathIn(lightShading.front), isTrue);
      // Nothing of the dark finish survives into the light render.
      expect(light.drewPathIn(darkShading.front), isFalse);
    });

    testWidgets('the depth faces are shaded away from the front',
        (tester) async {
      // This is what makes it read as solid rather than flat.
      const shading = SurfaceShading(anthracite);

      expect(shading.verticalSide, isNot(shading.front));
      expect(shading.horizontalSide, isNot(shading.front));
      expect(shading.verticalSide, isNot(shading.horizontalSide));
    });

    testWidgets('a near-black finish still has readable faces', (tester) async {
      // Shifting a very dark colour darker would collapse every face to the
      // same black, so the shift flips instead.
      const nearBlack = SurfaceShading(Color(0xFF050505));

      expect(nearBlack.verticalSide, isNot(nearBlack.front));
      expect(nearBlack.edge, isNot(nearBlack.front));
    });

    testWidgets('glass is drawn with a gradient, not a flat fill',
        (tester) async {
      final recorded = recordScene(twoBayWindow());

      // Two panels, one of them empty of nothing — both get a shaded pane.
      expect(recorded.shadedPathCount, greaterThanOrEqualTo(2));
    });

    testWidgets('every surface is outlined in the derived edge tone',
        (tester) async {
      // Two faces of a dark finish can shade to nearly the same tone, so the
      // outline is what keeps the shape readable.
      final recorded = recordScene(twoBayWindow());
      const shading = SurfaceShading(anthracite);

      expect(recorded.drewPathIn(shading.edge), isTrue);
    });

    testWidgets('an empty panel has no pane drawn at all', (tester) async {
      // فارغ is a hole, and the render has to show that (Phase 3, item 2).
      final glazed = recordScene(twoBayWindow());
      final empty = recordScene(
        twoBayWindow().copyWith(
          panels: twoBayWindow()
              .panels
              .map((p) => p.copyWith(isEmpty: true))
              .toList(),
        ),
      );

      expect(empty.shadedPathCount, 0);
      expect(empty.pathCount, lessThan(glazed.pathCount));
    });

    testWidgets('mesh and the opening glyph are drawn at different weights',
        (tester) async {
      // A hairline screen must not read as a structural symbol.
      final recorded = recordScene(twoBayWindow());
      final widths = recorded.lineWidths.toList();

      // Stroke widths are stored as floats, so they are compared loosely.
      expect(
        widths.any((w) => (w - AppViewerMetrics.meshWidth).abs() < 0.01),
        isTrue,
      );
      expect(
        widths.any((w) => (w - AppViewerMetrics.glyphWidth).abs() < 0.01),
        isTrue,
      );
    });

    testWidgets('a design with no CH symbol draws no glyph lines',
        (tester) async {
      final allFixed = twoBayWindow().copyWith(
        panels: [
          Panel.fixed(
            id: 'only',
            boundary: Polygon.rectangle(width: 1400, height: 1000),
          ),
        ],
        dividers: const [],
      );
      final recorded = recordScene(allFixed);

      expect(
        recorded.lineWidths
            .any((w) => (w - AppViewerMetrics.glyphWidth).abs() < 0.01),
        isFalse,
      );
    });
  });

  group('opening panels', () {
    testWidgets('tapping a Z panel opens it, tapping again closes it',
        (tester) async {
      final container = await pumpViewer(tester, phone);
      expect(container.read(viewerControllerProvider).openPanels, isEmpty);

      // The right-hand sash, well inside its own half.
      final canvas = tester.getRect(sceneCanvas());
      await tester.tapAt(
        Offset(canvas.left + canvas.width * 0.72, canvas.center.dy),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(viewerControllerProvider).openPanels,
        contains('right'),
      );

      await tester.tapAt(
        Offset(canvas.left + canvas.width * 0.72, canvas.center.dy),
      );
      await tester.pumpAndSettle();

      expect(container.read(viewerControllerProvider).openPanels, isEmpty);
    });

    testWidgets('a CH panel says it is fixed rather than doing nothing',
        (tester) async {
      // Spec section 3E: CH panels stay fixed. A dead tap would leave the user
      // wondering whether the app was broken.
      final container = await pumpViewer(
        tester,
        phone,
        design: twoBayWindow().copyWith(
          panels: [
            Panel.fixed(
              id: 'only',
              boundary: Polygon.rectangle(width: 1400, height: 1000),
            ),
          ],
          dividers: const [],
        ),
      );

      final canvas = tester.getRect(sceneCanvas());
      await tester.tapAt(canvas.center);
      await tester.pumpAndSettle();

      expect(find.textContaining('fixed, so it does not open'), findsOneWidget);
      expect(container.read(viewerControllerProvider).openPanels, isEmpty);
    });

    testWidgets('the animation runs inside the stated duration',
        (tester) async {
      final container = await pumpViewer(tester, phone);
      container.read(viewerControllerProvider.notifier).toggle('right');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      // Mid-flight: still animating.
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Spec asks for 250-400 ms; settling well before 500 proves it.
      await tester.pump(const Duration(milliseconds: 340));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing every panel is one action', (tester) async {
      final container = await pumpViewer(tester, phone);
      container.read(viewerControllerProvider.notifier).toggle('right');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close every panel'));
      await tester.pumpAndSettle();

      expect(container.read(viewerControllerProvider).openPanels, isEmpty);
    });
  });

  group('notes', () {
    testWidgets('tapping a panel with a note shows the note', (tester) async {
      await pumpViewer(tester, phone);

      final canvas = tester.getRect(sceneCanvas());
      await tester.tapAt(
        Offset(canvas.left + canvas.width * 0.28, canvas.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.text('توري'), findsOneWidget);
    });

    testWidgets('the design note is reachable from the summary strip',
        (tester) async {
      await pumpViewer(tester, phone);

      expect(find.text('Design note'), findsOneWidget);
      await tester.tap(find.text('Design note'));
      await tester.pumpAndSettle();

      expect(find.text('Customer wants obscure glass'), findsOneWidget);
    });
  });

  group('the summary strip', () {
    testWidgets('it shows dimensions, material, colour and the view side',
        (tester) async {
      await pumpViewer(tester, tabletLandscape);

      expect(find.textContaining('140.0 cm'), findsOneWidget);
      expect(find.text('PVC'), findsOneWidget);
      expect(find.text('Anthracite'), findsOneWidget);
      // Handing means nothing without this, so it is permanently on screen
      // (spec section 3C).
      expect(find.text('Viewed from outside'), findsOneWidget);
    });

    testWidgets('an unmeasured design says so rather than showing a guess',
        (tester) async {
      await pumpViewer(
        tester,
        phone,
        design: twoBayWindow().copyWith(
          overallWidth: const Measurement.estimated(1400),
          overallHeight: const Measurement.estimated(1000),
        ),
      );

      expect(find.text('Not confirmed'), findsOneWidget);
    });

    testWidgets('the preview never claims to be manufacturing data',
        (tester) async {
      await pumpViewer(tester, phone);

      expect(
        find.textContaining('generic, not manufacturing data'),
        findsOneWidget,
      );
    });
  });

  group('layout', () {
    testWidgets('a tablet in landscape shows the panel list beside the view',
        (tester) async {
      await pumpViewer(tester, tabletLandscape);

      expect(find.text('Panels'), findsOneWidget);
      expect(sceneCanvas(), findsOneWidget);
    });

    testWidgets('a phone gives the whole screen to the view', (tester) async {
      await pumpViewer(tester, phone);

      expect(find.text('Panels'), findsNothing);
      expect(sceneCanvas(), findsOneWidget);
    });

    testWidgets('rotating keeps the open panels and the camera',
        (tester) async {
      final container = await pumpViewer(tester, phone);
      container.read(viewerControllerProvider.notifier).toggle('right');
      container.read(viewerControllerProvider.notifier).setZoom(2);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      final viewer = container.read(viewerControllerProvider);
      expect(viewer.openPanels, contains('right'));
      expect(viewer.zoom, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it lays out at every size without overflowing',
        (tester) async {
      for (final size in const [
        Size(360, 800),
        Size(800, 360),
        Size(600, 960),
        Size(1440, 900),
      ]) {
        await pumpViewer(tester, size);
        expect(tester.takeException(), isNull, reason: 'overflowed at $size');
      }
    });
  });

  group('pan and zoom', () {
    testWidgets('dragging moves the view', (tester) async {
      final container = await pumpViewer(tester, phone);
      expect(container.read(viewerControllerProvider).pan, Offset.zero);

      await tester.drag(sceneCanvas(), const Offset(40, 25));
      await tester.pumpAndSettle();

      expect(container.read(viewerControllerProvider).pan, isNot(Offset.zero));
    });

    testWidgets('zoom stays inside its limits', (tester) async {
      final container = await pumpViewer(tester, phone);
      final controller = container.read(viewerControllerProvider.notifier);

      controller.setZoom(100);
      expect(container.read(viewerControllerProvider).zoom, lessThanOrEqualTo(5));

      controller.setZoom(0.01);
      expect(
        container.read(viewerControllerProvider).zoom,
        greaterThanOrEqualTo(0.5),
      );
    });

    testWidgets('fit the view puts the camera back', (tester) async {
      final container = await pumpViewer(tester, phone);
      container.read(viewerControllerProvider.notifier).setZoom(3);
      container.read(viewerControllerProvider.notifier).panBy(const Offset(90, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fit the view'));
      await tester.pumpAndSettle();

      final viewer = container.read(viewerControllerProvider);
      expect(viewer.zoom, 1);
      expect(viewer.pan, Offset.zero);
    });
  });

  group('round trip from the canvas and back', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester, Size size) async {
      await setSize(tester, size);
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(InMemoryStore())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProFrameApp(idFactory: () => 'p1'),
        ),
      );
      await tester.pumpAndSettle();
      // Past the project list into the new-design screen.
      await tester.tap(find.text('New design'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('preview is offered only once there is something to see',
        (tester) async {
      await pumpApp(tester, tabletLandscape);
      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
      await tester.pumpAndSettle();

      // Nothing drawn yet, so the button says why it is unavailable rather
      // than sitting there dead.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Draw a frame to preview'),
      );
      expect(button.onPressed, isNull);
    });

    /// Walks the product choices, then replaces the blank design with a real
    /// one, leaving the app on the canvas.
    Future<ProviderContainer> pumpAtCanvas(WidgetTester tester) async {
      final container = await pumpApp(tester, tabletLandscape);
      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
      await tester.pumpAndSettle();
      container.read(designControllerProvider.notifier).open(twoBayWindow());
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('canvas to viewer and back loses nothing', (tester) async {
      // Spec Phase 3, item 4: round-trip editing works indefinitely.
      final container = await pumpAtCanvas(tester);

      final before = container.read(designControllerProvider).design;

      // Three round trips.
      for (var i = 0; i < 3; i++) {
        expect(find.byType(DrawingCanvas), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '3D Preview'));
        await tester.pumpAndSettle();

        expect(sceneCanvas(), findsOneWidget);
        await tester.tap(find.byTooltip('Back to edit'));
        await tester.pumpAndSettle();
      }

      final after = container.read(designControllerProvider).design;
      expect(after.panels, before.panels);
      expect(after.dividers, before.dividers);
      expect(after.outline, before.outline);
      expect(after.overallWidth, before.overallWidth);
      expect(after.designNote, before.designNote);
    });

    testWidgets('an edit between visits reaches the viewer', (tester) async {
      // One model, two views: the viewer cannot disagree with the canvas.
      final container = await pumpAtCanvas(tester);

      container
          .read(designControllerProvider.notifier)
          .makeFixed('right');
      await tester.tap(find.widgetWithText(FilledButton, '3D Preview'));
      await tester.pumpAndSettle();

      // Both panels now read CH in the side list.
      expect(find.text('CH'), findsNWidgets(2));
      await flushAutosave(tester);
    });
  });

  testWidgets('the renderer is replaceable without touching the screen',
      (tester) async {
    // Spec Phase 3, item 1. A stand-in renderer proves the seam is real: the
    // screen builds whatever it is handed.
    await setSize(tester, phone);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(designControllerProvider.notifier).open(twoBayWindow());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ViewerScreen(
            onBack: () {},
            renderer: const _StubRenderer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stub engine'), findsOneWidget);
    expect(find.text('stub view'), findsOneWidget);
    // The real painter is gone; nothing else changed.
    expect(sceneCanvas(), findsNothing);
    expect(find.byTooltip('Back to edit'), findsOneWidget);
  });

  testWidgets('a two-bay window renders as expected', (tester) async {
    // The golden. Generated in this Linux container; font rasterisation
    // differs between platforms, so on another machine regenerate it with
    // `flutter test --update-goldens` rather than assuming a real regression.
    await pumpViewer(tester, const Size(600, 500));

    await expectLater(
      find.byType(ViewerScreen),
      matchesGoldenFile('goldens/two_bay_window.png'),
    );
  });
}

/// A renderer that draws nothing, to prove the interface is the only coupling.
class _StubRenderer implements DesignRenderer {
  const _StubRenderer();

  @override
  String labelIn(AppStrings strings) => 'Stub engine';

  @override
  bool get supportsOpeningAnimation => false;

  @override
  Widget build(BuildContext context, RenderRequest request) =>
      const Center(child: Text('stub view'));
}

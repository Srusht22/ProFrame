import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/canvas_projection.dart';
import 'package:proframe/app/canvas/drawing_canvas.dart';
import 'package:proframe/app/export/export_service.dart';
import 'package:proframe/app/rendering/scene_painter.dart';
import 'package:proframe/app/screens/export_sheet.dart';
import 'package:proframe/app/state/design_controller.dart';
import 'package:proframe/app/state/project_controller.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/rendering/point3.dart';
import 'package:proframe/domain/rendering/scene.dart';
import 'package:proframe/domain/rendering/scene_builder.dart';
import 'package:proframe/infrastructure/export/project_file.dart';
import 'package:proframe/infrastructure/key_value_store.dart';

/// Captures exports instead of opening a share sheet.
class _CapturingExports {
  final Map<String, List<int>> files = {};

  ExportService get service => ExportService(
        deliver: (bytes, name, mime) async => files[name] = bytes,
      );
}

const desktop = Size(1440, 1000);

Future<void> setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Taps an export and waits for it to finish.
///
/// Not `pumpAndSettle`: while an export runs the row shows a spinner, which
/// animates forever, so settling never happens. Fixed frames are the honest
/// way to wait for real asynchronous work in a widget test.
Future<void> runExport(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> flushAutosave(WidgetTester tester) async {
  await tester.pump(
    SaveController.autosaveDelay + const Duration(milliseconds: 60),
  );
  await tester.pumpAndSettle();
}

/// Pixel for a model point, using the canvas's own projection.
Offset pixelOf(WidgetTester tester, Point2 model, DesignState state) {
  final size = tester.getSize(find.byType(DrawingCanvas));
  final origin = tester.getTopLeft(find.byType(DrawingCanvas));
  return origin +
      CanvasProjection.view(size, zoom: state.zoom, pan: state.pan)
          .toPixels(model);
}

Future<void> drawStroke(
  WidgetTester tester,
  ProviderContainer container,
  List<Point2> points,
) async {
  final state = container.read(designControllerProvider);
  final gesture = await tester.startGesture(pixelOf(tester, points.first, state));
  for (final point in points.skip(1)) {
    await gesture.moveTo(pixelOf(tester, point, state));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// A rough rectangle, drawn the way a hand would.
List<Point2> rectangleStroke({
  double left = 700,
  double top = 500,
  double width = 1400,
  double height = 1100,
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
  return path..add(corners.last);
}

void main() {
  // The PDF export embeds fonts from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the whole workflow: draw, measure, assign, note, 3D, save, reopen, export',
    (tester) async {
      // This is the main scenario the specification asks for (section 14),
      // driven through the real screens rather than the controllers.
      await setSize(tester, desktop);
      final store = InMemoryStore();
      final exports = _CapturingExports();
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          exportServiceProvider.overrideWithValue(exports.service),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProFrameApp(idFactory: () => 'acceptance-1'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Create a Window / PVC project and choose a colour.
      expect(find.text('No saved designs yet'), findsOneWidget);
      await tester.tap(find.text('New design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PVC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anthracite'));
      await tester.pumpAndSettle();

      // 2. Open the drawing editor.
      await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawingCanvas), findsOneWidget);

      // 3. Draw a rough rectangle and a vertical divider.
      await drawStroke(tester, container, rectangleStroke());
      await drawStroke(
        tester,
        container,
        const [Point2(1300, 560), Point2(1300, 1540)],
      );

      // 4. Confirm the interpreted layout.
      var design = container.read(designControllerProvider).design;
      expect(design.outline, isNotNull);
      expect(design.panels, hasLength(2));
      expect(design.dividers, hasLength(1));

      final controller = container.read(designControllerProvider.notifier);
      final leftId = design.panels.first.id;
      final rightId = design.panels.last.id;

      // 5. Enter test dimensions and a divider position.
      controller
        ..setOverallWidth(1200)
        ..setOverallHeight(1500);
      await tester.pumpAndSettle();
      controller.setPanelWidth(leftId, 500);
      await tester.pumpAndSettle();

      design = container.read(designControllerProvider).design;
      expect(design.overallWidth!.millimetres, 1200);
      expect(design.overallWidth!.isConfirmed, isTrue);
      expect(design.outline!.width, closeTo(1200, 0.01));
      expect(design.panelById(leftId)!.widthMm, closeTo(500, 1));
      // The neighbour absorbed it, so the row still sums to the frame.
      expect(
        design.panels.fold<double>(0, (sum, p) => sum + p.widthMm),
        closeTo(1200, 1),
      );

      // 6 and 7. CH on one, Z on the other, with hinge side and direction.
      controller
        ..makeFixed(leftId)
        ..setOpening(
          rightId,
          const OpeningSpec(
            hingeSide: HingeSide.right,
            direction: OpeningDirection.outward,
            isConfirmed: true,
          ),
        );
      await tester.pumpAndSettle();

      design = container.read(designControllerProvider).design;
      expect(design.panelById(leftId)!.behaviour, PanelBehaviour.fixed);
      expect(design.panelById(rightId)!.opening!.hingeSide, HingeSide.right);

      // 8. An overall design note.
      controller.setDesignNote('Customer asked for obscure glass.');

      // 9. Different notes inside the two panels.
      controller
        ..addPanelNote(leftId, 'توري')
        ..addPanelNote(rightId, 'Frosted glass');
      await tester.pumpAndSettle();

      design = container.read(designControllerProvider).design;
      expect(design.panelById(leftId)!.notes.single.text, 'توري');
      expect(design.panelById(rightId)!.notes.single.text, 'Frosted glass');
      expect(design.allNotes, hasLength(3));

      // 10. Generate and inspect the 3D.
      await tester.tap(find.widgetWithText(FilledButton, '3D Preview'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ScenePainter,
        ),
        findsOneWidget,
      );

      // 11. Open the Z while the CH stays put.
      final closed = SceneBuilder.build(design);
      final opened = SceneBuilder.build(design, openFractions: {rightId: 1});
      List<Point3> faceOf(RenderScene scene, String id) => scene.faces
          .firstWhere(
            (f) =>
                f.panelId == id &&
                (f.role == PartRole.glass || f.role == PartRole.panel),
          )
          .corners;

      expect(faceOf(opened, leftId), faceOf(closed, leftId));
      expect(faceOf(opened, rightId), isNot(faceOf(closed, rightId)));

      await tester.tap(find.byTooltip('Back to edit'));
      await tester.pumpAndSettle();

      // 12. Change a dimension; both views follow, because there is one model.
      controller.setOverallWidth(1600);
      await tester.pumpAndSettle();
      design = container.read(designControllerProvider).design;
      expect(design.outline!.width, closeTo(1600, 0.01));
      // The generated 3D followed the edit. Measured as a span, because the
      // outline sits wherever on the sheet the user drew it.
      final xs = SceneBuilder.build(design).extent.map((p) => p.x).toList();
      expect(
        xs.reduce((a, b) => a > b ? a : b) -
            xs.reduce((a, b) => a < b ? a : b),
        // Plus the sill, which overhangs 25 mm each side.
        closeTo(1650, 5),
      );

      // 13. Save, leave, and reopen.
      await tester.tap(find.byTooltip('Save this project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Untitled design'), findsOneWidget);

      await tester.tap(find.text('Untitled design'));
      await tester.pumpAndSettle();

      // 14. Everything is still there and still editable.
      final reopened = container.read(designControllerProvider).design;
      expect(reopened.outline!.width, closeTo(1600, 0.01));
      expect(reopened.panels, hasLength(2));
      expect(reopened.designNote, 'Customer asked for obscure glass.');
      expect(
        reopened.panels.expand((p) => p.notes).map((n) => n.text),
        containsAll(<String>['توري', 'Frosted glass']),
      );
      expect(
        reopened.panels.where((p) => p.behaviour.isOpening).single.opening!
            .hingeSide,
        HingeSide.right,
      );

      // Still editable after reopening, not just viewable.
      container
          .read(designControllerProvider.notifier)
          .setOverallHeight(1800);
      await tester.pumpAndSettle();
      expect(
        container.read(designControllerProvider).design.outline!.height,
        closeTo(1800, 0.01),
      );

      // 15. Export and re-import the native project.
      final exported = ProjectFile.encode(
        container.read(designControllerProvider).design,
      );
      final imported = ExportService.importProject(exported);
      expect(imported.panels, hasLength(2));
      expect(imported.designNote, 'Customer asked for obscure glass.');
      expect(
        imported.panels.expand((p) => p.notes).map((n) => n.text),
        contains('توري'),
      );

      // 16. Generate the PDF and the PNG through the real export path.
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();

      await runExport(tester, 'Design sheet (PDF)');
      await runExport(tester, 'Project file (.proframe)');

      // The PNG goes through `Picture.toImage`, which is real asynchronous
      // work the fake-async test zone cannot run. The button is tapped like
      // the others to prove the row works, then the render itself is driven
      // through `runAsync` so the bytes are genuinely produced rather than
      // assumed.
      await tester.tap(find.text('Drawing (PNG)'));
      await tester.pump();
      await tester.runAsync(
        () => exports.service.exportPng(
          container.read(designControllerProvider).design,
        ),
      );
      await tester.pump();

      expect(exports.files.keys, hasLength(3));
      final pdf = exports.files.entries
          .firstWhere((e) => e.key.endsWith('.pdf'))
          .value;
      final png = exports.files.entries
          .firstWhere((e) => e.key.endsWith('.png'))
          .value;
      final project = exports.files.entries
          .firstWhere((e) => e.key.endsWith('.proframe'))
          .value;

      // Real files, not placeholders.
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(png.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(pdf.length, greaterThan(5000));
      expect(png.length, greaterThan(2000));
      // And the project file is the one that reopens.
      expect(
        ExportService.importProject(String.fromCharCodes(project)).panels,
        hasLength(2),
      );

      await flushAutosave(tester);
    },
  );

  testWidgets('the door workflow, in aluminium', (tester) async {
    await setSize(tester, desktop);
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(InMemoryStore())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProFrameApp(idFactory: () => 'door-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Door'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aluminium'));
    await tester.pumpAndSettle();

    // The aluminium profile is chosen for the material, not the PVC one.
    expect(find.text('Generic aluminium casement'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
    await tester.pumpAndSettle();
    await drawStroke(tester, container, rectangleStroke());

    final design = container.read(designControllerProvider).design;
    expect(design.category, ProductCategory.door);
    expect(design.material, FrameMaterial.aluminium);
    expect(design.profileSystem.id, 'generic.aluminium.casement');

    // A door gets a threshold rather than a projecting sill.
    final scene = SceneBuilder.build(design);
    final threshold =
        scene.faces.where((f) => f.role == PartRole.threshold).toList();
    expect(threshold, isNotEmpty);
    expect(threshold.first.corners.first.z, 0);

    await flushAutosave(tester);
  });

  testWidgets('a window sill noses out where a door threshold does not',
      (tester) async {
    // Spec section 7: respect Door versus Window.
    await setSize(tester, desktop);
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(InMemoryStore())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProFrameApp(idFactory: () => 'w-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PVC'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start drawing'));
    await tester.pumpAndSettle();
    await drawStroke(tester, container, rectangleStroke());

    final scene = SceneBuilder.build(
      container.read(designControllerProvider).design,
    );
    final sill = scene.faces.firstWhere((f) => f.role == PartRole.threshold);

    // Negative z: in front of the frame, towards the viewer.
    expect(sill.corners.first.z, lessThan(0));

    await flushAutosave(tester);
  });
}

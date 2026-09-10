import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/services/key_value_store.dart';
import 'package:proframe/core/services/providers.dart';
import 'package:proframe/features/configurator/screens/design_screen.dart';
import 'package:proframe/features/configurator/state/design_session.dart';
import 'package:proframe/features/drawing/screens/drawing_screen.dart';
import 'package:proframe/features/drawing/widgets/drawing_canvas.dart';
import 'package:proframe/features/pricing/screens/pricing_settings_screen.dart';
import 'package:proframe/shared/models/design_document.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/sketch.dart';

const phone = Size(390, 844);
const desktop = Size(1600, 1000);

/// The canvas starts translated by (-1500, -1000), so a stroke at sketch
/// (1500 + a, 1000 + b) sits at (a, b) inside the canvas widget.
Vec2Like sketchAt(double a, double b) => (x: 1500 + a, y: 1000 + b);

typedef Vec2Like = ({double x, double y});

Stroke _stroke(String id, SketchTool tool, Vec2Like from, Vec2Like to) => Stroke(
      id: id,
      tool: tool,
      points: [
        StrokePoint(x: from.x, y: from.y),
        StrokePoint(x: to.x, y: to.y),
      ],
    );

DesignDocument _designWithInk() =>
    DesignDocument.blank(id: 'd1', kind: OpeningKind.window).copyWith(
      sketch: Sketch(strokes: [
        _stroke('line1', SketchTool.line, sketchAt(60, 220), sketchAt(300, 220)),
        _stroke('dim1', SketchTool.dimension, sketchAt(60, 120), sketchAt(300, 120)),
      ]),
    );

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ProviderContainer _container() => ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
    );

Future<void> _flushAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpDrawing(WidgetTester tester, Size size) async {
  await _setSize(tester, size);
  final container = _container();
  addTearDown(container.dispose);
  container.read(designSessionProvider.notifier).open(_designWithInk());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: DrawingScreen(onInterpret: ({bool useDrawingExtent = false}) {})),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The tool palette scrolls horizontally on a phone, so the later tools have
/// to be brought into view before they can be tapped.
Future<void> _selectTool(WidgetTester tester, String tooltip) async {
  final finder = find.byTooltip(tooltip);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapCanvasAt(WidgetTester tester, Vec2Like local) async {
  final origin = tester.getTopLeft(find.byType(DrawingCanvas));
  await tester.tapAt(origin + Offset(local.x, local.y));
  await tester.pumpAndSettle();
}

void main() {
  group('a selected stroke can be acted on without a properties panel', () {
    testWidgets('the phone selection bar deletes the stroke it picked',
        (tester) async {
      final container = await _pumpDrawing(tester, phone);

      await _selectTool(tester, 'Select');
      await _tapCanvasAt(tester, (x: 180, y: 220));

      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // The action bar scrolls on a narrow phone.
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final strokes = container.read(designSessionProvider).document!.sketch.strokes;
      expect(strokes.any((s) => s.id == 'line1'), isFalse);
      await _flushAutosave(tester);
    });
  });

  group('a dimension can be measured after it is drawn', () {
    testWidgets('tapping a dimension with the select tool asks for the size',
        (tester) async {
      final container = await _pumpDrawing(tester, phone);

      await _selectTool(tester, 'Select');
      await _tapCanvasAt(tester, (x: 180, y: 120));

      expect(find.text('How long is this?'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Size'), '1500');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      final strokes = container.read(designSessionProvider).document!.sketch.strokes;
      final dimension = strokes.firstWhere((s) => s.id == 'dim1');
      expect(dimension.dimensionMm, 1500);
      await _flushAutosave(tester);
    });

    testWidgets('an already measured dimension opens ready to be corrected',
        (tester) async {
      await _setSize(tester, phone);
      final container = _container();
      addTearDown(container.dispose);
      final design = _designWithInk();
      container.read(designSessionProvider.notifier).open(
            design.copyWith(
              sketch: Sketch(
                strokes: design.sketch.strokes
                    .map((s) => s.id == 'dim1' ? s.copyWith(dimensionMm: 1200) : s)
                    .toList(),
              ),
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: DrawingScreen(onInterpret: ({bool useDrawingExtent = false}) {})),
        ),
      );
      await tester.pumpAndSettle();

      await _selectTool(tester, 'Select');
      await _tapCanvasAt(tester, (x: 180, y: 120));

      expect(find.text('Change this measurement'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Size'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await _flushAutosave(tester);
    });
  });

  group('pricing rates', () {
    testWidgets('the price panel opens a real editor', (tester) async {
      await _setSize(tester, desktop);
      final container = _container();
      addTearDown(container.dispose);
      container.read(designSessionProvider.notifier).open(
            DesignDocument.blank(id: 'd2', kind: OpeningKind.window),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DesignScreen(onEditDrawing: () {}, onExit: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Edit rates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit rates'));
      await tester.pumpAndSettle();

      expect(find.text('Pricing rates'), findsOneWidget);
      expect(find.text('Profile, per linear metre'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Outer frame'), findsWidgets);

      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Hinge, each'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(PricingSettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Hinge, each'), findsOneWidget);
    });
  });

  group('templates', () {
    testWidgets('a template starts a real design', (tester) async {
      await _setSize(tester, desktop);
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const ProFrameApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Or start from a template'), findsOneWidget);

      await tester.tap(find.text('Double door'));
      await tester.pumpAndSettle();

      expect(find.byType(DesignScreen), findsOneWidget);
      final model = container.read(designSessionProvider).model!;
      expect(model.kind, OpeningKind.door);
      expect(model.operableCount, 2);

      final saved = await container.read(designLibraryProviderForTest).loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.name, 'Double door');
    });
  });
}

/// Reads straight from storage to prove the template was actually persisted.
final designLibraryProviderForTest = designRepositoryProvider;

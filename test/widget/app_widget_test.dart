import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/services/key_value_store.dart';
import 'package:proframe/core/services/providers.dart';
import 'package:proframe/features/configurator/screens/design_screen.dart';
import 'package:proframe/features/configurator/screens/interpretation_screen.dart';
import 'package:proframe/features/configurator/state/design_session.dart';
import 'package:proframe/features/drawing/screens/drawing_screen.dart';
import 'package:proframe/features/drawing/widgets/drawing_canvas.dart';
import 'package:proframe/features/projects/screens/home_screen.dart';
import 'package:proframe/features/rendering/widgets/technical_drawing_view.dart';
import 'package:proframe/shared/models/design_document.dart';
import 'package:proframe/shared/models/opening_model.dart';

import '../support/sketch_builders.dart';

/// The three shapes the layout has to survive. Flutter turns any overflow into
/// a test failure, so these double as a responsive-layout regression suite.
const phone = Size(390, 844);
const tablet = Size(1024, 768);
const desktop = Size(1600, 1000);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ProviderContainer _container() => ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
    );

Future<ProviderContainer> _pumpApp(WidgetTester tester, Size size) async {
  await _setSize(tester, size);
  final container = _container();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  Size size,
  Widget screen, {
  DesignDocument? design,
}) async {
  await _setSize(tester, size);
  final container = _container();
  addTearDown(container.dispose);
  if (design != null) container.read(designSessionProvider.notifier).open(design);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The session autosaves a draft 1.2 s after a change; let that timer fire so
/// the test does not end with work still pending.
Future<void> _flushAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pumpAndSettle();
}

DesignDocument _windowDesign() =>
    DesignDocument.blank(id: 'd1', kind: OpeningKind.window).copyWith(
      name: 'Kitchen window',
      sketch: twoPanelWindowSketch(),
    );

void main() {
  group('the app boots to the drawing entry point', () {
    for (final (name, size) in [('phone', phone), ('tablet', tablet), ('desktop', desktop)]) {
      testWidgets('home lays out on $name without overflowing', (tester) async {
        await _pumpApp(tester, size);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('New door'), findsOneWidget);
        expect(find.text('New window'), findsOneWidget);
        expect(find.textContaining('Draw a door or window by hand'), findsOneWidget);
      });
    }

    testWidgets('starting a window opens the drawing sheet', (tester) async {
      await _pumpApp(tester, phone);

      await tester.tap(find.text('New window'));
      await tester.pumpAndSettle();

      expect(find.byType(DrawingScreen), findsOneWidget);
      expect(find.byType(DrawingCanvas), findsOneWidget);
      expect(find.textContaining('Draw the outline first'), findsOneWidget);
    });
  });

  group('the drawing screen', () {
    for (final (name, size) in [('phone', phone), ('tablet', tablet), ('desktop', desktop)]) {
      testWidgets('lays out on $name without overflowing', (tester) async {
        await _pumpScreen(
          tester,
          size,
          DrawingScreen(onInterpret: ({bool useDrawingExtent = false}) {}),
          design: _windowDesign(),
        );

        expect(find.byType(DrawingCanvas), findsOneWidget);
        // The freehand tool is always reachable, whatever the screen size.
        expect(find.byTooltip('Freehand — draw anything'), findsOneWidget);
      });
    }

    testWidgets('the desktop layout shows the properties panel', (tester) async {
      await _pumpScreen(
        tester,
        desktop,
        DrawingScreen(onInterpret: ({bool useDrawingExtent = false}) {}),
        design: _windowDesign(),
      );

      expect(find.text('Generate the design'), findsOneWidget);
      expect(find.text('What the app can see'), findsOneWidget);
    });

    testWidgets('a finger stroke on the sheet becomes ink', (tester) async {
      final container = await _pumpScreen(
        tester,
        desktop,
        DrawingScreen(onInterpret: ({bool useDrawingExtent = false}) {}),
        design: DesignDocument.blank(id: 'd2', kind: OpeningKind.window),
      );

      final canvas = find.byType(DrawingCanvas);
      final centre = tester.getCenter(canvas);
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(60, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(designSessionProvider).document!.sketch.strokes, isNotEmpty);
      await _flushAutosave(tester);
    });
  });

  group('the interpretation screen', () {
    for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('reads the design back on $name', (tester) async {
        await _setSize(tester, size);
        final container = _container();
        addTearDown(container.dispose);
        container.read(designSessionProvider.notifier).open(_windowDesign());
        await container.read(designSessionProvider.notifier).interpret();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: InterpretationScreen(onEditDrawing: () {}, onConfirm: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Understanding your design'), findsOneWidget);
        expect(find.textContaining('Width 1200 mm'), findsOneWidget);
        expect(find.text('Confirm design'), findsOneWidget);
        expect(find.text('Edit drawing'), findsOneWidget);
        await _flushAutosave(tester);
      });
    }

    testWidgets('an empty drawing explains what to do instead of failing', (tester) async {
      await _setSize(tester, phone);
      final container = _container();
      addTearDown(container.dispose);
      container.read(designSessionProvider.notifier).open(
            DesignDocument.blank(id: 'empty', kind: OpeningKind.window),
          );
      await container.read(designSessionProvider.notifier).interpret();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: InterpretationScreen(onEditDrawing: () {}, onConfirm: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Draw the outside shape'), findsOneWidget);
    });
  });

  group('the design screen', () {
    for (final (name, size) in [('phone', phone), ('tablet', tablet), ('desktop', desktop)]) {
      testWidgets('lays out on $name without overflowing', (tester) async {
        await _pumpScreen(
          tester,
          size,
          DesignScreen(onEditDrawing: () {}, onExit: () {}),
          design: _windowDesign(),
        );

        expect(find.text('Kitchen window'), findsOneWidget);
        expect(find.text('3D model'), findsOneWidget);
      });
    }

    testWidgets('switching to the drawing shows the technical drawing', (tester) async {
      await _pumpScreen(
        tester,
        desktop,
        DesignScreen(onEditDrawing: () {}, onExit: () {}),
        design: _windowDesign(),
      );

      await tester.tap(find.text('Drawing'));
      await tester.pumpAndSettle();

      expect(find.byType(TechnicalDrawingView), findsOneWidget);
    });

    testWidgets('editing the width updates the model everywhere', (tester) async {
      final container = await _pumpScreen(
        tester,
        desktop,
        DesignScreen(onEditDrawing: () {}, onExit: () {}),
        design: _windowDesign(),
      );

      final widthField = find.widgetWithText(TextField, 'Width');
      expect(widthField, findsOneWidget);
      await tester.enterText(widthField, '1800');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(container.read(designSessionProvider).model!.widthMm, 1800);
      await _flushAutosave(tester);
    });

    testWidgets('the desktop layout shows the price worked out from the geometry',
        (tester) async {
      await _pumpScreen(
        tester,
        desktop,
        DesignScreen(onEditDrawing: () {}, onExit: () {}),
        design: _windowDesign(),
      );

      expect(find.text('Estimated price'), findsOneWidget);
      expect(find.text('Outer frame profile'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });
  });
}

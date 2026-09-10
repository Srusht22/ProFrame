import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app.dart';
import 'package:proframe/core/services/key_value_store.dart';
import 'package:proframe/core/services/providers.dart';
import 'package:proframe/features/configurator/screens/interpretation_screen.dart';
import 'package:proframe/features/configurator/state/design_session.dart';
import 'package:proframe/features/drawing/screens/drawing_screen.dart';
import 'package:proframe/features/drawing/widgets/drawing_canvas.dart';

const phone = Size(390, 844);
const desktop = Size(1600, 1000);

Future<ProviderContainer> _openDrawing(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore())],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProFrameApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('New window'));
  await tester.pumpAndSettle();
  return container;
}

/// Draws with one finger, in small steps, the way a real hand does.
Future<void> _stroke(WidgetTester tester, Offset from, List<Offset> legs) async {
  final gesture = await tester.startGesture(from);
  for (final leg in legs) {
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(leg / 8);
      await tester.pump(const Duration(milliseconds: 8));
    }
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _drawOutline(WidgetTester tester) async {
  final origin = tester.getTopLeft(find.byType(DrawingCanvas));
  await _stroke(tester, origin + const Offset(80, 80), const [
    Offset(240, 0),
    Offset(0, 160),
    Offset(-240, 0),
    Offset(0, -156),
  ]);
}

Future<void> _drawTwoLoseLines(WidgetTester tester) async {
  final origin = tester.getTopLeft(find.byType(DrawingCanvas));
  await _stroke(tester, origin + const Offset(80, 80), const [Offset(240, 0)]);
  await _stroke(tester, origin + const Offset(80, 240), const [Offset(240, 0)]);
}

Future<void> _tapGenerate(WidgetTester tester, Size size) async {
  final label = size.width >= 1440 ? 'Generate the design' : 'Generate';
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
    group('Generate on $name', () {
      testWidgets('a readable drawing generates and moves on', (tester) async {
        final container = await _openDrawing(tester, size);
        await _drawOutline(tester);
        await _tapGenerate(tester, size);

        expect(find.byType(InterpretationScreen), findsOneWidget);
        expect(container.read(designSessionProvider).error, isNull);
        expect(container.read(designSessionProvider).model, isNotNull);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
      });

      testWidgets('a drawing it cannot read says so instead of doing nothing',
          (tester) async {
        await _openDrawing(tester, size);
        await _drawTwoLoseLines(tester);
        await _tapGenerate(tester, size);

        // Still on the drawing — and the reason is on screen, which is the
        // whole point: silence here reads as a broken button.
        expect(find.byType(DrawingScreen), findsOneWidget);
        expect(find.byType(InterpretationScreen), findsNothing);
        expect(
          find.text('That drawing could not be turned into a design'),
          findsOneWidget,
        );
        expect(find.textContaining('No closed outline found'), findsOneWidget);
        expect(find.text('Use what I drew as the outline'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
      });

      testWidgets('the offered way forward actually generates', (tester) async {
        final container = await _openDrawing(tester, size);
        await _drawTwoLoseLines(tester);
        await _tapGenerate(tester, size);

        final offer = find.text('Use what I drew as the outline');
        await tester.ensureVisible(offer);
        await tester.pumpAndSettle();
        await tester.tap(offer);
        await tester.pumpAndSettle();

        expect(find.byType(InterpretationScreen), findsOneWidget);
        expect(container.read(designSessionProvider).model, isNotNull);
        // And it is honest about where the outline came from.
        expect(
          find.textContaining('Outline assumed'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
      });

      testWidgets('drawing again clears the complaint', (tester) async {
        await _openDrawing(tester, size);
        await _drawTwoLoseLines(tester);
        await _tapGenerate(tester, size);
        expect(
          find.text('That drawing could not be turned into a design'),
          findsOneWidget,
        );

        await _drawOutline(tester);
        expect(
          find.text('That drawing could not be turned into a design'),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets('the desktop Generate button is reachable without scrolling',
      (tester) async {
    // A short window is where a primary action buried at the bottom of a
    // scrolling side panel stops being findable at all.
    await _openDrawing(tester, const Size(1600, 620));

    final button = find.widgetWithText(FilledButton, 'Generate the design');
    expect(button, findsOneWidget);
    final box = tester.getRect(button);
    expect(box.bottom, lessThanOrEqualTo(620));
    expect(box.top, greaterThanOrEqualTo(0));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets('Generate is only disabled while the sheet is empty', (tester) async {
    await _openDrawing(tester, desktop);

    final button = find.widgetWithText(FilledButton, 'Generate the design');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await _drawOutline(tester);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });
}

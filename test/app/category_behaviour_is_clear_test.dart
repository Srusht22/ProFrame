import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/screens/designs_screen.dart' show kindIcon;
import 'package:proframe/app/screens/normalized_note.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;

// The two kinds of category, told apart without making anything harder.
//
// Door, Window, Sliding and Door & window are standard: a line drawn a
// little out of square is straightened. Angled / Asymmetrical is for the
// sloped, the under-stair, the asymmetrical and the custom, and keeps every
// slope as it is drawn. The choice says so where it is made — a clear mark,
// its name and a line under it, and one sentence beneath the cards — and
// the drawing says so when it happens: a standard design put visibly right
// gets a quiet *Geometry normalized for standard design.* over the work,
// which goes on its own. No dialog, no question, nothing waiting, and
// nothing at all for the shake taken out of every hand-drawn line, for the
// same strokes read again, or for an angled design.

/// A 120 × 150 cm outline with its right side drawn leaning out by
/// [lean] millimetres over its height, and a transom.
Sketch leaningWindow({double lean = 160}) => Sketch(
  strokes: [
    sheet.pen('outline', [
      const Vec2(0, 0),
      const Vec2(1200, 0),
      Vec2(1200 + lean, 1500),
      const Vec2(0, 1500),
      const Vec2(0, 0),
    ]),
    sheet.pen('transom', const [Vec2(0, 500), Vec2(1200, 500)]),
  ],
);

Interpretation readAs(DesignKind kind, Sketch sketch) =>
    SketchInterpreter.interpret(
      Design.empty(id: 'd', kind: kind).copyWith(sketch: sketch),
    );

Future<ProviderContainer> openAt(
  WidgetTester tester,
  Size size,
  String card,
) async {
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

/// Puts [sketch] on the sheet and reads it, as **Read** does, then lets
/// the note come in — a few frames, not the whole of it.
Future<WorkspaceController> drawAndRead(
  WidgetTester tester,
  ProviderContainer c,
  Sketch sketch,
) async {
  final controller = c.read(workspaceProvider.notifier);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(sketch: sketch),
  );
  controller.readDrawing();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return controller;
}

final note = find.text(NormalizedNote.message);

/// The sizes a reading asks for put away — **Not now** — and a moment for
/// what was waiting behind them to come in.
Future<void> putSizesAway(WidgetTester tester) async {
  final notNow = find.descendant(
    of: find.byType(Dialog),
    matching: find.text('Not now'),
  );
  expect(notNow, findsOneWidget, reason: 'the sizes are asked');
  await tester.tap(notNow);
  await tester.pump();
  // The form going, and the note starting on the frame after it.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 600));
}

const sizes = {
  'a phone': Size(390, 844),
  'a tablet': Size(820, 1180),
  'a laptop': Size(1280, 820),
};

const standard = ['DOOR', 'WINDOW', 'SLIDING', 'DOOR & WINDOW'];
const angledCard = 'ANGLED / ASYMMETRICAL';

void main() {
  group('the reading says what it straightened', () {
    test('a standard design visibly put right says which strokes', () {
      for (final kind in [
        DesignKind.door,
        DesignKind.window,
        DesignKind.sliding,
        DesignKind.both,
      ]) {
        final read = readAs(kind, leaningWindow());
        final outline = read.design.frame!.outline;
        expect(
          outline.edges.every((e) => e.a.x == e.b.x || e.a.y == e.b.y),
          isTrue,
          reason: '${kind.name}: squared',
        );
        expect(read.noticeablyCorrected, {'outline'}, reason: kind.name);
      }
    });

    test('a drawing already square, or out by no more than a hand places '
        'a line, says nothing', () {
      for (final lean in [0.0, 5.0]) {
        final read = readAs(DesignKind.window, leaningWindow(lean: lean));
        expect(read.noticeablyCorrected, isEmpty, reason: 'out by $lean mm');
      }
    });

    test('an angled design keeps its slope and says nothing', () {
      final read = readAs(DesignKind.angled, leaningWindow());
      final outline = read.design.frame!.outline;
      expect(
        outline.edges.any((e) => e.a.x != e.b.x && e.a.y != e.b.y),
        isTrue,
        reason: 'the slope kept',
      );
      expect(read.noticeablyCorrected, isEmpty);
    });
  });

  group('on the real app', () {
    for (final MapEntry(key: where, value: size) in sizes.entries) {
      testWidgets('$where: a standard design straightened says so quietly, '
          'once, over the work, and the note goes on its own', (tester) async {
        final c = await openAt(tester, size, 'WINDOW');
        final controller = await drawAndRead(tester, c, leaningWindow());

        // The reading asks for the sizes straight away, and on a phone they
        // fill the screen: the note waits behind them rather than playing
        // out where it cannot be seen.
        await tester.pump(const Duration(seconds: 5));
        expect(note, findsNothing, reason: 'held back while the sizes are up');
        await putSizesAway(tester);

        expect(note, findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'it fits $where');
        // Never a dialog, and never in one.
        expect(
          find.ancestor(of: note, matching: find.byType(Dialog)),
          findsNothing,
        );
        expect(find.byType(AlertDialog), findsNothing);
        // It takes no tap: everything under it works as it would.
        final pill = find.byKey(const ValueKey('normalized-note'));
        expect(
          find
              .ancestor(of: pill, matching: find.byType(IgnorePointer))
              .evaluate()
              .any((e) => (e.widget as IgnorePointer).ignoring),
          isTrue,
        );
        // At the head of the view, over the work and inside it.
        final view = tester.getRect(find.byType(NormalizedNote));
        final at = tester.getRect(pill);
        expect(
          view.contains(at.topLeft) && view.contains(at.bottomRight),
          isTrue,
        );
        expect(at.top - view.top, lessThan(24));

        // It goes by itself.
        await tester.pumpAndSettle();
        expect(note, findsNothing);

        // The same sheet read again says nothing more.
        controller.readDrawing();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(note, findsNothing);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a square drawing says nothing', (tester) async {
      final c = await openAt(tester, sizes['a laptop']!, 'WINDOW');
      await drawAndRead(tester, c, leaningWindow(lean: 0));
      await putSizesAway(tester);
      expect(note, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('an angled design keeps the slope it is drawn with, and '
        'says nothing', (tester) async {
      final c = await openAt(tester, sizes['a laptop']!, angledCard);
      await drawAndRead(tester, c, leaningWindow());
      await putSizesAway(tester);
      expect(note, findsNothing);
      final outline = c.read(workspaceProvider).design.frame!.outline;
      expect(
        outline.edges.any((e) => e.a.x != e.b.x && e.a.y != e.b.y),
        isTrue,
        reason: 'the slope kept',
      );
      await tester.pumpAndSettle();
    });

    for (final card in standard) {
      testWidgets('$card says so', (tester) async {
        final c = await openAt(tester, sizes['a laptop']!, card);
        await drawAndRead(tester, c, leaningWindow());
        await putSizesAway(tester);
        expect(note, findsOneWidget, reason: card);
        await tester.pumpAndSettle();
      });
    }
  });

  group('the choice says what each is for', () {
    for (final MapEntry(key: where, value: size) in sizes.entries) {
      testWidgets('$where: the four standard categories and the angled '
          'one, its mark, its line and the sentence under them', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const ProviderScope(child: ProFrameApp()));
        await tester.pumpAndSettle();
        await toTheCategories(tester);

        for (final card in [...standard, angledCard]) {
          expect(find.text(card), findsOneWidget, reason: card);
        }
        // The angled card: its own clear mark and its line.
        expect(StartScreen.choices.last, (
          DesignKind.angled,
          'Sloped, under-stair & custom shapes',
        ));
        expect(kindIcon(DesignKind.angled), Icons.change_history_outlined);
        final angled = find.ancestor(
          of: find.text(angledCard),
          matching: find.byType(InkWell),
        );
        expect(
          find.descendant(
            of: angled.first,
            matching: find.text('Sloped, under-stair & custom shapes'),
          ),
          findsOneWidget,
        );
        // Its card draws its own mark — a window under a stair, drawn by
        // the pen as the others are — and the angled design's mark in the
        // lists is its own too.
        expect(
          find.descendant(of: angled.first, matching: find.byType(CustomPaint)),
          findsWidgets,
        );
        // The marks of the five are five different marks.
        expect({
          for (final (kind, _) in StartScreen.choices) kindIcon(kind),
        }, hasLength(5));

        // The one sentence that says the difference, where the choice is.
        final sentence = find.byKey(const ValueKey('straightening-note'));
        await tester.ensureVisible(sentence);
        await tester.pumpAndSettle();
        expect(find.text(StartScreen.straighteningNote), findsOneWidget);
        expect(StartScreen.straighteningNote, contains('straighten'));
        expect(
          StartScreen.straighteningNote,
          contains('Angled / Asymmetrical'),
        );
        expect(tester.takeException(), isNull, reason: 'it fits $where');
      });
    }
  });
}

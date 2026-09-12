import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/layout/panel_splitter.dart';
import 'package:proframe/domain/layout/width_solver.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/product/infill.dart';
import 'package:proframe/domain/product/opening.dart';

Panel panelAt(String id, double left, double width, {double height = 900}) =>
    Panel.fixed(
      id: id,
      boundary: Polygon.rectangle(
        width: width,
        height: height,
        topLeft: Point2(left, 0),
      ),
    );

void main() {
  group('a divider splits a panel where it was drawn', () {
    test('a third of the way across gives a third and two thirds', () {
      // Spec Phase 2, item 3: proportional, not equal.
      final whole = panelAt('p1', 0, 1200);

      final (left, right) =
          PanelSplitter.splitVertical(whole, 400, leftId: 'a', rightId: 'b');

      expect(left.widthMm, 400);
      expect(right.widthMm, 800);
      expect(left.boundary.left, 0);
      expect(right.boundary.left, 400);
    });

    test('the two halves still cover exactly what the panel covered', () {
      final whole = panelAt('p1', 0, 1200);

      final (left, right) =
          PanelSplitter.splitVertical(whole, 437, leftId: 'a', rightId: 'b');

      expect(left.widthMm + right.widthMm, 1200);
      expect(left.boundary.right, right.boundary.left);
    });

    test('an off-centre divider is not tidied to the middle', () {
      final whole = panelAt('p1', 0, 1200);

      final (left, _) =
          PanelSplitter.splitVertical(whole, 373, leftId: 'a', rightId: 'b');

      expect(left.widthMm, 373);
    });

    test('a horizontal divider splits top from bottom', () {
      final whole = panelAt('p1', 0, 1200);

      final (top, bottom) =
          PanelSplitter.splitHorizontal(whole, 300, topId: 'a', bottomId: 'b');

      expect(top.heightMm, 300);
      expect(bottom.heightMm, 600);
      expect(top.boundary.bottom, bottom.boundary.top);
    });

    test('both halves start fixed, because nobody has said otherwise', () {
      // Spec Phase 2, item 2: unmarked panels default to CH.
      final sash = Panel.opening(
        id: 'p1',
        boundary: Polygon.rectangle(width: 1200, height: 900),
        opening: const OpeningSpec(
          hingeSide: HingeSide.left,
          direction: OpeningDirection.inward,
          isConfirmed: true,
        ),
      );

      final (left, right) =
          PanelSplitter.splitVertical(sash, 600, leftId: 'a', rightId: 'b');

      // The old panel's Z assignment does not silently apply to both halves.
      expect(left.behaviour, PanelBehaviour.fixed);
      expect(right.behaviour, PanelBehaviour.fixed);
      expect(left.opening, isNull);
    });

    test('splitting gives new ids rather than reusing the old one', () {
      final whole = panelAt('p1', 0, 1200);

      final (left, right) =
          PanelSplitter.splitVertical(whole, 600, leftId: 'a', rightId: 'b');

      expect(left.id, 'a');
      expect(right.id, 'b');
      expect([left.id, right.id], isNot(contains('p1')));
    });

    test('the glass follows both halves, the notes do not', () {
      final whole = panelAt('p1', 0, 1200).copyWith(
        hasMesh: true,
        infill: Glazing.singleGlazed,
      );

      final (left, right) =
          PanelSplitter.splitVertical(whole, 600, leftId: 'a', rightId: 'b');

      for (final half in [left, right]) {
        expect(half.hasMesh, isTrue);
        expect(half.infill, Glazing.singleGlazed);
      }
      // Notes are not copied onto both halves — duplicating a remark would
      // put it somewhere the user never wrote it. NoteResolver places them.
      expect(left.notes, isEmpty);
      expect(right.notes, isEmpty);
    });

    test('a split that would leave an unbuildable sliver is refused', () {
      final whole = panelAt('p1', 0, 1200);

      expect(
        () => PanelSplitter.splitVertical(whole, 20, leftId: 'a', rightId: 'b'),
        throwsArgumentError,
      );
    });
  });

  group('panel widths always sum to the frame width', () {
    test('widening a panel narrows the one to its right', () {
      final row = [panelAt('a', 0, 400), panelAt('b', 400, 800)];

      final outcome = WidthSolver.setWidth(row, 'a', 600);

      expect(outcome, isA<WidthApplied>());
      final applied = outcome as WidthApplied;
      expect(applied.panels[0].widthMm, 600);
      expect(applied.panels[1].widthMm, 600);
      expect(applied.adjustedPanelId, 'b');
      expect(applied.adjustmentMm, -200);
      // Still 1200 in total.
      expect(
        applied.panels.fold<double>(0, (sum, p) => sum + p.widthMm),
        1200,
      );
    });

    test('the last panel in a row takes from its left-hand neighbour', () {
      final row = [
        panelAt('a', 0, 400),
        panelAt('b', 400, 400),
        panelAt('c', 800, 400),
      ];

      final outcome = WidthSolver.setWidth(row, 'c', 600) as WidthApplied;

      expect(outcome.adjustedPanelId, 'b');
      expect(outcome.panels.last.widthMm, 600);
      expect(
        outcome.panels.fold<double>(0, (sum, p) => sum + p.widthMm),
        1200,
      );
    });

    test('panels still tile the row with no gap after a change', () {
      final row = [
        panelAt('a', 0, 373),
        panelAt('b', 373, 411),
        panelAt('c', 784, 416),
      ];

      final outcome = WidthSolver.setWidth(row, 'a', 500) as WidthApplied;

      expect(WidthSolver.tilesExactly(outcome.panels), isTrue);
      expect(outcome.panels.first.boundary.left, 0);
      expect(outcome.panels.last.boundary.right, closeTo(1200, 0.001));
    });

    test('untouched panels keep their width exactly', () {
      final row = [
        panelAt('a', 0, 400),
        panelAt('b', 400, 400),
        panelAt('c', 800, 400),
      ];

      final outcome = WidthSolver.setWidth(row, 'a', 500) as WidthApplied;

      // c is not the neighbour, so it must not have moved in size.
      expect(outcome.panels[2].widthMm, 400);
    });

    test('an impossible width is refused, not quietly clamped', () {
      // Spec section 2: never silently give the user a different number.
      final row = [panelAt('a', 0, 400), panelAt('b', 400, 800)];

      final outcome = WidthSolver.setWidth(row, 'a', 1190);

      expect(outcome, isA<WidthRefused>());
      final refused = outcome as WidthRefused;
      expect(refused.reason, contains('not enough room'));
      expect(refused.largestWorkableMm, 1150);
    });

    test('the refusal explains itself in plain language', () {
      final row = [panelAt('a', 0, 400), panelAt('b', 400, 800)];

      final refused = WidthSolver.setWidth(row, 'a', 1190) as WidthRefused;

      // No jargon, no error codes: this sentence is shown to a factory worker.
      expect(refused.reason, isNot(contains('Exception')));
      expect(refused.reason, contains('mm'));
    });

    test('a width under the minimum is refused', () {
      final row = [panelAt('a', 0, 400), panelAt('b', 400, 800)];

      expect(WidthSolver.setWidth(row, 'a', 10), isA<WidthRefused>());
    });

    test('the only panel in a frame cannot be resized this way', () {
      final row = [panelAt('a', 0, 1200)];

      final outcome = WidthSolver.setWidth(row, 'a', 900);

      expect(outcome, isA<WidthRefused>());
      expect((outcome as WidthRefused).reason, contains('overall width'));
    });

    test('setting a panel to the width it already has changes nothing', () {
      final row = [panelAt('a', 0, 400), panelAt('b', 400, 800)];

      final outcome = WidthSolver.setWidth(row, 'a', 400) as WidthApplied;

      expect(outcome.adjustmentMm, 0);
      expect(outcome.panels[1].widthMm, 800);
    });
  });

  group('equal distribution happens only when asked for', () {
    test('it divides the row evenly', () {
      final row = [
        panelAt('a', 0, 100),
        panelAt('b', 100, 700),
        panelAt('c', 800, 400),
      ];

      final equal = WidthSolver.distributeEqually(row);

      for (final panel in equal) {
        expect(panel.widthMm, closeTo(400, 0.001));
      }
      expect(WidthSolver.tilesExactly(equal), isTrue);
      expect(equal.last.boundary.right, closeTo(1200, 0.001));
    });

    test('it keeps every panel id and assignment', () {
      final row = [
        panelAt('a', 0, 100),
        panelAt('b', 100, 1100),
      ];

      final equal = WidthSolver.distributeEqually(row);

      expect(equal.map((p) => p.id), ['a', 'b']);
    });

    test('a lopsided row stays lopsided unless it is called', () {
      // The solver never equalises on its own (spec section 2).
      final row = [panelAt('a', 0, 300), panelAt('b', 300, 900)];

      final outcome = WidthSolver.setWidth(row, 'a', 350) as WidthApplied;

      expect(outcome.panels[0].widthMm, 350);
      expect(outcome.panels[1].widthMm, 850);
      expect(outcome.panels[0].widthMm, isNot(outcome.panels[1].widthMm));
    });
  });
}

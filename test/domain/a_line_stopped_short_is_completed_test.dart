import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user's words: *when I start drawing a straight line and stop before
// reaching the existing boundary, complete it to that boundary — horizontal
// and vertical. Do not move the design, resize it, create a section or an
// opening, or move existing geometry.*
//
// A line with an end touching nothing is carried along its own line to the
// first line it meets. An end already touching a line stays where it is.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

const outline = [
  Vec2(0, 0),
  Vec2(1000, 0),
  Vec2(1000, 2100),
  Vec2(0, 2100),
  Vec2(0, 0),
];

Design read(List<Stroke> lines, {DesignKind kind = DesignKind.door}) =>
    SketchInterpreter.interpret(
      Design(
        id: 'door',
        name: 'Door',
        kind: kind,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sketch: Sketch(strokes: [pen('outline', outline), ...lines]),
      ),
    ).design;

DividerElement bar(Design design, String strokeId) =>
    design.dividers.firstWhere((d) => d.fromStrokeId == strokeId);

/// The two ends of [bar], lowest x then lowest y first.
(Vec2, Vec2) ends(DividerElement bar) {
  final a = bar.a;
  final b = bar.b;
  final first = a.x < b.x || (a.x == b.x && a.y < b.y);
  return first ? (a, b) : (b, a);
}

void main() {
  group('1–2 — a horizontal line stopped short is completed', () {
    test('drawn from the left jamb, stopped before the right one', () {
      final d = read([
        pen('transom', const [Vec2(0, 900), Vec2(600, 900)]),
      ]);
      final (left, right) = ends(bar(d, 'transom'));
      expect(left.x, closeTo(0, 1), reason: 'where it was started');
      expect(right.x, closeTo(1000, 1), reason: 'completed to the jamb');
      expect(left.y, closeTo(900, 1));
      expect(right.y, closeTo(900, 1), reason: 'along its own line');
      expect(d.topLevelSections, hasLength(2), reason: 'it now divides');
    });

    test('drawn from the right, stopped before the left', () {
      final d = read([
        pen('transom', const [Vec2(1000, 900), Vec2(350, 900)]),
      ]);
      final (left, right) = ends(bar(d, 'transom'));
      expect(left.x, closeTo(0, 1));
      expect(right.x, closeTo(1000, 1));
      expect(d.topLevelSections, hasLength(2));
    });
  });

  group('3–4 — a vertical line stopped short is completed', () {
    test('drawn down from the head, stopped before the sill', () {
      final d = read([
        pen('mullion', const [Vec2(400, 0), Vec2(400, 1300)]),
      ]);
      final (top, bottom) = ends(bar(d, 'mullion'));
      expect(top.y, closeTo(0, 1));
      expect(bottom.y, closeTo(2100, 1), reason: 'completed to the sill');
      expect(bottom.x, closeTo(400, 1), reason: 'along its own line');
      expect(d.topLevelSections, hasLength(2));
    });

    test('drawn up from the sill, stopped before the head', () {
      final d = read([
        pen('mullion', const [Vec2(400, 2100), Vec2(400, 800)]),
      ]);
      final (top, bottom) = ends(bar(d, 'mullion'));
      expect(top.y, closeTo(0, 1));
      expect(bottom.y, closeTo(2100, 1));
    });
  });

  group('the boundary is the first line it meets', () {
    test('a line heading for a transom stops at the transom, not the sill '
        'beyond it', () {
      final d = read([
        pen('transom', const [Vec2(0, 900), Vec2(1000, 900)]),
        pen('mullion', const [Vec2(500, 0), Vec2(500, 500)]),
      ]);
      final (top, bottom) = ends(bar(d, 'mullion'));
      expect(top.y, closeTo(0, 1));
      expect(bottom.y, closeTo(900, 1));
      expect(d.topLevelSections, hasLength(3));
    });

    test('a line drawn between two lines is left exactly as drawn — never '
        'stretched past what it reached', () {
      final d = read([
        pen('transom', const [Vec2(0, 900), Vec2(1000, 900)]),
        pen('upright', const [Vec2(500, 900), Vec2(500, 2100)]),
      ]);
      final (top, bottom) = ends(bar(d, 'upright'));
      expect(top.y, closeTo(900, 1), reason: 'not carried on to the head');
      expect(bottom.y, closeTo(2100, 1));
      expect(d.topLevelSections, hasLength(3));
    });

    test('a line touching nothing is completed at both ends', () {
      final d = read([
        pen('transom', const [Vec2(250, 900), Vec2(700, 900)]),
      ]);
      final (left, right) = ends(bar(d, 'transom'));
      expect(left.x, closeTo(0, 1));
      expect(right.x, closeTo(1000, 1));
    });
  });

  group('only a level or upright line', () {
    test('a line drawn at a slope is left exactly where it was drawn', () {
      final d = read([
        pen('diagonal', const [Vec2(100, 300), Vec2(600, 1100)]),
      ]);
      final (a, b) = ends(bar(d, 'diagonal'));
      expect(a.x, closeTo(100, 1));
      expect(a.y, closeTo(300, 1));
      expect(b.x, closeTo(600, 1));
      expect(b.y, closeTo(1100, 1));
    });
  });

  group('5 — nothing else moves', () {
    test('the frame, the other lines, and no new section or opening', () {
      final without = read([
        pen('transom', const [Vec2(0, 900), Vec2(1000, 900)]),
        pen('mark', const [Vec2(300, 1200), Vec2(700, 1500), Vec2(300, 1800)]),
      ]);
      final withShort = read([
        pen('transom', const [Vec2(0, 900), Vec2(1000, 900)]),
        pen('mark', const [Vec2(300, 1200), Vec2(700, 1500), Vec2(300, 1800)]),
        pen('short', const [Vec2(0, 400), Vec2(700, 400)]),
      ]);
      // The design is not moved or resized.
      expect(
        jsonEncode(withShort.frame!.toJson()),
        jsonEncode(without.frame!.toJson()),
      );
      expect(withShort.widthMm, without.widthMm);
      expect(withShort.heightMm, without.heightMm);
      // The line already there is exactly where it was.
      expect(
        jsonEncode(bar(withShort, 'transom').toJson()),
        jsonEncode(bar(without, 'transom').toJson()),
      );
      // The completed line is one bar, and it makes the one part it cuts
      // off — the upper light split in two — and nothing else.
      expect(withShort.dividers, hasLength(without.dividers.length + 1));
      expect(
        withShort.topLevelSections,
        hasLength(without.topLevelSections.length + 1),
      );
      // No opening is made, moved or lost: the one the mark made is still
      // the only one, on the part the mark is in.
      expect(withShort.openings, hasLength(1));
      expect(withShort.openings.single.markAt, without.openings.single.markAt);
      final marked = withShort.sectionById(
        withShort.openings.single.sectionId,
      )!;
      expect(marked.outline.contains(const Vec2(500, 1500)), isTrue);
      // And the user's own ink is untouched: completing is the design's
      // reading of the line, not a change to what they drew.
      final ink = withShort.sketch.strokes.firstWhere((s) => s.id == 'short');
      expect(ink.samples.last.at.x, closeTo(700, 1e-9));
    });

    test('reading the sheet again gives the same completed line', () {
      final once = read([
        pen('transom', const [Vec2(0, 900), Vec2(620, 900)]),
      ]);
      final twice = SketchInterpreter.interpret(once).design;
      expect(
        jsonEncode(bar(twice, 'transom').toJson()),
        jsonEncode(bar(once, 'transom').toJson()),
      );
    });

    test('no question is added', () {
      final result = SketchInterpreter.interpret(
        Design(
          id: 'door',
          name: 'Door',
          kind: DesignKind.door,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          sketch: Sketch(
            strokes: [
              pen('outline', outline),
              pen('transom', const [Vec2(0, 900), Vec2(600, 900)]),
            ],
          ),
        ),
      );
      expect(result.questions, isEmpty);
    });
  });
}

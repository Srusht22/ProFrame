import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// The user's screenshot: an Angled / Asymmetrical design with an opening
// marked `<`, its sizes typed into the form — and *That does not fit the
// parts inside it* under the overall width, though nothing about 260 cm was
// wrong. The cause: a size that moves a side of a frame that is not a
// rectangle — the overall height bringing a slope down, a jamb made
// shorter — moved every line, but left the opening's mark where it was
// drawn. Out past the slope, it was in no region, the opening was lost,
// and the size was refused. The mark now goes with its region, and so does
// the ink it was read from.

Design read(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

const shapes = {
  // Low on the left, the slope rising to a tall right side — the screenshot.
  'left low': [
    Vec2(0, 700),
    Vec2(0, 560),
    Vec2(1300, 0),
    Vec2(1300, 700),
    Vec2(0, 700),
  ],
  'right low': [
    Vec2(0, 700),
    Vec2(0, 0),
    Vec2(1300, 560),
    Vec2(1300, 700),
    Vec2(0, 700),
  ],
  'gable': [
    Vec2(0, 700),
    Vec2(0, 300),
    Vec2(650, 0),
    Vec2(1300, 300),
    Vec2(1300, 700),
    Vec2(0, 700),
  ],
};

Design drawn(List<Vec2> outline, Vec2 mark, {bool lineInside = false}) {
  var d = read(
    Design.empty(id: 'a', kind: DesignKind.angled).copyWith(
      sketch: Sketch(
        strokes: [pen('outline', outline), pen('mark', chevron(mark))],
      ),
    ),
  ).copyWith(measured: {});
  if (lineInside) {
    final o = d.openings.single;
    final r = d.sectionById(o.sectionId)!.outline;
    d = DesignEdits.addLineInside(
      d,
      o.sectionId,
      id: 'in',
      at: Vec2(r.centroid.x, r.bottom - 60),
      horizontal: true,
    );
  }
  return d;
}

void main() {
  test("the screenshot's sizes, all at once, are taken", () {
    final d = drawn(shapes['left low']!, const Vec2(900, 450));
    expect(d.openings, hasLength(1));
    final side = Measurements.of(d)
        .firstWhere((m) => m.key.startsWith('side:'))
        .key;
    final out = Measurements.apply(d, {
      Measurements.profileKey: 45,
      Measurements.barsKey: 45,
      Measurements.widthKey: 2600,
      Measurements.heightKey: 1800,
      side: 350,
    });
    expect(out.problems, isEmpty);
    final made = out.design;
    expect(made.widthMm, closeTo(2600, 0.5));
    expect(made.heightMm, closeTo(1800, 0.5));
    // The opening is still there, on the region holding its mark.
    final opening = made.openings.single;
    final region = made.sectionById(opening.sectionId)!.outline;
    expect(region.contains(opening.markAt!), isTrue);
    // And the ink moved with it, so reading the sheet again finds it.
    final again = read(made);
    expect(again.openings, hasLength(1));
    expect(again.heightMm, closeTo(1800, 0.5));
  });

  for (final shape in shapes.entries) {
    for (final x in [200.0, 650.0, 1100.0]) {
      if (shape.key == 'right low' && x == 1100) continue; // not in the frame
      for (final inside in [false, true]) {
        test('${shape.key}, the mark at $x${inside ? ', a line inside' : ''}: '
            'every size on its own and together keeps the opening', () {
          final d = drawn(shape.value, Vec2(x, 655), lineInside: inside);
          expect(d.openings, hasLength(1));
          final sides = [
            for (final m in Measurements.of(d))
              if (m.asked && m.key.startsWith('side:')) m.key,
          ];
          for (final values in [
            {Measurements.widthKey: 2600.0},
            {Measurements.heightKey: 1800.0},
            {Measurements.widthKey: 900.0},
            {Measurements.heightKey: 1000.0},
            {
              Measurements.profileKey: 45.0,
              Measurements.widthKey: 2600.0,
              Measurements.heightKey: 1800.0,
            },
            for (final k in sides) {k: 500.0},
            for (final k in sides) {Measurements.heightKey: 1800.0, k: 350.0},
          ]) {
            final out = Measurements.apply(d, values);
            expect(out.problems, isEmpty, reason: '$values');
            final opening = out.design.openings.single;
            expect(
              out.design
                  .sectionById(opening.sectionId)!
                  .outline
                  .contains(opening.markAt!),
              isTrue,
              reason: '$values',
            );
            if (inside) {
              expect(
                out.design.dividers.where((b) => b.parentId == opening.id),
                hasLength(1),
                reason: 'the line inside stays the opening\'s: $values',
              );
            }
            expect(read(out.design).openings, hasLength(1), reason: '$values');
          }
        });
      }
    }
  }

  test('a rectangle is unchanged: its mark was never in the way', () {
    final d = drawn(const [
      Vec2(0, 0),
      Vec2(1000, 0),
      Vec2(1000, 700),
      Vec2(0, 700),
      Vec2(0, 0),
    ], const Vec2(500, 350));
    final out = Measurements.apply(d, {
      Measurements.widthKey: 2000,
      Measurements.heightKey: 1400,
    });
    expect(out.problems, isEmpty);
    expect(out.design.openings, hasLength(1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
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

  // The user's second screenshot: the same design, the width still refused.
  // Made much taller, a raked frame took two more things apart. An upright
  // line inside the opening, carried with its region, was put back on the
  // edge it had met by the nearest crossing — and nearest its head, far
  // below the slope, was the sill its own foot stands on: the line folded
  // to nothing and the opening's two panes went. And a mullion's foot on
  // the sill went to the slope, which had come nearer than the sill had:
  // the mullion folded, a light went, and the size was refused.
  group('made much taller, every line keeps its own ends', () {
    const lines = {
      'level': [Vec2(820, 520), Vec2(1250, 520)],
      'level, short of both sides': [Vec2(900, 520), Vec2(1150, 520)],
      'level, past the mullion': [Vec2(700, 520), Vec2(1290, 520)],
      'upright, slope to sill': [Vec2(1000, 300), Vec2(1000, 690)],
      'upright, short of both': [Vec2(1000, 400), Vec2(1000, 650)],
      'diagonal': [Vec2(850, 650), Vec2(1250, 350)],
    };
    for (final mullion in [false, true]) {
      for (final markX in [400.0, 900.0]) {
        for (final line in lines.entries) {
          test('${mullion ? 'a mullion, ' : ''}the mark at $markX, a line '
              '${line.key}', () {
            var d = read(
              Design.empty(id: 'a', kind: DesignKind.angled).copyWith(
                sketch: Sketch(
                  strokes: [
                    pen('outline', shapes['left low']!),
                    if (mullion)
                      pen('mullion', const [Vec2(700, 300), Vec2(700, 700)]),
                    pen('mark', chevron(Vec2(markX, 600))),
                  ],
                ),
              ),
            ).copyWith(measured: {});
            expect(d.openings, hasLength(1));
            // Drawn on the sheet afterwards: inside the opening it joins it.
            d = read(
              d.copyWith(
                sketch: Sketch(
                  strokes: [...d.sketch.strokes, pen('line', line.value)],
                ),
              ),
            );
            final sides = [
              for (final m in Measurements.of(d))
                if (m.asked && m.key.startsWith('side:')) m.key,
            ];
            final sections = d.sections.length;
            // The sizes the user gave, then the width alone, as they did.
            var out = Measurements.apply(d, {
              Measurements.profileKey: 45,
              Measurements.barsKey: 45,
              Measurements.heightKey: 1800,
              for (final k in sides) k: 350,
            });
            expect(out.problems, isEmpty);
            expect(out.design.sections, hasLength(sections));
            expect(out.design.openings, hasLength(1));
            // A diagonal ending on the right jamb, with a mullion beside it,
            // cannot follow that jamb 150 cm out: the slope then passes
            // below both its ends. That is the one size refused, rightly.
            if (mullion && markX == 400 && line.key == 'diagonal') return;
            out = Measurements.apply(out.design, {Measurements.widthKey: 2800});
            expect(out.problems, isEmpty);
            expect(out.design.widthMm, closeTo(2800, 0.5));
            expect(out.design.heightMm, closeTo(1800, 0.5));
            expect(out.design.sections, hasLength(sections));
            expect(read(out.design).openings, hasLength(1));
            // Every bar of the design still has its length.
            for (final b in out.design.dividers) {
              expect(b.segment.length, greaterThan(100), reason: b.id);
            }
          });
        }
      }
    }
  });

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

  // The user's next screenshot: the width still refused, the form saying
  // only *That does not fit the parts inside it*. A mark drawn just under
  // the slope stays where it was while the frame is made taller — it is
  // still inside — and then a width turns the slope, and both ways of
  // carrying it left it above the slope, outside its own region. It is
  // carried among the region's own corners now, or to its middle where the
  // region gained or lost one; and where a size truly cannot be made, the
  // form is told why and the nearest size that fits.
  group('a mark just under a slope, and what a refusal says', () {
    // A short left jamb, a stair's slope up to a level head, a tall right
    // side; a mullion; the mark under the slope.
    Design stair({double? mullion}) => read(
      Design.empty(id: 'a', kind: DesignKind.angled).copyWith(
        sketch: Sketch(
          strokes: [
            pen('outline', const [
              Vec2(0, 900),
              Vec2(0, 700),
              Vec2(400, 300),
              Vec2(1600, 300),
              Vec2(1600, 900),
              Vec2(0, 900),
            ]),
            if (mullion case final x?) pen('m', [Vec2(x, 0), Vec2(x, 900)]),
            pen('mark', chevron(const Vec2(640, 495))),
          ],
        ),
      ),
    ).copyWith(measured: {});

    for (final mullion in [null, 800.0, 480.0]) {
      for (final height in [1800.0, 2400.0]) {
        for (final width in [2000.0, 2800.0, 4000.0]) {
          test('mullion $mullion, $height high, then $width wide', () {
            var d = stair(mullion: mullion);
            expect(d.openings, hasLength(1));
            final opening = d.openings.single.id;
            d = Measurements.apply(d, {
              Measurements.profileKey: 45,
              Measurements.barsKey: 45,
              Measurements.heightKey: height,
            }).design;
            final out = Measurements.apply(d, {Measurements.widthKey: width});
            expect(out.problems, isEmpty);
            expect(out.design.widthMm, closeTo(width, 0.5));
            final o = out.design.openings.single;
            expect(o.id, opening);
            expect(
              out.design.sectionById(o.sectionId)!.outline.contains(o.markAt!),
              isTrue,
            );
          });
        }
      }
    }

    // A triangle with a mullion near its low end: made very wide, the slope
    // runs down onto the sill beside the mullion and the opening there has
    // no room left. That is right to refuse — and the user is told so, with
    // the widest that does fit.
    Design triangle() => read(
      Design.empty(id: 'a', kind: DesignKind.angled).copyWith(
        sketch: Sketch(
          strokes: [
            pen('outline', const [
              Vec2(0, 1000),
              Vec2(0, 900),
              Vec2(1400, 0),
              Vec2(1400, 1000),
              Vec2(0, 1000),
            ]),
            pen('m', const [Vec2(420, 0), Vec2(420, 1000)]),
            pen('mark', chevron(const Vec2(560, 850))),
          ],
        ),
      ),
    ).copyWith(measured: {});

    test('a size that cannot be made says why, and the nearest that fits', () {
      final d = triangle();
      expect(d.openings, hasLength(1));
      final out = Measurements.apply(d, {Measurements.widthKey: 4000});
      final said = out.problems[Measurements.widthKey];
      expect(said, isNotNull);
      expect(said, contains('Opening 1'));
      expect(said, contains('The nearest size that fits is'));
      final nearest = out.suggestions[Measurements.widthKey]!;
      expect(nearest, greaterThan(d.widthMm));
      expect(nearest, lessThan(4000));
      // It is whole millimetres, it fits, and a centimetre more does not.
      expect(nearest, nearest.roundToDouble());
      final taken = Measurements.apply(d, {Measurements.widthKey: nearest});
      expect(taken.problems, isEmpty);
      expect(taken.design.widthMm, closeTo(nearest, 0.5));
      expect(taken.design.openings, hasLength(1));
      expect(
        Measurements.apply(d, {Measurements.widthKey: nearest + 10}).problems,
        isNotEmpty,
      );
      // The size refused changed nothing.
      expect(out.design.widthMm, d.widthMm);
    });

    test(
      'a size smaller than the border says so, with the smallest that fits',
      () {
        final d = Measurements.apply(triangle(), {
          Measurements.profileKey: 45,
        }).design;
        final out = Measurements.apply(d, {Measurements.heightKey: 50});
        expect(out.problems[Measurements.heightKey], isNotNull);
        final nearest = out.suggestions[Measurements.heightKey];
        if (nearest != null) {
          expect(
            Measurements.apply(d, {Measurements.heightKey: nearest}).problems,
            isEmpty,
          );
        }
      },
    );

    test(
      'the nearest that fits is between the size had and the size asked',
      () {
        expect(
          Measurements.nearestFitting(1000, 2000, (v) => v <= 1500.4),
          1500,
        );
        expect(Measurements.nearestFitting(1000, 500, (v) => v >= 712.2), 713);
        // Nothing moves at all: nothing to suggest.
        expect(
          Measurements.nearestFitting(1000, 2000, (v) => v <= 1000),
          isNull,
        );
      },
    );

    test('among the corners: a point keeps its place as the corners move', () {
      final square = Polygon(const [
        Vec2(0, 0),
        Vec2(100, 0),
        Vec2(100, 100),
        Vec2(0, 100),
      ]);
      final wide = Polygon(const [
        Vec2(0, 0),
        Vec2(300, 0),
        Vec2(300, 100),
        Vec2(0, 100),
      ]);
      final at = square.amongCornersIn(wide, const Vec2(25, 50))!;
      expect(at.x, closeTo(75, 1e-6));
      expect(at.y, closeTo(50, 1e-6));
      expect(
        square.amongCornersIn(square, const Vec2(13, 77))!.x,
        closeTo(13, 1e-6),
      );
      // A point just under a slope stays under it once the slope is turned.
      final raked = Polygon(const [
        Vec2(0, 400),
        Vec2(400, 0),
        Vec2(800, 0),
        Vec2(800, 600),
        Vec2(0, 600),
      ]);
      final turned = Polygon(const [
        Vec2(0, 400),
        Vec2(1600, 0),
        Vec2(2000, 0),
        Vec2(2000, 600),
        Vec2(0, 600),
      ]);
      const under = Vec2(300, 130);
      expect(raked.contains(under), isTrue);
      expect(turned.contains(raked.amongCornersIn(turned, under)!), isTrue);
      // Corners that do not pair: nothing said.
      expect(square.amongCornersIn(raked, const Vec2(50, 50)), isNull);
    });
  });
}

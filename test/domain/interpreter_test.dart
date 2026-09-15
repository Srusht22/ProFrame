import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

var _n = 0;

/// A stroke drawn by an unsteady hand: samples along the line, each nudged
/// off it by up to [wobble] millimetres.
Stroke drawn(
  List<Vec2> through, {
  double wobble = 8,
  int samplesPerLeg = 14,
  StrokeTool tool = StrokeTool.pen,
}) {
  final random = math.Random(_n + 7);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < samplesPerLeg; i++) {
      final t = i / samplesPerLeg;
      final point = through[leg].lerp(through[leg + 1], t);
      samples.add(StrokeSample(Vec2(
        point.x + (random.nextDouble() - 0.5) * wobble * 2,
        point.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples, tool: tool);
}

Design designOf(List<Stroke> strokes) {
  final at = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: strokes),
  );
}

void main() {
  setUp(() => _n = 0);

  test('a box drawn in one stroke becomes a frame', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(100, 100),
        Vec2(1100, 100),
        Vec2(1100, 2100),
        Vec2(100, 2100),
        Vec2(100, 100),
      ]),
    ]));
    expect(result.design.frame, isNotNull);
    expect(result.design.frame!.outline.corners, hasLength(4));
    expect(result.design.frame!.widthMm, closeTo(1000, 40));
    expect(result.design.frame!.heightMm, closeTo(2000, 40));
    expect(result.design.sections, hasLength(1));
  });

  test('a box drawn as four separate strokes still closes', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [Vec2(100, 100), Vec2(1100, 90)]),
      drawn(const [Vec2(1110, 110), Vec2(1095, 2100)]),
      drawn(const [Vec2(1100, 2110), Vec2(105, 2095)]),
      drawn(const [Vec2(95, 2100), Vec2(100, 105)]),
    ]));
    expect(result.design.frame, isNotNull);
    expect(result.design.sections, hasLength(1));
  });

  test('an off-centre bar stays off centre', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(310, 0), Vec2(310, 2000)]),
    ]));
    expect(result.design.dividers, hasLength(1));
    expect(result.design.sections, hasLength(2));

    final widths = [for (final s in result.design.sections) s.widthMm]..sort();
    // 310/690 before the frame profile is taken off — nowhere near equal,
    // and it must not have been made equal.
    expect(widths[1] / widths[0], greaterThan(1.7));
  });

  test('a sloped line keeps its slope', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 1000),
        Vec2(0, 1000),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(0, 0), Vec2(1000, 1000)], wobble: 4),
    ]));
    expect(result.design.dividers, hasLength(1));
    final divider = result.design.dividers.single;
    expect(divider.isVertical, isFalse);
    expect(divider.isHorizontal, isFalse);
    expect(divider.segment.headingDegrees, closeTo(45, 6));
    expect(result.design.sections, hasLength(2));
  });

  test('a line two degrees off vertical is straightened, not left crooked', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(500, 0), Vec2(530, 2000)], wobble: 3),
    ]));
    final divider = result.design.dividers.single;
    expect(divider.isVertical, isTrue);
    expect((divider.a.x - divider.b.x).abs(), lessThan(1));
  });

  test('an unequal three-by-two grid comes back unequal', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1200, 0),
        Vec2(1200, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(250, 0), Vec2(250, 2000)]),
      drawn(const [Vec2(600, 0), Vec2(600, 2000)]),
      drawn(const [Vec2(0, 1500), Vec2(1200, 1500)]),
    ]));
    expect(result.design.sections, hasLength(6));
    final widths = {
      for (final s in result.design.sections) (s.widthMm / 25).round(),
    };
    // Three genuinely different column widths survived.
    expect(widths, hasLength(3));
  });

  test('nothing is invented from an empty sketch', () {
    final result = SketchInterpreter.interpret(designOf([]));
    expect(result.design.frame, isNull);
    expect(result.design.sections, isEmpty);
    expect(result.design.dividers, isEmpty);
  });

  test('lines that do not close ask rather than guess a frame', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [Vec2(0, 0), Vec2(1000, 0)]),
      drawn(const [Vec2(0, 900), Vec2(1000, 900)]),
    ]));
    expect(result.design.frame, isNull);
    expect(result.questions.map((q) => q.id), contains('frame-not-closed'));
    // The user's lines are still there as real geometry.
    expect(result.design.dividers, hasLength(2));
  });

  test('a diagonal across a section is asked about, not assumed', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(80, 1900), Vec2(900, 1000)], wobble: 4),
    ]));
    // Nothing was made to open on its own.
    expect(result.design.openings, isEmpty);
    expect(
      result.questions.any((q) => q.id.startsWith('opening-')),
      isTrue,
    );
  });

  test('the sketch is never touched by interpreting it', () {
    final strokes = [
      drawn(const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
    ];
    final before = designOf(strokes);
    final beforeJson = before.sketch.toJson().toString();
    final result = SketchInterpreter.interpret(before);
    expect(result.design.sketch.toJson().toString(), beforeJson);
    expect(result.design.sketch.strokes, hasLength(1));
  });

  test('a five-sided opening keeps five sides', () {
    final result = SketchInterpreter.interpret(designOf([
      drawn(const [
        Vec2(0, 400),
        Vec2(500, 0),
        Vec2(1000, 400),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 400),
      ], wobble: 4),
    ]));
    expect(result.design.frame, isNotNull);
    expect(result.design.frame!.outline.corners, hasLength(5));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'hinges_round_the_back_test.dart' show pen;

// **In a sliding design `<-` and `->` are the marks.** The user's own
// drawing: an outline, two uprights, and in the light between them two
// arrows — `<-` near its left side and `->` near its right. In their words:
// *it means two opening parts; this one (<-) goes to the left side and this
// one (->) goes to the right side.*
//
// So the shaft of each arrow is part of the mark and never a bar, and the
// two marks in one light make it two panels, meeting where the drawing
// leaves room between the arrows, each sliding the way its arrow points.

/// A point of the user's screenshot, in millimetres on the sheet.
Vec2 at(double x, double y) => Vec2((x - 157) * 6, (y - 326) * 6);

Design theirDrawing({
  DesignKind kind = DesignKind.sliding,
  bool leftArrow = true,
  bool rightArrow = true,
}) {
  final time = DateTime(2026);
  return SketchInterpreter.interpret(
    Design(
      id: 'd',
      name: 'test',
      kind: kind,
      createdAt: time,
      updatedAt: time,
      sketch: Sketch(
        strokes: [
          pen('outline', [
            at(157, 326),
            at(665, 326),
            at(665, 598),
            at(157, 598),
            at(157, 326),
          ]),
          pen('upright-left', [at(305, 326), at(305, 598)]),
          pen('upright-right', [at(578, 326), at(578, 598)]),
          if (leftArrow) ...[
            pen('head-left', [at(387, 416), at(348, 452), at(376, 502)]),
            pen('shaft-left', [at(370, 455), at(425, 455)]),
          ],
          if (rightArrow) ...[
            pen('shaft-right', [at(477, 453), at(551, 453)]),
            pen('head-right', [at(533, 425), at(558, 455), at(538, 497)]),
          ],
        ],
      ),
    ),
  ).design;
}

void main() {
  final design = theirDrawing();

  test('the shafts are part of the marks, never bars', () {
    for (final bar in design.dividers) {
      expect(bar.fromStrokeId, isNot(anyOf('shaft-left', 'shaft-right')));
    }
  });

  test('two arrows in one light are two panels, each its own way', () {
    final order = design.openingsInOrder;
    expect(order, hasLength(2));
    expect(order[0].mechanism, OpeningMechanism.slidingLeft);
    expect(order[1].mechanism, OpeningMechanism.slidingRight);
    // The two lights either side are fixed, and the middle is now two.
    expect(design.topLevelSections, hasLength(4));
  });

  test('they meet half way across the gap the drawing leaves', () {
    final meeting = design.dividers.singleWhere(
      (d) => d.id.startsWith('meeting-'),
    );
    final between = (at(425, 0).x + at(477, 0).x) / 2;
    expect(meeting.segment.midpoint.x, closeTo(between, 1e-6));
    // Right across the light, head to sill.
    final daylight = design.frame!.innerOutline;
    expect(meeting.segment.length, greaterThan(daylight.height * 0.99));
  });

  test('reading it again gives the same design', () {
    final again = SketchInterpreter.interpret(design).design;
    expect(
      [for (final o in again.openingsInOrder) '${o.id} ${o.mechanism}'],
      [for (final o in design.openingsInOrder) '${o.id} ${o.mechanism}'],
    );
    expect(
      again.dividers.map((d) => d.id).toSet(),
      design.dividers.map((d) => d.id).toSet(),
    );
  });

  test('one arrow alone is one panel, and nothing is split', () {
    final one = theirDrawing(rightArrow: false);
    expect(one.openings, hasLength(1));
    expect(one.openings.single.mechanism, OpeningMechanism.slidingLeft);
    expect(one.dividers.where((d) => d.id.startsWith('meeting-')), isEmpty);
    expect(one.topLevelSections, hasLength(3));
  });

  test('a door drawn the same way is read as it always was', () {
    final door = theirDrawing(kind: DesignKind.door);
    expect(door.dividers.where((d) => d.id.startsWith('meeting-')), isEmpty);
    expect(
      door.openings.every((o) => o.mechanism.slideEdge == null),
      isTrue,
    );
  });

  test('opened, they part to either side and leave the middle clear', () {
    final order = design.openingsInOrder;
    final shut = MeshBuilder.build(design);
    final open = MeshBuilder.build(design, openFraction: 1);
    double middleOf(Mesh mesh, String id) {
      final xs = [
        for (final f in mesh.facets)
          if (f.elementId == id)
            for (final c in f.corners) c.x,
      ];
      return (xs.reduce((a, b) => a < b ? a : b) +
              xs.reduce((a, b) => a > b ? a : b)) /
          2;
    }

    expect(
      middleOf(open, order[0].sectionId),
      lessThan(middleOf(shut, order[0].sectionId)),
      reason: '<- goes to the left',
    );
    expect(
      middleOf(open, order[1].sectionId),
      greaterThan(middleOf(shut, order[1].sectionId)),
      reason: '-> goes to the right',
    );
  });
}

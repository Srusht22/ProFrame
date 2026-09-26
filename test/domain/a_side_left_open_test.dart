import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// A door drawn as a head and two jambs, a transom across near the top, and a
// `>` below it — and nothing across the foot. That is how a door frame is
// very often built, with no sill; it is also how an outline looks before it
// is finished. The drawing cannot say which, so the user is asked: *the
// design is not closed — do you want it this way, or are you going to
// change it?*
//
// Kept open, it is built exactly as drawn: no member across the bottom, and
// the leaf running down to the floor. Closed, a sill goes across between the
// two ends they drew. Either way nothing else is added, and the answer is
// the design's, so the same sheet read again is built the same way.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

const _foot = 2100.0;
const _width = 1000.0;

/// The door in the user's picture, outline in one stroke or in three.
Design door({OutlineGap? said, bool separateStrokes = false}) {
  final time = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: time,
    updatedAt: time,
    outlineGap: said,
    sketch: Sketch(strokes: [
      if (separateStrokes) ...[
        pen('head', const [Vec2(0, 0), Vec2(_width, 0)]),
        pen('left', const [Vec2(0, 0), Vec2(0, _foot)]),
        pen('right', const [Vec2(_width, 0), Vec2(_width, _foot)]),
      ] else
        pen('outline', const [
          Vec2(0, _foot),
          Vec2(0, 0),
          Vec2(_width, 0),
          Vec2(_width, _foot),
        ]),
      pen('transom', const [Vec2(0, 300), Vec2(_width, 300)]),
      pen('mark', const [Vec2(150, 600), Vec2(700, 1150), Vec2(150, 1800)]),
    ]),
  );
}

Interpretation read(Design design) => SketchInterpreter.interpret(design);

SectionElement lower(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.centroid.y > b.outline.centroid.y ? a : b);

void main() {
  group('asked, because the drawing cannot say', () {
    for (final separate in [false, true]) {
      test(separate ? 'drawn as three strokes' : 'drawn as one stroke', () {
        final result = read(door(separateStrokes: separate));
        final question = result.questions.singleWhere(
            (q) => q.id == SketchInterpreter.outlineGapQuestion);
        expect(question.prompt, contains('not closed'));
        expect(question.prompt, contains('the bottom'));
        expect(question.options.map((o) => o.key),
            ['leave-open', 'close-it', 'change-it']);
        expect(result.questions.map((q) => q.id),
            isNot(contains('frame-not-closed')));

        // Until they say, nothing is built round it and nothing is added:
        // their lines are kept exactly as lines.
        expect(result.design.frame, isNull);
        expect(result.design.dividers, hasLength(4));
      });
    }

    test('an outline drawn closed is not asked about', () {
      final time = DateTime(2026);
      final result = read(Design(
        id: 'd',
        name: 'test',
        kind: DesignKind.door,
        createdAt: time,
        updatedAt: time,
        sketch: Sketch(strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(_width, 0),
            Vec2(_width, _foot),
            Vec2(0, _foot),
            Vec2(0, 0),
          ]),
        ]),
      ));
      expect(result.design.frame, isNotNull);
      expect(result.questions.map((q) => q.id),
          isNot(contains(SketchInterpreter.outlineGapQuestion)));
    });

    Design drawn(List<Stroke> strokes) {
      final time = DateTime(2026);
      return Design(
        id: 'd',
        name: 'test',
        kind: DesignKind.door,
        createdAt: time,
        updatedAt: time,
        sketch: Sketch(strokes: strokes),
      );
    }

    test('jambs drawn a hand past a sill that is there are not a gap', () {
      // An overshoot to trim, not a side left open.
      final result = read(drawn([
        pen('head', const [Vec2(0, 0), Vec2(_width, 0)]),
        pen('left', const [Vec2(0, 0), Vec2(0, _foot + 60)]),
        pen('right', const [Vec2(_width, 0), Vec2(_width, _foot + 60)]),
        pen('sill', const [Vec2(0, _foot), Vec2(_width, _foot)]),
      ]));
      expect(result.questions.map((q) => q.id),
          isNot(contains(SketchInterpreter.outlineGapQuestion)));
      expect(result.design.frame, isNotNull);
    });

    test('a closed door with a transom near the head is not asked about', () {
      final result = read(drawn([
        pen('outline', const [
          Vec2(0, _foot),
          Vec2(0, 0),
          Vec2(_width, 0),
          Vec2(_width, _foot),
          Vec2(0, _foot),
        ]),
        pen('transom', const [Vec2(0, 300), Vec2(_width, 300)]),
      ]));
      expect(result.questions.map((q) => q.id),
          isNot(contains(SketchInterpreter.outlineGapQuestion)));
      expect(result.design.topLevelSections, hasLength(2));
    });

    test('a single line has no side missing — it has no shape at all', () {
      final time = DateTime(2026);
      final result = read(Design(
        id: 'd',
        name: 'test',
        kind: DesignKind.door,
        createdAt: time,
        updatedAt: time,
        sketch: Sketch(strokes: [
          pen('one', const [Vec2(0, 0), Vec2(_width, 0)]),
        ]),
      ));
      expect(result.questions.map((q) => q.id), ['frame-not-closed']);
    });
  });

  group('kept open, it is built as drawn', () {
    final design = read(door(said: OutlineGap.leaveOpen)).design;

    test('a frame, open along the bottom and nowhere else', () {
      final frame = design.frame!;
      expect(frame.openEdges, hasLength(1));
      final open = frame.outline.edges[frame.openEdges.single];
      expect(open.a.y, closeTo(_foot, 1));
      expect(open.b.y, closeTo(_foot, 1));
      // Nothing added round it: the outline is where the lines are.
      expect(frame.outline.bottom, closeTo(_foot, 1));
      expect(frame.outline.width, closeTo(_width, 1));
    });

    test('there is no sill to list, pick or move', () {
      final names = design.frameMembers.map((m) => m.placement).toList();
      expect(names, containsAll(['Head', 'Left jamb', 'Right jamb']));
      expect(names, isNot(contains('Sill')));
    });

    test('the door runs down to the floor', () {
      expect(design.frame!.innerOutline.bottom, closeTo(_foot, 1));
      expect(lower(design).outline.bottom, closeTo(_foot, 1));
    });

    test('the mark opens the lower light, and the transom is the one bar', () {
      expect(design.topLevelSections, hasLength(2));
      expect(design.openings, hasLength(1));
      expect(design.openings.single.sectionId, lower(design).id);
      expect(design.topLevelDividers, hasLength(1));
    });

    test('the solid builds no member across the foot', () {
      final mesh = MeshBuilder.build(design);
      final profile = design.frame!.profileMm;
      for (final facet in mesh.facets) {
        if (facet.elementId != design.frame!.id) continue;
        if (!facet.corners.every((c) => (c.y - _foot).abs() < 1)) continue;
        // At the foot there is only the cut end of each jamb.
        final xs = facet.corners.map((c) => c.x);
        expect(xs.reduce((a, b) => a > b ? a : b) -
            xs.reduce((a, b) => a < b ? a : b),
            lessThanOrEqualTo(profile + 1));
      }
    });

    test('read again, it is built the same way', () {
      final again = read(design).design;
      expect(again.frame!.openEdges, design.frame!.openEdges);
      expect(again.frame!.outline, design.frame!.outline);
      expect(read(design).questions.map((q) => q.id),
          isNot(contains(SketchInterpreter.outlineGapQuestion)));
    });

    test('a save and a reload keep it open', () {
      final loaded = Design.fromJson(design.toJson());
      expect(loaded.outlineGap, OutlineGap.leaveOpen);
      expect(loaded.frame!.openEdges, design.frame!.openEdges);
      expect(loaded.frame!.innerOutline.bottom, closeTo(_foot, 1));
    });
  });

  group('closed, a sill goes across between the ends they drew', () {
    final design = read(door(said: OutlineGap.closeIt)).design;

    test('closed all round, with a sill', () {
      expect(design.frame!.openEdges, isEmpty);
      expect(design.frameMembers.map((m) => m.placement), contains('Sill'));
      expect(design.frame!.outline.bottom, closeTo(_foot, 1));
    });

    test('and the leaf stops at the sill', () {
      expect(lower(design).outline.bottom,
          closeTo(_foot - design.frame!.profileMm, 1));
    });

    test('the solid builds the sill', () {
      final mesh = MeshBuilder.build(design);
      final spansFoot = mesh.facets.any((Facet facet) {
        if (facet.elementId != design.frame!.id) return false;
        if (!facet.corners.every((c) => (c.y - _foot).abs() < 1)) {
          return false;
        }
        final xs = facet.corners.map((c) => c.x);
        return xs.reduce((a, b) => a > b ? a : b) -
                xs.reduce((a, b) => a < b ? a : b) >
            _width / 2;
      });
      expect(spansFoot, isTrue);
    });
  });

  test('either way, the rest of the design is the same', () {
    // The answer is about one side. The transom, the mark and the opening
    // are the user's and come back the same.
    final open = read(door(said: OutlineGap.leaveOpen)).design;
    final shut = read(door(said: OutlineGap.closeIt)).design;
    expect(open.topLevelDividers.single.segment,
        shut.topLevelDividers.single.segment);
    expect(open.openings.single.mechanism, shut.openings.single.mechanism);
    expect(open.frame!.outline, shut.frame!.outline);
  });
}

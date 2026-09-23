import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The drawing the user made, traced off their screen:
//
//   ┌────┬──────┬──────┐
//   │ <  │      │      │   a small window, upper left
//   ├────┼──────┼──────┤
//   │    │      │  >   │   a door, lower right
//   │    │      │      │
//   └────┴──────┴──────┘
//
// **An end that touches a line on the sheet touches it in the design.**
//
// Their left jamb had a kink in it: upright above the transom, leaning out
// below. The outline is straightened leg by leg — a kink of a few
// centimetres in a metre is a hand's wobble, and taking it out is cleaning —
// but the straight leg then lay a hand's width left of where they had drawn
// it. The transom was drawn to *their* jamb, so it now stopped short of the
// straightened one and divided nothing on that side. The small upper light
// and the tall one beneath it ran together, and the `<` drawn in the small
// light opened the whole column from head to sill.
//
// A few millimetres either way decided it: a third of hand-wobbled copies
// of the drawing came back wrong. The fix asks the **ink** rather than the
// fit whether an end was drawn onto a line, and carries it along its own
// line to where that line now is.

/// The user's screen, in pixels, to the sheet, in millimetres.
Vec2 screen(double x, double y) => Vec2((x - 150) * 3.3, (y - 280) * 3.3);

var _random = math.Random(0);

Stroke pen(String id, List<Vec2> through, {double wobble = 0}) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 30);
      samples.add(
        StrokeSample(
          Vec2(
            at.x + (_random.nextDouble() - 0.5) * wobble,
            at.y + (_random.nextDouble() - 0.5) * wobble,
          ),
        ),
      );
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The drawing, with each point the hand put down shaken by up to
/// [shake] screen pixels.
Design drawn({double shake = 0, int seed = 0, double transomStartX = 178}) {
  _random = math.Random(seed);
  Vec2 at(double x, double y) => screen(
    x + (_random.nextDouble() - 0.5) * shake,
    y + (_random.nextDouble() - 0.5) * shake,
  );
  final wobble = shake * 1.5;
  final time = DateTime(2026);
  return SketchInterpreter.interpret(
    Design(
      id: 'd',
      name: 'test',
      kind: DesignKind.both,
      createdAt: time,
      updatedAt: time,
      sketch: Sketch(
        strokes: [
          pen('outline', wobble: wobble, [
            at(162, 293),
            at(668, 285),
            at(678, 340),
            at(680, 440),
            at(668, 500),
            at(662, 630),
            at(520, 648),
            at(300, 645),
            at(165, 607),
            at(150, 600),
            at(155, 520),
            at(165, 450),
            at(178, 378),
            at(178, 290),
          ]),
          pen('transom', wobble: wobble, [
            at(transomStartX, 376),
            at(595, 376),
            at(600, 372),
            at(680, 370),
          ]),
          pen('mullion-left', wobble: wobble, [
            at(315, 288),
            at(303, 378),
            at(303, 450),
            at(298, 625),
          ]),
          pen('mullion-right', wobble: wobble, [
            at(470, 283),
            at(470, 375),
            at(465, 640),
          ]),
          pen('window', [at(303, 295), at(232, 325), at(303, 378)]),
          pen('door', [at(470, 378), at(653, 510), at(480, 658)]),
        ],
      ),
    ),
  ).design;
}

SectionElement windowLight(Design design) => design.sectionById(
  design.openings.firstWhere((o) => o.id == 'opening-window').sectionId,
)!;

void main() {
  group('the drawing as it was made', () {
    test('six lights: the transom divides every column', () {
      final design = drawn();
      expect(design.topLevelSections, hasLength(6));
      expect(design.topLevelDividers, hasLength(3));
      expect(design.openings, hasLength(2));
    });

    test('the window is the small upper light and nothing more', () {
      final design = drawn();
      final light = windowLight(design);
      final transom = design.dividers.firstWhere(
        (b) => b.fromStrokeId == 'transom',
      );

      // It is above the transom, all of it — not a column from head to sill.
      expect(light.outline.bottom, lessThan(transom.a.y));
      expect(
        light.outline.height,
        lessThan(design.frame!.innerOutline.height / 3),
      );
    });

    test('the transom reaches the jamb it was drawn to', () {
      final design = drawn();
      final transom = design.dividers.firstWhere(
        (b) => b.fromStrokeId == 'transom',
      );
      final daylight = design.frame!.innerOutline;
      final left = math.min(transom.a.x, transom.b.x);
      expect(
        left,
        lessThanOrEqualTo(daylight.left),
        reason: 'it crosses the daylight rather than stopping inside it',
      );
    });
  });

  group('however a hand draws it', () {
    test('a steady hand and an ordinary one read the same', () {
      // Every point shaken by up to three screen pixels, and every sample
      // along every line by a few millimetres more. The user's own transom
      // ended within two pixels of their jamb.
      //
      // **The limit is a weld, and it is stated rather than hidden.** An end
      // more than a weld from the ink of a line — a hundredth of the
      // design's diagonal, some two centimetres here — was not drawn onto
      // it, by the same measure the rest of the reading uses for whether two
      // lines meet. Shake every point by six pixels and some transom ends
      // land out there, where whether the line was meant to touch the jamb
      // is a question the drawing no longer answers.
      final wrong = <String>[];
      for (final shake in [0.0, 3.0, 6.0]) {
        for (var seed = 0; seed < 40; seed++) {
          final design = drawn(shake: shake, seed: seed);
          if (design.topLevelSections.length != 6 ||
              design.openings.length != 2 ||
              windowLight(design).outline.height >
                  design.frame!.innerOutline.height / 3) {
            wrong.add('shake $shake, seed $seed');
          }
        }
      }
      expect(wrong, isEmpty);
    });

    test('the transom started a little either side of the jamb', () {
      // Within a weld of the jamb's ink, either side of it.
      for (final startX in [172.0, 174.0, 176.0, 178.0, 180.0, 182.0]) {
        final design = drawn(transomStartX: startX);
        expect(design.topLevelSections, hasLength(6), reason: 'start $startX');
      }
    });
  });

  group('and only a line drawn onto another is carried to it', () {
    test('the angle it was drawn at is kept', () {
      // Carried along its own line, so nothing is turned to meet the frame.
      final steady = drawn();
      final transom = steady.dividers.firstWhere(
        (b) => b.fromStrokeId == 'transom',
      );
      expect(
        transom.segment.offAxisDegrees,
        lessThan(1),
        reason: 'drawn level, so it stays level',
      );
    });

    test('a line that stops short of the jamb stays short', () {
      // A line drawn to reach part way is the drawing, not a wobble: it is
      // nowhere near the ink of the jamb, so nothing carries it there.
      final design = drawn(transomStartX: 230);
      final transom = design.dividers.firstWhere(
        (b) => b.fromStrokeId == 'transom',
      );
      final left = math.min(transom.a.x, transom.b.x);
      expect(
        left,
        closeTo(screen(230, 0).x, 1),
        reason: 'its end is where the user put it',
      );
      expect(
        design.topLevelSections,
        hasLength(5),
        reason: 'and so it divides nothing on that side',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user marks a leaf `>`, then on its panel makes it hinge the other way,
// or bottom hung, or open outward, or carry a knob. Then they read the sheet
// again.
//
// **A reading re-reads the drawing; it does not overturn what the user said
// about it.** The mark said which way the leaf opened the first time it was
// read. A mark still saying exactly that is the same mark read again — not a
// new instruction — so their change stands. It used to be read back off the
// mark every time, and every change they had made went back to the first.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A `>` in the right-hand light — `<` when [pointingLeft].
Stroke mark(String id, {bool pointingLeft = false}) {
  const at = Vec2(1800, 1050);
  final tip = pointingLeft ? -55.0 : 55.0;
  return pen(id, [
    Vec2(at.x - tip, at.y - 110),
    Vec2(at.x + tip, at.y),
    Vec2(at.x - tip, at.y + 110),
  ]);
}

Design read(Design design) => SketchInterpreter.interpret(design).design;

Design drawn({Stroke? withMark}) {
  final time = DateTime(2026);
  return read(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: time,
    updatedAt: time,
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(2400, 0),
        Vec2(2400, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
      withMark ?? mark('k'),
    ]),
  ));
}

OpeningElement theLeaf(Design design) => design.openings.single;

/// The same sheet, read again.
Design again(Design design) => read(design);

void main() {
  test('the mark decides the first time', () {
    expect(theLeaf(drawn()).mechanism, OpeningMechanism.hingedLeft);
  });

  test('hinged the other way, it stays hinged the other way', () {
    var design = drawn();
    design = DesignEdits.setOpeningMechanism(
        design, theLeaf(design).id, OpeningMechanism.hingedRight);

    final after = again(design);
    expect(theLeaf(after).mechanism, OpeningMechanism.hingedRight);
    // And the ironmongery that follows from it is on the other stile too.
    final section = after.sectionById(theLeaf(after).sectionId)!;
    for (final hinge
        in after.hardware.where((p) => p.kind == HardwareKind.hinge)) {
      expect(hinge.at.x, closeTo(section.outline.right, 1));
    }
  });

  test('bottom hung stays bottom hung', () {
    var design = drawn();
    design = DesignEdits.setOpeningMechanism(
        design, theLeaf(design).id, OpeningMechanism.bottomHung);
    expect(theLeaf(again(design)).mechanism, OpeningMechanism.bottomHung);
  });

  test('outward stays outward', () {
    var design = drawn();
    design = DesignEdits.setOpeningSwing(
        design, theLeaf(design).id, OpeningDirection.outward);
    expect(theLeaf(again(design)).direction, OpeningDirection.outward);
  });

  test('a knob stays a knob', () {
    var design = drawn();
    final leaf = theLeaf(design);
    design = OpeningHardwareFree.withHandle(design, leaf.id, HardwareKind.knob);
    expect(theLeaf(again(design)).handleKind, HardwareKind.knob);
  });

  test('read any number of times, it is still what they said', () {
    var design = drawn();
    design = DesignEdits.setOpeningMechanism(
        design, theLeaf(design).id, OpeningMechanism.topHung);
    for (var i = 0; i < 4; i++) {
      design = again(design);
    }
    expect(theLeaf(design).mechanism, OpeningMechanism.topHung);
  });

  test('the mark is still the one they drew, and still says what it said', () {
    // Nothing about the mark itself is rewritten to agree with the change:
    // the panel says "the mark was >, you have since changed it", and that
    // is only true while the mark is left as it was drawn.
    var design = drawn();
    design = DesignEdits.setOpeningMechanism(
        design, theLeaf(design).id, OpeningMechanism.hingedRight);
    final after = again(design);
    expect(theLeaf(after).markGlyph, '>');
  });

  test('a mark rubbed out and drawn afresh is a new instruction', () {
    var design = drawn();
    design = DesignEdits.setOpeningMechanism(
        design, theLeaf(design).id, OpeningMechanism.bottomHung);

    // The user rubs out their `>` and draws a `<` in its place.
    design = design.copyWith(
      sketch: Sketch(strokes: [
        for (final s in design.sketch.strokes)
          if (s.id != 'k') s,
        mark('k2', pointingLeft: true),
      ]),
    );
    expect(theLeaf(again(design)).mechanism, OpeningMechanism.hingedRight,
        reason: 'the new mark says so, and it is the latest thing said');
  });
}

/// Setting the handle form the way the panel does it.
abstract final class OpeningHardwareFree {
  static Design withHandle(Design design, String openingId, HardwareKind kind) {
    final opening = design.openingById(openingId)!;
    return design.withElement(opening.copyWith(handleKind: kind));
  }
}

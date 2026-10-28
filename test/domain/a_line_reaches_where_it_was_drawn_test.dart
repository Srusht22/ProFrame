import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// A line put into a section reaches where the user drew it.
//
//   ┌───────────────┐        ┌───────────────┐
//   │               │        │               │
//   ├───────────────┤        ├───────────────┤
//   │       │       │        │       │       │
//   │       │       │        │       │       │
//   └───────┴───────┘        └───────┴───────┘
//     the drawing              what gets built
//
// An upright drawn from the rail down to the sill used to come back running
// head to sill, and the sash had four panes where the drawing showed three.
// Taking an end out to the far side of a section is not cleaning a line, it
// is drawing a division nobody drew.
//
// The two things that *are* cleaning still happen, and they are not
// symmetrical: a line drawn past the edge is trimmed back to it whatever the
// distance, because outside the section it is not the section's anyway; a
// line drawn a few millimetres short is welded to it, because inside a
// section those few millimetres are the difference between two panes and one
// pane with a line lying on it.

/// A door whose whole daylight is one leaf, with [mark] to follow.
Design leaf() {
  final at = DateTime(2026);
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'Door',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 1000, 1400),
      profileMm: 60,
    ),
  ));
  return DesignEdits.setOpening(
    design,
    design.topLevelSections.single.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markAt: const Vec2(300, 1000),
    markGlyph: '>',
  );
}

Design putIn(Design design, String barId) => DesignEdits.setDividerParent(
    design, barId, design.openings.single.sectionId);

Polygon leafOf(Design design) =>
    design.sectionById(design.openings.single.sectionId)!.outline;

void main() {
  test('an upright drawn half way stays half way', () {
    var design = leaf();
    final box = leafOf(design);

    design = DesignEdits.addDivider(design, id: 'rail',
        a: Vec2(0, box.centroid.y), b: Vec2(1000, box.centroid.y));
    design = putIn(design, 'rail');

    // From the rail down to the sill. Nothing above it.
    design = DesignEdits.addDivider(design, id: 'upright',
        a: Vec2(520, box.centroid.y), b: const Vec2(520, 1400));
    design = putIn(design, 'upright');

    final bar = design.dividerById('upright')!;
    final now = leafOf(design);
    expect(bar.segment.a.y, closeTo(box.centroid.y, 1),
        reason: 'the top end was taken up to the head');
    expect(bar.segment.b.y, closeTo(now.bottom, 1),
        reason: 'the bottom end ran past the sill and is trimmed to it');

    // And so the leaf is the three panes the drawing shows, not four.
    final panes = design.childSectionsOf(design.openings.single.sectionId);
    expect(panes, hasLength(3));
    expect(
      panes.where((p) => p.outline.top < box.centroid.y),
      hasLength(1),
      reason: 'one undivided pane above the rail',
    );
    expect(
      panes.where((p) => p.outline.top > box.centroid.y),
      hasLength(2),
      reason: 'two panes below it, split by the upright',
    );
  });

  group('and the two things that are cleaning still happen', () {
    test('a line drawn past the edge is trimmed back to it', () {
      var design = leaf();
      final box = leafOf(design);

      design = DesignEdits.addDivider(design, id: 'over',
          a: Vec2(box.left - 25, box.centroid.y),
          b: Vec2(box.right + 25, box.centroid.y));
      design = putIn(design, 'over');

      final bar = design.dividerById('over')!;
      final now = leafOf(design);
      expect(bar.segment.a.x, closeTo(now.left, 1));
      expect(bar.segment.b.x, closeTo(now.right, 1));
      expect(design.childSectionsOf(design.openings.single.sectionId),
          hasLength(2));
    });

    test('a line drawn a few millimetres short is welded to it', () {
      var design = leaf();
      final box = leafOf(design);

      design = DesignEdits.addDivider(design, id: 'short',
          a: Vec2(box.left + 4, box.centroid.y),
          b: Vec2(box.right - 4, box.centroid.y));
      design = putIn(design, 'short');

      final bar = design.dividerById('short')!;
      final now = leafOf(design);
      expect(bar.segment.a.x, closeTo(now.left, 1),
          reason: 'four millimetres is a hand, not a decision');
      expect(bar.segment.b.x, closeTo(now.right, 1));
      expect(design.childSectionsOf(design.openings.single.sectionId),
          hasLength(2), reason: 'the face closes, so there are two panes');
    });
  });

}

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/opening_symbol.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

/// Two columns, the left one opening, hinged left.
Design twoColumns() {
  final at = DateTime(2026);
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 1600, 2100),
      profileMm: 60,
    ),
    dividers: const [
      DividerElement(
        id: 'm',
        a: Vec2(600, 0),
        b: Vec2(600, 2100),
        widthMm: 50,
      ),
    ],
  ));
  final left = design.sections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  return DesignEdits.setOpening(
    design,
    left.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markAt: left.outline.centroid,
    markGlyph: '>',
    fromStrokeId: 'mark',
  );
}

/// Where the leaf ends up when it is swung right open, so the hinge edge can
/// be read back out of the model.
({double minX, double maxX, double minY, double maxY, double z}) leafAt(
  Design design,
) {
  final mesh = MeshBuilder.build(design, openFraction: 1);
  var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9, z = 0.0;
  for (final facet in mesh.facets) {
    if (facet.role != FacetRole.sash) continue;
    for (final c in facet.corners) {
      if (c.x < minX) minX = c.x;
      if (c.x > maxX) maxX = c.x;
      if (c.y < minY) minY = c.y;
      if (c.y > maxY) maxY = c.y;
      if (c.z.abs() > z.abs()) z = c.z;
    }
  }
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY, z: z);
}

void main() {
  group('the opening is an object of its own', () {
    test('it can be selected by tapping the mark', () {
      final design = twoColumns();
      final opening = design.openings.single;
      final hit = DesignEdits.hitTest(design, opening.markAt!, slopMm: 40);
      expect(hit, isA<OpeningElement>());
      expect(hit!.id, opening.id);
    });

    test('tapping elsewhere in the same section still picks the section', () {
      final design = twoColumns();
      final section = design.sectionById(design.openings.single.sectionId)!;
      final corner = Vec2(
        section.outline.left + 30,
        section.outline.top + 30,
      );
      expect(
        DesignEdits.hitTest(design, corner, slopMm: 12),
        isA<SectionElement>(),
      );
    });

    test('it knows its own size and where it is', () {
      final design = twoColumns();
      final opening = design.openings.single;
      final section = design.sectionById(opening.sectionId)!;
      expect(section.widthMm, closeTo(515, 1));
      expect(section.heightMm, closeTo(1980, 1));
      expect(opening.markGlyph, '>');
      expect(opening.label, contains('>'));
    });
  });

  group('changing the direction', () {
    test('> to < swings the leaf about the other side', () {
      final design = twoColumns();
      final before = leafAt(design);
      final section = design.sectionById(design.openings.single.sectionId)!;

      // Hinged left: the left edge stays put and the right edge comes away.
      expect(before.minX, closeTo(section.outline.left, 1));

      final flipped = DesignEdits.setOpeningMechanism(
        design,
        'o',
        OpeningMechanism.hingedRight,
      );
      final after = leafAt(flipped);

      // Hinged right: now the right edge stays and the left comes away.
      expect(after.maxX, closeTo(section.outline.right, 1));
      expect(after.minX, greaterThan(before.minX + 100));
    });

    test('^ hinges the leaf at the bottom', () {
      final design = DesignEdits.setOpeningMechanism(
        twoColumns(),
        'o',
        OpeningMechanism.bottomHung,
      );
      final section = design.sectionById(design.openings.single.sectionId)!;
      final leaf = leafAt(design);
      expect(leaf.maxY, closeTo(section.outline.bottom, 1));
      expect(leaf.minY, greaterThan(section.outline.top + 100));
    });

    test('v hinges the leaf at the top', () {
      final design = DesignEdits.setOpeningMechanism(
        twoColumns(),
        'o',
        OpeningMechanism.topHung,
      );
      final section = design.sectionById(design.openings.single.sectionId)!;
      final leaf = leafAt(design);
      expect(leaf.minY, closeTo(section.outline.top, 1));
      expect(leaf.maxY, lessThan(section.outline.bottom - 100));
    });

    test('the drawing shows the direction it is now, not the one drawn', () {
      final design = DesignEdits.setOpeningMechanism(
        twoColumns(),
        'o',
        OpeningMechanism.hingedRight,
      );
      final opening = design.openings.single;
      // What it does now.
      expect(opening.mechanism.glyph, '<');
      // And the record of what was drawn is kept, so the two can be shown
      // side by side rather than one quietly replacing the other.
      expect(opening.markGlyph, '>');
    });

    test('changing the direction changes nothing else', () {
      final before = twoColumns();
      final after = DesignEdits.setOpeningMechanism(
        before,
        'o',
        OpeningMechanism.topHung,
      );

      expect(after.sections.length, before.sections.length);
      expect(after.dividers.length, before.dividers.length);
      expect(after.frame!.outline.corners, before.frame!.outline.corners);
      for (var i = 0; i < before.sections.length; i++) {
        expect(after.sections[i].outline.corners,
            before.sections[i].outline.corners);
        expect(after.sections[i].finish, before.sections[i].finish);
      }
      expect(after.openings.single.sectionId, before.openings.single.sectionId);
    });

    test('inward and outward swing opposite ways', () {
      final inward = twoColumns();
      final outward = DesignEdits.setOpeningSwing(
        inward,
        'o',
        OpeningDirection.outward,
      );
      expect(leafAt(inward).z * leafAt(outward).z, lessThan(0));
    });
  });

  group('changing the size', () {
    test('setting the width moves the bar beside it, nothing else', () {
      final before = twoColumns();
      final section = before.sectionById(before.openings.single.sectionId)!;

      final after =
          DesignEdits.setSectionWidth(before, section.id, 900);

      final grown = after.sectionById(after.openings.single.sectionId)!;
      expect(grown.widthMm, closeTo(900, 2));
      expect(after.frame!.widthMm, closeTo(before.frame!.widthMm, 0.01));
      expect(after.openings.single.mechanism,
          before.openings.single.mechanism);
      // The other column gave up exactly the difference and no more: it was
      // 915 wide, the bar moved 385, so it is 530. Nothing was invented and
      // nothing was rebalanced.
      final other = after.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      expect(other.widthMm, closeTo(530, 3));
    });

    test('the leaf in the model follows the section it is on', () {
      var design = twoColumns();
      final section = design.sectionById(design.openings.single.sectionId)!;
      design = DesignEdits.setSectionWidth(design, section.id, 900);

      final grown = design.sectionById(design.openings.single.sectionId)!;
      final leaf = leafAt(design);
      expect(leaf.minX, closeTo(grown.outline.left, 1));
    });
  });

  group('changing which section opens', () {
    test('the opening moves and the old section stops opening', () {
      final before = twoColumns();
      final right = before.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      final left = before.sections
          .reduce((a, b) => a.outline.left < b.outline.left ? a : b);

      final after = DesignEdits.moveOpeningToSection(before, 'o', right.id);

      expect(after.openings, hasLength(1));
      expect(after.openings.single.sectionId, right.id);
      expect(after.openingOf(left.id), isNull);
      expect(after.openingOf(right.id), isNotNull);
    });

    test('neither section changes shape', () {
      final before = twoColumns();
      final right = before.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', right.id);

      for (var i = 0; i < before.sections.length; i++) {
        expect(after.sections[i].outline.corners,
            before.sections[i].outline.corners);
      }
      expect(after.dividers.single.a, before.dividers.single.a);
    });

    test('the leaf in the model moves with it', () {
      final before = twoColumns();
      final right = before.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', right.id);

      expect(leafAt(before).minX, lessThan(600));
      expect(leafAt(after).minX, greaterThan(600));
    });

    test('moving it onto a section that already opens leaves one opening', () {
      var design = twoColumns();
      final right = design.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      design = DesignEdits.setOpening(
        design,
        right.id,
        openingId: 'o2',
        mechanism: OpeningMechanism.topHung,
      );
      expect(design.openings, hasLength(2));

      design = DesignEdits.moveOpeningToSection(design, 'o', right.id);
      expect(design.openings, hasLength(1));
      expect(design.openings.single.id, 'o');
    });
  });

  group('turning it off', () {
    test('setting it to fixed removes the opening and leaves the glass', () {
      final before = twoColumns();
      final after =
          DesignEdits.setOpeningMechanism(before, 'o', OpeningMechanism.fixed);

      expect(after.openings, isEmpty);
      expect(after.sections.length, before.sections.length);
      expect(
        MeshBuilder.build(after).facets.any((f) => f.role == FacetRole.sash),
        isFalse,
      );
      expect(
        MeshBuilder.build(after).facets.any((f) => f.role == FacetRole.glazing),
        isTrue,
      );
    });
  });

  group('every mark has a mechanism and back again', () {
    test('the four marks and the four mechanisms line up', () {
      expect(OpeningMechanism.hingedLeft.glyph, '>');
      expect(OpeningMechanism.hingedRight.glyph, '<');
      expect(OpeningMechanism.bottomHung.glyph, '^');
      expect(OpeningMechanism.topHung.glyph, 'v');
      expect(SymbolDirection.forMechanism(OpeningMechanism.slidingLeft), isNull);
    });
  });
}

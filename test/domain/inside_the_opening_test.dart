import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

/// The design the phase asks for: a window 200 cm by 160 cm of daylight,
/// with a mullion putting a 40 cm light down the left of it.
///
/// The frame is drawn round that daylight rather than the other way about,
/// so the figures below are the figures the phase quotes: the left light is
/// exactly 40 cm by 160 cm.
Design window() {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2100, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'mull', a: Vec2(470, 0), b: Vec2(470, 1700), widthMm: 40),
    ],
  ));
}

SectionElement leftLight(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.left < b.outline.left ? a : b);

/// The left light marked `<` — hinged on the right, opening from the left.
Design marked(Design design) {
  final light = leftLight(design);
  return DesignEdits.setOpening(
    design,
    light.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: light.outline.centroid,
  );
}

/// The user drawing a horizontal line inside the opening, 40 cm down it.
Design divided(Design design, {double downMm = 400, String id = 'inner'}) {
  final opening = design.openings.single.sectionId;
  final box = design.sectionById(opening)!.outline;
  return DesignEdits.addLineInside(
    design,
    opening,
    id: id,
    at: Vec2(box.centroid.x, box.top + downMm),
    horizontal: true,
  );
}

SectionElement upper(Design design, String openingId) => design
    .childSectionsOf(openingId)
    .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

SectionElement lower(Design design, String openingId) => design
    .childSectionsOf(openingId)
    .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

void main() {
  group('the phase’s own scenario', () {
    test('the window is 200 by 160 with a 40 cm light down the left', () {
      final design = window();
      expect(Units.format(design.frame!.innerOutline.width), '200');
      expect(Units.format(design.frame!.innerOutline.height), '160');

      final light = leftLight(design);
      expect(Units.format(light.widthMm), '40');
      expect(Units.format(light.heightMm), '160');
    });

    test('marking it < makes it an opening and divides nothing', () {
      final design = marked(window());

      expect(design.openings, hasLength(1));
      expect(design.openings.single.markGlyph, '<');
      expect(design.openings.single.mechanism.hingeEdge, OpeningEdge.right);
      // Nothing was added inside it. An opening with no line drawn in it is
      // one pane, however tall.
      expect(design.childSectionsOf(design.openings.single.sectionId),
          isEmpty);
      expect(design.childDividersOf(design.openings.single.sectionId),
          isEmpty);
    });

    test('a line drawn inside gives glass over panel, and one opening', () {
      final before = marked(window());
      final design = divided(before);
      final openingId = design.openings.single.sectionId;

      // Still two main divisions: the opening did not end and nothing new
      // appeared beside it.
      expect(design.topLevelSections, hasLength(2));
      expect(design.topLevelDividers, hasLength(1));
      expect(design.openings, hasLength(1));

      // And inside it, one bar and the two panes it makes.
      expect(design.childDividersOf(openingId), hasLength(1));
      expect(design.childSectionsOf(openingId), hasLength(2));
      expect(design.sectionById(openingId)!.widthMm,
          closeTo(before.sectionById(openingId)!.widthMm, 0.01));
      expect(design.sectionById(openingId)!.heightMm,
          closeTo(before.sectionById(openingId)!.heightMm, 0.01));
    });

    test('the bar is laid right across the opening, and only across it', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      final bar = design.childDividersOf(openingId).single;

      expect(bar.isHorizontal, isTrue);
      expect(bar.a.x, closeTo(box.left, 0.5));
      expect(bar.b.x, closeTo(box.right, 0.5));
      expect(bar.segment.midpoint.y, closeTo(box.top + 400, 0.5));
      // It stops at the opening. It does not run on into the fixed light.
      expect(bar.b.x, lessThan(design.frame!.innerOutline.right));
    });

    test('the two panes and the bar fill the opening exactly', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final opening = design.sectionById(openingId)!;
      final bar = design.childDividersOf(openingId).single;

      final glass = upper(design, openingId);
      final panel = lower(design, openingId);

      expect(Units.format(glass.widthMm), '40');
      expect(Units.format(panel.widthMm), '40');
      // A real divider is real material, and takes its own thickness out of
      // the opening. Nothing is lost and nothing is invented.
      expect(
        glass.heightMm + bar.widthMm + panel.heightMm,
        closeTo(opening.heightMm, 0.5),
      );
      expect(glass.outline.top, closeTo(opening.outline.top, 0.01));
      expect(panel.outline.bottom, closeTo(opening.outline.bottom, 0.01));
    });

    test('the hierarchy is the one the phase asks for', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;

      // Window → the main light, and the opening.
      expect(
        {for (final s in design.topLevelSections) s.id},
        contains(openingId),
      );
      // Opening → glass, internal divider, panel, hinges, handle.
      final inside = design.descendantsOf(openingId);
      expect(inside.whereType<SectionElement>(), hasLength(2));
      expect(inside.whereType<DividerElement>(), hasLength(1));

      final hardware = [
        for (final piece in design.hardware)
          if (piece.parentId == openingId) piece.kind,
      ];
      expect(hardware, contains(HardwareKind.hinge));
      expect(hardware, contains(HardwareKind.handle));
    });
  });

  group('the user says what each pane is', () {
    test('glass above and panel below, and neither touches the other', () {
      var design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;

      final glass = upper(design, openingId);
      final panel = lower(design, openingId);
      final was = glass.outline.corners.toString();

      design = design.withElement(panel.copyWith(
        finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
      ));

      expect(design.sectionById(panel.id)!.finish.material,
          MaterialKind.panel);
      expect(design.sectionById(glass.id)!.finish.material.isGlazing, isTrue);
      expect(design.sectionById(glass.id)!.outline.corners.toString(), was);
    });

    test('nothing decides for them', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      // Both panes come back as what a pane is until the user says
      // otherwise. Nothing looked at where they are and decided.
      for (final pane in design.childSectionsOf(openingId)) {
        expect(pane.finish.material.isGlazing, isTrue);
      }
    });
  });

  group('the figures inside the opening', () {
    test('typing the glass height moves the internal bar and nothing else',
        () {
      final before = divided(marked(window()));
      final openingId = before.openings.single.sectionId;
      final openingWas = before.sectionById(openingId)!.heightMm;
      final overallWas = before.heightMm;
      final fixedWas = before.topLevelSections
          .firstWhere((s) => s.id != openingId)
          .outline
          .corners
          .toString();

      final after = DesignEdits.setSectionHeight(
        before,
        upper(before, openingId).id,
        Units.toMm(50),
      );

      expect(Units.format(upper(after, openingId).heightMm), '50');
      // The panel gave up what the glass gained, and the opening, the
      // design and the light beside it did not move at all.
      expect(after.sectionById(openingId)!.heightMm,
          closeTo(openingWas, 0.5));
      expect(after.heightMm, closeTo(overallWas, 0.01));
      expect(
        after.topLevelSections
            .firstWhere((s) => s.id != openingId)
            .outline
            .corners
            .toString(),
        fixedWas,
      );
    });

    test('a bar can be placed by how far down the opening it is', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final bar = design.childDividersOf(openingId).single;
      final box = design.sectionById(openingId)!.outline;

      final moved =
          DesignEdits.moveDividerWithin(design, bar.id, Units.toMm(60));

      final now = moved.dividers.firstWhere((d) => d.id == bar.id);
      expect(now.segment.midpoint.y, closeTo(box.top + 600, 0.5));
      expect(design.sectionHolding(now.parentId), openingId);
      expect(moved.topLevelSections, hasLength(2));
    });

    test('where a pane is, is said in the opening’s own terms', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final panel = lower(design, openingId);

      final at = DesignEdits.within(design, openingId, panel.outline.topLeft)!;
      expect(at.x, closeTo(0, 0.5));
      expect(at.y, closeTo(400 + design.childDividersOf(openingId).single.widthMm / 2, 1));
    });
  });

  group('the opening carries what is in it', () {
    test('moving the opening takes the bar and the panes with it', () {
      final before = divided(marked(window()));
      final openingId = before.openings.single.sectionId;
      final barWas = before
          .childDividersOf(openingId)
          .single
          .segment
          .midpoint
          .y -
          before.sectionById(openingId)!.outline.top;

      // Widen the opening by moving the mullion that bounds it.
      final after = DesignEdits.moveDivider(before, 'mull', const Vec2(300, 0));

      final bar = after.childDividersOf(openingId).single;
      final box = after.sectionById(openingId)!.outline;
      expect(after.childSectionsOf(openingId), hasLength(2));
      expect(bar.a.x, closeTo(box.left, 1));
      expect(bar.b.x, closeTo(box.right, 1));
      // It stayed where it was in the opening, in proportion.
      expect(
        (bar.segment.midpoint.y - box.top) / box.height,
        closeTo(barWas / before.sectionById(openingId)!.heightMm, 0.02),
      );
    });

    test('the internal bar and panes swing with the leaf', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final barId = design.childDividersOf(openingId).single.id;
      final paneIds = {
        for (final s in design.childSectionsOf(openingId)) s.id,
      };

      double frontOf(double open, Set<String> ids) {
        var front = -1e9;
        for (final facet
            in MeshBuilder.build(design, openFraction: open).facets) {
          if (!ids.contains(facet.elementId)) continue;
          for (final corner in facet.corners) {
            if (corner.z > front) front = corner.z;
          }
        }
        return front;
      }

      expect(frontOf(0.4, {barId}), greaterThan(frontOf(0, {barId}) + 50));
      expect(frontOf(0.4, paneIds), greaterThan(frontOf(0, paneIds) + 50));
    });
  });

  group('the model has the structure, not a picture of it', () {
    test('there is a real bar between the glass and the panel', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final barId = design.childDividersOf(openingId).single.id;

      final bars = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role == FacetRole.bar) facet.elementId,
      };
      expect(bars, contains(barId));

      // And it is a solid, not a line: it has a front, a back and sides.
      final facets = [
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.elementId == barId) facet,
      ];
      expect(facets.length, greaterThan(3));
    });

    test('the panes in the model are the children, not the opening', () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;

      final filled = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role == FacetRole.glazing ||
              facet.role == FacetRole.panel)
            facet.elementId,
      };
      expect(filled, isNot(contains(openingId)),
          reason: 'a container is not filled; its children fill it');
      for (final child in design.childSectionsOf(openingId)) {
        expect(filled, contains(child.id));
      }
    });
  });

  group('the user decides how many divisions', () {
    test('an opening with nothing drawn in it stays one pane', () {
      final design = marked(window());
      final openingId = design.openings.single.sectionId;

      expect(design.childDividersOf(openingId), isEmpty);
      expect(design.childSectionsOf(openingId), isEmpty);
      expect(design.hasChildren(openingId), isFalse);

      final filled = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role == FacetRole.glazing ||
              facet.role == FacetRole.panel)
            facet.elementId,
      };
      expect(filled, contains(openingId));
    });

    test('three lines make four panes, and still one opening', () {
      var design = marked(window());
      for (final (i, down) in [400.0, 700.0, 1000.0].indexed) {
        design = divided(design, downMm: down, id: 'in-$i');
      }
      final openingId = design.openings.single.sectionId;

      expect(design.childDividersOf(openingId), hasLength(3));
      expect(design.childSectionsOf(openingId), hasLength(4));
      expect(design.topLevelSections, hasLength(2));
      expect(design.openings, hasLength(1));
    });

    test('a vertical line inside divides the opening, not the design', () {
      var design = marked(window());
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(
        design,
        openingId,
        id: 'up',
        at: Vec2(box.centroid.x, box.centroid.y),
        horizontal: false,
      );

      final bar = design.childDividersOf(openingId).single;
      expect(bar.isVertical, isTrue);
      expect(design.childSectionsOf(openingId), hasLength(2));
      expect(design.topLevelSections, hasLength(2));
    });

    test('lines both ways make a grid inside the opening', () {
      var design = marked(window());
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(design, openingId,
          id: 'across', at: Vec2(box.centroid.x, box.top + 800), horizontal: true);
      design = DesignEdits.addLineInside(design, openingId,
          id: 'up', at: Vec2(box.left + 200, box.centroid.y), horizontal: false);

      expect(design.childSectionsOf(openingId), hasLength(4));
      expect(design.topLevelSections, hasLength(2));
    });

    test('a line that misses the opening puts nothing anywhere', () {
      final before = marked(window());
      final openingId = before.openings.single.sectionId;

      // A vertical standing in the fixed light beside the opening. It never
      // crosses the opening, so there is nothing to lay across it.
      final beside = DesignEdits.addDividerInside(
        before,
        openingId,
        id: 'stray',
        a: const Vec2(1400, 900),
        b: const Vec2(1400, 901),
      );
      expect(beside.dividers.any((d) => d.id == 'stray'), isFalse);
      expect(beside.dividers, hasLength(before.dividers.length));

      // A horizontal below the sill. The same.
      final under = DesignEdits.addDividerInside(
        before,
        openingId,
        id: 'gone',
        a: const Vec2(0, 1690),
        b: const Vec2(2100, 1690),
      );
      expect(under.dividers.any((d) => d.id == 'gone'), isFalse);
      expect(under.topLevelSections, hasLength(2));
    });
  });

  group('picking a part of an opening finds the opening', () {
    test('from the opening, its section, its bar, its pane and its handle',
        () {
      final design = divided(marked(window()));
      final openingId = design.openings.single.sectionId;
      final barId = design.childDividersOf(openingId).single.id;
      final paneId = upper(design, openingId).id;
      final handleId = design.hardware
          .firstWhere((p) => p.kind == HardwareKind.handle)
          .id;

      for (final id in [
        design.openings.single.id,
        openingId,
        barId,
        paneId,
        handleId,
      ]) {
        expect(DesignEdits.openingAround(design, id), openingId,
            reason: 'picking $id should offer the opening to draw in');
      }
    });

    test('nothing outside an opening offers one', () {
      final design = divided(marked(window()));
      final fixed = design.topLevelSections
          .firstWhere((s) => s.id != design.openings.single.sectionId);

      expect(DesignEdits.openingAround(design, fixed.id), isNull);
      expect(DesignEdits.openingAround(design, 'mull'), isNull);
      expect(DesignEdits.openingAround(design, design.frame!.id), isNull);
      expect(DesignEdits.openingAround(design, null), isNull);
    });
  });
}

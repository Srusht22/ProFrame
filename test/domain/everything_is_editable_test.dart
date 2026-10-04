import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase's checklist. Every one of these must be selectable, and every
// figure on its panel must move the geometry rather than the label:
//
//   Outer frame · Fixed section · Opening · Internal line
//   Glass · Panel · Handle · Hinge
//
// Opening:       width, height, position, direction
// Internal line: position, length, direction
// Glass, Panel:  width, height, material, colour
//
// Every figure typed is centimetres.

const _blue = Finish(colour: 0xFF112233, material: MaterialKind.panel);

Design built() {
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2400, 1800),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'mull', a: Vec2(1000, 0), b: Vec2(1000, 1800),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  design = DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markGlyph: '>',
    markAt: sash.outline.centroid,
  );
  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  design = DesignEdits.addLineInside(
    design,
    design.openings.single.sectionId,
    id: 'inner',
    at: Vec2(box.centroid.x, box.top + 500),
    horizontal: true,
  );
  final low = design
      .childSectionsOf(design.openings.single.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _blue));
}

String openingSection(Design d) => d.openings.single.sectionId;

List<SectionElement> panes(Design d) =>
    d.childSectionsOf(openingSection(d))
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

void main() {
  group('every part on the list can be picked', () {
    test('each one is in the design and answers to its own id', () {
      final design = built();
      final tree = DesignTree.of(design);
      final opening = design.openings.single;

      final wanted = <String, String?>{
        'outer frame': design.frame!.id,
        'fixed section': tree.fixedSections.single.sectionId,
        'opening': opening.id,
        'opening’s section': opening.sectionId,
        'internal line': 'inner',
        'glass': panes(design).first.id,
        'panel': panes(design).last.id,
        'handle': [
          for (final p in design.hardware)
            if (p.kind == HardwareKind.handle) p.id,
        ].firstOrNull,
        'hinge': [
          for (final p in design.hardware)
            if (p.kind == HardwareKind.hinge) p.id,
        ].firstOrNull,
      };

      wanted.forEach((what, id) {
        expect(id, isNotNull, reason: '$what is not in the design at all');
        expect(design.elementById(id!), isNotNull,
            reason: '$what cannot be picked');
      });
    });

    test('a frame member is a part of its own, not just an edge', () {
      final design = built();
      final members = design.frameMembers;
      expect(members, hasLength(4),
          reason: 'head, sill and two jambs');
      for (final member in members) {
        expect(design.elementById(member.id), isNotNull);
      }
    });
  });

  group('an opening: width, height, position, direction', () {
    test('width and height move the geometry', () {
      final before = built();
      final on = openingSection(before);

      final wider = DesignEdits.setSectionWidth(before, on, 600);
      expect(Units.format(
          wider.sectionById(openingSection(wider))!.widthMm), '60');

      final shorter = DesignEdits.setSectionHeight(before, on, 900);
      expect(Units.format(
          shorter.sectionById(openingSection(shorter))!.heightMm), '90');
    });

    test('position moves it to another light, with everything it holds', () {
      final before = built();
      final places = DesignEdits.placesFor(before, 'o');
      expect(places, isNotEmpty);

      final wide = before.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', wide.id);

      expect(after.openings.single.sectionId, wide.id);
      expect(after.childDividersOf(openingSection(after)), hasLength(1));
      expect(panes(after), hasLength(2));
    });

    test('direction changes which side it hangs on, and which way it opens',
        () {
      final before = built();

      final right = DesignEdits.setOpeningMechanism(
          before, 'o', OpeningMechanism.hingedRight);
      expect(right.openings.single.mechanism, OpeningMechanism.hingedRight);

      // Not a label: the hinges are built on the other stile now.
      double hingeX(Design d) {
        final at = [
          for (final p in d.hardware)
            if (p.kind == HardwareKind.hinge) p.at.x,
        ];
        return at.reduce((a, b) => a + b) / at.length;
      }

      expect(hingeX(right), greaterThan(hingeX(before) + 100));

      final out =
          DesignEdits.setOpeningSwing(before, 'o', OpeningDirection.outward);
      expect(out.openings.single.direction, OpeningDirection.outward);
    });
  });

  group('an internal line: position, length, direction', () {
    test('position moves it down the opening, and nothing else', () {
      final before = built();
      final box = before.sectionById(openingSection(before))!.outline;

      final after = DesignEdits.moveDividerWithin(before, 'inner', 900);
      expect(Units.format(
          DesignEdits.alongWithin(after, after.dividerById('inner'))!), '90');
      expect(after.sectionById(openingSection(after))!.outline, box,
          reason: 'the opening moved when its line did');
    });

    test('length changes the geometry, about the line’s own middle', () {
      final before = built();
      final was = before.dividerById('inner')!.segment;

      final after = DesignEdits.setDividerLength(before, 'inner', 500);
      final now = after.dividerById('inner')!.segment;

      expect(Units.format(now.length), '50');
      expect(now.midpoint.x, closeTo(was.midpoint.x, 0.01),
          reason: 'it slid along when it was shortened');
      expect(now.midpoint.y, closeTo(was.midpoint.y, 0.01));
      expect(now.headingDegrees, closeTo(was.headingDegrees, 1e-9));
      // Both ends moved, by the same amount.
      expect(was.a.distanceTo(now.a), closeTo(was.b.distanceTo(now.b), 0.01));
    });

    test('direction turns it, about the line’s own middle', () {
      final before = built();
      final was = before.dividerById('inner')!.segment;

      final after = DesignEdits.setDividerAngle(before, 'inner', 30);
      final now = after.dividerById('inner')!.segment;

      expect(now.headingDegrees, closeTo(30, 0.01));
      expect(now.length, closeTo(was.length, 0.01));
      expect(now.midpoint.x, closeTo(was.midpoint.x, 0.01));
      expect(now.midpoint.y, closeTo(was.midpoint.y, 0.01));
    });

    test('a figure typed is a figure that comes back', () {
      var design = built();
      for (final cm in [40.0, 75.5, 120.0]) {
        design = DesignEdits.setDividerLength(design, 'inner', cm * 10);
        expect(Units.format(design.dividerById('inner')!.lengthMm),
            Units.format(cm * 10));
      }
      for (final degrees in [15.0, 45.0, 135.0]) {
        design = DesignEdits.setDividerAngle(design, 'inner', degrees);
        expect(design.dividerById('inner')!.segment.headingDegrees,
            closeTo(degrees, 0.01));
      }
    });

    test('turned, it keeps its length — so it may no longer span', () {
      final before = built();
      final box = before.sectionById(openingSection(before))!.outline;
      expect(before.childSectionsOf(openingSection(before)), hasLength(2));

      // A bar turned about its middle keeps its length, so a bar that ran
      // jamb to jamb no longer reaches them: it stops short, and a bar that
      // stops half way divides nothing. The answer is a longer Length, not
      // a line quietly stretched to fit.
      final turned = DesignEdits.setDividerAngle(before, 'inner', 25);
      expect(turned.childSectionsOf(openingSection(turned)), isEmpty);

      final needed = box.width / math.cos(25 * math.pi / 180);
      final longer = DesignEdits.setDividerLength(turned, 'inner', needed);
      expect(longer.childSectionsOf(openingSection(longer)), hasLength(2),
          reason: 'made long enough to span, it divides again');
    });

    test('a length below what a line can be is refused, not built', () {
      final before = built();
      expect(DesignEdits.setDividerLength(before, 'inner', 0),
          same(before));
      expect(DesignEdits.setDividerLength(before, 'inner', -50),
          same(before));
    });
  });

  group('glass and panel: width, height, material, colour', () {
    test('each pane carries its own material and colour', () {
      final design = built();
      final two = panes(design);

      expect(two.first.finish.material.isGlazing, isTrue);
      expect(two.last.finish.material, MaterialKind.panel);
      expect(two.last.finish.colour, 0xFF112233);
      expect(two.first.finish.colour, isNot(two.last.finish.colour));
    });

    test('changing one pane’s finish leaves the other alone', () {
      final before = built();
      final two = panes(before);
      final after = before.withElement(two.first.copyWith(
        finish: const Finish(colour: 0xFF445566, material: MaterialKind.panel),
      ));

      expect(after.sectionById(two.first.id)!.finish.colour, 0xFF445566);
      expect(after.sectionById(two.last.id)!.finish, two.last.finish);
    });

    test('width and height move the bar beside the pane', () {
      final before = built();
      final upper = panes(before).first;
      final wasAlong =
          DesignEdits.alongWithin(before, before.dividerById('inner'))!;

      final after = DesignEdits.setSectionHeight(before, upper.id, 300);
      expect(Units.format(after.sectionById(upper.id)!.heightMm), '30');
      // The figure moved the line, not a caption: the bar is somewhere else.
      expect(DesignEdits.alongWithin(after, after.dividerById('inner')),
          isNot(closeTo(wasAlong, 1)));
    });

    test('the finish reaches the solid, so it is not a label', () {
      final before = built();
      final panel = panes(before).last;

      Set<FacetRole> rolesOf(Design d, String id) => {
            for (final f in MeshBuilder.build(d).facets)
              if (f.elementId == id) f.role,
          };

      expect(rolesOf(before, panel.id), contains(FacetRole.panel));
      final glazed = before.withElement(panel.copyWith(
        finish: const Finish(
            colour: 0xFFCCDDEE, material: MaterialKind.clearGlass),
      ));
      expect(rolesOf(glazed, panel.id), contains(FacetRole.glazing));
    });
  });

  group('typing a figure changes what gets built', () {
    test('the drawing and the solid both follow every edit', () {
      final before = built();
      final was = MeshBuilder.build(before).facets.length;

      for (final after in [
        DesignEdits.setSectionWidth(before, openingSection(before), 600),
        DesignEdits.setDividerLength(before, 'inner', 400),
        DesignEdits.setDividerAngle(before, 'inner', 20),
        before.withElement(
            before.dividerById('inner')!.copyWith(widthMm: 60)),
      ]) {
        expect(after.toJson().toString(), isNot(before.toJson().toString()),
            reason: 'a figure was typed and the document did not change');
        expect(MeshBuilder.build(after).facets, isNotEmpty);
        expect(was, greaterThan(0));
      }
    });

    test('every figure is centimetres, in and out', () {
      final design = built();
      expect(Units.symbol, 'cm');
      expect(Units.label(design.dividerById('inner')!.lengthMm),
          endsWith(' cm'));
      // Typed in centimetres, exact in millimetres, back as typed.
      final typed = Units.parse('72.25')!;
      expect(typed, 722.5);
      final after = DesignEdits.setDividerLength(design, 'inner', typed);
      expect(Units.format(after.dividerById('inner')!.lengthMm), '72.3');
    });
  });
}

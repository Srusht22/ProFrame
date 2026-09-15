import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/scale.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

Design base() {
  final at = DateTime(2026);
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    depthMm: 70,
    frame: FrameElement(
      id: 'frame',
      outline: Polygon.rect(0, 0, 1600, 2100),
      profileMm: 60,
    ),
    dividers: const [
      DividerElement(id: 'v', a: Vec2(620, 0), b: Vec2(620, 2100), widthMm: 50),
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
  );
}

/// Everything about the solid that could possibly differ, as one string.
String solidFingerprint(Design design, {double openFraction = 0}) {
  final mesh = MeshBuilder.build(design, openFraction: openFraction);
  final lines = <String>[];
  for (final facet in mesh.facets) {
    lines.add('${facet.elementId}|${facet.role}|${facet.colour}'
        '|${facet.transparency.toStringAsFixed(4)}'
        '|${facet.corners.map((c) => '${c.x.toStringAsFixed(3)},'
            '${c.y.toStringAsFixed(3)},${c.z.toStringAsFixed(3)}').join(';')}');
  }
  lines.sort();
  return lines.join('\n');
}

/// Everything the technical drawing is drawn from.
String drawingFingerprint(Design design) {
  final lines = <String>[
    'frame ${design.frame?.outline.corners} ${design.frame?.profileMm}',
    'inner ${design.frame?.innerOutline.corners}',
    for (final d in design.dividers) 'bar ${d.a} ${d.b} ${d.widthMm}',
    for (final s in design.sections)
      'pane ${s.outline.corners} ${s.finish.colour} ${s.finish.material}',
    for (final o in design.openings)
      'opens ${o.sectionId} ${o.mechanism} ${o.direction} ${o.markGlyph}',
    for (final chain in DimensionChains.of(design))
      'chain ${chain.axis} ${chain.row} '
          '${chain.runs.map((r) => r.valueMm.toStringAsFixed(3)).join(',')}',
  ];
  return lines.join('\n');
}

void main() {
  group('there is one model and the solid is a function of it', () {
    test('the same design gives an identical model, every time', () {
      final design = base();
      expect(solidFingerprint(design), solidFingerprint(design));

      // And a second design built the same way gives the same model, so
      // nothing is carried over between builds.
      expect(solidFingerprint(base()), solidFingerprint(design));
    });

    test('building the model does not change the design', () {
      final design = base();
      final before = design.toJson().toString();
      MeshBuilder.build(design, openFraction: 0.6);
      expect(design.toJson().toString(), before);
    });

    test('two designs that differ give models that differ', () {
      final a = base();
      final b = DesignEdits.moveDivider(a, 'v', const Vec2(180, 0));
      expect(solidFingerprint(a), isNot(solidFingerprint(b)));
    });

    test('how far the leaves are swung changes the model, not the design',
        () {
      final design = base();
      final shut = design.toJson().toString();
      expect(
        solidFingerprint(design, openFraction: 0),
        isNot(solidFingerprint(design, openFraction: 1)),
      );
      expect(design.toJson().toString(), shut);
      // And the drawing does not move when the preview does.
      expect(drawingFingerprint(design), drawingFingerprint(design));
    });
  });

  group('a change in the drawing reaches the model', () {
    test('changing a dimension', () {
      final before = base();
      final after = DesignScale.toWidth(before, 2400);

      expect(drawingFingerprint(after), isNot(drawingFingerprint(before)));
      expect(solidFingerprint(after), isNot(solidFingerprint(before)));

      var widest = 0.0;
      for (final facet in MeshBuilder.build(after).facets) {
        for (final c in facet.corners) {
          if (c.x > widest) widest = c.x;
        }
      }
      expect(widest, closeTo(2400, 1));
    });

    test('moving a divider', () {
      final before = base();
      final after = DesignEdits.moveDividerAcross(before, 'v', const Vec2(950, 1000));

      double barMiddle(Design design) {
        var sum = 0.0;
        var count = 0;
        for (final facet in MeshBuilder.build(design).facets) {
          if (facet.elementId != 'v') continue;
          sum += facet.centre.x;
          count++;
        }
        return sum / count;
      }

      expect(barMiddle(before), closeTo(620, 2));
      expect(barMiddle(after), closeTo(950, 2));
    });

    test('changing the opening', () {
      final before = base();
      final after = DesignEdits.setOpeningMechanism(
        before,
        'o',
        OpeningMechanism.topHung,
      );

      double lowestSash(Design design) {
        var low = -1e9;
        for (final facet in
            MeshBuilder.build(design, openFraction: 1).facets) {
          if (facet.role != FacetRole.sash) continue;
          for (final c in facet.corners) {
            if (c.y > low) low = c.y;
          }
        }
        return low;
      }

      // Hinged left, the leaf keeps its full height. Top hung, its bottom
      // edge swings up and away.
      expect(lowestSash(after), lessThan(lowestSash(before) - 100));
    });

    test('changing a section from panel to glass', () {
      var design = base();
      final right = design.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);

      design = design.withElement(right.copyWith(
        finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
      ));
      final asPanel = MeshBuilder.build(design);
      expect(
        asPanel.facets.any(
            (f) => f.elementId == right.id && f.role == FacetRole.panel),
        isTrue,
      );

      design = design.withElement(
        design.sectionById(right.id)!.copyWith(
              finish: const Finish(
                colour: 0xFFD8E6EA,
                material: MaterialKind.clearGlass,
              ),
            ),
      );
      final asGlass = MeshBuilder.build(design);
      expect(
        asGlass.facets.any(
            (f) => f.elementId == right.id && f.role == FacetRole.glazing),
        isTrue,
      );
      expect(
        asGlass.facets.any(
            (f) => f.elementId == right.id && f.role == FacetRole.panel),
        isFalse,
      );
      // And the pane is see-through in the model, as glass is.
      final pane = asGlass.facets
          .firstWhere((f) => f.elementId == right.id && f.role == FacetRole.glazing);
      expect(pane.transparency, greaterThan(0.5));
    });

    test('recolouring a pane', () {
      final before = base();
      final target = before.sections.first;
      final after = before.withElement(
        target.copyWith(finish: target.finish.copyWith(colour: 0xFF8C1E20)),
      );
      expect(
        MeshBuilder.build(after)
            .facets
            .any((f) => f.elementId == target.id && f.colour == 0xFF8C1E20),
        isTrue,
      );
    });

    test('moving one side of the frame', () {
      final before = base();
      final head = before.frameMembers.firstWhere((m) => m.label == 'Head');
      final after = DesignEdits.moveFrameMember(before, head.index, 250);

      double highest(Design design) {
        var top = 1e9;
        for (final facet in MeshBuilder.build(design).facets) {
          for (final c in facet.corners) {
            if (c.y < top) top = c.y;
          }
        }
        return top;
      }

      expect(highest(before), closeTo(0, 1));
      expect(highest(after), closeTo(-250, 1));
    });
  });

  group('a change made on the solid reaches the drawing', () {
    test('depth is the design, so both views see it', () {
      final before = base();
      final after = before.copyWith(depthMm: 140);

      // The body of the design — its frame, its bars and what fills them.
      // Ironmongery stands proud of that, as a handle does on a real door,
      // so it is not what the design's depth measures.
      double thickness(Design design) {
        var front = -1e9, back = 1e9;
        for (final facet in MeshBuilder.build(design).facets) {
          if (facet.role == FacetRole.hardware) continue;
          for (final c in facet.corners) {
            if (c.z > front) front = c.z;
            if (c.z < back) back = c.z;
          }
        }
        return front - back;
      }

      expect(thickness(before), closeTo(70, 0.01));
      expect(thickness(after), closeTo(140, 0.01));
      // The elevation does not show depth, but the design it is drawn from
      // is the same object, so the figure travels with it.
      expect(after.depthMm, 140);
      expect(Design.fromJson(after.toJson()).depthMm, 140);
    });

    test('the frame profile changes the drawing as well as the solid', () {
      final before = base();
      final after = SectionBuilder.rebuild(
        before.withElement(before.frame!.copyWith(profileMm: 140)),
      );

      // The daylight openings in the drawing shrink by the difference.
      expect(drawingFingerprint(after), isNot(drawingFingerprint(before)));
      final wasWidest = before.sections
          .reduce((a, b) => a.widthMm > b.widthMm ? a : b)
          .widthMm;
      final nowWidest = after.sections
          .reduce((a, b) => a.widthMm > b.widthMm ? a : b)
          .widthMm;
      expect(nowWidest, closeTo(wasWidest - 80, 1));

      // And the solid's frame is thicker to match.
      expect(solidFingerprint(after), isNot(solidFingerprint(before)));
    });

    test('picking a pane in the model picks the same pane in the drawing', () {
      final design = base();
      final section = design.sections.first;

      // Every face of that pane in the solid carries the pane's own id, so
      // whatever is tapped in either view names the same part.
      final faces = MeshBuilder.build(design)
          .facets
          .where((f) => f.elementId == section.id);
      expect(faces, isNotEmpty);
      expect(design.elementById(section.id), isA<SectionElement>());
    });
  });

  group('the two views never disagree', () {
    test('every pane in the drawing is a pane in the model, after any edit',
        () {
      var design = base();
      final edits = <Design Function(Design)>[
        (d) => DesignEdits.moveDividerAcross(d, 'v', const Vec2(900, 1000)),
        (d) => DesignScale.toWidth(d, 2000),
        (d) => DesignEdits.setOpeningMechanism(d, 'o', OpeningMechanism.topHung),
        (d) => d.copyWith(depthMm: 110),
        (d) => SectionBuilder.rebuild(
              d.withElement(d.frame!.copyWith(profileMm: 90)),
            ),
        (d) => DesignEdits.addDivider(
              d,
              id: 'h',
              a: const Vec2(0, 1500),
              b: const Vec2(2000, 1500),
            ),
      ];

      for (final edit in edits) {
        design = edit(design);
        final mesh = MeshBuilder.build(design);
        final inModel = {
          for (final f in mesh.facets)
            if (f.role == FacetRole.glazing ||
                f.role == FacetRole.panel ||
                f.role == FacetRole.sash)
              f.elementId,
        };
        final inDrawing = {for (final s in design.sections) s.id};
        expect(inModel, inDrawing,
            reason: 'the panes should match after every edit');

        final barsInModel = {
          for (final f in mesh.facets)
            if (f.role == FacetRole.bar) f.elementId,
        };
        expect(barsInModel, {for (final d in design.dividers) d.id});
      }
    });
  });
}

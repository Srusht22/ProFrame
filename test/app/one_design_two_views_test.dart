import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
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

//              DESIGN GEOMETRY
//                /        \
//               /          \
//             CAD          3D
//
// One model. Both views are functions of it and hold no geometry of their
// own, so an edit reaches both or it reaches neither — there is nowhere for
// one of them to keep a second opinion.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);
const _size = Size(900, 640);

/// A window whose marked light is exactly 40 cm wide, with a line drawn
/// inside it making glass over panel.
Design built() {
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2000, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'mull', a: Vec2(470, 0), b: Vec2(470, 1700),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  design = DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: sash.outline.centroid,
  );

  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  design = DesignEdits.addLineInside(
    design,
    design.openings.single.sectionId,
    id: 'inner',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );
  final low = design
      .childSectionsOf(design.openings.single.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

String openingSection(Design d) => d.openings.single.sectionId;

List<SectionElement> panes(Design d) => d.childSectionsOf(openingSection(d))
  ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

/// The drawing, rasterised.
Future<Uint8List> drawn(Design design) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: design,
    view: ViewTransform.fit(
      design.frame!.outline,
      _size,
      padding: const EdgeInsets.all(40),
    ),
    layers: const CadLayers(),
  ).paint(Canvas(recorder), _size);
  final image = await recorder
      .endRecording()
      .toImage(_size.width.round(), _size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The solid, written out so two builds can be compared exactly.
String modelled(Design design) {
  final lines = <String>[];
  for (final facet in MeshBuilder.build(design).facets) {
    lines.add([
      facet.elementId,
      facet.role.name,
      for (final c in facet.corners)
        '${c.x.toStringAsFixed(4)},'
            '${c.y.toStringAsFixed(4)},'
            '${c.z.toStringAsFixed(4)}',
    ].join('|'));
  }
  return lines.join('\n');
}

Set<String> partsOf(Mesh mesh) => {for (final f in mesh.facets) f.elementId};

Set<String> cadParts(Design design) {
  final tree = DesignTree.of(design);
  return {
    if (tree.frameId != null) tree.frameId!,
    ...tree.everyBar,
    for (final s in tree.everySection) if (s.isLeaf) s.sectionId,
    for (final o in tree.openings) o.sectionId,
    for (final h in design.hardware) h.id,
  };
}

void main() {
  group('one edit reaches both views', () {
    test('the opening 40 cm wide becomes 50 cm, in the drawing and the model',
        () async {
      final before = built();
      expect(Units.format(
          before.sectionById(openingSection(before))!.widthMm), '40');

      final after =
          DesignEdits.setSectionWidth(before, openingSection(before), 500);

      // The one model changed.
      expect(Units.format(
          after.sectionById(openingSection(after))!.widthMm), '50');
      // And both views changed with it.
      expect(await drawn(after), isNot(await drawn(before)));
      expect(modelled(after), isNot(modelled(before)));
    });

    test('the internal divider moved changes the drawing and the model',
        () async {
      final before = built();
      final was = before.dividerById('inner')!.segment.midpoint;

      final after = DesignEdits.moveDividerWithin(before, 'inner', 900);

      expect(after.dividerById('inner')!.segment.midpoint.y,
          isNot(closeTo(was.y, 1)));
      expect(await drawn(after), isNot(await drawn(before)));
      expect(modelled(after), isNot(modelled(before)));
    });

    test('the panel made glass changes the drawing and the model', () async {
      final before = built();
      final panel = panes(before).last;
      expect(panel.finish.material, MaterialKind.panel);

      final after = before.withElement(panel.copyWith(
        finish: const Finish(
            colour: 0xFFCCDDEE, material: MaterialKind.clearGlass),
      ));

      expect(after.sectionById(panel.id)!.finish.material.isGlazing, isTrue);
      expect(await drawn(after), isNot(await drawn(before)));

      // The model's own answer for that pane changed from panel to glazing —
      // not a colour swap in a picture of one.
      Set<FacetRole> roles(Design d) => {
            for (final f in MeshBuilder.build(d).facets)
              if (f.elementId == panel.id) f.role,
          };
      expect(roles(before), contains(FacetRole.panel));
      expect(roles(after), contains(FacetRole.glazing));
    });
  });

  group('neither view keeps geometry of its own', () {
    test('drawing and modelling change nothing in the design', () async {
      final design = built();
      final before = design.toJson().toString();
      await drawn(design);
      MeshBuilder.build(design, openFraction: 0.5);
      expect(design.toJson().toString(), before);
    });

    test('the same design gives the same drawing and the same model',
        () async {
      final design = built();
      expect(await drawn(design), await drawn(design));
      expect(modelled(design), modelled(design));
    });

    test('an edit that changes nothing changes neither view', () async {
      final before = built();
      // Setting a figure to what it already is is not an edit.
      final after = DesignEdits.setSectionWidth(
          before, openingSection(before),
          before.sectionById(openingSection(before))!.widthMm);

      expect(after.toJson().toString(), before.toJson().toString());
      expect(await drawn(after), await drawn(before));
      expect(modelled(after), modelled(before));
    });

    test('rebuilding from the same design gives the same two views',
        () async {
      final design = built();
      final again = SectionBuilder.rebuild(design);
      expect(await drawn(again), await drawn(design));
      expect(modelled(again), modelled(design));
    });
  });

  group('the two cannot drift apart', () {
    test('after every edit they still hold the same set of parts', () {
      final before = built();
      final on = openingSection(before);

      for (final after in <(String, Design)>[
        ('as built', before),
        ('opening widened', DesignEdits.setSectionWidth(before, on, 500)),
        ('opening shortened', DesignEdits.setSectionHeight(before, on, 900)),
        ('divider moved', DesignEdits.moveDividerWithin(before, 'inner', 900)),
        ('divider turned', DesignEdits.setDividerAngle(before, 'inner', 8)),
        ('bar widened',
            before.withElement(
                before.dividerById('inner')!.copyWith(widthMm: 60))),
        ('panel glazed', before.withElement(panes(before).last.copyWith(
            finish: const Finish(
                colour: 0xFFCCDDEE, material: MaterialKind.clearGlass)))),
        ('mullion moved',
            DesignEdits.moveDivider(before, 'mull', const Vec2(200, 0))),
        ('frame rescaled', DesignEdits.resizeFrame(before, heightMm: 2100)),
        ('opening turned', DesignEdits.setOpeningMechanism(
            before, 'o', OpeningMechanism.hingedLeft)),
      ]) {
        expect(partsOf(MeshBuilder.build(after.$2)), cadParts(after.$2),
            reason: 'after ${after.$1} the two views disagree about what the '
                'design is made of');
      }
    });

    test('a figure typed reaches the model, not just the drawing', () {
      final before = built();
      final on = openingSection(before);

      double widestGap(Design d, String id) {
        var least = 1e9;
        var most = -1e9;
        for (final f in MeshBuilder.build(d).facets) {
          if (f.elementId != id) continue;
          for (final c in f.corners) {
            if (c.x < least) least = c.x;
            if (c.x > most) most = c.x;
          }
        }
        return most - least;
      }

      final was = widestGap(before, on);
      final after = DesignEdits.setSectionWidth(before, on, 500);
      // The leaf the model builds is wider by what was typed, give or take
      // the sash's own material.
      expect(widestGap(after, on), greaterThan(was + 80));
    });
  });
}

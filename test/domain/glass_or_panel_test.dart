import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// Glass or panel: the user says what fills the parts their own lines made,
// and nothing else changes. The user's words: *material selection changes
// material and appearance, not geometry*, and *the user decides panel versus
// glass — the application does not decide for them.*

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at) => [
  Vec2(at.x - 150, at.y - 220),
  Vec2(at.x + 150, at.y),
  Vec2(at.x - 150, at.y + 220),
];

const outline = [
  Vec2(0, 0),
  Vec2(1000, 0),
  Vec2(1000, 2100),
  Vec2(0, 2100),
  Vec2(0, 0),
];

/// A door with a transom across it: an upper part and a lower one, as the
/// user drew them — not halves.
Design door({
  Construction? construction,
  Finish? infill,
  List<Stroke> more = const [],
}) => SketchInterpreter.interpret(
  Design(
    id: 'door',
    name: 'Door',
    kind: DesignKind.door,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    construction: construction,
    infill: infill,
    sketch: Sketch(
      strokes: [
        pen('outline', outline),
        pen('transom', const [Vec2(0, 700), Vec2(1000, 700)]),
        ...more,
      ],
    ),
  ),
).design;

/// Everything about [design] that is geometry, as text: the frame, every
/// bar and every part's outline and parent. What fills a part is left out.
String geometryOf(Design design) => jsonEncode({
  'frame': design.frame?.toJson(),
  'dividers': [for (final d in design.dividers) d.toJson()],
  'sections': [
    for (final s in design.sections)
      {'id': s.id, 'outline': s.outline.toJson(), 'parent': s.parentId},
  ],
  'openings': [for (final o in design.openings) o.toJson()],
});

(SectionElement, SectionElement) upperAndLower(Design design) {
  final parts = [...Infill.partsOf(design)]
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  return (parts.first, parts.last);
}

void main() {
  test('the parts are the ones the lines made, in reading order', () {
    final d = door();
    final parts = Infill.partsOf(d);
    expect(parts, hasLength(2));
    final (upper, lower) = upperAndLower(d);
    expect(parts.map((p) => p.id), [upper.id, lower.id]);
    // Not halves: the transom is where it was drawn.
    expect(upper.heightMm, lessThan(lower.heightMm / 2));
  });

  group('the whole door', () {
    test('1 — entire design = panel: every part a panel, in the colour '
        'chosen, and nothing moved', () {
      final before = door();
      final after = Infill.fillWhole(
        before,
        Construction.panel,
        PanelColour.white.finish,
      );
      expect(geometryOf(after), geometryOf(before));
      for (final part in Infill.partsOf(after)) {
        expect(part.finish, PanelColour.white.finish);
      }
      expect(after.construction, Construction.panel);
      expect(after.sections, hasLength(before.sections.length));
      expect(after.dividers, hasLength(before.dividers.length));
    });

    test('2 — entire design = glass: every part glass, in the glass chosen, '
        'and nothing moved', () {
      final before = door();
      final after = Infill.fillWhole(
        before,
        Construction.glass,
        GlassLook.frosted.finish,
      );
      expect(geometryOf(after), geometryOf(before));
      for (final part in Infill.partsOf(after)) {
        expect(part.finish, GlassLook.frosted.finish);
        expect(Infill.isGlass(part.finish), isTrue);
      }
    });

    test('said before anything is drawn, it is what every part drawn '
        'afterwards starts as', () {
      // The alert comes as the design starts, before the drawing: the parts
      // the user then draws are the panel they said.
      final d = door(
        construction: Construction.panel,
        infill: PanelColour.brown.finish,
      );
      expect(Infill.partsOf(d), hasLength(2));
      for (final part in Infill.partsOf(d)) {
        expect(part.finish, PanelColour.brown.finish);
      }
      // And a line drawn later makes panel parts too, not glass.
      final more = door(
        construction: Construction.panel,
        infill: PanelColour.brown.finish,
        more: [
          pen('upright', const [Vec2(500, 700), Vec2(500, 2100)]),
        ],
      );
      expect(Infill.partsOf(more), hasLength(3));
      for (final part in Infill.partsOf(more)) {
        expect(part.finish, PanelColour.brown.finish);
      }
    });

    test('a design where nothing was said is read exactly as before', () {
      for (final part in Infill.partsOf(door())) {
        expect(part.finish, Finish.glazingDefault);
      }
    });
  });

  group('both panel and glass', () {
    test('3 — exactly the parts named receive exactly what was said', () {
      final before = door(construction: Construction.both);
      final (upper, lower) = upperAndLower(before);
      final after = Infill.fill(before, {
        upper.id: GlassLook.frosted.finish,
        lower.id: PanelColour.white.finish,
      });
      expect(geometryOf(after), geometryOf(before));
      expect(after.sectionById(upper.id)!.finish, GlassLook.frosted.finish);
      expect(after.sectionById(lower.id)!.finish, PanelColour.white.finish);
    });

    test('4 — changing one part changes that part and nothing else', () {
      final d = door(construction: Construction.both);
      final (upper, lower) = upperAndLower(d);
      final said = Infill.fill(d, {
        upper.id: GlassLook.clear.finish,
        lower.id: PanelColour.white.finish,
      });
      final changed = Infill.fill(said, {upper.id: PanelColour.black.finish});
      expect(geometryOf(changed), geometryOf(said));
      expect(changed.sectionById(upper.id)!.finish, PanelColour.black.finish);
      // The other part is exactly as it was.
      expect(
        jsonEncode(changed.sectionById(lower.id)!.toJson()),
        jsonEncode(said.sectionById(lower.id)!.toJson()),
      );
      // And back again, the other way round: upper panel, lower glass.
      final swapped = Infill.fill(changed, {lower.id: GlassLook.clear.finish});
      expect(geometryOf(swapped), geometryOf(said));
      expect(Infill.isPanel(swapped.sectionById(upper.id)!.finish), isTrue);
      expect(Infill.isGlass(swapped.sectionById(lower.id)!.finish), isTrue);
    });

    test(
      'a colour changed is a colour changed, and the part does not move',
      () {
        final d = door();
        final (_, lower) = upperAndLower(d);
        final white = Infill.fill(d, {lower.id: PanelColour.white.finish});
        final black = Infill.fill(white, {lower.id: PanelColour.black.finish});
        expect(geometryOf(black), geometryOf(white));
        expect(
          black.sectionById(lower.id)!.outline.toJson(),
          white.sectionById(lower.id)!.outline.toJson(),
        );
      },
    );
  });

  group('the solid is built of what was said', () {
    test('glass geometry for the glass, panel geometry in its colour for '
        'the panel, and the divider between them', () {
      final design = said();
      final (upper, lower) = upperAndLower(design);
      final mesh = MeshBuilder.build(design);
      final glass = mesh.facets.where((f) => f.elementId == upper.id);
      final panel = mesh.facets.where((f) => f.elementId == lower.id);
      expect(glass, isNotEmpty);
      expect(panel, isNotEmpty);
      expect(glass.every((f) => f.role == FacetRole.glazing), isTrue);
      expect(panel.every((f) => f.role == FacetRole.panel), isTrue);
      expect(glass.every((f) => f.transparency > 0), isTrue);
      expect(panel.every((f) => f.transparency == 0), isTrue);
      // The panel is built in the brown chosen — shaded by the light, never
      // another colour: the face towards the light is the colour itself.
      expect(panel.map((f) => f.colour), contains(PanelColour.brown.colour));
      final transom = design.dividers.single;
      expect(mesh.facets.where((f) => f.elementId == transom.id), isNotEmpty);
    });

    test('changing the panel colour changes the colour of its facets and '
        'not where any of them are', () {
      final design = said();
      final (_, lower) = upperAndLower(design);
      final recoloured = Infill.fill(design, {
        lower.id: PanelColour.black.finish,
      });
      final before = MeshBuilder.build(design).facets;
      final after = MeshBuilder.build(recoloured).facets;
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(
          after[i].corners.map((c) => c.toString()).join(),
          before[i].corners.map((c) => c.toString()).join(),
        );
      }
      expect(
        after.where((f) => f.elementId == lower.id).map((f) => f.colour),
        contains(PanelColour.black.colour),
      );
    });
  });

  group('saved with the design', () {
    test('what was said, part by part, outlasts a save and a reload', () {
      final design = said();
      final back = Design.fromJson(jsonDecode(jsonEncode(design.toJson())));
      expect(back.construction, Construction.both);
      expect(back.partsAsked, isFalse);
      final (upper, lower) = upperAndLower(back);
      expect(upper.finish, GlassLook.frosted.finish);
      expect(lower.finish, PanelColour.brown.finish);
      expect(jsonEncode(back.toJson()), jsonEncode(design.toJson()));
    });

    test('and so does the whole door said to be panel', () {
      final design = Infill.fillWhole(
        door(construction: Construction.pending),
        Construction.panel,
        PanelColour.grey.finish,
      );
      final back = Design.fromJson(jsonDecode(jsonEncode(design.toJson())));
      expect(back.construction, Construction.panel);
      expect(back.infill, PanelColour.grey.finish);
    });

    test('a design kept before the question existed is never asked it', () {
      final json = door().toJson()
        ..remove('construction')
        ..remove('infill')
        ..remove('partsAsked');
      final back = Design.fromJson(json);
      expect(back.construction, isNull);
      expect(back.infill, isNull);
      expect(back.partsAsked, isFalse);
    });

    test('a second reading of the sheet keeps every part as it was said', () {
      final design = said();
      final again = SketchInterpreter.interpret(design).design;
      final (upper, lower) = upperAndLower(again);
      expect(upper.finish, GlassLook.frosted.finish);
      expect(lower.finish, PanelColour.brown.finish);
    });
  });

  group('which kinds are asked', () {
    test('a door and a door & window set; a window and a sliding set are '
        'not', () {
      expect(DesignKind.door.asksConstruction, isTrue);
      expect(DesignKind.both.asksConstruction, isTrue);
      expect(DesignKind.window.asksConstruction, isFalse);
      expect(DesignKind.sliding.asksConstruction, isFalse);
    });
  });

  test('7 — inside an opening: glass, a divider and a panel, all the '
      "opening's own", () {
    // A door marked `>`, and a line drawn inside the leaf — the opening's
    // own glass over its own panel.
    var d = SketchInterpreter.interpret(
      Design(
        id: 'leaf',
        name: 'Leaf',
        kind: DesignKind.door,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sketch: Sketch(
          strokes: [
            pen('outline', outline),
            pen('mark', chevron(const Vec2(500, 1050))),
          ],
        ),
      ),
    ).design;
    final opening = d.openings.single;
    d = SketchInterpreter.interpret(
      d.copyWith(
        sketch: Sketch(
          strokes: [
            ...d.sketch.strokes,
            pen('inside', const [Vec2(250, 800), Vec2(750, 800)]),
          ],
        ),
      ),
    ).design;
    final parts = Infill.partsOf(d);
    expect(parts, hasLength(2));
    final (upper, lower) = upperAndLower(d);
    final said = Infill.fill(d, {
      upper.id: GlassLook.clear.finish,
      lower.id: PanelColour.white.finish,
    });
    expect(geometryOf(said), geometryOf(d));

    final leaf = said.openings.single;
    expect(leaf.id, opening.id, reason: 'the same opening');
    final inside = said.dividers.where((b) => b.parentId != null).toList();
    expect(inside, hasLength(1));
    expect(inside.single.parentId, leaf.id);
    for (final part in [upper, lower]) {
      expect(said.sectionById(part.id)!.parentId, leaf.id);
      expect(
        said.openingHolding(said.sectionById(part.id)!.parentId)?.id,
        leaf.id,
      );
    }
    final contents = said.contentsOf(leaf).map((e) => e.id).toSet();
    expect(contents, containsAll([upper.id, lower.id, inside.single.id]));
    expect(Infill.isGlass(said.sectionById(upper.id)!.finish), isTrue);
    expect(Infill.isPanel(said.sectionById(lower.id)!.finish), isTrue);
    expect(
      Infill.whereIs(said, said.sectionById(upper.id)!),
      said.nameOf(leaf),
    );
  });
}

Design said() {
  final d = door(construction: Construction.both);
  final (upper, lower) = upperAndLower(d);
  return Infill.fill(d, {
    upper.id: GlassLook.frosted.finish,
    lower.id: PanelColour.brown.finish,
  });
}

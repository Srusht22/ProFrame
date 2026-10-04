import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The phase's example, drawn the way the user draws it: an opening 40 × 160
// cm, an incomplete horizontal line drawn inside it 40 cm from its top, which
// the reading completes across the opening — and then the upper part made
// glass and the lower part a panel.
//
//   ┌──────────┐        Opening
//   │  GLASS   │        ├── Upper section   glass
//   ├──────────┤        ├── Internal divider
//   │  PANEL   │        └── Lower section   panel
//   └──────────┘
//
// One opening. One internal divider. The glass and the panel stay inside the
// opening, and are never two top-level sections.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A window whose left light is 40 × 160 cm of daylight, marked `<` and
/// read, so the opening is there before the line is drawn.
Design marked() => SketchInterpreter.interpret(
  Design(
    id: 'w',
    name: 'Window',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1720),
          Vec2(0, 1720),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(484, 0), Vec2(484, 1720)]),
        pen('mark', const [Vec2(340, 500), Vec2(160, 700), Vec2(340, 900)]),
      ],
    ),
  ),
).design;

/// The opening's top, read from the design rather than written down.
double topOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!.outline.top;

/// [marked] with an incomplete horizontal line drawn 40 cm down the opening
/// — started in from the jamb and stopped short of the mullion.
Design divided() {
  final before = marked();
  final y = topOf(before) + 400;
  return SketchInterpreter.interpret(
    before.copyWith(
      sketch: Sketch(
        strokes: [
          ...before.sketch.strokes,
          pen('line', [Vec2(120, y), Vec2(330, y)]),
        ],
      ),
    ),
  ).design;
}

List<SectionElement> panesOf(Design d) =>
    d.childSectionsOf(d.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

/// [divided] with the upper part made glass and the lower a panel, each on
/// its own, as the Material tool does it.
Design glassOverPanel() {
  final design = divided();
  final panes = panesOf(design);
  return Infill.fill(design, {
    panes.first.id: GlassLook.clear.finish,
    panes.last.id: PanelColour.white.finish,
  });
}

String topLevelOf(Design d) => jsonEncode({
  'frame': d.frame!.toJson(),
  'bars': [for (final b in d.topLevelDividers) b.toJson()],
  'sections': [for (final s in d.topLevelSections) s.toJson()],
  'openings': [for (final o in d.openings) o.toJson()],
});

void main() {
  test('the opening is 40 × 160 cm, and the drawn line is completed across '
      'it 40 cm from its top', () {
    final design = divided();
    final opening = design.openings.single;
    final box = design.sectionById(opening.sectionId)!.outline;
    expect(Units.format(box.width), '40');
    expect(Units.format(box.height), '160');

    final line = design.dividers.singleWhere((d) => d.fromStrokeId == 'line');
    expect([line.a.x, line.b.x]..sort(), [
      closeTo(box.left, 1),
      closeTo(box.right, 1),
    ], reason: 'completed across the opening, and no further');
    expect(Units.format(DesignEdits.alongWithin(design, line)!), '40');
  });

  test('the phase\'s test: one opening, one internal divider, glass and '
      'panel inside that opening', () {
    final before = marked();
    final design = glassOverPanel();

    // One opening — the same one, on the same region.
    expect(design.openings, hasLength(1));
    final opening = design.openings.single;
    expect(opening.id, before.openings.single.id);
    expect(opening.sectionId, before.openings.single.sectionId);

    // One internal divider, and it is the opening's.
    final internal = [
      for (final d in design.dividers)
        if (design.openingHolding(d.parentId) != null) d,
    ];
    expect(internal, hasLength(1));
    expect(internal.single.parentId, opening.id);

    // The upper section glass, the lower a panel — both inside the opening.
    final panes = panesOf(design);
    expect(panes, hasLength(2));
    expect(Infill.isGlass(panes.first.finish), isTrue);
    expect(Infill.isPanel(panes.last.finish), isTrue);
    for (final pane in panes) {
      expect(pane.parentId, opening.id);
      expect(design.openingHolding(pane.parentId)!.id, opening.id);
      expect(design.contentsOf(opening).map((e) => e.id), contains(pane.id));
    }

    // The tree every view walks says the same.
    final branch = DesignTree.of(design).openings.single;
    expect(branch.openingId, opening.id);
    expect(branch.barIds, [internal.single.id]);
    expect(branch.panes.map((p) => p.sectionId), [for (final p in panes) p.id]);
  });

  test('the two parts are not two top-level sections: the design outside '
      'the opening is exactly what it was', () {
    final before = marked();
    final design = glassOverPanel();
    expect(design.topLevelSections, hasLength(2), reason: 'opening + fixed');
    expect(design.topLevelDividers, hasLength(1), reason: 'the mullion');
    for (final pane in panesOf(design)) {
      expect(
        design.topLevelSections.map((s) => s.id),
        isNot(contains(pane.id)),
      );
    }
    expect(topLevelOf(design), topLevelOf(before));
  });

  test('glass, divider and panel together are the opening exactly', () {
    final design = glassOverPanel();
    final box = design.sectionById(design.openings.single.sectionId)!.outline;
    final panes = panesOf(design);
    final bar = design.dividers.singleWhere((d) => d.parentId != null);
    for (final pane in panes) {
      expect(pane.outline.width, closeTo(box.width, 1e-6));
    }
    expect(
      panes.first.outline.height + bar.widthMm + panes.last.outline.height,
      closeTo(box.height, 1e-6),
    );
  });

  test('saying glass and panel moves nothing', () {
    String geometryOf(Design d) => jsonEncode({
      'bars': [for (final b in d.dividers) b.toJson()],
      'outlines': [for (final s in d.sections) s.outline.toJson()],
      'openings': [for (final o in d.openings) o.toJson()],
    });
    expect(geometryOf(glassOverPanel()), geometryOf(divided()));
  });

  test('it outlasts a second reading, a save and a reload', () {
    final once = glassOverPanel();
    final twice = SketchInterpreter.interpret(once).design;
    final loaded = Design.fromJson(
      jsonDecode(jsonEncode(twice.toJson())) as Map<String, Object?>,
    );
    for (final d in [twice, loaded]) {
      expect(d.openings, hasLength(1));
      expect(d.dividers.where((b) => b.parentId != null), hasLength(1));
      final panes = panesOf(d);
      expect(panes, hasLength(2));
      expect(Infill.isGlass(panes.first.finish), isTrue);
      expect(Infill.isPanel(panes.last.finish), isTrue);
      for (final pane in panes) {
        expect(pane.parentId, d.openings.single.id);
      }
      expect(d.topLevelSections, hasLength(2));
    }
  });
}

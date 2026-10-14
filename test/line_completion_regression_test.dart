import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The final regression test of the line-completion system, drawn the way the
// user draws it — every line a stroke on the sheet, every line stopped short.
//
// ┌──────────────────────────────────────┐
// │   ─────── outside                    │   the band: main design
// ├────────────┬────────────┬────────────┤
// │  >         │            │  >         │
// │ ── in #1   │            │   ── in #2 │
// │            │   FIXED    │            │
// │ Opening #1 │            │ Opening #2 │
// └────────────┴────────────┴────────────┘
//
// The three lower lights are the same size, so moving Opening #1 into the
// middle one is a move and nothing else.

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

final _sheet = [
  pen('outline', const [
    Vec2(0, 0),
    Vec2(2400, 0),
    Vec2(2400, 2000),
    Vec2(0, 2000),
    Vec2(0, 0),
  ]),
  pen('transom', const [Vec2(0, 600), Vec2(2400, 600)]),
  pen('mullion-1', const [Vec2(812, 600), Vec2(812, 2000)]),
  pen('mullion-2', const [Vec2(1588, 600), Vec2(1588, 2000)]),
  pen('one', chevron(const Vec2(400, 1000))),
  pen('two', chevron(const Vec2(2000, 1000))),
];

/// The lines drawn once the openings are there, every one stopped short.
final _outside = [
  // Across the band, touching nothing at either end.
  pen('outside', const [Vec2(300, 300), Vec2(1100, 300)]),
];
final _inside = [
  pen('in-1', const [Vec2(200, 1300), Vec2(550, 1300)]),
  pen('in-2', const [Vec2(1800, 1400), Vec2(2150, 1400)]),
];

/// The design as read, with no line drawn yet: two openings.
Design marked() => SketchInterpreter.interpret(
  Design(
    id: 'w',
    name: 'Window',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(strokes: _sheet),
  ),
).design;

Design drawn(Design d, List<Stroke> lines) => SketchInterpreter.interpret(
  d.copyWith(sketch: Sketch(strokes: [...d.sketch.strokes, ...lines])),
).design;

/// Every line drawn, and Opening #1's upper part made glass and its lower
/// part a panel.
Design complete() {
  final d = drawn(marked(), [..._outside, ..._inside]);
  final panes = panesOf(d, 'opening-one');
  return Infill.fill(d, {
    panes.first.id: GlassLook.clear.finish,
    panes.last.id: PanelColour.white.finish,
  });
}

OpeningElement opening(Design d, String id) => d.openingById(id)!;

Polygon regionOf(Design d, String id) =>
    d.sectionById(opening(d, id).sectionId)!.outline;

List<SectionElement> panesOf(Design d, String id) =>
    d.childSectionsOf(opening(d, id).sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

DividerElement line(Design d, String strokeId) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == strokeId);

List<double> xs(DividerElement b) => [b.a.x, b.b.x]..sort();
List<double> ys(DividerElement b) => [b.a.y, b.b.y]..sort();

/// The body CAD lays down for a bar: its two faces, stopped at the sash it
/// is in — `CadPainter._barBody`.
Polygon bodyOf(Design d, DividerElement bar) {
  final side = bar.segment.unit.perpendicular * (bar.widthMm / 2);
  final body = Polygon([
    bar.a + side,
    bar.b + side,
    bar.b - side,
    bar.a - side,
  ]);
  final daylight = OpeningLeaf.daylightAround(d, bar.parentId);
  return daylight == null ? body : body.clippedTo(daylight);
}

String json(Object? o) => jsonEncode(o);

/// [point] is inside [box] or within [reach] of its edge.
bool within(Polygon box, Vec2 point, {double reach = 1}) =>
    box.contains(point) || box.edges.any((e) => e.distanceTo(point) < reach);

/// An opening and everything about where it is and what it holds.
String fingerprint(Design d, String id) {
  final o = opening(d, id);
  return json({
    'opening': o.toJson(),
    'region': d.sectionById(o.sectionId)!.outline.toJson(),
    'contents': [for (final e in d.contentsOf(o)) e.toJson()],
  });
}

/// The design outside both openings: the frame and the design's own bars.
String mainDesign(Design d) => json({
  'frame': d.frame!.toJson(),
  'bars': [for (final b in d.topLevelDividers) b.toJson()],
});

const _size = Size(960, 800);

Future<Uint8List> pixels(Design d, ViewTransform view) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: d,
    view: view,
    layers: const CadLayers(),
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(960, 800);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Design before;
  late Design after;
  setUp(() {
    before = marked();
    after = complete();
  });

  test(
    'the drawing reads as the brief\'s: two openings, three equal lights',
    () {
      expect(before.openings.map((o) => o.id).toSet(), {
        'opening-one',
        'opening-two',
      });
      final lower = [
        for (final s in before.topLevelSections)
          if (s.outline.top > 300) s.outline.width,
      ];
      expect(lower, hasLength(3));
      for (final w in lower) {
        expect(w, closeTo(lower.first, 1e-6));
      }
    },
  );

  test('TEST 1 — an incomplete line outside the openings completes to the '
      'main design\'s boundary', () {
    final across = line(after, 'outside');
    expect(across.parentId, isNull, reason: 'the main design\'s');
    expect(xs(across).first, closeTo(0, 1), reason: 'to the frame');
    expect(xs(across).last, closeTo(2400, 1), reason: 'to the frame');
    expect(across.a.y, closeTo(300, 1));
    expect(across.b.y, closeTo(300, 1));
  });

  test('TEST 2 — an incomplete line inside Opening #1 completes to Opening '
      '#1\'s boundary', () {
    final bar = line(after, 'in-1');
    final region = regionOf(before, 'opening-one');
    expect(bar.parentId, 'opening-one');
    expect(xs(bar).first, closeTo(region.left, 1));
    expect(xs(bar).last, closeTo(region.right, 1));
    expect(bar.a.y, closeTo(1300, 1));
    expect(bar.b.y, closeTo(1300, 1));
  });

  test('TEST 3 — an incomplete line inside Opening #2 completes to Opening '
      '#2\'s boundary', () {
    final bar = line(after, 'in-2');
    final region = regionOf(before, 'opening-two');
    expect(bar.parentId, 'opening-two');
    expect(xs(bar).first, closeTo(region.left, 1));
    expect(xs(bar).last, closeTo(region.right, 1));
    expect(bar.a.y, closeTo(1400, 1));
    expect(bar.b.y, closeTo(1400, 1));
  });

  test('TEST 4 — an opening\'s internal divider remains inside it', () {
    for (final (stroke, id) in [
      ('in-1', 'opening-one'),
      ('in-2', 'opening-two'),
    ]) {
      final bar = line(after, stroke);
      final region = regionOf(after, id);
      expect(region.holds(bar.segment, reach: 1), isTrue);
      for (final corner in bodyOf(after, bar).corners) {
        expect(region.contains(corner), isTrue, reason: '$stroke at $corner');
      }
      // And a second reading leaves it where it is.
      final again = SketchInterpreter.interpret(after).design;
      expect(json(line(again, stroke).toJson()), json(bar.toJson()));
    }
  });

  test('TEST 5 — glass, divider and panel all remain children of the '
      'opening', () {
    final one = opening(after, 'opening-one');
    final panes = panesOf(after, 'opening-one');
    final divider = line(after, 'in-1');
    expect(panes, hasLength(2));
    expect(Infill.isGlass(panes.first.finish), isTrue);
    expect(Infill.isPanel(panes.last.finish), isTrue);
    for (final child in [divider.parentId, for (final p in panes) p.parentId]) {
      expect(child, one.id);
    }
    final branch = DesignTree.of(after).openings
        .singleWhere((b) => b.openingId == one.id);
    expect(branch.barIds, [divider.id]);
    expect(branch.panes.map((p) => p.sectionId), [for (final p in panes) p.id]);
    // None of them is a main division of the design.
    final topLevel = {for (final s in after.topLevelSections) s.id};
    for (final p in panes) {
      expect(topLevel, isNot(contains(p.id)));
    }
    expect(
      after.topLevelDividers.map((d) => d.id),
      isNot(contains(divider.id)),
    );
  });

  test('TEST 6 — moved, all of the opening\'s children move with it', () {
    final middle = after.topLevelSections.singleWhere(
      (s) =>
          s.outline.top > 300 &&
          after.openingOf(s.id) == null &&
          s.outline.left > 800 &&
          s.outline.right < 1600,
    );
    final from = regionOf(after, 'opening-one');
    final by = Vec2(
      middle.outline.left - from.left,
      middle.outline.top - from.top,
    );
    final moved = DesignEdits.moveOpeningToSection(
      after,
      'opening-one',
      middle.id,
    );
    expect(opening(moved, 'opening-one').sectionId, middle.id);

    // Every child is where it was, carried by exactly the move.
    final bar = line(moved, 'in-1');
    final was = line(after, 'in-1');
    expect(bar.parentId, 'opening-one');
    expect(bar.a.x, closeTo(was.a.x + by.x, 1e-6));
    expect(bar.b.x, closeTo(was.b.x + by.x, 1e-6));
    expect(bar.a.y, closeTo(was.a.y + by.y, 1e-6));
    final panes = panesOf(moved, 'opening-one');
    final panesWere = panesOf(after, 'opening-one');
    expect(panes, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(panes[i].parentId, 'opening-one');
      expect(panes[i].finish.toJson(), panesWere[i].finish.toJson());
      expect(
        panes[i].outline.left,
        closeTo(panesWere[i].outline.left + by.x, 1e-6),
      );
      expect(
        panes[i].outline.top,
        closeTo(panesWere[i].outline.top + by.y, 1e-6),
      );
    }
    // And its hinges and handle went with it.
    for (final piece in moved.hardware) {
      if (moved.openingHolding(piece.parentId)?.id != 'opening-one') continue;
      expect(within(moved.sectionById(middle.id)!.outline, piece.at), isTrue);
    }
    // In 3D too: every facet of the opening is carried by exactly the move.
    Set<String> ids(Design d) => {
      'opening-one',
      opening(d, 'opening-one').sectionId,
      for (final e in d.contentsOf(opening(d, 'opening-one'))) e.id,
    };
    List<String> facets(Design d, [Vec2 shift = Vec2.zero]) => [
      for (final f in MeshBuilder.build(d).facets)
        if (ids(d).contains(f.elementId))
          [
            f.role.name,
            for (final c in f.corners)
              '${(c.x + shift.x).toStringAsFixed(3)},'
                  '${(c.y + shift.y).toStringAsFixed(3)},'
                  '${c.z.toStringAsFixed(3)}',
          ].join(' '),
    ]..sort();
    expect(facets(moved), facets(after, by));
  });

  test('TEST 7 — resized, its internal geometry stays associated with it', () {
    final mullion = line(after, 'mullion-1');
    final resized = DesignEdits.moveDivider(
      after,
      mullion.id,
      const Vec2(120, 0),
    );
    final region = regionOf(resized, 'opening-one');
    expect(
      region.width,
      closeTo(regionOf(after, 'opening-one').width + 120, 1),
    );

    final bar = line(resized, 'in-1');
    expect(bar.parentId, 'opening-one');
    expect(xs(bar).first, closeTo(region.left, 1));
    expect(
      xs(bar).last,
      closeTo(region.right, 1),
      reason: 'spans the new width',
    );
    expect(
      DesignEdits.alongWithin(resized, bar),
      closeTo(DesignEdits.alongWithin(after, line(after, 'in-1'))!, 1e-6),
      reason: 'the same place in the opening\'s own terms',
    );
    final panes = panesOf(resized, 'opening-one');
    expect(panes, hasLength(2));
    expect(Infill.isGlass(panes.first.finish), isTrue);
    expect(Infill.isPanel(panes.last.finish), isTrue);
    for (final p in panes) {
      expect(p.parentId, 'opening-one');
      expect(region.holds(p.outline.edges.first, reach: 1), isTrue);
    }
    expect(
      fingerprint(resized, 'opening-two'),
      fingerprint(after, 'opening-two'),
    );
  });

  test('TEST 8 — CAD draws exactly the same geometry: each opening\'s line '
      'inside that opening, and nowhere else', () async {
    final view = ViewTransform.fit(
      after.frame!.outline,
      _size,
      padding: const EdgeInsets.all(60),
    );
    // The same design with and without the two lines drawn in the openings:
    // every pixel those lines put on the drawing is inside one of them.
    final withoutInside = drawn(marked(), _outside);
    final withInside = drawn(marked(), [..._outside, ..._inside]);
    final a = await pixels(withoutInside, view);
    final b = await pixels(withInside, view);
    final boxes = [
      for (final id in ['opening-one', 'opening-two'])
        Rect.fromPoints(
          view.toScreen(regionOf(withInside, id).topLeft),
          view.toScreen(
            Vec2(
              regionOf(withInside, id).right,
              regionOf(withInside, id).bottom,
            ),
          ),
        ).inflate(1),
    ];
    // Right of the drawing is the row of the divisions made inside each
    // part: the lines made panes of the openings, whose heights are written
    // down the right — beside the drawing, measured off it, never on it.
    final drawing = Rect.fromPoints(
      view.toScreen(after.frame!.outline.topLeft),
      view.toScreen(
        Vec2(after.frame!.outline.right, after.frame!.outline.bottom),
      ),
    );
    var changed = 0, beside = 0;
    for (var i = 0; i < a.length; i += 4) {
      if (a[i] == b[i] && a[i + 1] == b[i + 1] && a[i + 2] == b[i + 2]) {
        continue;
      }
      final p = Offset(
        ((i ~/ 4) % 960).toDouble(),
        ((i ~/ 4) ~/ 960).toDouble(),
      );
      if (p.dx > drawing.right + 2) {
        beside++;
        continue;
      }
      changed++;
      expect(
        boxes.any((box) => box.contains(p)),
        isTrue,
        reason: 'pixel at $p',
      );
    }
    expect(changed, greaterThan(0));
    expect(beside, greaterThan(0), reason: 'the panes are dimensioned');

    // And CAD draws from the model's own tree: each bar once, at the level
    // the model puts it.
    final tree = DesignTree.of(after);
    expect(tree.barIds.toSet(), {for (final d in after.topLevelDividers) d.id});
    expect(
      [...tree.everyBar]..sort(),
      [for (final d in after.dividers) d.id]..sort(),
    );
  });

  test('TEST 9 — 3D builds exactly the same geometry', () {
    final mesh = MeshBuilder.build(after);
    final built = {for (final f in mesh.facets) f.elementId};
    // Every bar and every pane of the tree is built.
    for (final d in after.dividers) {
      expect(built, contains(d.id));
    }
    for (final branch in DesignTree.of(after).everySection) {
      if (branch.isLeaf) expect(built, contains(branch.sectionId));
    }
    // Nothing is built that the design does not have.
    final parts = {for (final e in after.allElements) e.id};
    expect(built.difference(parts), isEmpty);
    // And every bar stands where CAD draws it: each of its facets inside the
    // body CAD lays down for it.
    for (final bar in after.dividers) {
      final body = bodyOf(after, bar);
      for (final f in mesh.facets.where((f) => f.elementId == bar.id)) {
        for (final c in f.corners) {
          expect(
            within(body, c.flat),
            isTrue,
            reason: '${bar.fromStrokeId} at $c',
          );
        }
      }
    }
  });

  test('TEST 10 — completing a line never changes an opening\'s size or '
      'location', () {
    for (final id in ['opening-one', 'opening-two']) {
      final was = before.sectionById(opening(before, id).sectionId)!.outline;
      final now = after.sectionById(opening(after, id).sectionId)!.outline;
      expect(json(now.toJson()), json(was.toJson()));
      expect(opening(after, id).sectionId, opening(before, id).sectionId);
      expect(opening(after, id).markAt, opening(before, id).markAt);
    }
    // Read again, still the same.
    final again = SketchInterpreter.interpret(after).design;
    for (final id in ['opening-one', 'opening-two']) {
      expect(
        json(regionOf(again, id).toJson()),
        json(regionOf(before, id).toJson()),
      );
    }
  });

  test('TEST 11 — no line exists as both global and opening geometry', () {
    for (final design in [after, SketchInterpreter.interpret(after).design]) {
      // One bar per line drawn.
      for (final s in [..._outside, ..._inside]) {
        expect(
          design.dividers.where((d) => d.fromStrokeId == s.id),
          hasLength(1),
        );
      }
      // Each bar has one owner, and appears once in the tree.
      final everyBar = [...DesignTree.of(design).everyBar];
      expect(everyBar.toSet(), hasLength(everyBar.length));
      final topLevel = {for (final d in design.topLevelDividers) d.id};
      for (final d in design.dividers) {
        if (d.parentId != null) expect(topLevel, isNot(contains(d.id)));
      }
      // And no two bars lie on the same line.
      final segments = [
        for (final d in design.dividers)
          json([d.a.x, d.a.y, d.b.x, d.b.y].map((v) => v.round()).toList()),
      ];
      expect(segments.toSet(), hasLength(segments.length));
    }
  });

  test('TEST 12 — no unrelated geometry moves', () {
    // Drawing the lines moved nothing that was there: the frame and every
    // bar already drawn, and both openings.
    final drawnBefore = {for (final d in before.dividers) d.id: d};
    for (final d in after.dividers) {
      if (drawnBefore[d.id] case final was?) {
        expect(json(d.toJson()), json(was.toJson()));
      }
    }
    expect(json(after.frame!.toJson()), json(before.frame!.toJson()));

    // Moving or resizing Opening #1 leaves Opening #2 and the main design's
    // own lines exactly where they were.
    final middle = after.topLevelSections.singleWhere(
      (s) =>
          s.outline.top > 300 &&
          after.openingOf(s.id) == null &&
          s.outline.left > 800 &&
          s.outline.right < 1600,
    );
    final moved = DesignEdits.moveOpeningToSection(
      after,
      'opening-one',
      middle.id,
    );
    expect(
      fingerprint(moved, 'opening-two'),
      fingerprint(after, 'opening-two'),
    );
    expect(mainDesign(moved), mainDesign(after));

    // Swinging Opening #1 moves nothing outside it in 3D.
    final ones = {
      'opening-one',
      opening(after, 'opening-one').sectionId,
      for (final e in after.contentsOf(opening(after, 'opening-one'))) e.id,
    };
    String outside(Mesh m) => ([
      for (final f in m.facets)
        if (!ones.contains(f.elementId) &&
            after.openingHolding(f.elementId) == null &&
            f.elementId != opening(after, 'opening-two').sectionId &&
            !after
                .contentsOf(opening(after, 'opening-two'))
                .any((e) => e.id == f.elementId))
          f.corners.map((c) => c.toString()).join(),
    ]..sort()).join('|');
    expect(
      outside(MeshBuilder.build(after, openFraction: 1)),
      outside(MeshBuilder.build(after)),
    );
  });
}

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
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The phase: *CAD must render the exact same geometry hierarchy. If the
// divider belongs to the opening, CAD renders it inside the opening — not by
// recalculating its ownership, not by an offset, not in the overall design's
// coordinates, but at the opening's position plus the child's own.*
//
// ┌──────────────────────────────┐
// │            FIXED             │
// ├─────────┬────────────────────┤
// │    >    │                    │
// │ ──      │       FIXED        │   an incomplete line drawn in the opening
// │         │                    │
// └─────────┴────────────────────┘
//
// Everything is held on the pixels the technical drawing actually lays down:
// the drawing with the line against the same drawing without it, so every
// pixel the line is responsible for is found, and required to be inside the
// opening.

const _size = Size(900, 700);

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The drawing, read: a band across the head, a narrow left light marked
/// `>` and a wide fixed light beside it.
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
          Vec2(2400, 0),
          Vec2(2400, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        pen('transom', const [Vec2(0, 600), Vec2(2400, 600)]),
        pen('mullion', const [Vec2(800, 600), Vec2(800, 2000)]),
        pen('mark', const [Vec2(250, 1000), Vec2(550, 1300), Vec2(250, 1600)]),
      ],
    ),
  ),
).design;

/// [marked] with an incomplete line drawn in the opening — started in from
/// the jamb, stopped well short of the mullion — and the sheet read again.
Design withLine() {
  final before = marked();
  return SketchInterpreter.interpret(
    before.copyWith(
      sketch: Sketch(
        strokes: [
          ...before.sketch.strokes,
          pen('line', const [Vec2(200, 1400), Vec2(600, 1400)]),
        ],
      ),
    ),
  ).design;
}

DividerElement lineOf(Design d) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == 'line');

Polygon openingOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!.outline;

/// The one view every drawing here is painted through, so the pixels of two
/// designs are comparable.
ViewTransform viewOf(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _size,
  padding: const EdgeInsets.all(60),
);

Future<Uint8List> pixels(Design d, ViewTransform view, CadLayers layers) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: d,
    view: view,
    layers: layers,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Every pixel that differs between [a] and [b].
List<Offset> changed(Uint8List a, Uint8List b) => [
  for (var i = 0; i < a.length; i += 4)
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2])
      Offset(
        ((i ~/ 4) % _size.width.round()).toDouble(),
        ((i ~/ 4) ~/ _size.width.round()).toDouble(),
      ),
];

/// [box] on the screen, with a pixel of antialiasing either side.
Rect onScreen(ViewTransform view, Polygon box) => Rect.fromPoints(
  view.toScreen(box.topLeft),
  view.toScreen(Vec2(box.right, box.bottom)),
).inflate(1);

const _everyLayer = [
  CadLayers(),
  CadLayers(sketch: true),
  CadLayers(centreLines: true, hiddenDetail: true),
  CadLayers(dimensions: false, annotations: false, grips: false, grid: false),
];

void main() {
  test('the divider completes inside the opening, and is the opening\'s', () {
    final design = withLine();
    final opening = design.openings.single;
    final box = openingOf(design);
    final line = lineOf(design);

    expect(line.parentId, opening.id);
    expect([line.a.x, line.b.x]..sort(), [
      closeTo(box.left, 1),
      closeTo(box.right, 1),
    ]);
    expect(line.a.y, closeTo(1400, 1));
    expect(box.holds(line.segment, reach: 1), isTrue);

    // The tree CAD walks puts it in the opening's branch and nowhere else,
    // so the drawing never has to work out whose it is.
    final tree = DesignTree.of(design);
    expect(tree.barIds, isNot(contains(line.id)));
    expect(tree.openings.single.barIds, [line.id]);
  });

  test('the body CAD draws for it stays inside the opening', () {
    final design = withLine();
    final line = lineOf(design);
    // Exactly the body the painter lays down: the bar's two faces, stopped
    // at the sash it is in.
    final side = line.segment.unit.perpendicular * (line.widthMm / 2);
    final body = Polygon([
      line.a + side,
      line.b + side,
      line.b - side,
      line.a - side,
    ]).clippedTo(OpeningLeaf.daylightAround(design, line.parentId)!);
    expect(body.isEmpty, isFalse);
    final box = openingOf(design);
    for (final corner in body.corners) {
      // `contains` counts a point on the edge as inside.
      expect(
        box.contains(corner),
        isTrue,
        reason: '$corner is outside the opening',
      );
    }
  });

  test('every pixel the line puts on the drawing is inside the opening — '
      'none above it, none in the fixed lights', () async {
    final before = marked();
    final after = withLine();
    final view = viewOf(after);
    final opening = onScreen(view, openingOf(after));
    final band = after.topLevelSections.reduce(
      (a, b) => a.outline.top < b.outline.top ? a : b,
    );
    final fixed = after.topLevelSections.singleWhere(
      (s) => s.id != band.id && s.id != after.openings.single.sectionId,
    );

    // Right of the drawing is the row of the divisions made inside each
    // part: the line made two panes of the opening, and with dimensions on
    // their heights are written down the right — measured off the opening,
    // standing beside the drawing and not on it.
    final drawing = onScreen(view, after.frame!.outline);
    for (final layers in _everyLayer) {
      var diff = changed(
        await pixels(before, view, layers),
        await pixels(after, view, layers),
      );
      if (layers.dimensions) {
        expect(
          diff.any((p) => p.dx > drawing.right),
          isTrue,
          reason: 'the panes it makes are dimensioned',
        );
        diff = [
          for (final p in diff)
            if (p.dx <= drawing.right + 2) p,
        ];
      }
      expect(diff, isNotEmpty, reason: 'the line is drawn');
      final outside = [
        for (final p in diff)
          if (!opening.contains(p)) p,
      ];
      expect(outside, isEmpty, reason: 'drawn outside the opening');
      // Said the phase's way too: nothing above the opening, nothing in the
      // band across the head, nothing in the fixed light beside it.
      expect(diff.where((p) => p.dy < opening.top), isEmpty);
      expect(
        diff.where((p) => onScreen(view, band.outline).deflate(2).contains(p)),
        isEmpty,
      );
      expect(
        diff.where((p) => onScreen(view, fixed.outline).deflate(2).contains(p)),
        isEmpty,
      );
    }
  });

  test('it is drawn at the opening\'s position plus its own: moved to the '
      'other light, the opening takes the line there, the same distance '
      'down it', () async {
    DesignElement other(Design d) => d.topLevelSections.singleWhere(
      (s) =>
          s.id != d.openings.single.sectionId &&
          s.outline.top > d.frame!.outline.top + 300,
    );
    Design moved(Design d) =>
        DesignEdits.moveOpeningToSection(d, d.openings.single.id, other(d).id);

    // The bar alone: without the glass's hatching, which follows the panes
    // and so is drawn differently in a light of a different width.
    const layers = CadLayers(
      dimensions: false,
      annotations: false,
      grips: false,
      grid: false,
      hatching: false,
    );
    final view = viewOf(withLine());

    final here = changed(
      await pixels(marked(), view, layers),
      await pixels(withLine(), view, layers),
    );
    final there = changed(
      await pixels(moved(marked()), view, layers),
      await pixels(moved(withLine()), view, layers),
    );

    final hereBox = onScreen(view, openingOf(withLine()));
    final thereBox = onScreen(view, openingOf(moved(withLine())));
    expect(thereBox.left, greaterThan(hereBox.right), reason: 'it moved');

    // Inside the opening where it now is, and nothing left where it was.
    expect([
      for (final p in there)
        if (!thereBox.contains(p)) p,
    ], isEmpty);
    expect(there, isNotEmpty);

    // The same place in the opening's own terms: as far down it as before.
    double topOf(List<Offset> ps) =>
        ps.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    double bottomOf(List<Offset> ps) =>
        ps.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    expect(
      topOf(there) - thereBox.top,
      closeTo(topOf(here) - hereBox.top, 1.5),
    );
    expect(
      bottomOf(there) - thereBox.top,
      closeTo(bottomOf(here) - hereBox.top, 1.5),
    );
  });
}

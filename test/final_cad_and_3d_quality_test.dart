import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/dimension_layout.dart';
import 'package:proframe/app/canvas/view_controls.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/model_view.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/surface.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/studio.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/a_customer_s_page_test.dart' as page;
import 'app/a_design_in_every_view_test.dart' as every;
import 'app/customers_screen_test.dart' as customers;
import 'app/the_designs_screen_test.dart' as screen;
import 'mixed_door_and_window_test.dart' as mixed;

// Phase 20 of the CAD and 3D work: the final quality assurance.
//
// One complex, real design — drawn stroke by stroke and read, not laid out:
//
//   ┌──────────┬──────────┬──────────┬──────────┐
//   │  CLEAR   │  WINDOW  │  TINTED  │   DOOR   │
//   │  GLASS   │  clear   │  GLASS   │  tinted  │
//   │          ├──────────┤          ├──────────┤
//   │          │  panel   │          │  panel   │
//   └──────────┴──────────┴──────────┴──────────┘
//
// an anthracite aluminium frame, white uPVC mullions, an aluminium divider
// inside each opening, a door's bronze lever and lock and a window's silver
// espagnolette, hinges on both, a dimension the user drew, and then every
// claim the brief makes about the technical drawing and the solid measured
// on what each actually puts down: the drawing's pixels, the solid's facets
// and the model's pixels. Beside it, a board of five pieces of one shape
// and one colour — glass, panel, frame, metal and rubber — which only the
// materials can tell apart. Then that nothing in the look moved any of the
// geometry, and the design taken through the real app: opened for its
// customer, drawn in CAD and 3D, turned, zoomed, fitted, edited, saved and
// read back.

const _anthracite = Finish(
  colour: 0xFF3A3D40,
  material: MaterialKind.aluminium,
);
const _whitePvc = Finish(colour: 0xFFF4F4F1, material: MaterialKind.upvc);

/// The design, built the way the user builds it.
Design qaDesign() {
  var d = mixed.theScreen();
  final lights = d.topLevelSections;
  final window = mixed.windowLeaf(d), door = mixed.doorLeaf(d);
  SectionElement upper(OpeningElement o) => d
      .childSectionsOf(o.sectionId)
      .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
  d = Infill.fill(d, {
    lights[0].id: GlassLook.clear.finish,
    upper(window).id: GlassLook.clear.finish,
    lights[2].id: GlassLook.tinted.finish,
    upper(door).id: GlassLook.tinted.finish,
  });
  d = d.withElement(d.frame!.copyWith(finish: _anthracite));
  for (final bar in d.dividers) {
    d = d.withElement(
      bar.copyWith(finish: bar.parentId == null ? _whitePvc : _anthracite),
    );
  }
  for (final piece in d.hardware) {
    final onDoor = d.openingHolding(piece.parentId)?.id == door.id;
    final colour = piece.kind == HardwareKind.hinge
        ? HardwareColour.black.colour
        : onDoor
        ? HardwareColour.bronze.colour
        : HardwareColour.silver.colour;
    d = d.withElement(
      piece.copyWith(finish: piece.finish.copyWith(colour: colour)),
    );
  }
  return d.copyWith(
    dimensions: const [
      DimensionElement(
        id: 'dim-width',
        a: Vec2(0, -400),
        b: Vec2(4800, -400),
        statedMm: 4800,
      ),
    ],
  );
}

// ------------------------------------------------------------------ pixels

class _Picture {
  final Uint8List rgba;
  final Size size;
  _Picture(this.rgba, this.size);

  List<int> at(Offset p) {
    final x = p.dx.round().clamp(0, size.width.round() - 1);
    final y = p.dy.round().clamp(0, size.height.round() - 1);
    final i = (y * size.width.round() + x) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }

  double light(Offset p) {
    final c = at(p);
    return (c[0] + c[1] + c[2]) / 3;
  }
}

Future<_Picture> _paint(Size size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return _Picture(data!.buffer.asUint8List(), size);
}

double _distance(List<int> a, List<int> b) => math.sqrt(
  [for (var c = 0; c < 3; c++) (a[c] - b[c]) * (a[c] - b[c])]
      .reduce((x, y) => x + y),
);

List<int> _median(_Picture p, Iterable<Offset> points) {
  final all = points.toList();
  return [
    for (var c = 0; c < 3; c++)
      (([for (final q in all) p.at(q)[c]])..sort())[all.length ~/ 2],
  ];
}

double _spread(List<double> v) {
  final s = [...v]..sort();
  final inner = s.sublist(
    s.length ~/ 10,
    math.max(s.length ~/ 10 + 1, s.length * 9 ~/ 10),
  );
  return inner.last - inner.first;
}

// --------------------------------------------------------------- the CAD

const _sheet = Size(1600, 1000);

ViewTransform _cadView(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _sheet,
  marginFraction: 0.06,
  padding:
      const EdgeInsets.only(left: 118, right: 70, top: 20, bottom: 150) +
      DimensionLayout.roomFor(d),
);

Future<_Picture> _cad(Design d, {ViewTransform? view}) => _paint(
  _sheet,
  (canvas) => CadPainter(
    design: d,
    view: view ?? _cadView(d),
    layers: const CadLayers(),
  ).paint(canvas, _sheet),
);

/// Every point of a grid inside [shape] on the sheet, [inset] pixels clear
/// of its edge.
List<Offset> _inside(ViewTransform view, Polygon shape, {double inset = 10}) {
  final box = Rect.fromPoints(
    view.toScreen(shape.topLeft),
    view.toScreen(Vec2(shape.right, shape.bottom)),
  ).deflate(inset);
  return [
    for (var y = box.top; y <= box.bottom; y += 3)
      for (var x = box.left; x <= box.right; x += 3) Offset(x, y),
  ];
}

// --------------------------------------------------------------- the solid

const _stage = Size(1100, 800);

Future<(_Picture, ModelPainter)> _model(
  Design d, {
  Camera camera = Camera.presentation,
  ViewMode mode = ViewMode.realistic,
  Palette palette = Palette.light,
  bool floor = false,
  Mesh? mesh,
}) async {
  final built = mesh ?? MeshBuilder.build(d);
  final framed = camera.framing(
    built,
    width: _stage.width,
    height: _stage.height,
  );
  final painter = ModelPainter(
    faces: framed.project(built),
    size: _stage,
    viewSpan: Camera.viewSpan(built),
    mode: mode,
    groundPlane: floor,
    floor: floor ? Floor.under(built)?.seenBy(framed, built) : null,
    palette: palette,
  );
  return (await _paint(_stage, (c) => painter.paint(c, _stage)), painter);
}

/// The uppermost face at every point of a 3-pixel grid — the last one
/// painted that holds the point, never a sheet of glass where it is kept off
/// what lies in front of it — and the points where it is one of [which],
/// with the same face all round.
List<Offset> _on(
  ModelPainter painter,
  bool Function(ProjectedFacet) which, {
  bool sameFace = true,
  bool sides = false,
}) {
  const step = 3.0;
  final faces = painter.faces;
  final scale = 1 / painter.millimetresPerPixel;
  final size = painter.size;
  Offset place(Vec2 v) =>
      Offset(size.width / 2 + v.x * scale, size.height / 2 + v.y * scale);
  final outlines = [
    for (final f in faces) [for (final c in f.corners) place(c)],
  ];
  final boxes = [
    for (final o in outlines)
      Rect.fromLTRB(
        o.map((p) => p.dx).reduce(math.min),
        o.map((p) => p.dy).reduce(math.min),
        o.map((p) => p.dx).reduce(math.max),
        o.map((p) => p.dy).reduce(math.max),
      ),
  ];
  bool inside(List<Offset> o, Offset p) {
    var hit = false;
    for (var i = 0, j = o.length - 1; i < o.length; j = i++) {
      if ((o[i].dy > p.dy) != (o[j].dy > p.dy) &&
          p.dx <
              (o[j].dx - o[i].dx) * (p.dy - o[i].dy) / (o[j].dy - o[i].dy) +
                  o[i].dx) {
        hit = !hit;
      }
    }
    return hit;
  }

  ProjectedFacet? top(Offset p) {
    for (var k = faces.length - 1; k >= 0; k--) {
      if (!boxes[k].contains(p) || !inside(outlines[k], p)) continue;
      if (faces[k].hiders.any(
        (h) => h.length >= 3 && inside([for (final c in h) place(c)], p),
      )) {
        continue;
      }
      return faces[k];
    }
    return null;
  }

  final grid = [
    for (var y = 0.0; y < size.height; y += step)
      [for (var x = 0.0; x < size.width; x += step) top(Offset(x, y))],
  ];
  bool ok(ProjectedFacet? f) =>
      f != null && which(f) && (sides || !f.source.isSide);
  bool near(ProjectedFacet? f, ProjectedFacet here) =>
      sameFace ? identical(f, here) : ok(f);
  return [
    for (var j = 1; j + 1 < grid.length; j++)
      for (var i = 1; i + 1 < grid[j].length; i++)
        if (grid[j][i] case final here?
            when ok(here) &&
                near(grid[j - 1][i], here) &&
                near(grid[j + 1][i], here) &&
                near(grid[j][i - 1], here) &&
                near(grid[j][i + 1], here))
          Offset(i * step, j * step),
  ];
}

// ------------------------------------------------------------ the board

/// Five pieces of one shape and one colour, side by side: which is glass,
/// which panel, which frame, which metal and which rubber is left to the
/// materials alone.
const boardColour = 0xFFE6E8E9;
const boardPieces = ['glass', 'panel', 'frame', 'metal', 'rubber'];

/// Rubber is the one piece in its own colour, the seal's, because its
/// darkness *is* its colour: square on, a matte grey rubber and a matte grey
/// panel take the light identically, as they would on the bench. The other
/// four share [boardColour] and are told apart by what they do alone.
const rubberColour = 0xFF26282A;

List<Facet> _box(
  String id,
  double x0,
  double y0,
  double x1,
  double y1,
  double z0,
  double z1,
  Surface surface,
  FacetRole role, {
  int glassFaces = 2,
  int colour = boardColour,
}) {
  final centre = Vec3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
  Facet face(List<Vec3> c, {bool side = false}) {
    // Turned to face out of the box, whichever way round it was listed.
    final n = (c[1] - c[0]).cross(c[2] - c[0]);
    final mid = c.reduce((a, b) => a + b) * (1 / c.length);
    final corners = n.dot(mid - centre) < 0 ? c.reversed.toList() : c;
    return Facet(
      corners: corners,
      elementId: id,
      colour: colour,
      surface: surface,
      role: role,
      isSide: side,
      glassFaces: glassFaces,
    );
  }

  Vec3 p(double x, double y, double z) => Vec3(x, y, z);
  return [
    face([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)]),
    face([p(x0, y0, z0), p(x1, y0, z0), p(x1, y1, z0), p(x0, y1, z0)]),
    face([
      p(x0, y0, z0),
      p(x1, y0, z0),
      p(x1, y0, z1),
      p(x0, y0, z1),
    ], side: true),
    face([
      p(x0, y1, z0),
      p(x1, y1, z0),
      p(x1, y1, z1),
      p(x0, y1, z1),
    ], side: true),
    face([
      p(x0, y0, z0),
      p(x0, y1, z0),
      p(x0, y1, z1),
      p(x0, y0, z1),
    ], side: true),
    face([
      p(x1, y0, z0),
      p(x1, y1, z0),
      p(x1, y1, z1),
      p(x1, y0, z1),
    ], side: true),
  ];
}

Mesh materialBoard() {
  const w = 400.0, h = 600.0, gap = 120.0;
  final facets = <Facet>[];
  for (var k = 0; k < boardPieces.length; k++) {
    final x = k * (w + gap);
    final id = boardPieces[k];
    switch (id) {
      case 'glass':
        facets.addAll(
          _box(
            id,
            x,
            0,
            x + w,
            h,
            -8,
            0,
            Surfaces.clearGlass,
            FacetRole.glazing,
          ),
        );
      case 'panel':
        facets.addAll(
          _box(id, x, 0, x + w, h, -24, 0, Surfaces.panel, FacetRole.panel),
        );
      case 'frame':
        // A frame's own section: four members seventy deep, with the
        // reveals facing into the opening they hold.
        const m = 70.0;
        for (final (a, b, c, e) in [
          (x, 0.0, x + w, m),
          (x, h - m, x + w, h),
          (x, m, x + m, h - m),
          (x + w - m, m, x + w, h - m),
        ]) {
          facets.addAll(
            _box(id, a, b, c, e, -70, 0, Surfaces.pvc, FacetRole.frame),
          );
        }
      case 'metal':
        facets.addAll(
          _box(
            id,
            x,
            0,
            x + w,
            h,
            -6,
            0,
            Surfaces.handleMetal,
            FacetRole.hardware,
          ),
        );
      case 'rubber':
        facets.addAll(
          _box(
            id,
            x,
            0,
            x + w,
            h,
            -12,
            0,
            Surfaces.rubber,
            FacetRole.frame,
            colour: rubberColour,
          ),
        );
    }
  }
  return Mesh(facets);
}

// ------------------------------------------------------------ fingerprints

String _geometry(Design d) => jsonEncode({
  'frame': [
    for (final c in d.frame!.outline.corners) [c.x, c.y],
  ],
  'profile': d.frame!.profileMm,
  'depth': d.depthMm,
  'bars': [
    for (final b in d.dividers)
      [b.id, b.parentId, b.a.x, b.a.y, b.b.x, b.b.y, b.widthMm],
  ],
  'sections': [
    for (final s in d.sections)
      [
        s.id,
        s.parentId,
        for (final c in s.outline.corners) [c.x, c.y],
      ],
  ],
  'openings': [
    for (final o in d.openings) [o.id, o.sectionId],
  ],
  'dimensions': [
    for (final m in d.dimensions) [m.a.x, m.a.y, m.b.x, m.b.y, m.statedMm],
  ],
});

String _finishes(Design d) => jsonEncode({
  'frame': d.frame!.finish.toJson(),
  for (final b in d.dividers) b.id: b.finish.toJson(),
  for (final s in d.sections) s.id: s.finish.toJson(),
  for (final h in d.hardware) h.id: h.finish.toJson(),
});

String _mesh(Mesh mesh) => [
  for (final f in mesh.facets)
    [
      f.elementId,
      f.role.name,
      for (final c in f.corners)
        '${c.x.toStringAsFixed(4)},${c.y.toStringAsFixed(4)},${c.z.toStringAsFixed(4)}',
    ].join('|'),
].join('\n');

void main() {
  final d = qaDesign();
  final lights = d.topLevelSections;
  final window = mixed.windowLeaf(d), door = mixed.doorLeaf(d);
  List<SectionElement> panesOf(OpeningElement o) =>
      d.childSectionsOf(o.sectionId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  DividerElement dividerOf(OpeningElement o) =>
      d.dividers.singleWhere((b) => d.openingHolding(b.parentId)?.id == o.id);
  final outline = d.frame!.outline;

  group('the design', () {
    test('is the one the user drew: four lights, two openings, a divider '
        'and glass over panel in each, and every material said', () {
      expect(lights, hasLength(4));
      expect(d.topLevelDividers, hasLength(3));
      expect([for (final b in d.topLevelDividers) b.a.x]..sort(), [
        1200,
        2400,
        3600,
      ]);
      expect(d.openings, hasLength(2));
      expect(d.kindOf(window), DesignKind.window);
      expect(d.kindOf(door), DesignKind.door);
      for (final o in [window, door]) {
        final panes = panesOf(o);
        expect(panes, hasLength(2));
        expect(panes.first.finish.material.isGlazing, isTrue);
        expect(panes.last.finish.material, MaterialKind.panel);
      }
      expect(lights[0].finish.material, MaterialKind.clearGlass);
      expect(lights[2].finish.material, MaterialKind.tintedGlass);
      expect(panesOf(door).first.finish.material, MaterialKind.tintedGlass);
      expect(d.frame!.finish, _anthracite);
      expect(d.topLevelDividers.every((b) => b.finish == _whitePvc), isTrue);
      final kinds = {for (final h in d.hardware) h.kind};
      expect(kinds, containsAll([HardwareKind.hinge, HardwareKind.lock]));
      expect(d.hardware.where((h) => h.kind.isHandle), hasLength(2));
      expect(d.dimensions.single.statedMm, 4800);
    });
  });

  group('CAD', () {
    final view = _cadView(d);
    late _Picture sheet;
    setUpAll(() async => sheet = await _cad(d));

    bool dark(Offset p, [double below = 120]) => sheet.light(p) < below;

    test('1. the geometry is accurate: the frame, every bar and every '
        'section exactly where the design has it', () {
      expect(outline.width, 4800);
      expect(outline.height, 2200);
      final geometry = DesignGeometry.of(d);
      for (final bar in d.topLevelDividers) {
        final body = geometry.barBody(bar);
        expect((body.left + body.right) / 2, closeTo(bar.a.x, 1e-6));
        expect(body.width, closeTo(bar.widthMm, 1e-6));
      }
      // The lights tile the daylight: their widths, the bars' and the
      // frame's together are the width drawn.
      final daylight = d.frame!.innerOutline;
      final widths = lights.map((s) => s.outline.width).reduce((a, b) => a + b);
      final bars = d.topLevelDividers
          .map((b) => b.widthMm)
          .reduce((a, b) => a + b);
      expect(widths + bars, closeTo(daylight.width, 1e-6));
      // Each opening is its own light, and nothing wider.
      for (final o in [window, door]) {
        expect(d.outlineOf(o), d.sectionById(o.sectionId)!.outline);
      }
      // And on the sheet: the frame's four corners are inked.
      for (final c in outline.corners) {
        final at = view.toScreen(c);
        final inked = [
          for (var dx = -2; dx <= 2; dx++)
            for (var dy = -2; dy <= 2; dy++)
              dark(at + Offset(dx + 0.0, dy + 0.0)),
        ];
        expect(inked, contains(true), reason: '$c');
      }
    });

    test('2. the dimensions are accurate: every run is a section that is '
        'there, written to the millimetre', () {
      final chains = DimensionChains.of(d);
      final overall = chains
          .expand((c) => c.runs)
          .where((r) => r.of == ChainRunOf.overall)
          .map((r) => r.valueMm)
          .toSet();
      expect(overall, {4800.0, 2200.0});
      for (final run in chains.expand((c) => c.runs)) {
        if (run.of == ChainRunOf.overall) continue;
        final s = d.sectionById(run.sectionId!)!.outline;
        expect(
          [s.width, s.height].any((v) => (v - run.valueMm).abs() < 1e-6),
          isTrue,
          reason: '${run.of} ${run.valueMm}',
        );
      }
      final layout = DimensionLayout.of(d, view, canvas: _sheet);
      expect(layout.figures, isNotEmpty);
      for (final f in layout.figures) {
        expect(f.text, '${Units.formatTo(f.run.valueMm, 1)} ${Units.symbol}');
      }
      expect(layout.figures.map((f) => f.text), contains('480.0 cm'));
      expect(layout.figures.map((f) => f.text), contains('220.0 cm'));
    });

    test('3. the lines are clean: the frame\'s outside runs unbroken', () {
      final y = view.toScreen(outline.topLeft).dy;
      final from = view.toScreen(outline.topLeft).dx + 4;
      final to = view.toScreen(Vec2(outline.right, outline.top)).dx - 4;
      for (var x = from; x <= to; x += 1) {
        expect(
          [for (var dy = -1.5; dy <= 1.5; dy += 0.5) dark(Offset(x, y + dy))],
          contains(true),
          reason: 'a gap at $x',
        );
      }
    });

    test('4. the line hierarchy is clear: the frame\'s outside is heavier '
        'than a divider inside an opening', () {
      int thickness(Offset along, Offset across) {
        var best = 0, run = 0;
        for (var k = -12; k <= 12; k++) {
          if (dark(along + across * k.toDouble(), 90)) {
            run++;
            best = math.max(best, run);
          } else {
            run = 0;
          }
        }
        return best;
      }

      final top = view.toScreen(
        Vec2(lights[0].outline.centroid.x, outline.top),
      );
      final divider = dividerOf(window);
      final inside = view.toScreen(
        Vec2((divider.a.x + divider.b.x) / 2 - 150, divider.a.y),
      );
      final heavy = thickness(top, const Offset(0, 1));
      final light = thickness(inside, const Offset(0, 1));
      expect(
        heavy,
        greaterThan(light),
        reason: 'outline $heavy, divider $light',
      );
      expect(Cad.outline, greaterThan(Cad.bar));
      expect(Cad.bar, greaterThan(Cad.glazingBar));
      expect(Cad.glazingBar, greaterThan(Cad.detail));
      expect(Cad.detail, greaterThan(Cad.hairline));
    });

    test('5–7. glass, panel and frame are each drawn as what they are — a '
        'tint, hatching and the structural tone — and none is a coloured '
        'rectangle', () {
      final glass = _inside(view, lights[0].outline, inset: 40);
      final panel = _inside(view, panesOf(window).last.outline, inset: 12);
      final jamb = Polygon([
        outline.topLeft,
        Vec2(outline.left + d.frame!.profileMm, outline.top),
        Vec2(outline.left + d.frame!.profileMm, outline.bottom),
        Vec2(outline.left, outline.bottom),
      ]);
      final frameAt = view.toScreen(
        Vec2(outline.left + d.frame!.profileMm * 0.3, outline.top + 1100),
      );
      final glassColour = _median(sheet, glass);
      final frameColour = sheet.at(frameAt);
      final paper = [
        (Cad.paper.sheet.r * 255).round(),
        (Cad.paper.sheet.g * 255).round(),
        (Cad.paper.sheet.b * 255).round(),
      ];
      // The glass is the sheet's pale tint: light, cool, and not the paper.
      expect(_distance(glassColour, paper), greaterThan(8));
      expect(glassColour[2], greaterThan(glassColour[0]));
      // The panel is hatched on the paper — never flooded with its brown.
      final hatched =
          panel.where((p) => sheet.light(p) < 225).length / panel.length;
      expect(hatched, inInclusiveRange(0.03, 0.45));
      expect(_distance(_median(sheet, panel), paper), lessThan(12));
      // The frame is the structural tone.
      final structure = [
        (Cad.paper.structure.r * 255).round(),
        (Cad.paper.structure.g * 255).round(),
        (Cad.paper.structure.b * 255).round(),
      ];
      expect(_distance(frameColour, structure), lessThan(10), reason: '$jamb');
      // Three different things, and all of them quiet: no fill on the sheet
      // is a saturated colour.
      expect(_distance(glassColour, frameColour), greaterThan(8));
      for (final c in [glassColour, frameColour, _median(sheet, panel)]) {
        expect(c.reduce(math.max) - c.reduce(math.min), lessThan(20));
      }
    });

    test('8. every internal divider is drawn inside its own opening, as its '
        'opening\'s', () {
      final tree = DesignTree.of(d);
      final geometry = DesignGeometry.of(d);
      for (final o in [window, door]) {
        final bar = dividerOf(o);
        final branch = tree.sections.singleWhere(
          (s) => s.sectionId == o.sectionId,
        );
        expect(branch.barIds, [bar.id]);
        expect(tree.barIds, isNot(contains(bar.id)));
        final box = d.outlineOf(o)!;
        for (final c in geometry.barBody(bar).corners) {
          expect(c.x, inInclusiveRange(box.left - 1e-6, box.right + 1e-6));
          expect(c.y, inInclusiveRange(box.top - 1e-6, box.bottom + 1e-6));
        }
      }
    });

    test('9. the openings are independent: moving one\'s divider changes the '
        'drawing inside that opening and nowhere else on it', () async {
      final bar = dividerOf(window);
      final moved = DesignEdits.moveDividerWithin(d, bar.id, 700);
      expect(moved.openings, hasLength(2));
      final after = await _cad(moved, view: view);
      final box = Rect.fromPoints(
        view.toScreen(d.outlineOf(window)!.topLeft),
        view.toScreen(
          Vec2(d.outlineOf(window)!.right, d.outlineOf(window)!.bottom),
        ),
      ).inflate(3);
      final drawing = Rect.fromPoints(
        view.toScreen(outline.topLeft),
        view.toScreen(Vec2(outline.right, outline.bottom)),
      );
      var changed = 0;
      for (var y = drawing.top; y <= drawing.bottom; y += 1) {
        for (var x = drawing.left; x <= drawing.right; x += 1) {
          final p = Offset(x, y);
          if (_distance(sheet.at(p), after.at(p)) < 1) continue;
          changed++;
          expect(box.contains(p), isTrue, reason: 'changed at $p');
        }
      }
      expect(changed, greaterThan(50));
    });

    test('10. it is a drawing, not coloured rectangles: across a jamb the '
        'outside, the sightline and the daylight edge are three lines', () {
      final y = view.toScreen(Vec2(0, outline.top + 1100)).dy;
      final from = view.toScreen(outline.topLeft).dx - 4;
      final to = view.toScreen(Vec2(d.frame!.innerOutline.left, 0)).dx + 3;
      var lines = 0;
      var inLine = false;
      for (var x = from; x <= to; x += 0.5) {
        final on = sheet.light(Offset(x, y)) < 200;
        if (on && !inLine) lines++;
        inLine = on;
      }
      expect(lines, greaterThanOrEqualTo(3));
    });

    test('11. it stays readable: no figure or name overlaps another, and '
        'none lies on the drawing', () {
      final layout = DimensionLayout.of(d, view, canvas: _sheet);
      final words = [
        for (final f in layout.figures) (f.text, f.rect),
        for (final n in layout.names) (n.text, n.rect),
      ];
      final drawing = Rect.fromPoints(
        view.toScreen(outline.topLeft),
        view.toScreen(Vec2(outline.right, outline.bottom)),
      );
      for (var i = 0; i < words.length; i++) {
        expect(
          words[i].$2.deflate(0.5).overlaps(drawing),
          isFalse,
          reason: words[i].$1,
        );
        for (var j = i + 1; j < words.length; j++) {
          expect(
            words[i].$2.deflate(0.5).overlaps(words[j].$2.deflate(0.5)),
            isFalse,
            reason: '${words[i].$1} and ${words[j].$1}',
          );
        }
      }
    });
  });

  group('3D', () {
    final mesh = MeshBuilder.build(d);
    List<Facet> of(String id) => [
      for (final f in mesh.facets)
        if (f.elementId == id) f,
    ];
    (double, double) zRange(Iterable<Facet> facets) {
      var lo = double.infinity, hi = -double.infinity;
      for (final f in facets) {
        for (final c in f.corners) {
          lo = math.min(lo, c.z);
          hi = math.max(hi, c.z);
        }
      }
      return (lo, hi);
    }

    test('1–2. the model and its frame have real depth: the frame runs the '
        'whole depth, with sides and reveals as well as a face', () {
      final (lo, hi) = zRange(of(d.frame!.id));
      expect(hi, closeTo(0, 1e-6));
      expect(lo, closeTo(-d.depthMm, 1e-6));
      final turned = of(d.frame!.id).where((f) => f.normal.z.abs() < 0.2);
      expect(turned.length, greaterThan(8), reason: 'sides and reveals');
      final (mlo, mhi) = zRange(mesh.facets);
      expect(mhi - mlo, greaterThan(d.depthMm));
    });

    test('3 & 6. the panel is a solid slab, and not transparent', () {
      final panel = of(panesOf(window).last.id)
          .where((f) => f.role == FacetRole.panel);
      final (lo, hi) = zRange(panel);
      expect(hi - lo, greaterThan(10));
      expect(panel.every((f) => !f.surface.isTransparent), isTrue);
      expect(panel.any((f) => f.normal.z > 0.9), isTrue);
      expect(panel.any((f) => f.normal.z < -0.9), isTrue);
    });

    test('4–5. the glass is a sealed unit of glass: two sheets that let '
        'light through, and a rubber seal', () {
      final glass = of(lights[0].id).where((f) => f.role == FacetRole.glazing);
      final sheets = glass.where((f) => f.surface.isTransparent && !f.isSide);
      expect(
        sheets.length,
        greaterThanOrEqualTo(4),
        reason: 'two sheets, two faces',
      );
      expect(glass.any((f) => f.surface.kind == MaterialClass.rubber), isTrue);
      for (final f in sheets) {
        expect(f.surface.transmission, greaterThan(0.3));
        expect(f.surface.reflectivity, greaterThan(0.04));
      }
    });

    test('7–8. the frame answers the light as aluminium, and the '
        'ironmongery as metal', () {
      expect(of(d.frame!.id).first.surface.kind, MaterialClass.aluminium);
      for (final piece in d.hardware) {
        for (final f in of(piece.id)) {
          expect(f.surface.metallic, 1, reason: piece.kind.name);
        }
      }
    });

    test('9–10. the handles stand out of their leaves, and the hinges have '
        'thickness', () {
      for (final piece in d.hardware) {
        final (lo, hi) = zRange(of(piece.id));
        if (piece.kind.isHandle) {
          expect(hi - lo, greaterThan(30), reason: '${piece.kind}');
        }
        if (piece.kind == HardwareKind.hinge) {
          expect(hi - lo, greaterThan(3), reason: 'hinge');
        }
      }
    });

    test('4, 5, 6, 8 & 12 on the picture: glass seen through and catching '
        'the light, the panel opaque and even, the metal lit across', () async {
      final (light, painter) = await _model(d, mesh: mesh);
      final (dark, _) = await _model(d, mesh: mesh, palette: Palette.dark);
      final glass = _on(
        painter,
        (f) => f.elementId == lights[0].id && f.source.surface.isTransparent,
      );
      final panel = _on(
        painter,
        (f) =>
            f.elementId == panesOf(window).last.id &&
            f.source.role == FacetRole.panel,
      );
      final handle = _on(
        painter,
        (f) => f.elementId == d.hardware.firstWhere((h) => h.kind.isHandle).id,
        sameFace: false,
      );
      expect(glass, isNotEmpty);
      expect(panel, isNotEmpty);
      expect(handle, isNotEmpty);
      final through = glass
          .where((p) => _distance(light.at(p), dark.at(p)) > 6)
          .length;
      expect(
        through / glass.length,
        greaterThan(0.8),
        reason: 'glass seen through',
      );
      for (final p in panel) {
        expect(dark.at(p), light.at(p), reason: 'panel opaque at $p');
      }
      expect(
        _spread([for (final p in glass) light.light(p)]),
        greaterThan(_spread([for (final p in panel) light.light(p)])),
        reason: 'the glass carries the light across it; the panel is even',
      );
      expect(_spread([for (final p in panel) light.light(p)]), lessThan(12));
      final lit = [for (final p in handle) light.light(p)];
      expect(
        lit.reduce(math.max) - lit.reduce(math.min),
        greaterThan(40),
        reason: 'a highlight and a shade across the metal',
      );
    });

    test('11. shadows say where things stand: the floor darkens at the foot, '
        'and the ironmongery casts onto its leaf', () async {
      final (realistic, painter) = await _model(d, mesh: mesh, floor: true);
      final (material, _) = await _model(
        d,
        mesh: mesh,
        floor: true,
        mode: ViewMode.material,
      );
      final scale = 1 / painter.millimetresPerPixel;
      final framed = Camera.presentation.framing(
        mesh,
        width: _stage.width,
        height: _stage.height,
      );
      final eye = framed.eyeSpaceFor(mesh);
      final foot = eye.place(Vec3(2400, 2200, 60))!;
      final at = Offset(
        _stage.width / 2 + foot.x * scale,
        _stage.height / 2 + foot.y * scale + 4,
      );
      expect(realistic.light(at), lessThan(material.light(at) - 8));
      var differs = 0;
      for (var i = 0; i < realistic.rgba.length; i += 4) {
        if (realistic.rgba[i] != material.rgba[i]) differs++;
      }
      expect(differs, greaterThan(1000));
    });
  });

  group('the most important visual test: glass, panel, frame, metal and '
      'rubber side by side, one shape and one colour', () {
    final board = materialBoard();
    final camera = Camera.presentation;
    late _Picture light, dark;
    late ModelPainter painter;
    late Map<String, List<Offset>> front;
    late Map<String, List<int>> colour;

    setUpAll(() async {
      final framed = camera.framing(
        board,
        width: _stage.width,
        height: _stage.height,
      );
      ModelPainter paint(Palette palette) => ModelPainter(
        faces: framed.project(board),
        size: _stage,
        viewSpan: Camera.viewSpan(board),
        mode: ViewMode.realistic,
        // Standing on the studio's floor, as the app shows every model: the
        // floor is what the glass is seen through.
        floor: Floor.under(board)?.seenBy(framed, board),
        palette: palette,
      );
      painter = paint(Palette.light);
      light = await _paint(_stage, (c) => painter.paint(c, _stage));
      final other = paint(Palette.dark);
      dark = await _paint(_stage, (c) => other.paint(c, _stage));
      front = {
        for (final piece in boardPieces)
          piece: _on(painter, (f) => f.elementId == piece && f.normal.z > 0.5),
      };
      colour = {
        for (final piece in boardPieces) piece: _median(light, front[piece]!),
      };
    });

    test('glass, panel, frame and metal are given the same colour, the '
        'rubber its own, and each is on the screen', () {
      expect(
        board.facets.every(
          (f) =>
              f.colour ==
              (f.elementId == 'rubber' ? rubberColour : boardColour),
        ),
        isTrue,
      );
      for (final piece in boardPieces) {
        expect(front[piece], isNotEmpty, reason: piece);
      }
    });

    test('they do not look like five rectangles of one colour: each is '
        'told from every other by what it does with the light', () {
      // What a viewer reads a material by: the colour it shows, whether
      // what is behind it shows through, and how the light varies across
      // all of it that is seen. Colour alone is the one thing the brief says must not be all
      // there is, so all three are measured, on one scale of levels.
      List<double> signature(String piece) {
        // All of it that is seen — its sides and reveals too, because a
        // frame is told from a panel of the same finish by its form.
        final at = _on(painter, (f) => f.elementId == piece, sides: true);
        final through =
            at.where((p) => _distance(light.at(p), dark.at(p)) > 6).length /
            at.length;
        return [
          ...colour[piece]!.map((c) => c.toDouble()),
          through * 100,
          _spread([for (final p in at) light.light(p)]),
        ];
      }

      final signatures = {for (final p in boardPieces) p: signature(p)};
      double apart(List<double> a, List<double> b) => math.sqrt(
        [for (var k = 0; k < a.length; k++) (a[k] - b[k]) * (a[k] - b[k])]
            .reduce((x, y) => x + y),
      );
      final alike = [
        for (var a = 0; a < boardPieces.length; a++)
          for (var b = a + 1; b < boardPieces.length; b++)
            if (apart(
                  signatures[boardPieces[a]]!,
                  signatures[boardPieces[b]]!,
                ) <=
                12)
              '${boardPieces[a]} ${signatures[boardPieces[a]]} and '
                  '${boardPieces[b]} ${signatures[boardPieces[b]]}',
      ];
      expect(alike, isEmpty);
    });

    test('GLASS is transparent and reflective: what is behind it shows '
        'through, and the light lies across it', () {
      final glass = front['glass']!;
      final through = glass
          .where((p) => _distance(light.at(p), dark.at(p)) > 6)
          .length;
      expect(through / glass.length, greaterThan(0.8));
      expect(
        _spread([for (final p in glass) light.light(p)]),
        greaterThan(_spread([for (final p in front['panel']!) light.light(p)])),
      );
    });

    test('PANEL is opaque, solid and matte: the same whatever is behind it, '
        'one even face', () {
      for (final p in front['panel']!) {
        expect(dark.at(p), light.at(p));
      }
      expect(
        _spread([for (final p in front['panel']!) light.light(p)]),
        lessThan(8),
      );
    });

    test('FRAME is a solid profile with depth: opaque, and its reveals '
        'answer the light differently from its face', () {
      for (final p in front['frame']!) {
        expect(dark.at(p), light.at(p));
      }
      final reveals = _on(
        painter,
        (f) => f.elementId == 'frame' && f.normal.z.abs() < 0.2,
        sides: true,
      );
      expect(reveals, isNotEmpty, reason: 'the depth of the section is seen');
      expect(
        _distance(_median(light, reveals), colour['frame']!),
        greaterThan(10),
      );
    });

    test('METAL is metallic and reflective: it mirrors the studio in its own '
        'colour, brighter and more varied than any painted face', () {
      final metal = [for (final p in front['metal']!) light.light(p)];
      for (final p in front['metal']!) {
        expect(dark.at(p), light.at(p), reason: 'opaque');
      }
      expect(
        _spread(metal),
        greaterThan(_spread([for (final p in front['panel']!) light.light(p)])),
      );
    });

    test('RUBBER is dark and rough: it reflects the least of the five and '
        'carries no highlight, and the rubber the model builds — the seal '
        'round every sealed unit — is dark', () {
      // Its darkness is its colour, as rubber's is: given the board's one
      // colour it can only be told by how it takes the light.
      for (final other in [
        Surfaces.clearGlass,
        Surfaces.panel,
        Surfaces.pvc,
        Surfaces.handleMetal,
      ]) {
        expect(Surfaces.rubber.roughness, greaterThan(other.roughness));
        expect(Surfaces.rubber.reflectivity, lessThan(other.reflectivity));
      }
      final rubber = _spread([
        for (final p in front['rubber']!) light.light(p),
      ]);
      expect(rubber, lessThan(8));
      expect(
        rubber,
        lessThan(_spread([for (final p in front['metal']!) light.light(p)])),
      );
      final seal = MeshBuilder.build(qaDesign()).facets
          .where((f) => f.surface.kind == MaterialClass.rubber);
      expect(seal, isNotEmpty);
      for (final f in seal) {
        final c = Color(f.colour);
        expect(c.computeLuminance(), lessThan(0.05));
      }
    });
  });

  group('geometry safety', () {
    final geometry = _geometry(d);
    final json = jsonEncode(d.toJson());
    final mesh = _mesh(MeshBuilder.build(d));

    test('the geometry is the drawing\'s: bars where drawn, the dividers where '
        'placed, the openings their lights', () {
      for (final o in [window, door]) {
        final bar = dividerOf(o);
        final box = d.outlineOf(o)!;
        expect(bar.a.y, closeTo(box.top + box.height * 0.45, 1e-6));
        expect(bar.b.y, closeTo(bar.a.y, 1e-6));
      }
    });

    test('painting every view, in every mode, from every side, in either '
        'appearance, moves nothing', () async {
      await _cad(d);
      await _paint(
        _sheet,
        (c) => CadPainter(
          design: d,
          view: _cadView(d),
          layers: const CadLayers(),
          ink: Cad.night,
        ).paint(c, _sheet),
      );
      await _paint(
        _sheet,
        (c) => DesignPainter(design: d, view: _cadView(d)).paint(c, _sheet),
      );
      for (final mode in ViewMode.values) {
        for (final camera in [
          Camera.presentation,
          Camera.front,
          Camera.isometric,
          Camera.top,
        ]) {
          await _model(d, camera: camera, mode: mode, floor: true);
        }
        await _model(d, mode: mode, palette: Palette.dark);
      }
      expect(jsonEncode(d.toJson()), json);
      expect(_geometry(d), geometry);
      expect(_mesh(MeshBuilder.build(d)), mesh);
    });

    test('a change of material, a colour or a glass moves no geometry', () {
      var changed = Infill.fill(d, {
        lights[0].id: GlassLook.frosted.finish,
        panesOf(window).last.id: PanelColour.grey.finish,
      });
      changed = changed.withElement(
        changed.frame!.copyWith(
          finish: const Finish(colour: 0xFFF4F4F1, material: MaterialKind.upvc),
        ),
      );
      expect(_geometry(changed), geometry);
      expect(_finishes(changed), isNot(_finishes(d)));
    });
  });

  group('regression, through the app', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> keep() async {
      final people = CustomerStore();
      final store = DesignStore(customers: people);
      final adam = await people.create(
        name: 'Adam',
        now: DateTime(2026, 3, 1, 8),
      );
      await store.save(d.copyWith(name: 'Shop front', customerId: adam.id));
    }

    Future<void> openIt(WidgetTester tester) async {
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      final open = find.byKey(CustomerDesignCard.openKey(d.id)).hitTestable();
      await tester.scrollUntilVisible(
        open,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
    }

    testWidgets('the design opens, draws in CAD and 3D, turns, zooms and '
        'fits, is edited, saved and read back — materials and geometry '
        'both kept, and the customer as they were', (tester) async {
      await tester.runAsync(keep);
      var c = await screen.openTheApp(tester, size: every.laptop);
      final customerBefore = await tester.runAsync(
        () async => jsonEncode(
          (await CustomerStore().page()).items.map((s) => s.toJson()).toList(),
        ),
      );
      await openIt(tester);

      // 1. Opens correctly: the saved design, exactly.
      final saved = await every.savedText(tester, d.id);
      expect(jsonEncode(c.read(workspaceProvider).design.toJson()), saved);
      final kept = Design.fromJson(jsonDecode(saved) as Map<String, Object?>);
      expect(_geometry(kept), _geometry(d));
      expect(_finishes(kept), _finishes(d));

      // 3. CAD opens on it.
      await every.showView(tester, WorkspaceView.plan);
      expect(
        identical(
          every.painterOf<CadPainter>(tester).design,
          c.read(workspaceProvider).design,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      // 4. 3D opens on it, and 13–16: turned, zoomed and fitted.
      await every.showView(tester, WorkspaceView.model);
      final solid = every.painterOf<ModelPainter>(tester);
      expect(
        every.facets(solid),
        every.projected(c, c.read(workspaceProvider).design),
      );
      final camera = c.read(workspaceProvider).camera;
      final middle = tester.getCenter(find.byType(ModelView));
      await tester.dragFrom(middle, const Offset(120, 40));
      await tester.pumpAndSettle();
      expect(
        c.read(workspaceProvider).camera.yawDegrees,
        isNot(camera.yawDegrees),
        reason: 'rotated',
      );
      final turned = c.read(workspaceProvider).camera;
      await tester.tap(find.byKey(ViewControls.inKey));
      await tester.pumpAndSettle();
      expect(
        c.read(workspaceProvider).camera.zoom,
        greaterThan(turned.zoom),
        reason: 'zoomed',
      );
      final zoomedIn = c.read(workspaceProvider).camera.zoom;
      await tester.tap(find.byKey(ViewControls.fitKey));
      await tester.pumpAndSettle();
      final fitted = c.read(workspaceProvider).camera;
      expect(
        fitted.yawDegrees,
        closeTo(turned.yawDegrees, 1e-9),
        reason: 'fit keeps the side',
      );
      expect(
        fitted.zoom,
        lessThan(zoomedIn),
        reason: 'fitted back out to the whole model',
      );
      // Fitted is fitted: pressing it again changes nothing.
      await tester.tap(find.byKey(ViewControls.fitKey));
      await tester.pumpAndSettle();
      expect(
        c.read(workspaceProvider).camera.zoom,
        closeTo(fitted.zoom, fitted.zoom * 1e-9),
      );
      expect(jsonEncode(c.read(workspaceProvider).design.toJson()), saved);
      expect(c.read(workspaceProvider.notifier).canUndo, isFalse);

      // 2. Editable: the door's upper pane made frosted, and 5. saved.
      final pane = panesOf(door).first.id;
      c
          .read(workspaceProvider.notifier)
          .setFinish(pane, GlassLook.frosted.finish);
      await tester.pumpAndSettle();
      final edited = c.read(workspaceProvider).design;
      expect(_geometry(edited), _geometry(d));
      expect(edited.sectionById(pane)!.finish, GlassLook.frosted.finish);
      await tester.runAsync(() => c.read(workspaceProvider.notifier).keep());
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // 6. Reloaded, from nothing but what the device kept.
      await tester.pumpWidget(const SizedBox());
      c = await screen.openTheApp(tester, size: every.laptop);
      await openIt(tester);
      final back = c.read(workspaceProvider).design;
      // 7–8. Materials and geometry kept.
      expect(back.sectionById(pane)!.finish, GlassLook.frosted.finish);
      expect(_geometry(back), _geometry(d));
      expect(back.frame!.finish, _anthracite);
      expect(back.dimensions.single.statedMm, 4800);
      // 9. The customer and their designs as they were.
      final customerAfter = await tester.runAsync(
        () async => jsonEncode(
          (await CustomerStore().page()).items.map((s) => s.toJson()).toList(),
        ),
      );
      expect(customerAfter, customerBefore);
      final theirs = await tester.runAsync(
        () async =>
            (await DesignStore().page(customerId: back.customerId)).items
                .map((s) => s.id)
                .toList(),
      );
      expect(theirs, [d.id]);
      await every.showView(tester, WorkspaceView.plan);
      await every.showView(tester, WorkspaceView.model);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    });
  });
}

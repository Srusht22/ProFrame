import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/app/viewer/view_mode.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 19 of the CAD and 3D work: the visual test.
//
// One window holding every material a workshop puts in one: an anthracite
// aluminium frame and bars, clear glass, tinted glass, a white panel, a
// silver handle and its hinges. A viewer should know at a glance that these
// are different physical things — so the test looks at the picture, part by
// part, and requires each to be told from every other by what it shows:
//
//   the frame, the panel, the two glasses and the ironmongery each a colour
//   of their own on the screen;
//   the glass seen through — it changes with the studio behind it, where
//   every solid part is the same to the byte;
//   the tinted glass darker than the clear;
//   the handle a metal, carrying a highlight and a shade across it, where
//   the panel is one even matte face;
//   and nothing of the application's own green in any of it.

const _size = Size(900, 700);

Design showcase() {
  var d = base.window();
  final section = d.sectionById(d.openings.single.sectionId)!;
  final o = section.outline;
  d = DesignEdits.addLineInside(
    d,
    section.id,
    id: 'inside',
    at: Vec2(o.left + o.width / 2, o.top + o.height * 0.55),
    horizontal: true,
  );
  final panes = d.childSectionsOf(d.openings.single.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final fixed =
      d.topLevelSections
          .where((s) => s.id != d.openings.single.sectionId)
          .toList()
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  d = Infill.fill(d, {
    panes.first.id: GlassLook.clear.finish,
    panes.last.id: PanelColour.white.finish,
    fixed.first.id: GlassLook.clear.finish,
    fixed.last.id: GlassLook.tinted.finish,
  });
  const aluminium = Finish(
    colour: 0xFF3A3D40,
    material: MaterialKind.aluminium,
  );
  d = d.withElement(d.frame!.copyWith(finish: aluminium));
  for (final bar in d.dividers) {
    d = d.withElement(bar.copyWith(finish: aluminium));
  }
  for (final h in d.hardware) {
    d = d.withElement(
      h.copyWith(
        finish: h.finish.copyWith(colour: HardwareColour.silver.colour),
      ),
    );
  }
  return d;
}

class _Shot {
  final Uint8List rgba;
  final ModelPainter painter;
  _Shot(this.rgba, this.painter);

  List<int> at(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }
}

Future<_Shot> _shoot(
  Design d,
  Camera camera, {
  Palette palette = Palette.light,
}) async {
  final mesh = MeshBuilder.build(d);
  final framed = camera.framing(mesh, width: _size.width, height: _size.height);
  final painter = ModelPainter(
    faces: framed.project(mesh),
    size: _size,
    viewSpan: Camera.viewSpan(mesh),
    mode: ViewMode.realistic,
    groundPlane: false,
    palette: palette,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return _Shot(data!.buffer.asUint8List(), painter);
}

/// The uppermost face at every point of a 3-pixel grid, worked out once:
/// the last face painted that holds the point, and never a sheet of glass
/// where it is kept off what lies in front of it — as the painter paints it.
List<List<ProjectedFacet?>> _uppermost(_Shot shot) {
  final faces = shot.painter.faces;
  final scale = 1 / shot.painter.millimetresPerPixel;
  Offset place(Vec2 v) =>
      Offset(_size.width / 2 + v.x * scale, _size.height / 2 + v.y * scale);
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

  ProjectedFacet? at(Offset p) {
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

  return [
    for (var y = 0.0; y < _size.height; y += _step)
      [for (var x = 0.0; x < _size.width; x += _step) at(Offset(x, y))],
  ];
}

const _step = 3.0;

/// The points of the grid where the uppermost face is one of [which], with
/// the same face a step away all round — so no edge and no neighbouring
/// part is sampled. The ironmongery is built of many small faces, so for it
/// the same part all round will do ([sameFace] false).
List<Offset> _pointsOf(
  List<List<ProjectedFacet?>> grid,
  bool Function(ProjectedFacet) which, {
  bool sameFace = true,
}) {
  bool ok(ProjectedFacet? f) => f != null && which(f) && !f.source.isSide;
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
          Offset(i * _step, j * _step),
  ];
}

List<int> _median(_Shot shot, List<Offset> points) => [
  for (var c = 0; c < 3; c++)
    (([for (final p in points) shot.at(p)[c]])..sort())[points.length ~/ 2],
];

double _distance(List<int> a, List<int> b) => math.sqrt(
  [for (var c = 0; c < 3; c++) (a[c] - b[c]) * (a[c] - b[c])]
      .reduce((x, y) => x + y),
);

double _light(List<int> c) => (c[0] + c[1] + c[2]) / 3;

void main() {
  final d = showcase();
  final opening = d.openings.single;
  final panes = d.childSectionsOf(opening.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final fixed =
      d.topLevelSections.where((s) => s.id != opening.sectionId).toList()
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final handle = d.hardware.firstWhere((h) => h.kind.isHandle);
  final hinges = {
    for (final h in d.hardware)
      if (h.kind == HardwareKind.hinge) h.id,
  };

  bool glassOf(ProjectedFacet f, String id) =>
      f.elementId == id && f.source.surface.isTransparent;
  final parts = <String, bool Function(ProjectedFacet)>{
    'frame': (f) =>
        f.elementId == d.frame!.id && f.source.role == FacetRole.frame,
    'clear glass': (f) => glassOf(f, fixed.first.id),
    'tinted glass': (f) => glassOf(f, fixed.last.id),
    'panel': (f) =>
        f.elementId == panes.last.id && f.source.role == FacetRole.panel,
    'handle': (f) => f.elementId == handle.id,
    'hinges': (f) => hinges.contains(f.elementId),
  };

  for (final (view, camera) in [
    ('square on', Camera.front),
    ('as first shown', Camera.presentation),
  ]) {
    group('seen $view', () {
      late _Shot shot, dark;
      late Map<String, List<Offset>> points;
      late Map<String, List<int>> colour;

      setUpAll(() async {
        shot = await _shoot(d, camera);
        dark = await _shoot(d, camera, palette: Palette.dark);
        final grid = _uppermost(shot);
        points = {
          for (final MapEntry(key: name, value: which) in parts.entries)
            name: _pointsOf(
              grid,
              which,
              sameFace: name != 'handle' && name != 'hinges',
            ),
        };
        colour = {
          for (final MapEntry(key: name, value: at) in points.entries)
            if (at.isNotEmpty) name: _median(shot, at),
        };
      });

      test('every part is on the screen', () {
        for (final MapEntry(key: name, value: at) in points.entries) {
          expect(at, isNotEmpty, reason: name);
        }
      });

      test('the frame, the two glasses, the panel and the ironmongery are '
          'each a colour of their own', () {
        final names = colour.keys.toList();
        for (var a = 0; a < names.length; a++) {
          for (var b = a + 1; b < names.length; b++) {
            // The handle and its hinges are one silver, polished and satin:
            // they are told apart from each other by the light on them, below,
            // and from everything else by their colour here.
            if ({names[a], names[b]}.containsAll({'handle', 'hinges'})) {
              continue;
            }
            expect(
              _distance(colour[names[a]]!, colour[names[b]]!),
              greaterThan(24),
              reason:
                  '${names[a]} ${colour[names[a]]} and '
                  '${names[b]} ${colour[names[b]]}',
            );
          }
        }
      });

      test('glass is seen through; every solid part is the same whatever '
          'is behind it', () {
        for (final name in ['clear glass', 'tinted glass']) {
          final moved = points[name]!
              .where((p) => _distance(shot.at(p), dark.at(p)) > 6)
              .length;
          expect(moved / points[name]!.length, greaterThan(0.8), reason: name);
        }
        for (final name in ['frame', 'panel', 'handle', 'hinges']) {
          for (final p in points[name]!) {
            expect(dark.at(p), shot.at(p), reason: '$name at $p');
          }
        }
      });

      test('the tinted glass is darker than the clear', () {
        expect(
          _light(colour['tinted glass']!),
          lessThan(_light(colour['clear glass']!) - 25),
        );
      });

      test('the handle is metal — a highlight and a shade across it — and '
          'the panel one even matte face', () {
        final handle = [for (final p in points['handle']!) _light(shot.at(p))];
        final panel = [for (final p in points['panel']!) _light(shot.at(p))];
        double spread(List<double> v) =>
            v.reduce(math.max) - v.reduce(math.min);
        expect(spread(handle), greaterThan(50), reason: 'handle');
        final middle = [...panel]..sort();
        final inner = middle.sublist(
          middle.length ~/ 10,
          middle.length * 9 ~/ 10,
        );
        expect(spread(inner), lessThan(12), reason: 'panel');
      });

      test('the handle, polished, catches more light than the hinges, '
          'satin', () {
        double brightest(String name) =>
            points[name]!.map((p) => _light(shot.at(p))).reduce(math.max);
        expect(brightest('handle'), greaterThan(brightest('hinges') + 10));
      });

      test('nothing of the application\'s own colours is in the model', () {
        for (final brand in [
          Palette.light.primary,
          Palette.light.band,
          Palette.light.selection,
        ]) {
          final rgb = [
            (brand.r * 255).round(),
            (brand.g * 255).round(),
            (brand.b * 255).round(),
          ];
          for (final MapEntry(key: name, value: c) in colour.entries) {
            expect(_distance(c, rgb), greaterThan(40), reason: '$name $brand');
          }
        }
      });
    });
  }

  test('the finishes are the customer\'s: every facet carries the colour '
      'the part was given', () {
    final mesh = MeshBuilder.build(d);
    for (final f in mesh.facets.where((f) => f.elementId == d.frame!.id)) {
      expect(f.colour, 0xFF3A3D40);
    }
    for (final f in mesh.facets.where((f) => f.elementId == handle.id)) {
      expect(f.colour, HardwareColour.silver.colour);
    }
    for (final f in mesh.facets.where(
      (f) => f.elementId == panes.last.id && f.role == FacetRole.panel,
    )) {
      expect(f.colour, PanelColour.white.finish.colour);
    }
  });
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// The point of the material system, held on the picture: a viewer tells
// glass from panel from frame without being told — and not because they are
// different colours. Here all three are given *the same colour*, so whatever
// tells them apart on the screen is what they are made of.

const _size = Size(700, 900);
const _camera = Camera(yawDegrees: 14, pitchDegrees: 6);
const _same = 0xFFE8E9E6;

/// The baseline door with its frame, its glass and its panel all one
/// colour.
Design oneColour() {
  final door = base.door();
  final panes = door.childSectionsOf(door.openings.single.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final filled = Infill.fill(door, {
    panes.first.id: const Finish(
      colour: _same,
      material: MaterialKind.clearGlass,
    ),
    panes.last.id: const Finish(colour: _same, material: MaterialKind.panel),
  });
  return filled.copyWith(
    frame: filled.frame!.copyWith(
      finish: const Finish(colour: _same, material: MaterialKind.upvc),
    ),
  );
}

class Rendered {
  final Uint8List rgba;
  final List<ProjectedFacet> faces;
  final double scale;

  Rendered(this.rgba, this.faces, this.scale);

  /// The screen point of the middle of the nearest face of [id] that faces
  /// the viewer.
  Offset middleOf(String id, {bool Function(Facet)? which}) {
    // A glass section also holds the bead that stands on its edge and the
    // seal round its cavity; its middle is its glass.
    final candidates = faces.where(
      (f) =>
          f.elementId == id &&
          !f.source.isSide &&
          f.source.role != FacetRole.bead &&
          (which == null || which(f.source)),
    );
    // Its main face — the largest on the screen, not an arris or a rim
    // round it — and of those, the nearest.
    double area(ProjectedFacet f) {
      var a = 0.0;
      for (var i = 0; i < f.corners.length; i++) {
        final p = f.corners[i], q = f.corners[(i + 1) % f.corners.length];
        a += p.x * q.y - q.x * p.y;
      }
      return a.abs() / 2;
    }

    final biggest = candidates.map(area).reduce((a, b) => a > b ? a : b);
    final face = candidates
        .where((f) => area(f) > biggest * 0.9)
        .reduce((a, b) => a.depth < b.depth ? a : b);
    var x = 0.0, y = 0.0;
    for (final c in face.corners) {
      x += c.x;
      y += c.y;
    }
    final n = face.corners.length;
    return Offset(
      _size.width / 2 + x / n * scale,
      _size.height / 2 + y / n * scale,
    );
  }

  List<int> at(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }
}

Future<Rendered> render(
  Design design, {
  Palette palette = Palette.light,
  DisplayStyle style = DisplayStyle.shaded,
}) async {
  final mesh = MeshBuilder.build(design);
  final faces = _camera.project(mesh);
  final span = Camera.viewSpan(mesh);
  final painter = ModelPainter(
    faces: faces,
    size: _size,
    viewSpan: span,
    style: style,
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
  final scale = _size.shortestSide * 0.92 / span;
  return Rendered(data!.buffer.asUint8List(), faces, scale);
}

int apart(List<int> a, List<int> b) =>
    [for (var i = 0; i < 3; i++) (a[i] - b[i]).abs()]
        .reduce((x, y) => x > y ? x : y);

void main() {
  final design = oneColour();
  final panes = design.childSectionsOf(design.openings.single.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final glass = panes.first, panel = panes.last;

  test('in one colour, glass, panel and frame are three different things '
      'on the screen', () async {
    final picture = await render(design);
    final seenGlass = picture.at(picture.middleOf(glass.id));
    final seenPanel = picture.at(picture.middleOf(panel.id));
    final seenFrame = picture.at(
      picture.middleOf(design.frame!.id, which: (f) => f.normal.z.abs() > 0.99),
    );
    expect(apart(seenGlass, seenPanel), greaterThan(12));
    expect(apart(seenGlass, seenFrame), greaterThan(12));
    expect(apart(seenPanel, seenFrame), greaterThan(4));
  });

  test('glass is seen through; the panel and the frame are not', () async {
    // The same design against the light backdrop and the dark one: what
    // changes where the glass is, is what is behind it.
    final light = await render(design);
    final dark = await render(design, palette: Palette.dark);
    final g = light.middleOf(glass.id);
    final p = light.middleOf(panel.id);
    final f = light.middleOf(
      design.frame!.id,
      which: (f) => f.normal.z.abs() > 0.99,
    );
    expect(apart(light.at(g), dark.at(g)), greaterThan(40));
    expect(apart(light.at(p), dark.at(p)), 0);
    expect(apart(light.at(f), dark.at(f)), 0);
  });

  test(
    'the technical drawing indicates rubber as a drawing does: solid',
    () async {
      final rubber = Infill.fill(design, {
        panel.id: const Finish(
          colour: 0xFF161616,
          material: MaterialKind.rubber,
        ),
      });
      Future<List<int>> centre(Design d) async {
        final recorder = ui.PictureRecorder();
        final view = ViewTransform.fit(
          d.frame!.outline,
          _size,
          padding: const EdgeInsets.all(40),
        );
        CadPainter(
          design: d,
          view: view,
          layers: const CadLayers(
            grid: false,
            dimensions: false,
            annotations: false,
          ),
        ).paint(Canvas(recorder), _size);
        final image = await recorder.endRecording().toImage(
          _size.width.round(),
          _size.height.round(),
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        final at = view.toScreen(
          Vec2(panel.outline.centroid.x + 150, panel.outline.centroid.y + 150),
        );
        final i = (at.dy.round() * _size.width.round() + at.dx.round()) * 4;
        final bytes = data!.buffer.asUint8List();
        return [bytes[i], bytes[i + 1], bytes[i + 2]];
      }

      final solid = await centre(rubber);
      final hatched = await centre(design);
      expect(solid.every((c) => c < 90), isTrue, reason: '$solid');
      expect(hatched.every((c) => c > 150), isTrue, reason: '$hatched');
    },
  );
}

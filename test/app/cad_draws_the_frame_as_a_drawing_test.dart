import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/materials.dart';

import '../domain/the_frame_is_a_real_profile_test.dart' as frame;

// The technical drawing of a profiled frame stays a technical drawing: the
// outline heavy, the daylight lighter, and between them the one thing an
// elevation shows of a profile — the line where the face turns into the
// sightline — as a hairline, from the same profile the solid is swept
// along. No shading, no render. And what the frame is made of changes only
// the frame on the drawing.

const _size = Size(800, 900);

const _plain = CadLayers(
  grid: false,
  dimensions: false,
  annotations: false,
  hatching: false,
  centreLines: false,
  grips: false,
);

Future<(Uint8List, ViewTransform)> cad(Design design) async {
  final view = ViewTransform.fit(
    design.frame!.outline,
    _size,
    padding: const EdgeInsets.all(40),
  );
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: design,
    view: view,
    layers: _plain,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return (data!.buffer.asUint8List(), view);
}

List<int> px(Uint8List rgba, Offset p) {
  final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2]];
}

void main() {
  // A wide profile, so the section reads at the drawing's scale.
  Design wide(MaterialKind m) =>
      frame.drawn(1200, 1500, material: m, profileMm: 160);

  test('between the outline and the daylight, the sightline and nothing '
      'else', () async {
    for (final m in [MaterialKind.upvc, MaterialKind.aluminium]) {
      final design = wide(m);
      final (rgba, view) = await cad(design);
      final top = design.frame!.outline.top;
      final middle = design.frame!.outline.centroid.x;
      final sightline = DesignGeometry.of(design).frameProfile!.sightlines;
      Offset at(double down) => view.toScreen(Vec2(middle, top + down));
      final sheet = px(rgba, at(-30));

      for (final s in sightline) {
        expect(px(rgba, at(s)), isNot(sheet), reason: '${m.label} at $s');
      }
      // Clear of the lines, the frame's face is the sheet: a drawing, not a
      // render.
      for (final clear in [20.0, 55.0, 90.0]) {
        if (sightline.any((s) => (s - clear).abs() < 12)) continue;
        expect(px(rgba, at(clear)), sheet, reason: '${m.label} at $clear');
      }
    }
  });

  test(
    'what the frame is made of changes only the frame on the drawing',
    () async {
      final (pvc, view) = await cad(wide(MaterialKind.upvc));
      final (alu, _) = await cad(wide(MaterialKind.aluminium));
      final design = wide(MaterialKind.upvc);
      final outer = design.frame!.outline;
      final inner = design.frame!.innerOutline;
      var differ = 0;
      final w = _size.width.round();
      for (var i = 0; i < pvc.length; i += 4) {
        if (pvc[i] == alu[i] &&
            pvc[i + 1] == alu[i + 1] &&
            pvc[i + 2] == alu[i + 2]) {
          continue;
        }
        final screen = Offset(((i ~/ 4) % w).toDouble(), ((i ~/ 4) ~/ w) * 1.0);
        final p = view.toSheet(screen);
        // Inside the ring, allowing a couple of pixels for a line's width.
        final slack = view.lengthToSheet(3);
        final inRing =
            (outer.contains(p) || outer.awayFrom(p) <= slack) &&
            !(inner.contains(p) && inner.awayFrom(p) > slack);
        if (!inRing) differ++;
      }
      expect(differ, 0);
    },
  );
}

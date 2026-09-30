import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 7 of the CAD and 3D work: handles, hinges and the rest of the
// ironmongery as the metal pieces they are.
//
// They were already geometry — a lever on a backplate, a window's
// espagnolette, a butt hinge — but lit facet by facet, so a round lever was
// a prism with a stripe on each flat and nothing about it said metal; its
// plates were sharp-edged card; a hinge's leaf stood off the face it is
// screwed to; and nothing sat on the door, because nothing cast a shadow.
//
// Now a round part carries the way its surface faces at every corner and is
// lit point by point, so a highlight runs along it; a metal mirrors the
// studio in its own colour; plates are pressed with a rounded edge; the
// lever is one bent piece closed in a dome; and every piece casts its
// shadow on what it is fixed to — never on glass, which takes none.
//
// Held here: the door's lever and the window's espagnolette stay the two
// different objects they were; every piece is placed from its opening and
// follows it; every piece lies on the face it is fixed to; round parts are
// round to the light and move nothing; on the pictures, a lever shades
// smoothly with a highlight, casts a shadow on its door and none on glass,
// and keeps the colour it was given; and the technical drawing stays a
// drawing.

const _size = Size(600, 600);

HardwareElement _piece(Design d, HardwareKind kind) =>
    d.hardware.firstWhere((p) => p.kind == kind && p.isOpeningHardware);

List<Facet> _facetsOf(Design d, HardwareElement piece, {double open = 0}) => [
  for (final f in MeshBuilder.build(d, openFraction: open).facets)
    if (f.elementId == piece.id && f.part == null) f,
];

/// A close view of [piece]: the camera turned [yaw] and centred on it.
Camera _near(Design d, HardwareElement piece, {double zoom = 16}) {
  final c = MeshBuilder.build(d).centre;
  return Camera(
    zoom: zoom,
    target: Vec3(piece.at.x - c.x, piece.at.y - c.y, 0),
  );
}

class _Shot {
  final Uint8List rgba;
  final ModelPainter painter;
  final double scale;

  _Shot(this.rgba, this.painter, this.scale);

  Offset place(Vec2 at) =>
      Offset(_size.width / 2 + at.x * scale, _size.height / 2 + at.y * scale);

  double brightness(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
  }

  List<int> at(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }
}

/// [d] rendered from [camera] — with the faces of [leaving] taken out after
/// the model is projected, so the view is exactly the same view without them.
Future<_Shot> _render(Design d, Camera camera, {String? leaving}) async {
  final mesh = MeshBuilder.build(d);
  final span = Camera.viewSpan(mesh);
  final painter = ModelPainter(
    faces: [
      for (final f in camera.project(mesh))
        if (f.elementId != leaving) f,
    ],
    size: _size,
    viewSpan: span,
    style: DisplayStyle.shadedWithEdges,
    groundPlane: false,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return _Shot(
    data!.buffer.asUint8List(),
    painter,
    _size.shortestSide * 0.92 / span,
  );
}

/// The brightness across the lever's arm, top to bottom, half way along it.
Future<List<double>> _acrossTheLever(Design d) async {
  final lever = _piece(d, HardwareKind.lever);
  final camera = _near(d, lever);
  final shot = await _render(d, camera);
  final mesh = MeshBuilder.build(d);
  final ids = {
    for (final f in mesh.facets)
      if (f.elementId == lever.id && f.part == null) f,
  };
  final faces = [
    for (final f in camera.project(mesh))
      if (ids.contains(f.source)) f,
  ];
  // The arm's rings half way along: every facet whose corners all lie
  // within a few millimetres of that point across the leaf.
  final furniture = DesignGeometry.of(d).hardwareOf(lever);
  final arm = furniture.last;
  final middle = Vec2((arm.left + arm.right) / 2, (arm.top + arm.bottom) / 2);
  final lift = MeshBuilder.leafFront(d.depthMm) + 20;
  final ring = [
    for (final f in faces)
      if (f.source.normals.isNotEmpty &&
          f.source.corners.every((c) => c.z > lift) &&
          f.source.corners.any((c) => c.x < middle.x) &&
          f.source.corners.any((c) => c.x > middle.x))
        f,
  ];
  expect(ring, isNotEmpty);
  var top = double.infinity, bottom = -double.infinity, x = 0.0, n = 0;
  for (final f in ring) {
    for (final c in f.corners) {
      final p = shot.place(c);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
      x += p.dx;
      n++;
    }
  }
  x /= n;
  final across = [
    for (var y = top.ceil(); y <= bottom.floor(); y++)
      if (shot.painter.elementAt(Offset(x, y.toDouble())) == lever.id)
        shot.brightness(Offset(x, y.toDouble())),
  ];
  // Less the pixels its silhouette is drawn over, which are half lever and
  // half whatever is behind it.
  return across.length > 8 ? across.sublist(3, across.length - 3) : across;
}

void main() {
  final door = base.door();
  final window = base.window();

  group('a door is a door and a window a window', () {
    test('the door carries a lever and a lock, the window an espagnolette '
        'and no lock', () {
      final doorKinds = {
        for (final p in door.hardware)
          if (p.isOpeningHardware) p.kind,
      };
      final windowKinds = {
        for (final p in window.hardware)
          if (p.isOpeningHardware) p.kind,
      };
      expect(doorKinds, containsAll([HardwareKind.lever, HardwareKind.lock]));
      expect(windowKinds, {HardwareKind.handle, HardwareKind.hinge});
    });

    test('the lever reaches across the leaf; the espagnolette hangs down '
        'it', () {
      Rect box(List<Facet> facets) {
        final xs = [
          for (final f in facets)
            for (final c in f.corners) c.x,
        ];
        final ys = [
          for (final f in facets)
            for (final c in f.corners) c.y,
        ];
        return Rect.fromLTRB(
          xs.reduce(math.min),
          ys.reduce(math.min),
          xs.reduce(math.max),
          ys.reduce(math.max),
        );
      }

      final lever = _piece(door, HardwareKind.lever);
      final handle = _piece(window, HardwareKind.handle);
      // Beyond their plates: what the hand holds.
      final reach = box(_facetsOf(door, lever));
      final hang = box(_facetsOf(window, handle));
      expect(
        (lever.at.x - reach.left).abs() + (reach.right - lever.at.x).abs(),
        greaterThan(100),
        reason: 'a lever reaches back across the door',
      );
      expect(
        hang.bottom - handle.at.y,
        greaterThan(handle.at.x - hang.left),
        reason: 'a shut window handle hangs down the sash',
      );
      expect(
        _facetsOf(door, lever).length,
        isNot(_facetsOf(window, handle).length),
        reason: 'two different objects, not one scaled',
      );
    });
  });

  group('every piece is placed from its opening and goes with it', () {
    test('the handle is half way up the leaf it is on', () {
      final lever = _piece(door, HardwareKind.lever);
      final opening = door.openingHolding(lever.parentId)!;
      final leaf = door.sectionById(opening.sectionId)!.outline;
      expect(lever.at.y, closeTo((leaf.top + leaf.bottom) / 2, 1e-6));
      expect(
        leaf.contains(lever.at) ||
            leaf.edges.any((e) => e.distanceTo(lever.at) < 1e-6),
        isTrue,
      );
    });

    test('moving the bar beside the leaf moves the handle with its stile', () {
      final lever = _piece(door, HardwareKind.lever);
      final mullion = door.topLevelDividers.single;
      final moved = DesignEdits.moveDivider(
        door,
        mullion.id,
        const Vec2(-120, 0),
      );
      final after = _piece(moved, HardwareKind.lever);
      double closingEdge(Design d, HardwareElement piece) {
        final opening = d.openingHolding(piece.parentId)!;
        final leaf = d.sectionById(opening.sectionId)!.outline;
        return opening.mechanism.hingeEdge == OpeningEdge.left
            ? leaf.right
            : leaf.left;
      }

      // On the edge the leaf closes on, wherever that edge now is — not
      // where it was, and not a figure of its own.
      expect(lever.at.x, closeTo(closingEdge(door, lever), 1e-6));
      expect(after.at.x, closeTo(closingEdge(moved, after), 1e-6));
      expect(after.at.x, lessThan(lever.at.x - 100));
      expect(after.at.y, closeTo(lever.at.y, 1e-6));
      // And the piece as built stands on that point: its plate is centred
      // on it. (It is sized from its leaf, so a narrower leaf's lever is a
      // little smaller — in proportion, never a fixed size.)
      for (final (d, piece) in [(door, lever), (moved, after)]) {
        final plate = _facetsOf(d, piece).firstWhere(
          (f) =>
              f.corners.length > 4 &&
              f.corners.every(
                (c) => (c.z - MeshBuilder.leafFront(d.depthMm)).abs() < 1e-6,
              ),
        );
        final xs = [for (final c in plate.corners) c.x];
        final ys = [for (final c in plate.corners) c.y];
        expect(
          (xs.reduce(math.min) + xs.reduce(math.max)) / 2,
          closeTo(piece.at.x, 1e-6),
        );
        expect(
          (ys.reduce(math.min) + ys.reduce(math.max)) / 2,
          closeTo(piece.at.y, 1e-6),
        );
      }
    });

    test('a taller design puts the handle half way up the taller leaf', () {
      final taller = DesignEdits.resizeFrame(
        door,
        heightMm: door.frame!.outline.height * 1.3,
      );
      final lever = _piece(taller, HardwareKind.lever);
      final opening = taller.openingHolding(lever.parentId)!;
      final leaf = taller.sectionById(opening.sectionId)!.outline;
      expect(lever.at.y, closeTo((leaf.top + leaf.bottom) / 2, 1e-6));
    });

    test('every piece names its opening, and swings with it', () {
      for (final d in [door, window]) {
        for (final piece in d.hardware.where((p) => p.isOpeningHardware)) {
          expect(d.openingHolding(piece.parentId), isNotNull);
          final shut = _facetsOf(d, piece);
          final open = _facetsOf(d, piece, open: 1);
          expect(open.length, shut.length);
          expect(
            [
              for (final f in open)
                for (final c in f.corners) '$c',
            ],
            isNot([
              for (final f in shut)
                for (final c in f.corners) '$c',
            ]),
            reason: '${piece.kind.name} goes with its leaf',
          );
        }
      }
    });
  });

  group('every piece lies on the face it is fixed to', () {
    for (final (name, design) in [('door', door), ('window', window)]) {
      test(name, () {
        final front = MeshBuilder.leafFront(design.depthMm);
        final back = MeshBuilder.leafBack(design.depthMm);
        for (final piece in design.hardware.where((p) => p.isOpeningHardware)) {
          if (piece.kind == HardwareKind.pull) continue;
          final facets = _facetsOf(design, piece);
          final face = design.isConcealed(piece) ? back : front;
          final away = design.isConcealed(piece) ? -1.0 : 1.0;
          // Its plate's underside lies on the face — on it, not off it…
          expect(
            facets.any(
              (f) =>
                  f.corners.length > 4 &&
                  f.corners.every((c) => (c.z - face).abs() < 1e-6),
            ),
            isTrue,
            reason: '${piece.kind.name} lies on its face',
          );
          // …and the piece stands out of that face, the way it faces.
          final out = [
            for (final f in facets)
              for (final c in f.corners) (c.z - face) * away,
          ];
          expect(
            out.reduce(math.max),
            greaterThan(2),
            reason: '${piece.kind.name} stands out of its face',
          );
          // And says so, for its shadow.
          for (final f in _facetsOf(design, piece)) {
            expect(f.mountAt, isNotNull);
            expect(f.mountNormal!.length, closeTo(1, 1e-9));
          }
        }
      });
    }
  });

  group('round parts are round to the light, and move nothing', () {
    test('a lever, a knuckle and a handle carry the way they face at every '
        'corner', () {
      for (final (d, kind) in [
        (door, HardwareKind.lever),
        (window, HardwareKind.handle),
        (window, HardwareKind.hinge),
      ]) {
        final facets = _facetsOf(d, _piece(d, kind));
        final curved = facets.where((f) => f.normals.isNotEmpty).toList();
        expect(
          curved.length,
          greaterThan(facets.length ~/ 2),
          reason: kind.name,
        );
        for (final f in curved) {
          expect(f.normals, hasLength(f.corners.length));
          for (var k = 0; k < f.normals.length; k++) {
            expect(f.normals[k].length, closeTo(1, 1e-9));
            // Out of the surface, not into it: the same side as the face
            // itself turns, give or take the curve across it.
            expect(f.normals[k].dot(f.normal).abs(), greaterThan(0.2));
          }
        }
      }
    });

    test('the painter lights a part and does not move one', () {
      // What is painted is a function of the solid; the solid carries no
      // lighting. Every facet's colour is its piece's own.
      for (final d in [door, window]) {
        for (final f in MeshBuilder.build(d).facets) {
          if (f.role != FacetRole.hardware) continue;
          final piece = d.hardware.firstWhere((p) => p.id == f.elementId);
          if (f.colour != piece.finish.colour) {
            // Only a keyhole's bore is dark, because it is a hole.
            expect(piece.kind, HardwareKind.lock);
          }
        }
      }
    });
  });

  group('in 3D, ironmongery is metal', () {
    test('a lever shades smoothly round its arm, with a highlight', () async {
      final profile = await _acrossTheLever(door);
      expect(profile.length, greaterThan(20), reason: 'a close view');
      final lo = profile.reduce(math.min), hi = profile.reduce(math.max);
      expect(hi - lo, greaterThan(40), reason: 'lit round: $profile');
      // Smooth, not a prism: no step from one pixel to the next is more
      // than a small share of the whole change across it.
      var jump = 0.0;
      for (var i = 1; i < profile.length; i++) {
        jump = math.max(jump, (profile[i] - profile[i - 1]).abs());
      }
      expect(jump, lessThan((hi - lo) * 0.3), reason: '$profile');
    });

    test('a lever casts its shadow on its door, and none on glass', () async {
      final lever = _piece(door, HardwareKind.lever);
      final camera = _near(door, lever, zoom: 10);
      final withIt = await _render(door, camera);
      final without = await _render(door, camera, leaving: lever.id);
      // Where the lever itself is, on either face of the door — seen
      // through the glass, its twin on the far face is the lever and not
      // its shadow.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final f in withIt.painter.faces) {
        if (f.elementId != lever.id) continue;
        final path = Path();
        final first = withIt.place(f.corners.first);
        path.moveTo(first.dx, first.dy);
        for (final c in f.corners.skip(1)) {
          final at = withIt.place(c);
          path.lineTo(at.dx, at.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke,
        );
      }
      final image = await recorder.endRecording().toImage(600, 600);
      final mask = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      bool isLever(Offset p) =>
          mask[(p.dy.round() * 600 + p.dx.round()) * 4 + 3] > 0;

      var darker = 0, onGlass = 0;
      for (var y = 0; y < _size.height; y += 2) {
        for (var x = 0; x < _size.width; x += 2) {
          final p = Offset(x.toDouble(), y.toDouble());
          if (isLever(p)) continue;
          final change = withIt.brightness(p) - without.brightness(p);
          if (change < -6) {
            darker++;
            // Asked of the face and not of its part: a divided opening's
            // sash and the glass it held undivided share the section's id.
            final under = without.painter.faceAt(p);
            if (under != null && under.source.surface.isTransparent) {
              onGlass++;
            }
          }
        }
      }
      expect(darker, greaterThan(200), reason: 'a shadow the lever casts');
      // Glass lets the light through, so it takes no shadow. The only
      // exception is a pixel or two where a pane's edge, running into the
      // sash's rebate behind the stile, is painted over the stile's own
      // edge: what is dark there is the stile.
      expect(
        onGlass,
        lessThan(darker * 0.01),
        reason: 'glass lets the light through',
      );
    });

    test('it keeps the colour it was given', () async {
      final lever = _piece(door, HardwareKind.lever);
      final looks = <HardwareColour, double>{};
      for (final colour in [
        HardwareColour.black,
        HardwareColour.grey,
        HardwareColour.silver,
      ]) {
        final d = door.copyWith(
          hardware: [
            for (final p in door.hardware)
              p.id == lever.id
                  ? p.copyWith(finish: p.finish.copyWith(colour: colour.colour))
                  : p,
          ],
        );
        for (final f in _facetsOf(d, _piece(d, HardwareKind.lever))) {
          expect(f.colour, colour.colour);
        }
        final profile = await _acrossTheLever(d);
        looks[colour] = profile.reduce((a, b) => a + b) / profile.length;
      }
      expect(
        looks[HardwareColour.black]!,
        lessThan(looks[HardwareColour.grey]!),
      );
      expect(
        looks[HardwareColour.grey]!,
        lessThan(looks[HardwareColour.silver]!),
      );
    });
  });

  group('on the technical drawing, ironmongery stays a drawing', () {
    Future<(Uint8List, ViewTransform)> cad(Design d, Vec2 at) async {
      final view = ViewTransform.fit(
        Polygon.rect(at.x - 150, at.y - 150, at.x + 150, at.y + 150),
        _size,
      );
      final recorder = ui.PictureRecorder();
      CadPainter(
        design: d,
        view: view,
        layers: const CadLayers(grid: false, dimensions: false, grips: false),
      ).paint(Canvas(recorder), _size);
      final image = await recorder.endRecording().toImage(600, 600);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (data!.buffer.asUint8List(), view);
    }

    double lum(Uint8List rgba, Offset p) {
      final i = (p.dy.round() * 600 + p.dx.round()) * 4;
      return 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
    }

    test('a keyhole is drawn solid; the plate round it is the sheet', () async {
      final lock = _piece(door, HardwareKind.lock);
      final bores = DesignGeometry.of(door).boresOf(lock);
      expect(bores, isNotEmpty);
      final (rgba, view) = await cad(door, lock.at);
      final hole = view.toScreen(bores.first.centroid);
      final plate = DesignGeometry.of(door).hardwareOf(lock).first;
      final onPlate = view.toScreen(
        Vec2(plate.centroid.x, plate.top + (plate.height * 0.12)),
      );
      expect(lum(rgba, hole), lessThan(90), reason: 'a hole');
      expect(lum(rgba, onPlate), greaterThan(200), reason: 'the plate');
    });

    test('a piece is lines and the sheet, not a rendering', () async {
      final lever = _piece(door, HardwareKind.lever);
      final (rgba, view) = await cad(door, lever.at);
      // Across the lever's plate, off its lines, the drawing is one flat
      // colour — no shading, no highlight.
      final plate = DesignGeometry.of(door).hardwareOf(lever).first;
      final values = [
        for (var t = 0.2; t <= 0.3; t += 0.02)
          lum(
            rgba,
            view.toScreen(Vec2(plate.centroid.x, plate.top + plate.height * t)),
          ),
      ];
      final spread = values.reduce(math.max) - values.reduce(math.min);
      expect(spread, lessThan(2), reason: '$values');
    });
  });
}

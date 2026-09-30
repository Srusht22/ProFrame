import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/studio.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import 'glass_looks_like_glass_test.dart' as glass;

// Phase 11 of the CAD and 3D work: what the model is shown in.
//
// A photographer's studio and nothing else: a neutral backdrop with no
// horizon drawn on it, and a floor at the model's foot that says where it
// stands, how big it is — a grid of ten-centimetre squares laid from its own
// side and face — that it touches, and how deep the space is. The floor's
// shadow is worked out by rays against the design's own opaque members, so
// glass lets the light through it, and it is lit by the same light as every
// face of the model. It is all drawn before the model, so it can never lie
// over the design.
//
// **The application's colours are not the model's.** The house green and
// cream are the application — its bars, its buttons — and the backdrop,
// the floor, the edges and the monochrome clay are the studio's, which is
// neutral. A palette in any colours at all paints the model to the byte as
// the application's own does.
//
// Held here too: the view is from where it says it is. A positive pitch
// rises over the model — it was applied the wrong way round, so the first
// view looked up at the model from below the floor, and "Top" showed its
// underside.

const _size = Size(640, 640);

class _Shot {
  final Uint8List rgba;
  final ModelPainter painter;

  _Shot(this.rgba, this.painter);

  List<int> at(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }

  double brightness(Offset p) {
    final c = at(p);
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }

  /// Where a point in view units lands on the picture.
  Offset place(Vec2 v) {
    final scale = _size.shortestSide * Camera.spanShare / painter.viewSpan;
    return Offset(
      _size.width / 2 + v.x * scale,
      _size.height / 2 + v.y * scale,
    );
  }
}

Future<_Shot> _shoot(
  Design d, {
  Camera camera = Camera.presentation,
  Palette palette = Palette.light,
  bool floor = true,
  DisplayStyle style = DisplayStyle.shaded,
}) async {
  final mesh = MeshBuilder.build(d);
  final framed = camera.framing(mesh, width: _size.width, height: _size.height);
  final painter = ModelPainter(
    faces: framed.project(mesh),
    size: _size,
    viewSpan: Camera.viewSpan(mesh),
    style: style,
    groundPlane: floor,
    floor: floor ? Floor.under(mesh)?.seenBy(framed, mesh) : null,
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

/// The application's palette in colours nobody would choose, everything the
/// application draws in changed — and nothing the model is shown in.
Palette _garish(Palette p) => Palette(
  brightness: p.brightness,
  primary: const Color(0xFFFF00FF),
  onPrimary: const Color(0xFF00FF00),
  band: const Color(0xFFFF0000),
  onBand: const Color(0xFF0000FF),
  notice: const Color(0xFFFFFF00),
  onNotice: const Color(0xFF00FFFF),
  ink: const Color(0xFFFF8800),
  muted: const Color(0xFF8800FF),
  hairline: const Color(0xFF00FF88),
  surface: const Color(0xFF123456),
  raised: const Color(0xFF654321),
  canvas: const Color(0xFFABCDEF),
  shell: const Color(0xFFFEDCBA),
  selection: p.selection,
  shadow: const Color(0xFF884400),
  drawnInk: const Color(0xFF4400FF),
  cad: p.cad,
);

bool _neutral(int argb) =>
    (argb >> 16 & 0xFF) == (argb >> 8 & 0xFF) &&
    (argb >> 8 & 0xFF) == (argb & 0xFF);

void main() {
  final door = base.door();
  final mesh = MeshBuilder.build(door);

  group('the studio is neutral, and it is not the application', () {
    test('every colour the studio has is a grey, in both appearances', () {
      for (final s in [Studio.light, Studio.dark]) {
        expect(_neutral(s.backdropTop), isTrue);
        expect(_neutral(s.backdropBottom), isTrue);
        expect(_neutral(s.lines), isTrue);
      }
      expect(_neutral(Studio.edgeInk), isTrue);
      expect(_neutral(Studio.clay), isTrue);
    });

    test('the backdrop on the screen is grey, not the house green', () async {
      for (final palette in [Palette.light, Palette.dark]) {
        final shot = await _shoot(door, palette: palette);
        for (final p in const [Offset(4, 4), Offset(636, 4), Offset(320, 4)]) {
          final c = shot.at(p);
          expect((c[0] - c[1]).abs(), lessThanOrEqualTo(1), reason: '$p $c');
          expect((c[1] - c[2]).abs(), lessThanOrEqualTo(1), reason: '$p $c');
        }
      }
    });

    test('a palette in any colours paints the model to the byte as the '
        'application\'s own does', () async {
      for (final palette in [Palette.light, Palette.dark]) {
        for (final style in DisplayStyle.values) {
          final own = await _shoot(door, palette: palette, style: style);
          final other = await _shoot(
            door,
            palette: _garish(palette),
            style: style,
          );
          expect(other.rgba, own.rgba, reason: '$palette $style');
        }
      }
    });
  });

  group('the floor', () {
    test('is at the model\'s foot, and seen from above in the first view', () {
      final floor = Floor.under(mesh)!;
      var lowest = -double.infinity;
      for (final f in mesh.facets) {
        for (final c in f.corners) {
          lowest = math.max(lowest, c.y);
        }
      }
      expect(floor.level, lowest);
      expect(floor.seenBy(Camera.presentation, mesh), isNotNull);
      // From beneath there is no floor to show: it would stand in front of
      // the model.
      expect(
        floor.seenBy(Camera.presentation.copyWith(pitchDegrees: -15), mesh),
        isNull,
      );
    });

    test('its grid is ten-centimetre squares laid from the model\'s own side '
        'and face, a metre line every ten', () {
      final floor = Floor.under(mesh)!;
      final outline = door.frame!.outline;
      final across = floor.linesAcross;
      expect(across.map((l) => l.$1), contains(outline.left));
      for (final (x, major) in across) {
        final squares = (x - outline.left) / Floor.gridStep;
        expect(squares, closeTo(squares.roundToDouble(), 1e-9));
        expect(major, squares.round() % 10 == 0, reason: '$x');
      }
      expect(
        across.where((l) => l.$2).map((l) => l.$1),
        containsAll([outline.left, outline.left + 1000]),
      );
      final deep = floor.linesDeep;
      expect(deep.map((l) => l.$1), contains(0.0), reason: 'the drawn face');
      for (final (z, _) in deep) {
        expect(z / Floor.gridStep, closeTo((z / Floor.gridStep).round(), 1e-9));
      }
    });

    test('its shadow is dark at the foot and falls away to nothing', () {
      final floor = Floor.under(mesh)!;
      final middle = (floor.minX + floor.maxX) / 2;
      final out = [
        for (final d in [5.0, 100, 400, 1000, 2000, floor.reach])
          floor.occlusionAt(middle, floor.maxZ + d),
      ];
      expect(out.first, greaterThan(0.3), reason: '$out');
      // Falling away — give or take one of the sky's directions, of which
      // there are ninety-six.
      for (var i = 1; i < out.length; i++) {
        expect(out[i], lessThanOrEqualTo(out[i - 1] + 0.025), reason: '$out');
      }
      expect(out[2], lessThan(out.first * 0.7), reason: '$out');
      expect(out.last, lessThan(0.05), reason: '$out');
      expect(floor.fadeAt(middle, floor.maxZ + floor.reach), 0);
    });

    test('glass lets the light through; a panel does not', () {
      // The key light from in front and above: the floor behind the middle
      // of the light is in the shadow of whatever fills it.
      final glazed = Floor.under(
        MeshBuilder.build(glass.glazed(GlassLook.clear)),
      )!;
      final panelled = Floor.under(MeshBuilder.build(glass.panelled()))!;
      const towards = Vec3(0, -1, 1);
      double behind(Floor f) {
        final x = f.minX + (f.maxX - f.minX) * 0.7;
        return f.keyShutAt(
          x,
          f.minZ - f.height * 0.45,
          towardsKey: towards,
          angularSize: 0.1,
        );
      }

      expect(behind(glazed), lessThan(0.2));
      expect(behind(panelled), greaterThan(0.9));
    });

    test('it says that the model stands on it: darker just in front of its '
        'foot', () async {
      final floor = Floor.under(mesh)!;
      final withIt = await _shoot(door);
      final without = await _shoot(door, floor: false);
      final camera = Camera.presentation.framing(
        mesh,
        width: _size.width,
        height: _size.height,
      );
      final space = camera.eyeSpaceFor(mesh);
      final foot = withIt.place(
        space.place(
          Vec3((floor.minX + floor.maxX) / 2, floor.level, floor.maxZ + 15),
        )!,
      );
      expect(
        without.brightness(foot) - withIt.brightness(foot),
        greaterThan(10),
        reason: 'at $foot',
      );
    });

    test('nothing on the floor lies over the model', () async {
      final withIt = await _shoot(door);
      final without = await _shoot(door, floor: false);
      // Where the design's opaque faces are on the picture — seen through
      // glass the floor is what is behind it, as it should be.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final f in without.painter.faces) {
        if (f.source.surface.isTransparent) continue;
        final path = Path();
        final first = without.place(f.corners.first);
        path.moveTo(first.dx, first.dy);
        for (final c in f.corners.skip(1)) {
          final at = without.place(c);
          path.lineTo(at.dx, at.dy);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = Colors.white);
      }
      // Glass painted over them takes them back out.
      for (final f in without.painter.faces) {
        if (!f.source.surface.isTransparent) continue;
        final path = Path();
        final first = without.place(f.corners.first);
        path.moveTo(first.dx, first.dy);
        for (final c in f.corners.skip(1)) {
          final at = without.place(c);
          path.lineTo(at.dx, at.dy);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = Colors.black);
      }
      final image = await recorder.endRecording().toImage(
        _size.width.round(),
        _size.height.round(),
      );
      final mask = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      bool solid(int x, int y) {
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final i = ((y + dy) * _size.width.round() + x + dx) * 4;
            if (mask[i] < 255) return false;
          }
        }
        return true;
      }

      var checked = 0;
      for (var y = 3; y < _size.height - 3; y++) {
        for (var x = 3; x < _size.width - 3; x++) {
          if (!solid(x, y)) continue;
          checked++;
          final p = Offset(x.toDouble(), y.toDouble());
          expect(withIt.at(p), without.at(p), reason: '$p');
        }
      }
      expect(checked, greaterThan(5000));
    });

    test('it takes the studio\'s colours, never the design\'s or the '
        'application\'s, and the design is untouched by it', () {
      final before = door.toJson().toString();
      final facets = [
        for (final f in mesh.facets) [f.elementId, ...f.corners, f.colour],
      ].toString();
      Floor.under(mesh)!.seenBy(Camera.presentation, mesh);
      expect(door.toJson().toString(), before);
      expect(
        [
          for (final f in mesh.facets) [f.elementId, ...f.corners, f.colour],
        ].toString(),
        facets,
      );
    });
  });

  group('the view is from where it says', () {
    test('the first view is from a little above the model\'s middle', () {
      final space = Camera.presentation.eyeSpaceFor(mesh);
      final eye = space.eye!;
      expect(eye.y, lessThan(mesh.centre.y), reason: 'above: y runs down');
      // A sill's top is turned towards the eye, a head's underside away.
      final up = space.turn(const Vec3(0, -1, 0));
      expect(up.z, greaterThan(0));
    });

    test('Top looks down on the model and Bottom up at it', () {
      final top = Camera.top.eyeSpaceFor(mesh);
      final bottom = Camera.bottom.eyeSpaceFor(mesh);
      expect(top.eye!.y, lessThan(mesh.centre.y - mesh.span));
      expect(bottom.eye!.y, greaterThan(mesh.centre.y + mesh.span));
      expect(top.turn(const Vec3(0, -1, 0)).z, greaterThan(0.99));
    });

    test('the screen\'s own down is the camera\'s', () {
      for (final c in [
        Camera.presentation,
        Camera.top,
        const Camera(yawDegrees: -70, pitchDegrees: 40),
      ]) {
        final space = c.eyeSpaceFor(mesh);
        final down = space.turn(c.screenDown);
        final right = space.turn(c.screenRight);
        expect(down.y, closeTo(1, 1e-9));
        expect(right.x, closeTo(1, 1e-9));
      }
    });
  });

  test('a pane is never painted over the stile it sits behind', () async {
    // The front faces of the frame and the sashes: all of each is nearer
    // the viewer than any glass, so no glass can be painted over any of it.
    var glassFront = -double.infinity;
    for (final f in mesh.facets) {
      if (!f.surface.isTransparent) continue;
      for (final c in f.corners) {
        glassFront = math.max(glassFront, c.z);
      }
    }
    bool inFrontOfGlass(Facet f) =>
        (f.role == FacetRole.sash || f.role == FacetRole.frame) &&
        f.normal.z > 0.9 &&
        f.corners.every((c) => c.z > glassFront + 0.5);

    final lever = door.hardware.firstWhere((p) => p.kind == HardwareKind.lever);
    final c = mesh.centre;
    for (final camera in [
      Camera.presentation,
      const Camera(),
      Camera.isometric,
      Camera(zoom: 10, target: Vec3(lever.at.x - c.x, lever.at.y - c.y, 0)),
    ]) {
      final painter = ModelPainter(
        faces: camera.project(mesh),
        size: _size,
        viewSpan: Camera.viewSpan(mesh),
        style: DisplayStyle.shaded,
        groundPlane: false,
      );
      final scale = _size.shortestSide * Camera.spanShare / painter.viewSpan;
      var checked = 0;
      for (final f in painter.faces) {
        if (!inFrontOfGlass(f.source)) continue;
        var sx = 0.0, sy = 0.0;
        for (final p in f.corners) {
          sx += p.x;
          sy += p.y;
        }
        final at = Offset(
          _size.width / 2 + sx / f.corners.length * scale,
          _size.height / 2 + sy / f.corners.length * scale,
        );
        if (!(Offset.zero & _size).contains(at)) continue;
        final top = painter.faceAt(at);
        if (top == null) continue;
        checked++;
        expect(
          top.source.surface.isTransparent,
          isFalse,
          reason: 'glass ${top.elementId} over ${f.elementId} at $at',
        );
      }
      expect(checked, greaterThan(0));
    }
  });
}

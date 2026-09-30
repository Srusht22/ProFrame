import 'dart:math' as math;
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
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/surface.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/shading.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import '../domain/the_frame_is_a_real_profile_test.dart' as frame;

// Phase 5 of the CAD and 3D work: glass that looks like glass.
//
// A pane used to be shaded once, as one colour, over whatever was behind it:
// a tinted card. Now it is shaded point by point across its face, in a
// studio with strip lights either side of the camera, as glass is
// photographed: what it lets through multiplies what is behind it, what it
// scatters is laid over, and what it reflects — the sky, the ground, and
// the strip light as a sheen that lies across the pane where it truly falls
// and moves as the view turns — is added. It has thickness, and its thin
// side is the green of the iron in it.
//
// Held here, on the pictures themselves: every glass choice is exactly the
// same geometry; each is a different picture; clear glass shows what is
// behind it and frosted does not; a pane is not a flat rectangle where a
// panel in the same place is; the sheen moves with the view; and the
// technical drawing stays a drawing, its lines where they were.

const _size = Size(760, 580);
const _camera = Camera();

/// A window of a narrow leaf and a wide fixed light, every pane in [look].
Design glazed(GlassLook look) {
  final d = frame.drawn(1800, 1200, divided: true, profileMm: 60);
  return Infill.fill(d, {for (final s in d.sections) s.id: look.finish});
}

/// The same window, every pane a white panel.
Design panelled() {
  final d = frame.drawn(1800, 1200, divided: true, profileMm: 60);
  return Infill.fill(d, {
    for (final s in d.sections) s.id: PanelColour.white.finish,
  });
}

class Picture {
  final Uint8List rgba;
  final List<ProjectedFacet> faces;
  final double scale;

  Picture(this.rgba, this.faces, this.scale);

  Offset place(Vec2 at) =>
      Offset(_size.width / 2 + at.x * scale, _size.height / 2 + at.y * scale);

  List<int> at(Offset p) {
    final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2]];
  }

  double brightness(Offset p) {
    final c = at(p);
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }

  /// Points along the diagonal of the main face of [id] nearest the eye —
  /// the largest on the screen, not a thin arris round it — a sixth of the
  /// way in from each end.
  List<Offset> across(String id) {
    double area(ProjectedFacet f) {
      var a = 0.0;
      for (var i = 0; i < f.corners.length; i++) {
        final p = f.corners[i], q = f.corners[(i + 1) % f.corners.length];
        a += p.x * q.y - q.x * p.y;
      }
      return a.abs() / 2;
    }

    final candidates = faces
        .where(
          (f) =>
              f.elementId == id &&
              !f.source.isSide &&
              f.source.role != FacetRole.sash,
        )
        .toList();
    final biggest = candidates.map(area).reduce((a, b) => a > b ? a : b);
    final face = candidates
        .where((f) => area(f) > biggest * 0.9)
        .reduce((a, b) => a.depth < b.depth ? a : b);
    final c = [for (final p in face.corners) place(p)];
    final from = Offset.lerp(c[0], c[2], 1 / 6)!;
    final to = Offset.lerp(c[0], c[2], 5 / 6)!;
    return [for (var i = 0; i <= 12; i++) Offset.lerp(from, to, i / 12)!];
  }
}

Future<Picture> render(
  Design design, {
  Camera camera = _camera,
  Palette palette = Palette.light,
}) async {
  final mesh = MeshBuilder.build(design);
  final faces = camera.project(mesh);
  final span = Camera.viewSpan(mesh);
  final recorder = ui.PictureRecorder();
  ModelPainter(
    faces: faces,
    size: _size,
    viewSpan: span,
    style: DisplayStyle.shaded,
    groundPlane: false,
    palette: palette,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return Picture(
    data!.buffer.asUint8List(),
    faces,
    _size.shortestSide * 0.92 / span,
  );
}

/// The wide fixed light: the pane the eye sees most of.
String wideLight(Design d) =>
    d.topLevelSections.where((s) => d.openingOf(s.id) == null).single.id;

double spread(List<double> v) =>
    v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);

int apart(List<int> a, List<int> b) =>
    [for (var i = 0; i < 3; i++) (a[i] - b[i]).abs()]
        .reduce((x, y) => x > y ? x : y);

void main() {
  group('changing the glass changes nothing but how it looks', () {
    final clear = glazed(GlassLook.clear);
    for (final look in GlassLook.values) {
      test('clear → ${look.label}', () {
        final other = glazed(look);
        expect(base.designGeometry(other), base.designGeometry(clear));
        expect(
          base.meshGeometry(MeshBuilder.build(other)),
          base.meshGeometry(MeshBuilder.build(clear)),
        );
        expect(
          base.meshGeometry(MeshBuilder.build(other, openFraction: 1)),
          base.meshGeometry(MeshBuilder.build(clear, openFraction: 1)),
        );
        final a = DesignGeometry.of(clear), b = DesignGeometry.of(other);
        for (final s in clear.sections) {
          expect(
            b.fillOf(other.sectionById(s.id)!).corners,
            a.fillOf(s).corners,
            reason: 'width, height and position of ${s.id}',
          );
        }
        for (final bar in clear.dividers) {
          expect(
            b.barBody(other.dividerById(bar.id)!).corners,
            a.barBody(bar).corners,
            reason: 'the divider stays where it was',
          );
        }
        String chains(Design d) => [
          for (final chain in DimensionChains.of(d))
            for (final run in chain.runs)
              '${chain.axis} ${run.fromMm.toStringAsFixed(3)} '
                  '${run.toMm.toStringAsFixed(3)}',
        ].join(';');
        expect(chains(other), chains(clear), reason: 'every dimension');
      });
    }
  });

  group('in 3D, glass is glass', () {
    test('each glass is a different picture', () async {
      // Compared where the pane is seen through — its darkest point, clear
      // of the strip lights' sheen — because what makes two glasses two
      // pictures is what they let through: a reflection is added in white
      // over it, and inside one, two tints come together, as they do on
      // real glass. And by how far apart the two colours are in all three
      // channels, since two tints of the same depth — the grey-green and the
      // blue-grey — differ in their hue, which is all three at once.
      final clear = glazed(GlassLook.clear);
      final clearPicture = await render(clear);
      final across = clearPicture.across(wideLight(clear));
      var through = 0;
      for (var i = 1; i < across.length; i++) {
        if (clearPicture.brightness(across[i]) <
            clearPicture.brightness(across[through])) {
          through = i;
        }
      }
      final seen = <String, List<int>>{};
      for (final look in GlassLook.values) {
        final d = glazed(look);
        final picture = await render(d);
        final points = picture.across(wideLight(d));
        seen[look.label] = picture.at(points[through]);
      }
      double distance(List<int> a, List<int> b) => math.sqrt(
        [for (var i = 0; i < 3; i++) (a[i] - b[i]) * (a[i] - b[i])]
            .reduce((x, y) => x + y)
            .toDouble(),
      );
      final looks = seen.keys.toList();
      for (var i = 0; i < looks.length; i++) {
        for (var j = i + 1; j < looks.length; j++) {
          expect(
            distance(seen[looks[i]]!, seen[looks[j]]!),
            greaterThan(6),
            reason: '${looks[i]} and ${looks[j]}',
          );
        }
      }
    });

    test(
      'clear glass shows what is behind it; frosted glass hardly does',
      () async {
        Future<double> through(GlassLook look) async {
          final d = glazed(look);
          final light = await render(d);
          final dark = await render(d, palette: Palette.dark);
          final points = light.across(wideLight(d));
          var total = 0.0;
          for (final p in points) {
            total += (light.brightness(p) - dark.brightness(p)).abs();
          }
          return total / points.length;
        }

        final clear = await through(GlassLook.clear);
        final tinted = await through(GlassLook.tinted);
        final frosted = await through(GlassLook.frosted);
        expect(clear, greaterThan(90));
        expect(tinted, lessThan(clear));
        expect(frosted, lessThan(clear * 0.75));
      },
    );

    test(
      'tinted glass is darker than clear, and the dark glass darkest',
      () async {
        Future<double> mean(GlassLook look) async {
          final d = glazed(look);
          final picture = await render(d);
          final points = picture.across(wideLight(d));
          return points.map(picture.brightness).reduce((a, b) => a + b) /
              points.length;
        }

        final clear = await mean(GlassLook.clear);
        final tinted = await mean(GlassLook.tinted);
        final dark = await mean(GlassLook.dark);
        expect(tinted, lessThan(clear - 15));
        expect(dark, lessThan(tinted));
      },
    );

    test('a pane is not a flat rectangle: the light moves across it, where '
        'a panel in the same place is one even face', () async {
      final d = glazed(GlassLook.clear);
      final glass = await render(d);
      final panes = glass.across(wideLight(d)).map(glass.brightness).toList();

      final p = panelled();
      final panel = await render(p);
      final panels = panel.across(wideLight(p)).map(panel.brightness).toList();

      // Seen from a little above, as the view now is, a pane reflects the
      // studio's even floor below the horizon, and what moves across it is
      // the strip light's sheen. It was 40 when the camera was, wrongly,
      // below the model and the pane reflected the sky's horizon line.
      expect(spread(panes), greaterThan(15), reason: '$panes');
      expect(spread(panels), lessThan(4), reason: '$panels');
    });

    test('the sheen moves as the view turns', () async {
      final d = glazed(GlassLook.clear);
      int brightest(Picture p) {
        final values = p.across(wideLight(d)).map(p.brightness).toList();
        var best = 0;
        for (var i = 1; i < values.length; i++) {
          if (values[i] > values[best]) best = i;
        }
        return best;
      }

      final here = brightest(await render(d));
      final turned = brightest(
        await render(d, camera: const Camera(yawDegrees: 33)),
      );
      expect(turned, isNot(here));
    });

    test('frosted glass spreads the light: its sheen is softer than clear '
        'glass\'s', () async {
      Future<double> sheen(GlassLook look) async {
        final d = glazed(look);
        final p = await render(d);
        return spread(p.across(wideLight(d)).map(p.brightness).toList());
      }

      final clear = await sheen(GlassLook.clear);
      final frosted = await sheen(GlassLook.frosted);
      expect(frosted, lessThan(clear));
      expect(frosted, greaterThan(0));
    });

    test('a pane has thickness, and its edge is the green of the glass', () {
      // A sealed unit: two sheets of glass a few millimetres thick with a
      // sealed cavity between them — as thick as a unit is, and no block of
      // glass that thick.
      final d = glazed(GlassLook.clear);
      final mesh = MeshBuilder.build(d);
      final pane = mesh.facets
          .where(
            (f) => f.elementId == wideLight(d) && f.role == FacetRole.glazing,
          )
          .toList();
      final faces = pane.where((f) => !f.isSide).toList();
      expect(faces, hasLength(4));
      final zs = [for (final f in faces) f.corners.first.z]..sort();
      expect(zs.last - zs.first, greaterThan(10), reason: 'the unit');
      expect(zs[1] - zs[0], inInclusiveRange(2, 6), reason: 'a sheet');
      expect(zs[3] - zs[2], inInclusiveRange(2, 6), reason: 'a sheet');
      expect(zs[2] - zs[1], greaterThan(6), reason: 'the cavity');
      final sides = pane
          .where((f) => f.isSide && f.surface.isTransparent)
          .toList();
      expect(sides, isNotEmpty);
      // The cavity is sealed round its edge, by something that is not glass.
      expect(
        pane.where((f) => f.isSide && !f.surface.isTransparent),
        isNotEmpty,
      );
      // Edge on, it is not seen through: it is the glass's body, green.
      final edge = Shading.of(
        surface: Surfaces.clearGlass,
        colour: GlassLook.clear.colour,
        normal: sides.first.normal,
        environment: Environment.daylight,
        side: true,
      );
      expect(edge.opacity, greaterThan(0.8));
      final c = Rgb.of(edge.colour);
      expect(c.g, greaterThan(c.r));
    });
  });

  group('on the technical drawing, glass stays readable', () {
    const plain = CadLayers(
      grid: false,
      dimensions: false,
      annotations: false,
      centreLines: false,
      grips: false,
    );

    Future<(Uint8List, ViewTransform)> cad(Design d) async {
      final view = ViewTransform.fit(
        d.frame!.outline,
        _size,
        padding: const EdgeInsets.all(40),
      );
      final recorder = ui.PictureRecorder();
      CadPainter(
        design: d,
        view: view,
        layers: plain,
      ).paint(Canvas(recorder), _size);
      final image = await recorder.endRecording().toImage(
        _size.width.round(),
        _size.height.round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return (data!.buffer.asUint8List(), view);
    }

    double brightness(Uint8List rgba, Offset p) {
      final i = (p.dy.round() * _size.width.round() + p.dx.round()) * 4;
      return (0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2]) /
          255;
    }

    /// Points on a small grid in the middle of the wide light, clear of
    /// its corner mark.
    List<Offset> middle(Design d, ViewTransform view) {
      final fill = DesignGeometry.of(d).fillOf(d.sectionById(wideLight(d))!);
      final c = fill.centroid;
      return [
        for (var i = -3; i <= 3; i++)
          for (var j = -3; j <= 3; j++)
            view.toScreen(Vec2(c.x + i * 23, c.y + j * 23 + 150)),
      ];
    }

    test(
      'a light tint, never so dark or so pale the lines disappear',
      () async {
        for (final look in GlassLook.values) {
          final d = glazed(look);
          final (rgba, view) = await cad(d);
          final inside = middle(d, view).map((p) => brightness(rgba, p));
          for (final b in inside) {
            expect(b, inInclusiveRange(0.6, 0.995), reason: look.label);
          }
          // The pane's own outline is drawn over its tint, darker than it.
          final fill = DesignGeometry.of(d)
              .fillOf(d.sectionById(wideLight(d))!);
          final edge = view.toScreen(Vec2(fill.centroid.x, fill.top));
          final line = [
            for (var dy = -2; dy <= 2; dy++)
              brightness(rgba, edge + Offset(0, dy.toDouble())),
          ].reduce((a, b) => a < b ? a : b);
          expect(line, lessThan(inside.reduce((a, b) => a < b ? a : b) - 0.2));
        }
      },
    );

    test(
      'tinted glass is shaded darker than clear; frosted is stippled',
      () async {
        Future<List<double>> tint(GlassLook look) async {
          final d = glazed(look);
          final (rgba, view) = await cad(d);
          return middle(d, view).map((p) => brightness(rgba, p)).toList();
        }

        double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
        final clear = await tint(GlassLook.clear);
        final tinted = await tint(GlassLook.tinted);
        expect(mean(tinted), lessThan(mean(clear) - 0.02));

        // Clear glass is one even tint across its middle; frosted is dotted.
        final d = glazed(GlassLook.frosted);
        final (rgba, view) = await cad(d);
        final fill = DesignGeometry.of(d).fillOf(d.sectionById(wideLight(d))!);
        final c = view.toScreen(fill.centroid + const Vec2(0, 150));
        final row = [
          for (var x = -40; x <= 40; x++)
            brightness(rgba, c + Offset(x.toDouble(), 0)),
        ];
        final plainRow = await () async {
          final dc = glazed(GlassLook.clear);
          final (rgbaClear, _) = await cad(dc);
          return [
            for (var x = -40; x <= 40; x++)
              brightness(rgbaClear, c + Offset(x.toDouble(), 0)),
          ];
        }();
        expect(spread(plainRow), lessThan(0.01));
        final rows = [
          for (var y = 0; y < 7; y++)
            spread([
              for (var x = -40; x <= 40; x++)
                brightness(rgba, c + Offset(x.toDouble(), y.toDouble())),
            ]),
        ];
        expect(rows.reduce((a, b) => a > b ? a : b), greaterThan(0.03));
        expect(row, isNotEmpty);
      },
    );

    test(
      'the lines of the drawing are where they were, whatever the glass',
      () async {
        final (clear, view) = await cad(glazed(GlassLook.clear));
        final d = glazed(GlassLook.frosted);
        final (frosted, _) = await cad(d);
        final geometry = DesignGeometry.of(d);
        final fills = [
          for (final s in d.sections)
            if (d.childSectionsOf(s.id).isEmpty) geometry.fillOf(s),
        ];
        var differ = 0;
        final w = _size.width.round();
        for (var i = 0; i < clear.length; i += 4) {
          if (clear[i] == frosted[i] &&
              clear[i + 1] == frosted[i + 1] &&
              clear[i + 2] == frosted[i + 2]) {
            continue;
          }
          final p = view.toSheet(
            Offset(((i ~/ 4) % w).toDouble(), ((i ~/ 4) ~/ w).toDouble()),
          );
          // Inside a pane, or on its very edge, where a dot is cut off.
          final inAPane = fills.any(
            (f) => f.contains(p) || f.awayFrom(p) <= view.lengthToSheet(1.5),
          );
          if (!inAPane) differ++;
        }
        expect(differ, 0);
      },
    );
  });
}

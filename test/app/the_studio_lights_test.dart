import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/app/viewer/display_style.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/surface.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/shading.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import 'glass_looks_like_glass_test.dart' as glass;

// Phase 10 of the CAD and 3D work: lighting a manufacturer can inspect by.
//
// A product photographer's studio, not a stage: a large soft key light over
// the viewer's left shoulder that lights what is turned towards it; a
// weaker fill from the other side, so what is turned away is in shade and
// never in darkness; light from all round, a little stronger from above;
// and strip lights either side of the camera, seen only in what reflects
// them. All of it white. The key used to light both sides of a face alike,
// so the two reveals of an opening were the same shade and the depth was
// read only from the drawn edges; the strips stood where the old camera
// reflected them and not the view a design is now shown from, and when a
// pane did catch one it went white.
//
// Held here: the light is neutral and exposed so a white face is white;
// nothing is black and nothing burns out; what faces the light is lighter
// than what faces away, and what faces up than what faces down, so the
// frame's reveals and profile read; highlights are as soft as the light is
// large; glass carries its sheen in the view a design is shown from and
// stays glass; and panel, frame, metal and rubber in one colour are told
// apart by the light.

const white = 0xFFF2F2F0;
const grey = 0xFF8C9094;

final env = Environment.daylight;

double lum(Shaded s) => Rgb.of(s.colour).luminance;

Shaded shade(Surface surface, int colour, Vec3 normal) => Shading.of(
  surface: surface,
  colour: colour,
  normal: normal,
  environment: env,
);

/// Directions a face can be turned and still be seen: across the half of
/// the sphere facing the viewer.
List<Vec3> seenDirections() => [
  for (var a = -80; a <= 80; a += 20)
    for (var b = -80; b <= 80; b += 20)
      Vec3(
        math.sin(a * math.pi / 180) * math.cos(b * math.pi / 180),
        math.sin(b * math.pi / 180),
        math.cos(a * math.pi / 180) * math.cos(b * math.pi / 180),
      ).normalised,
];

void main() {
  group('the studio', () {
    test('the light is white: a grey surface is grey whichever way it '
        'faces', () {
      for (final n in seenDirections()) {
        // Rubber hardly reflects, so what is seen is the light on it.
        final c = Rgb.of(shade(Surfaces.rubber, grey, n).colour);
        expect((c.r - c.g).abs(), lessThan(0.03), reason: '$n');
        expect((c.g - c.b).abs(), lessThan(0.03), reason: '$n');
      }
    });

    test('exposed for the design: a white panel square to the viewer is '
        'white', () {
      final front = lum(shade(Surfaces.panel, white, const Vec3(0, 0, 1)));
      expect(front, inInclusiveRange(0.9, 1.0));
    });

    test('nothing is in darkness and nothing burns out', () {
      final seen = [
        for (final n in seenDirections()) lum(shade(Surfaces.panel, white, n)),
      ];
      final darkest = seen.reduce(math.min);
      final lightest = seen.reduce(math.max);
      expect(darkest, greaterThan(0.25), reason: 'readable shadows');
      expect(lightest, lessThanOrEqualTo(1.0), reason: 'nothing blown out');
      // Not a stage: shade is shade, not night.
      expect(lightest / darkest, lessThan(3.5));
    });

    test('lit as it faces: towards the key lighter than away, up lighter '
        'than down', () {
      double at(Vec3 n) => lum(shade(Surfaces.panel, white, n.normalised));
      // The two reveals of an opening, seen from in front.
      final towardsKey = at(const Vec3(-0.6, 0, 0.8));
      final awayFromKey = at(const Vec3(0.6, 0, 0.8));
      expect(towardsKey - awayFromKey, greaterThan(0.1));
      // A sill's top and a head's underside.
      final up = at(const Vec3(0, -0.6, 0.8));
      final down = at(const Vec3(0, 0.6, 0.8));
      expect(up - down, greaterThan(0.1));
      // And a face square to the viewer lighter than a side turned away.
      expect(at(const Vec3(0, 0, 1)), greaterThan(awayFromKey));
    });

    test('a face turned from the key is not lit by it: only the fill and '
        'the room reach it', () {
      // Turned towards the viewer but away from the key light — the
      // underside and far side of a member. Lit by the key it would read
      // like the side facing the light, and the depth would be lost.
      for (final n in seenDirections()) {
        if (n.dot(env.light) >= -0.05) continue;
        final lit = lum(shade(Surfaces.rubber, white, n));
        final unlit = env.lightOn(n, shadowed: 1);
        expect(env.lightOn(n), closeTo(unlit, 1e-9), reason: '$n');
        expect(
          lit,
          lessThan(env.lightOn(const Vec3(0, 0, 1)) * 0.8),
          reason: '$n',
        );
      }
    });

    test('highlights are as soft as the light is large', () {
      // A highlight is the key seen in the surface: its lobe is never
      // narrower than the light, so a polished handle carries a soft sheen
      // rather than a pinpoint.
      final n = env.sharpestHighlight;
      expect(math.pow(math.cos(env.keySize / 4), n), closeTo(0.5, 1e-9));
      expect(n, lessThan(400));
    });
  });

  group('on the model', () {
    test('the frame\'s reveals are lit as they face, so its depth reads', () {
      // Every face of the frame turned to one side against every face
      // turned to the other: the key's side lighter, by what the painter
      // itself shades them with.
      final design = base.window();
      final mesh = MeshBuilder.build(design);
      final camera = Camera.presentation.framing(mesh, width: 800, height: 600);
      final painter = ModelPainter(
        faces: camera.project(mesh),
        size: const Size(800, 600),
        viewSpan: Camera.viewSpan(mesh),
        style: DisplayStyle.shaded,
      );
      // Grouped as the painter lights them: by which way each face turns
      // on the screen, once turned to the viewer.
      final left = <double>[], right = <double>[], up = <double>[];
      final down = <double>[];
      for (final f in painter.faces) {
        if (f.source.role != FacetRole.frame) continue;
        var n = f.normal.normalised;
        if (n.z < 0) n = n * -1;
        final l = Rgb.of(painter.shadeOf(f).colour).luminance;
        if (n.x > 0.5) right.add(l);
        if (n.x < -0.5) left.add(l);
        if (n.y < -0.5) up.add(l);
        if (n.y > 0.5) down.add(l);
      }
      double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
      // Faces turned to the right are turned from a key over the left
      // shoulder: in shade, but not in darkness.
      expect(mean(left) - mean(right), greaterThan(0.05));
      expect(mean(right), greaterThan(0.25));
      // Faces turned up — y runs down the screen — are lighter than faces
      // turned down.
      expect(mean(up) - mean(down), greaterThan(0.05));
    });

    test('glass carries its sheen in the view a design is shown from, and '
        'stays glass', () async {
      final d = glass.glazed(GlassLook.clear);
      final light = await glass.render(d, camera: Camera.presentation);
      final dark = await glass.render(
        d,
        camera: Camera.presentation,
        palette: Palette.dark,
      );
      final points = light.across(glass.wideLight(d));
      final values = points.map(light.brightness).toList();
      // A sheen lies across it…
      expect(glass.spread(values), greaterThan(15), reason: '$values');
      // …without whitening it: no point of the pane burnt out…
      for (final p in points) {
        expect(light.at(p).reduce(math.max), lessThan(250), reason: '$p');
      }
      // …and what is behind it still shows through, even in the sheen.
      final brightest = points[values.indexOf(values.reduce(math.max))];
      expect(
        (light.brightness(brightest) - dark.brightness(brightest)).abs(),
        greaterThan(40),
      );
    });

    test('in one colour, panel, frame, metal and rubber are told apart by '
        'the light', () {
      // The same grey, turned the same few ways: each material answers the
      // light its own way — the panel and the frame's PVC by how they take
      // a glancing light, the metal by what it mirrors, the rubber by
      // hardly changing at all.
      final ways = [
        const Vec3(0, 0, 1),
        const Vec3(-0.7, -0.3, 0.65),
        const Vec3(0.8, 0.2, 0.55),
        const Vec3(0.97, 0, 0.24),
      ].map((v) => v.normalised).toList();
      final surfaces = {
        'panel': Surfaces.panel,
        'PVC': Surfaces.pvc,
        'metal': Surfaces.handleMetal,
        'rubber': Surfaces.rubber,
      };
      final looks = {
        for (final e in surfaces.entries)
          e.key: [for (final n in ways) lum(shade(e.value, grey, n))],
      };
      final names = looks.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          var most = 0.0;
          for (var k = 0; k < ways.length; k++) {
            most = math.max(
              most,
              (looks[names[i]]![k] - looks[names[j]]![k]).abs(),
            );
          }
          expect(most, greaterThan(0.03), reason: '${names[i]}/${names[j]}');
        }
      }
    });
  });
}

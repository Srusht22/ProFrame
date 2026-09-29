import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/theme/app_theme.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/frame_profile.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import '../domain/the_frame_is_a_real_profile_test.dart' as frame;
import 'glass_looks_like_glass_test.dart' as glass;

// Phase 6 of the CAD and 3D work: a panel that looks like a panel.
//
// A panel used to be a flat slab painted one colour: from the front, a
// rectangle the colour the user chose, and nothing else to say it was a
// solid thing set into a sash rather than a card. Now it is shaded as what
// it is. Its faces are eased at the edges, as a finished panel is, so the
// edges take the light differently from the face; and it sits back from
// the frame or the sash around it, so the edge of the face in the corner of
// that step is darker — the light the step shuts out, and on the side the
// light comes from, the shadow the step casts across it. Opaque, so nothing
// behind it shows; and every colour the user chose is the colour it is
// built in, lit, never replaced.
//
// Held here: changing a panel's colour changes nothing but how it looks;
// every facet carries the user's colour exactly; the panel has thickness
// and eased edges, all inside its fill; on the pictures it is opaque,
// keeps the hue it was given, is darker in the corner of its step than in
// its middle and even across its middle; and a panel, a pane of glass and
// the frame in one colour are three different things.

const _blue = 0xFF2F5FA8;

/// The window of a narrow leaf and a wide fixed light, every pane [finish].
Design panelled(Finish finish) {
  final d = frame.drawn(1800, 1200, divided: true, profileMm: 60);
  return Infill.fill(d, {for (final s in d.sections) s.id: finish});
}

final _finishes = <String, Finish>{
  for (final c in PanelColour.values) c.label: c.finish,
  'custom blue': const Finish(colour: _blue, material: MaterialKind.panel),
};

double _area(List<Vec2> c) {
  var a = 0.0;
  for (var i = 0; i < c.length; i++) {
    final p = c[i], q = c[(i + 1) % c.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a.abs() / 2;
}

/// The panel's main face nearest the eye: the largest of its faces on the
/// screen, not an arris or a side.
List<Offset> _face(glass.Picture picture, String id) {
  final candidates = picture.faces
      .where(
        (f) =>
            f.elementId == id &&
            f.source.role != FacetRole.sash &&
            !f.source.isSide,
      )
      .toList();
  final biggest = candidates
      .map((f) => _area(f.corners))
      .reduce((a, b) => a > b ? a : b);
  final face = candidates
      .where((f) => _area(f.corners) > biggest * 0.9)
      .reduce((a, b) => a.depth < b.depth ? a : b);
  return [for (final p in face.corners) picture.place(p)];
}

Offset _middle(List<Offset> c) =>
    c.reduce((a, b) => a + b) / c.length.toDouble();

/// Just inside the middle of each edge of [c], [by] pixels in.
List<Offset> _insideEdges(List<Offset> c, double by) {
  final centre = _middle(c);
  return [
    for (var i = 0; i < c.length; i++)
      () {
        final m = (c[i] + c[(i + 1) % c.length]) / 2;
        final towards = centre - m;
        return m + towards / towards.distance * by;
      }(),
  ];
}

double _hue(List<int> rgb) {
  final r = rgb[0] / 255, g = rgb[1] / 255, b = rgb[2] / 255;
  final hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
  final d = hi - lo;
  if (d < 1e-9) return 0;
  final double h;
  if (hi == r) {
    h = ((g - b) / d) % 6;
  } else if (hi == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return (h * 60 + 360) % 360;
}

double _hueApart(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('changing a panel changes nothing but how it looks', () {
    final white = panelled(PanelColour.white.finish);
    for (final MapEntry(key: name, value: finish) in _finishes.entries) {
      test('white → $name', () {
        final other = panelled(finish);
        expect(base.designGeometry(other), base.designGeometry(white));
        for (final open in [0.0, 1.0]) {
          expect(
            base.meshGeometry(MeshBuilder.build(other, openFraction: open)),
            base.meshGeometry(MeshBuilder.build(white, openFraction: open)),
            reason: 'the solid at openFraction $open',
          );
        }
        final a = DesignGeometry.of(white), b = DesignGeometry.of(other);
        for (final s in white.sections) {
          expect(
            b.fillOf(other.sectionById(s.id)!).corners,
            a.fillOf(s).corners,
            reason: 'width, height and position of ${s.id}',
          );
        }
        for (final bar in white.dividers) {
          expect(
            b.barBody(other.dividerById(bar.id)!).corners,
            a.barBody(bar).corners,
          );
        }
        String chains(Design d) => [
          for (final chain in DimensionChains.of(d))
            for (final run in chain.runs)
              '${chain.axis} ${run.fromMm.toStringAsFixed(3)} '
                  '${run.toMm.toStringAsFixed(3)}',
        ].join(';');
        expect(chains(other), chains(white), reason: 'every dimension');
      });
    }

    test('the door keeps its geometry whatever colour its panel is', () {
      final door = base.door();
      final panel = door.sections.firstWhere(
        (s) => s.finish.material == MaterialKind.panel,
      );
      final recoloured = Infill.fill(door, {
        panel.id: const Finish(colour: _blue, material: MaterialKind.panel),
      });
      expect(base.designGeometry(recoloured), base.designGeometry(door));
      expect(
        base.meshGeometry(MeshBuilder.build(recoloured)),
        base.meshGeometry(MeshBuilder.build(door)),
      );
    });
  });

  group('the user’s colour is the colour it is built in', () {
    for (final MapEntry(key: name, value: finish) in _finishes.entries) {
      test(name, () {
        final d = panelled(finish);
        final panels = MeshBuilder.build(d).facets
            .where((f) => f.role == FacetRole.panel)
            .toList();
        expect(panels, isNotEmpty);
        for (final f in panels) {
          expect(f.colour, finish.colour, reason: 'no darkening stored');
          expect(f.surface.isTransparent, isFalse);
        }
      });
    }
  });

  group('a panel is a solid with edges', () {
    final d = panelled(PanelColour.grey.finish);
    final mesh = MeshBuilder.build(d);
    final geometry = DesignGeometry.of(d);

    for (final section in d.sections.where((s) => d.openingOf(s.id) == null)) {
      test('the fixed light ${section.id}', () {
        final faces = mesh.facets
            .where((f) => f.elementId == section.id)
            .toList();
        final zs = [
          for (final f in faces)
            for (final c in f.corners) c.z,
        ];
        final thickness = zs.reduce(math.max) - zs.reduce(math.min);
        expect(thickness, greaterThan(10), reason: 'a slab, not a sheet');

        // Its sides stand the whole thickness.
        final sides = faces.where((f) => f.isSide).toList();
        expect(sides, hasLength(4));
        for (final side in sides) {
          final z = [for (final c in side.corners) c.z];
          expect(
            z.reduce(math.max) - z.reduce(math.min),
            lessThan(thickness),
            reason: 'the arrises take the corners off',
          );
          expect(
            z.reduce(math.max) - z.reduce(math.min),
            greaterThan(thickness * 0.8),
          );
        }

        // The faces are eased: the front and the back are the fill inset by
        // the arris, and the arrises between them turn the corner.
        final arris = panelArrisOf(thickness);
        expect(arris, greaterThan(0));
        final fill = geometry.fillOf(section);
        final eased = fill.inset(arris);
        final flat = faces.where((f) => !f.isSide && f.corners.length == 4);
        final biggest = flat
            .map(
              (f) => Polygon([for (final c in f.corners) Vec2(c.x, c.y)]).area,
            )
            .reduce(math.max);
        expect(biggest, closeTo(eased.area, 1), reason: 'the eased face');
        expect(
          faces.length,
          2 + 4 * 3,
          reason: 'front, back, and a side and two arrises round each edge',
        );

        // All of it inside the fill: a finish is not a size.
        for (final f in faces) {
          for (final c in f.corners) {
            final at = Vec2(c.x, c.y);
            expect(
              fill.contains(at) ||
                  fill.edges.any((e) => e.distanceTo(at) < 1e-6),
              isTrue,
              reason: '$c is inside the pane',
            );
          }
        }
      });
    }
  });

  group('in 3D, a panel is a panel', () {
    test('it is opaque: the backdrop never shows through it', () async {
      for (final finish in _finishes.values) {
        final d = panelled(finish);
        final id = glass.wideLight(d);
        final light = await glass.render(d);
        final dark = await glass.render(d, palette: Palette.dark);
        final face = _face(light, id);
        for (final p in [_middle(face), ..._insideEdges(face, 6)]) {
          expect(
            glass.apart(light.at(p), dark.at(p)),
            lessThanOrEqualTo(1),
            reason: 'the same on a light and a dark backdrop',
          );
        }
      }
    });

    test('it keeps the hue it was given', () async {
      for (final colour in [PanelColour.brown.colour, _blue]) {
        final d = panelled(
          Finish(colour: colour, material: MaterialKind.panel),
        );
        final picture = await glass.render(d);
        final seen = picture.at(_middle(_face(picture, glass.wideLight(d))));
        final given = [
          (colour >> 16) & 0xFF,
          (colour >> 8) & 0xFF,
          colour & 0xFF,
        ];
        expect(
          _hueApart(_hue(seen), _hue(given)),
          lessThan(12),
          reason: 'seen $seen, given $given',
        );
      }
    });

    test('it is even across its middle — a painted face, not glass', () async {
      for (final finish in _finishes.values) {
        final d = panelled(finish);
        final picture = await glass.render(d);
        final c = _face(picture, glass.wideLight(d));
        final from = Offset.lerp(c[0], c[2], 0.3)!;
        final to = Offset.lerp(c[0], c[2], 0.7)!;
        final values = [
          for (var i = 0; i <= 10; i++)
            picture.brightness(Offset.lerp(from, to, i / 10)!),
        ];
        expect(glass.spread(values), lessThan(4), reason: '$values');
      }
    });

    test('it is set in: darker in the corner of its step than in its '
        'middle', () async {
      for (final MapEntry(key: name, value: finish) in _finishes.entries) {
        if (finish.colour == PanelColour.black.colour) continue;
        final d = panelled(finish);
        final picture = await glass.render(d);
        final face = _face(picture, glass.wideLight(d));
        final middle = picture.brightness(_middle(face));
        final edges = [
          for (final p in _insideEdges(face, 2)) picture.brightness(p),
        ];
        // Every edge is darker than the middle, where the step round it
        // shuts out some of the light…
        for (final e in edges) {
          expect(
            e,
            lessThan(middle * 0.985),
            reason: '$name: $edges vs $middle',
          );
        }
        // …and the darkest by a clear margin, where it casts its shadow.
        expect(
          edges.reduce(math.min),
          lessThan(middle * 0.9),
          reason: '$name: $edges vs $middle',
        );
        // A little further in, the face is back to its own colour.
        final inward = [
          for (final p in _insideEdges(face, 30)) picture.brightness(p),
        ];
        for (final e in inward) {
          expect(
            (e - middle).abs(),
            lessThan(middle * 0.08 + 3),
            reason: '$name inward $inward $middle',
          );
        }
      }
    });

    test(
      'a panel, glass and the frame in one colour are three things',
      () async {
        const colour = 0xFF8C9094;
        final base0 = frame.drawn(1800, 1200, divided: true, profileMm: 60);
        final ids = [for (final s in base0.sections) s.id];
        final d = Infill.fill(
          base0.copyWith(
            frame: base0.frame!.copyWith(
              finish: base0.frame!.finish.copyWith(colour: colour),
            ),
          ),
          {
            ids.first: const Finish(
              colour: colour,
              material: MaterialKind.panel,
            ),
            ids.last: const Finish(
              colour: colour,
              material: MaterialKind.clearGlass,
            ),
          },
        );
        final picture = await glass.render(d);
        final panel = picture.at(_middle(_face(picture, ids.first)));
        final pane = picture.at(_middle(_face(picture, ids.last)));
        expect(glass.apart(panel, pane), greaterThan(20));
        // The frame and a panel of the same colour, turned the same way to
        // the same light, are the same colour on their faces — as two grey
        // surfaces are — and a lighting that made them otherwise would be
        // inventing a difference. They are told apart by their form: across
        // a member of the frame the light changes, face to sightline to
        // reveal — its profile — where across the middle of the panel it is
        // one even face.
        // Where a corner of the frame is on the screen: the one nearest the
        // viewer at that point of the drawing.
        Offset corner(Vec2 at) {
          Offset? best;
          var front = -double.infinity;
          for (final f in picture.faces) {
            if (f.elementId != d.frame!.id) continue;
            for (var k = 0; k < f.corners.length; k++) {
              final c = f.source.corners[k];
              if ((c.x - at.x).abs() < 1e-6 &&
                  (c.y - at.y).abs() < 1e-6 &&
                  c.z > front) {
                front = c.z;
                best = picture.place(f.corners[k]);
              }
            }
          }
          return best!;
        }

        final outline = d.frame!.outline, inner = d.frame!.innerOutline;
        // Half way up the left jamb, from its outer edge to the daylight.
        final from = Offset.lerp(
          corner(Vec2(outline.left, outline.top)),
          corner(Vec2(outline.left, outline.bottom)),
          0.5,
        )!;
        final to = Offset.lerp(
          corner(Vec2(inner.left, inner.top)),
          corner(Vec2(inner.left, inner.bottom)),
          0.5,
        )!;
        final across = [
          for (var t = 0.08; t <= 0.92; t += 0.06)
            picture.brightness(Offset.lerp(from, to, t)!),
        ];
        expect(glass.spread(across), greaterThan(8), reason: '$across');
        final panelFace = _face(picture, ids.first);
        final even = [
          for (var t = 0.35; t <= 0.65; t += 0.05)
            picture.brightness(Offset.lerp(panelFace[0], panelFace[2], t)!),
        ];
        expect(glass.spread(even), lessThan(4), reason: '$even');
      },
    );
  });
}

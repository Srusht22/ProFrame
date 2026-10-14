import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/opening_leaf.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;

// Phase 13 of the CAD and 3D work: what each part is made of, on the
// drawing, as a drawing shows it.
//
// Three things must be told apart at a glance, and nothing may be noisy:
//
// - **The frame** — and a sash, a mullion, a transom — is structure: one
//   flat light grey band under its heavy outline, whatever it is made of.
// - **Glass** is the sheet's pale glass tint and the two strokes across a
//   corner; frosted glass is stippled and tinted glass a controlled shade
//   darker. Never a heavy fill.
// - **A panel** is fine forty-five degree hatching on the paper.
//
// **A drawing names a colour; it does not paint it.** A panel's colour is
// written on it — PANEL · BROWN — and never flooded over it, so a brown
// door and a white one are one drawing but for that word. No colour on the
// sheet is chosen to tell parts apart: the fills are grey, paper, and the
// glass tint.

const _size = Size(900, 720);

const _materials = CadLayers(
  grid: false,
  dimensions: false,
  annotations: false,
  openings: false,
);

ViewTransform _viewOf(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _size,
  padding: const EdgeInsets.all(40),
);

Future<Uint8List> _paint(
  Design d, {
  CadColours ink = Cad.paper,
  CadLayers layers = _materials,
}) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: d,
    view: _viewOf(d),
    layers: layers,
    ink: ink,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

int _argb(Uint8List rgba, int x, int y) {
  final i = (y * _size.width.round() + x) * 4;
  return 0xFF000000 | rgba[i] << 16 | rgba[i + 1] << 8 | rgba[i + 2];
}

/// The colours in a small square round [at], and how often each is seen.
Map<int, int> _patch(Uint8List rgba, Offset at, {int half = 8}) {
  final seen = <int, int>{};
  for (var y = at.dy.round() - half; y <= at.dy.round() + half; y++) {
    for (var x = at.dx.round() - half; x <= at.dx.round() + half; x++) {
      final c = _argb(rgba, x, y);
      seen[c] = (seen[c] ?? 0) + 1;
    }
  }
  return seen;
}

int _modal(Map<int, int> patch) =>
    patch.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

bool _near(int a, Color b, {int by = 2}) {
  for (final (shift, channel) in [(16, b.r), (8, b.g), (0, b.b)]) {
    if (((a >> shift & 0xFF) - (channel * 255).round()).abs() > by) {
      return false;
    }
  }
  return true;
}

int _chroma(Color c) {
  final v = [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];
  return v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);
}

/// Where to look at each kind of part on [d]: a point on the frame's
/// jamb clear of its sightlines, one inside the clear fixed light, and one
/// inside the panel.
({Offset frame, Offset glass, Offset panel, Offset bar}) _where(Design d) {
  final view = _viewOf(d);
  final outline = d.frame!.outline;
  final profile = d.frame!.profileMm;
  final sightlines = DesignGeometry.of(d).frameProfile!.sightlines;
  // Across the right jamb, the widest stretch between the sightlines.
  final marks = [0.0, ...sightlines, profile]..sort();
  var at = 0.0, widest = 0.0;
  for (var i = 1; i < marks.length; i++) {
    if (marks[i] - marks[i - 1] > widest) {
      widest = marks[i] - marks[i - 1];
      at = (marks[i] + marks[i - 1]) / 2;
    }
  }
  final frame = view.toScreen(
    Vec2(outline.right - at, outline.top + outline.height * 0.7),
  );

  Polygon fill(String id) => OpeningLeaf.fillOf(d, d.sectionById(id)!);
  final light = d.topLevelSections.firstWhere((s) => d.openingOf(s.id) == null);
  final glass = fill(light.id);
  final opening = d.openings.single.sectionId;
  final panes = d.childSectionsOf(opening)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final panel = fill(panes.last.id);
  final bar = d.dividers.firstWhere((b) => b.parentId == null);
  final body = DesignGeometry.of(d).barBody(bar);
  return (
    frame: frame,
    glass: view.toScreen(
      Vec2(glass.centroid.x, glass.top + glass.height * 0.8),
    ),
    panel: view.toScreen(
      Vec2(panel.centroid.x, panel.top + panel.height * 0.8),
    ),
    bar: view.toScreen(
      Vec2(body.centroid.x, outline.top + outline.height * 0.7),
    ),
  );
}

void main() {
  final door = base.door();

  group('frame, glass and panel are three things on the sheet', () {
    for (final (name, ink) in [('paper', Cad.paper), ('night', Cad.night)]) {
      test('on $name: each by its own convention', () async {
        final rgba = await _paint(door, ink: ink);
        final at = _where(door);

        final frame = _patch(rgba, at.frame, half: 2);
        final glass = _patch(rgba, at.glass);
        final panel = _patch(rgba, at.panel);

        // The frame: the flat structural tone.
        expect(
          _near(_modal(frame), ink.structure),
          isTrue,
          reason: _modal(frame).toRadixString(16),
        );
        // Glass: the sheet's glass tint, evenly.
        expect(
          _near(_modal(glass), ink.glass),
          isTrue,
          reason: _modal(glass).toRadixString(16),
        );
        expect(glass[_modal(glass)]! / 289, greaterThan(0.9));
        // A panel: the paper, with hatching across it — some of the patch
        // lines, most of it paper.
        expect(
          _near(_modal(panel), ink.sheet),
          isTrue,
          reason: _modal(panel).toRadixString(16),
        );
        final lined = 1 - panel[_modal(panel)]! / 289;
        expect(lined, inInclusiveRange(0.05, 0.4), reason: 'hatched: $lined');

        // And the three are not one another.
        expect(_modal(frame), isNot(_modal(glass)));
        expect(_modal(frame), isNot(_modal(panel)));
        expect(_modal(glass), isNot(_modal(panel)));
      });
    }

    test('a mullion is the frame\'s structure, not an infill', () async {
      final rgba = await _paint(door);
      final at = _where(door);
      expect(
        _near(
          _argb(rgba, at.bar.dx.round(), at.bar.dy.round()),
          Cad.paper.structure,
        ),
        isTrue,
      );
    });
  });

  group('quiet, and nothing chosen to be bright', () {
    test(
      'glass is never a heavy fill, and tinted only as much as it is',
      () async {
        for (final look in GlassLook.values) {
          final d = Infill.fill(door, {
            door.topLevelSections
                    .firstWhere((s) => door.openingOf(s.id) == null)
                    .id:
                look.finish,
          });
          final rgba = await _paint(d);
          final c = _modal(_patch(rgba, _where(d).glass));
          final luminance = Color(c).computeLuminance();
          expect(luminance, greaterThan(0.45), reason: look.label);
          if (look == GlassLook.clear) {
            expect(luminance, greaterThan(0.8));
          }
        }
      },
    );

    test('every fill is grey, paper or the sheet\'s glass tint', () {
      for (final ink in [Cad.paper, Cad.night]) {
        expect(_chroma(ink.structure), lessThanOrEqualTo(6));
        expect(_chroma(ink.sheet), lessThanOrEqualTo(4));
        expect(_chroma(ink.hatch), lessThanOrEqualTo(10));
        // The glass tint is a pale cool grey, not a colour.
        expect(_chroma(ink.glass), lessThanOrEqualTo(24));
      }
      expect(Cad.paper.structure.computeLuminance(), greaterThan(0.7));
      expect(Cad.paper.glass.computeLuminance(), greaterThan(0.8));
    });
  });

  test(
    'a panel\'s colour is named on the drawing, never painted on it',
    () async {
      final opening = door.openings.single.sectionId;
      final panes = door.childSectionsOf(opening)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      Design panel(PanelColour colour) =>
          Infill.fill(door, {panes.last.id: colour.finish});

      final pictures = [
        for (final colour in PanelColour.values) await _paint(panel(colour)),
      ];
      for (final other in pictures.skip(1)) {
        expect(other, pictures.first, reason: 'the same drawing');
      }
      // With its lettering, each says which it is: PANEL · GREY and PANEL ·
      // BROWN. (Two names of one length would letter alike in the test's
      // own typeface, whose every letter is the same box.)
      const lettered = CadLayers(grid: false, dimensions: false);
      final brown = await _paint(panel(PanelColour.brown), layers: lettered);
      final grey = await _paint(panel(PanelColour.grey), layers: lettered);
      expect(brown, isNot(grey));
    },
  );

  test('drawing the materials moves nothing', () async {
    final before = door.toJson().toString();
    await _paint(door);
    await _paint(door, ink: Cad.night);
    expect(door.toJson().toString(), before);
  });
}

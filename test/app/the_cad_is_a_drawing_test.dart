import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/cad_style.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/dimension_layout.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';

import '../domain/rendering_geometry_baseline_test.dart' as base;
import '../domain/the_frame_is_a_real_profile_test.dart' as frame;

// Phase 12 of the CAD and 3D work: the technical drawing drawn as one.
//
// Line weight carries the rank of a line, each rank a clear step from the
// next as a draughtsman's pens are: the outside of the frame heaviest; the
// frame's daylight edge, a leaf, a mullion or transom next; a glazing bar
// inside a section; where glass or a panel meets what holds it; dimensions
// and the swing of a leaf; and hatching, sightlines and the grid finest.
// The inks are graphite, neutral, and one slate for everything that
// measures; the squared paper is quieter than any line on it. A figure is
// written just above its dimension line — to the left of one running down,
// read up the page — masked by the paper round its letters rather than
// boxed, so the line runs on under it; and its tap target is where it is
// written.
//
// **Nothing here changes a figure.** Every figure is the saved geometry
// written in centimetres to the millimetre: a design 964.3 cm across is
// 964.3 cm on the drawing, never 964 and never 1000.

const _size = Size(900, 720);

ViewTransform _viewOf(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _size,
  padding: const EdgeInsets.fromLTRB(120, 20, 40, 130),
);

Future<Uint8List> _paint(
  Design d, {
  CadLayers layers = const CadLayers(),
}) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: d,
    view: _viewOf(d),
    layers: layers,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

List<int> _at(Uint8List rgba, int x, int y) {
  final i = (y * _size.width.round() + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2]];
}

double _dark(List<int> c) =>
    1 - (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// How far from grey [c] is, in levels of its most different channel.
int _chroma(Color c) {
  final r = (c.r * 255).round(), g = (c.g * 255).round();
  final b = (c.b * 255).round();
  final hi = [r, g, b].reduce((a, v) => a > v ? a : v);
  final lo = [r, g, b].reduce((a, v) => a < v ? a : v);
  return hi - lo;
}

void main() {
  group('line weight is the rank of a line', () {
    test('each rank a clear step from the next', () {
      final ranks = [
        Cad.outline,
        Cad.profile,
        Cad.glazingBar,
        Cad.detail,
        Cad.annotation,
        Cad.hairline,
      ];
      for (var i = 1; i < ranks.length; i++) {
        expect(
          ranks[i - 1] / ranks[i],
          greaterThanOrEqualTo(1.15),
          reason: 'rank $i',
        );
      }
      // The outside of the frame is the heaviest line of all, and a
      // mullion is drawn as the frame's own inner edge is.
      expect(Cad.outline / Cad.profile, greaterThan(1.6));
      expect(Cad.bar, Cad.profile);
    });

    test('on the sheet: the frame\'s outside heaviest, its daylight edge '
        'next, its sightline and the bead finest', () async {
      // Across the left side of a window at mid-height, with nothing on the
      // sheet but the lines: each run of ink, left to right, and how wide.
      final d = frame.drawn(1800, 1200, profileMm: 80);
      final rgba = await _paint(
        d,
        layers: const CadLayers(
          grid: false,
          dimensions: false,
          hatching: false,
          annotations: false,
          openings: false,
        ),
      );
      final view = _viewOf(d);
      final outline = d.frame!.outline;
      final y = view
          .toScreen(Vec2(0, (outline.top + outline.bottom) / 2))
          .dy
          .round();
      final from = view.toScreen(Vec2(outline.left, 0)).dx.round() - 4;
      final to = view.toScreen(Vec2(outline.left + 160, 0)).dx.round();
      final runs = <double>[];
      var ink = 0.0;
      for (var x = from; x <= to; x++) {
        final dark = _dark(_at(rgba, x, y));
        if (dark > 0.08) {
          ink += dark;
        } else if (ink > 0) {
          runs.add(ink);
          ink = 0;
        }
      }
      if (ink > 0) runs.add(ink);
      // Outside in: the frame's outside, the sightline where its face turns,
      // the daylight edge — the glass stops on it — and the bead's line.
      expect(runs.length, 4, reason: '$runs');
      final [outside, sightline, daylight, bead] = runs;
      expect(outside, greaterThan(daylight * 1.5), reason: '$runs');
      expect(daylight, greaterThan(sightline * 3), reason: '$runs');
      expect(daylight, greaterThan(bead * 3), reason: '$runs');
    });
  });

  group('the inks', () {
    test('graphite on paper: every line of the drawing is grey', () {
      const c = Cad.paper;
      for (final ink in [c.heavy, c.medium, c.light, c.hidden, c.hatch]) {
        expect(_chroma(ink), lessThanOrEqualTo(10), reason: '$ink');
      }
      for (final ink in [c.sheet, c.grid, c.gridStrong]) {
        expect(_chroma(ink), lessThanOrEqualTo(4), reason: '$ink');
      }
    });

    test('the squared paper is quieter than any line drawn on it', () {
      for (final c in [Cad.paper, Cad.night]) {
        final grid = _contrast(c.gridStrong, c.sheet);
        for (final line in [c.heavy, c.medium, c.light, c.hatch, c.dimension]) {
          expect(_contrast(line, c.sheet), greaterThan(grid * 1.5));
        }
      }
    });

    test('everything that measures is in one ink, clear of the geometry', () {
      for (final c in [Cad.paper, Cad.night]) {
        expect(_contrast(c.dimension, c.sheet), greaterThanOrEqualTo(4.5));
        expect(c.dimension, isNot(c.heavy));
        expect(c.dimension, isNot(c.selection));
      }
    });
  });

  group('every figure is the saved geometry', () {
    test('964.3 cm across is written 964.3 cm, not 964 and not 1000', () {
      final d = frame.drawn(9643, 1200);
      final outline = d.frame!.outline;
      expect(outline.width, 9643);
      final overall = DimensionChains.of(d)
          .where((c) => c.axis == DimensionAxis.horizontal)
          .expand((c) => c.runs)
          .where((r) => r.of == ChainRunOf.overall)
          .single;
      expect(overall.valueMm, outline.width);
      expect(Measurements.figure(overall.valueMm, known: true), '964.3 cm');
      expect(Units.label(9640), '964 cm');
    });

    test('what can be typed over reads exactly what the geometry is', () {
      for (final d in [base.door(), base.window(), base.sliding()]) {
        final handles = CadDimensions.of(d, _viewOf(d), const CadLayers());
        expect(handles, isNotEmpty);
        for (final h in handles) {
          switch (h.of) {
            case DimensionOf.overallWidth:
              expect(h.valueMm, d.frame!.outline.width);
            case DimensionOf.overallHeight:
              expect(h.valueMm, d.frame!.outline.height);
            case DimensionOf.sectionWidth || DimensionOf.sectionHeight:
              expect(h.elementId, isNotNull);
            case DimensionOf.drawn:
              break;
            case DimensionOf.side:
              expect(h.elementId, startsWith('side:'));
          }
        }
      }
    });

    test('a chain\'s figure is written where it can be tapped, just off its '
        'line, and the line runs on under it', () async {
      final d = base.window();
      final view = _viewOf(d);
      final rgba = await _paint(d, layers: const CadLayers(grid: false));
      final handles = CadDimensions.of(d, view, const CadLayers());
      final placed = DimensionLayout.of(d, view).figures;
      expect(placed.length, greaterThan(2));
      for (final figure in placed) {
        expect(
          handles.any((h) => h.rect.contains(figure.figure)),
          isTrue,
          reason: 'tap target for ${figure.run}',
        );
        // Right under the middle of the figure's run the dimension line is
        // still there: nothing boxes the figure out of it.
        final middle = (figure.from + figure.to) / 2;
        // A fine line may fall between two pixels: the darker of those
        // within one of the middle.
        var darkest = 0.0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final c = _at(rgba, middle.dx.round() + dx, middle.dy.round() + dy);
            if (_dark(c) > darkest) darkest = _dark(c);
          }
        }
        expect(darkest, greaterThan(0.2), reason: 'line under ${figure.run}');
        // And the figure stands off it, not on it.
        expect(figure.rect.contains(middle), isFalse);
      }
    });
  });

  test('drawing it changes nothing in the design', () async {
    final d = base.door();
    final before = d.toJson().toString();
    await _paint(d);
    expect(d.toJson().toString(), before);
  });
}

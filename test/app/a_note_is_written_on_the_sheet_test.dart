import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';

// **A note is written on the sheet, so it is the sheet's size and not the
// screen's.** Zoomed out, the user's drawing shrank to a postage stamp and
// their note "naw bo naw 50 pani" stayed the size it was, sprawling over it:
// the drawing held a note at eleven pixels at least, and the technical
// drawing at one size whatever the zoom.
//
// Held here on the pixels of both views. The note is written in a red that
// nothing else in either drawing uses, so its ink can be counted on its own.

const _size = Size(900, 900);
const _red = 0xFFE00000;
const _at = Vec2(1000, 300);

final _design = Design(
  id: 'd',
  name: 'test',
  kind: DesignKind.window,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  frame: FrameElement(id: 'f', outline: Polygon.rect(0, 0, 2000, 2000)),
  texts: const [
    TextElement(
      id: 'note',
      text: 'naw bo naw 50 pani',
      at: _at,
      sizeMm: 90,
      colour: _red,
    ),
  ],
);

ViewTransform zoomed(double scale) =>
    ViewTransform(scale: scale, origin: const Offset(20, 20));

Future<Uint8List> rgba(void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The note's ink: how many pixels, and how far across it runs.
({int count, int left, int right}) redInk(Uint8List pixels) {
  var count = 0;
  var left = 1 << 30;
  var right = -1;
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
    if (r > 150 && g < 90 && b < 90) {
      count++;
      final x = (i ~/ 4) % _size.width.round();
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  return (count: count, left: left, right: right);
}

Future<Uint8List> cad(ViewTransform view) => rgba(
  (canvas) => CadPainter(
    design: _design,
    view: view,
    layers: const CadLayers(),
  ).paint(canvas, _size),
);

Future<Uint8List> sheet(ViewTransform view) => rgba(
  (canvas) => DesignPainter(design: _design, view: view).paint(canvas, _size),
);

/// Where each view hangs a note on its point: the drawing centres it there,
/// and the technical drawing starts it there beside a dot, as a drafted note
/// does. Either way the point is the one the user put it at.
final _anchor = <String, double Function(({int count, int left, int right}))>{
  'the drawing': (ink) => (ink.left + ink.right) / 2,
  'the technical drawing': (ink) => ink.left.toDouble(),
};

void main() {
  final views = {'the drawing': sheet, 'the technical drawing': cad};

  for (final entry in views.entries) {
    group('in ${entry.key}', () {
      test('zooming out makes the note smaller with everything else', () async {
        final close = redInk(await entry.value(zoomed(0.4)));
        final far = redInk(await entry.value(zoomed(0.1)));

        expect(close.count, greaterThan(0), reason: 'the note is drawn');
        // A quarter of the zoom is a sixteenth of the area; allow a lot for
        // the way small type is rasterised, and still refuse a note that
        // stays the size it was.
        expect(far.count, lessThan(close.count / 4));
      });

      test('it stays at the point it was put', () async {
        for (final scale in [0.4, 0.2]) {
          final view = zoomed(scale);
          final ink = redInk(await entry.value(view));
          expect(
            _anchor[entry.key]!(ink),
            closeTo(view.toScreen(_at).dx, 8),
            reason: 'at ${scale}x the note starts where it was written',
          );
        }
      });
    });
  }

  test('both views give the note the same size', () {
    // One rule, in `ViewTransform.letteringFor`, read by both painters.
    for (final scale in [0.05, 0.4, 2.0]) {
      final view = zoomed(scale);
      expect(view.letteringFor(90), closeTo(view.lengthToScreen(90) / 2, 1e-9));
    }
    expect(
      zoomed(0.01).letteringFor(90),
      lessThan(1),
      reason: 'no floor: far enough out, a note is too small to read',
    );
  });
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The elevation is of one face, and which face comes from the kind.
//
// A door is drawn from outside, so its hinges are round the back: hidden
// detail, dashed, because somebody still has to fit them. A window is drawn
// from inside, where its hinges are, so they are solid.
//
// Held on the picture itself rather than on the model behind it, because
// "it is drawn differently" is the claim, and only the pixels can say so.

const _size = Size(900, 640);

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design leaf(DesignKind kind) => SketchInterpreter.interpret(Design(
      id: 'd',
      name: kind.label,
      kind: kind,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(900, 0), Vec2(900, 2000)]),
        pen('mark', const [Vec2(560, 900), Vec2(700, 1000), Vec2(560, 1100)]),
      ]),
    )).design;

Future<Uint8List> pixels(Design design) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: design,
    view: ViewTransform.fit(design.frame!.outline, _size,
        padding: const EdgeInsets.all(40)),
    layers: const CadLayers(),
  ).paint(Canvas(recorder), _size);
  final image = await recorder
      .endRecording()
      .toImage(_size.width.round(), _size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  test('the same design paints the same picture every time', () async {
    expect(await pixels(leaf(DesignKind.door)),
        await pixels(leaf(DesignKind.door)));
    expect(await pixels(leaf(DesignKind.window)),
        await pixels(leaf(DesignKind.window)));
  });

  test('a door and a window are different pictures', () async {
    // Same strokes, same geometry, same hinges in the same places — and a
    // different drawing, because one of them is drawn from the other side.
    expect(await pixels(leaf(DesignKind.door)),
        isNot(await pixels(leaf(DesignKind.window))));
  });

  test('and the difference is the ironmongery, and nothing else', () async {
    // Take the ironmongery off both and the two are the same picture again.
    // The kind decides which side of the leaf the hinges are on and how high
    // the handle goes; if anything *else* in the drawing had started
    // depending on it, this is where it would show.
    Design bare(Design design) => design.copyWith(hardware: const []);

    expect(
      await pixels(bare(leaf(DesignKind.door))),
      await pixels(bare(leaf(DesignKind.window))),
    );
  });

  test('a door still shows its hinges — as hidden detail, not as nothing',
      () async {
    // Drawn dashed is not the same as not drawn: the fitter needs to know
    // they are there. So a door with hinges and a door without them are
    // different pictures.
    final design = leaf(DesignKind.door);
    expect(design.hardware.any((p) => p.kind == HardwareKind.hinge), isTrue);

    final stripped = design.copyWith(hardware: [
      for (final piece in design.hardware)
        if (piece.kind != HardwareKind.hinge) piece,
    ]);
    expect(await pixels(design), isNot(await pixels(stripped)));
  });
}

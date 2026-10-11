import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'geometry_normalizer_test.dart' show pen;

// Design category → geometry policy → normalisation behaviour.
//
// One geometry engine serves every category. A category's whole say over
// geometry is its policy — normalise or preserve — and every part of the
// reading that differs by category asks that, and nothing else. No part of
// the geometry asks *is this a door* or *is this angled* for itself.

/// A 120 × 150 cm outline with its right side drawn 4° out of plumb.
List<Stroke> leaning() => [
  pen('outline', const [
    Vec2(0, 0),
    Vec2(1200, 0),
    Vec2(1305, 1500),
    Vec2(0, 1500),
    Vec2(0, 0),
  ]),
];

void main() {
  test('the four standard categories normalise, and the angled one '
      'preserves — as does a category this version does not know, which '
      'is never given a standard category\'s squaring', () {
    expect(
      {for (final k in DesignKind.values) k: k.geometryPolicy},
      {
        DesignKind.door: GeometryPolicy.normalize,
        DesignKind.window: GeometryPolicy.normalize,
        DesignKind.sliding: GeometryPolicy.normalize,
        DesignKind.both: GeometryPolicy.normalize,
        DesignKind.angled: GeometryPolicy.preserve,
        DesignKind.unsupported: GeometryPolicy.preserve,
      },
    );
  });

  test('the normaliser and the reading follow the policy and nothing '
      'else', () {
    for (final kind in DesignKind.values) {
      final policy = kind.geometryPolicy;
      expect(
        NormalizationContext(kind: kind).isStandard,
        policy == GeometryPolicy.normalize,
        reason: kind.name,
      );
      final read = SketchInterpreter.interpret(
        Design.empty(
          id: 'd',
          kind: kind,
        ).copyWith(sketch: Sketch(strokes: leaning())),
      );
      final outline = read.design.frame!.outline;
      final square = outline.edges.every(
        (e) => e.a.x == e.b.x || e.a.y == e.b.y,
      );
      switch (policy) {
        case GeometryPolicy.normalize:
          expect(square, isTrue, reason: '${kind.name}: squared');
          expect(read.noticeablyCorrected, {'outline'}, reason: kind.name);
        case GeometryPolicy.preserve:
          expect(square, isFalse, reason: '${kind.name}: kept');
          expect(read.noticeablyCorrected, isEmpty);
          expect(read.problems, isEmpty, reason: 'checked, and valid');
      }
    }
  });

  test('no geometry code asks for itself which category a design is', () {
    // The category reaches the geometry through its policy alone. The
    // leaf's own kind (a door's lever, a window's fastener) is a different
    // question and is asked of the leaf; what the screens say in words is
    // the screens' business.
    final asking = RegExp(r'\.kind\s*[!=]=\s*DesignKind\.angled');
    final offenders = [
      for (final file in Directory('lib/domain').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (asking.hasMatch(line)) '${file.path}:${i + 1}: $line',
    ];
    expect(offenders, isEmpty);
  });
}

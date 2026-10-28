import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/opening_symbol.dart';
import 'package:proframe/domain/sketch/stroke.dart';

var _n = 0;

/// A stroke drawn through the given points by an unsteady hand.
Stroke drawn(List<Vec2> through, {double wobble = 5}) {
  final random = math.Random(_n + 11);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 14; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 14);
      samples.add(StrokeSample(Vec2(
        at.x + (random.nextDouble() - 0.5) * wobble * 2,
        at.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples);
}

void main() {
  setUp(() => _n = 0);

  group('reading the two symbols', () {
    test('a > is read as pointing right', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 0),
        Vec2(300, 260),
        Vec2(0, 520),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsRight);
      expect(symbol.glyph, '>');
      expect(symbol.apex.x, closeTo(300, 30));
    });

    test('a < is read as pointing left', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(300, 0),
        Vec2(0, 260),
        Vec2(300, 520),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsLeft);
      expect(symbol.glyph, '<');
    });

    test('> means hinged left, opening from the right', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 0),
        Vec2(260, 220),
        Vec2(0, 440),
      ]))!;
      expect(symbol.mechanism, OpeningMechanism.hingedLeft);
      expect(symbol.meaning, contains('from the right'));
    });

    test('< means hinged right, opening from the left', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(260, 0),
        Vec2(0, 220),
        Vec2(260, 440),
      ]))!;
      expect(symbol.mechanism, OpeningMechanism.hingedRight);
      expect(symbol.meaning, contains('from the left'));
    });

    test('a symbol drawn the other way round reads the same', () {
      // Bottom arm first, then up to the apex, then the top arm.
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 520),
        Vec2(300, 260),
        Vec2(0, 0),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsRight);
    });

    test('a wide, shallow chevron is still read', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 0),
        Vec2(180, 300),
        Vec2(0, 600),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsRight);
    });
  });

  group('the two upright symbols', () {
    test('a v is read as pointing down', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 0),
        Vec2(260, 440),
        Vec2(520, 0),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsDown);
      expect(symbol.glyph, 'v');
    });

    test('a ^ is read as pointing up', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 440),
        Vec2(260, 0),
        Vec2(520, 440),
      ]));
      expect(symbol, isNotNull);
      expect(symbol!.direction, SymbolDirection.pointsUp);
      expect(symbol.glyph, '^');
    });

    test('^ hinges at the bottom, because the top is what moves', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 400),
        Vec2(240, 0),
        Vec2(480, 400),
      ]))!;
      expect(symbol.mechanism, OpeningMechanism.bottomHung);
      expect(symbol.meaning, contains('at the bottom'));
    });

    test('v hinges at the top, because the bottom is what moves', () {
      final symbol = OpeningSymbolReader.read(drawn(const [
        Vec2(0, 0),
        Vec2(240, 400),
        Vec2(480, 0),
      ]))!;
      expect(symbol.mechanism, OpeningMechanism.topHung);
      expect(symbol.meaning, contains('at the top'));
    });

    test('every mark and its mechanism agree both ways round', () {
      for (final direction in SymbolDirection.values) {
        expect(direction.mechanism.glyph, direction.glyph);
        expect(
          SymbolDirection.forMechanism(direction.mechanism),
          direction,
        );
      }
    });
  });

  group('what is not one of the four symbols', () {
    test('a straight line is not', () {
      expect(
        OpeningSymbolReader.read(drawn(const [Vec2(0, 0), Vec2(600, 0)])),
        isNull,
      );
    });

    test('a diagonal line is not', () {
      expect(
        OpeningSymbolReader.read(drawn(const [Vec2(0, 0), Vec2(500, 500)])),
        isNull,
      );
    });

    test('a box is not', () {
      expect(
        OpeningSymbolReader.read(drawn(const [
          Vec2(0, 0),
          Vec2(500, 0),
          Vec2(500, 500),
          Vec2(0, 500),
          Vec2(0, 0),
        ])),
        isNull,
      );
    });

    test('a corner is not — one arm is far longer than the other', () {
      expect(
        OpeningSymbolReader.read(drawn(const [
          Vec2(0, 0),
          Vec2(600, 0),
          Vec2(600, 60),
        ])),
        isNull,
      );
    });

    test('a mark too small to be deliberate is not', () {
      expect(
        OpeningSymbolReader.read(drawn(const [
          Vec2(0, 0),
          Vec2(12, 10),
          Vec2(0, 20),
        ], wobble: 0)),
        isNull,
      );
    });

    test('a zigzag with more than one apex is not', () {
      expect(
        OpeningSymbolReader.read(drawn(const [
          Vec2(0, 0),
          Vec2(300, 200),
          Vec2(0, 400),
          Vec2(300, 600),
        ])),
        isNull,
      );
    });
  });
}

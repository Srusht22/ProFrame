import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utils/unit_converter.dart';

void main() {
  group('LengthUnit conversions', () {
    test('mm is the identity unit', () {
      expect(LengthUnit.mm.toMm(1000), 1000);
      expect(LengthUnit.mm.fromMm(1000), 1000);
    });

    test('cm <-> mm', () {
      expect(LengthUnit.cm.toMm(100), 1000);
      expect(LengthUnit.cm.fromMm(1000), 100);
    });

    test('m <-> mm', () {
      expect(LengthUnit.m.toMm(1.2), closeTo(1200, 1e-9));
      expect(LengthUnit.m.fromMm(1200), closeTo(1.2, 1e-9));
    });

    test('inch <-> mm', () {
      expect(LengthUnit.inch.toMm(1), closeTo(25.4, 1e-9));
      expect(LengthUnit.inch.fromMm(25.4), closeTo(1, 1e-9));
    });

    test('round-trips through any unit without drift', () {
      const originalMm = 1234.5;
      for (final unit in LengthUnit.values) {
        final converted = unit.fromMm(originalMm);
        final backToMm = unit.toMm(converted);
        expect(backToMm, closeTo(originalMm, 1e-6));
      }
    });
  });

  group('AreaConverter', () {
    test('computes m² from mm dimensions', () {
      expect(AreaConverter.squareMetersFromMm(1000, 2000), closeTo(2.0, 1e-9));
    });

    test('computes meters from a single mm length', () {
      expect(AreaConverter.metersFromMm(1500), closeTo(1.5, 1e-9));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/units/length_unit.dart';
import 'package:proframe/domain/measurement.dart';

void main() {
  group('a length remembers where it came from', () {
    test('a confirmed value is trustworthy', () {
      const value = Measurement.confirmed(1200);

      expect(value.millimetres, 1200);
      expect(value.isConfirmed, isTrue);
      expect(value.isTrustworthy, isTrue);
    });

    test('a value scaled from the drawing is never trustworthy', () {
      const value = Measurement.estimated(1200);

      expect(value.isConfirmed, isFalse);
      expect(value.isTrustworthy, isFalse);
      expect(value.explanation, contains('Not confirmed'));
    });

    test('a derived value is as good as its inputs', () {
      const value = Measurement.derived(400, explanation: 'The rest of the width.');

      expect(value.isConfirmed, isFalse);
      expect(value.isTrustworthy, isTrue);
      expect(value.explanation, 'The rest of the width.');
    });

    test('an estimate and a confirmed value of the same size are not equal', () {
      // If these compared equal, an estimate could be substituted for a
      // confirmed dimension anywhere the model compares values.
      expect(
        const Measurement.estimated(1200) == const Measurement.confirmed(1200),
        isFalse,
      );
    });

    test('confirming takes a new number rather than blessing the guess', () {
      const estimate = Measurement.estimated(1187);
      final confirmed = estimate.confirmedAs(1200);

      expect(confirmed.millimetres, 1200);
      expect(confirmed.isConfirmed, isTrue);
      // The estimate is untouched; nothing was promoted in place.
      expect(estimate.millimetres, 1187);
      expect(estimate.isConfirmed, isFalse);
    });
  });

  group('display units', () {
    test('millimetres are what is stored, whatever is shown', () {
      const value = Measurement.confirmed(1200);

      expect(value.millimetres, 1200);
      expect(value.inUnit(LengthUnit.centimetre), 120);
      expect(value.inUnit(LengthUnit.metre), 1.2);
      expect(value.inUnit(LengthUnit.inch), closeTo(47.24, 0.01));
    });

    test('each unit formats to a sensible number of decimals', () {
      expect(LengthUnit.millimetre.format(1200), '1200 mm');
      expect(LengthUnit.centimetre.format(1200), '120.0 cm');
      expect(LengthUnit.metre.format(1200), '1.200 m');
      expect(LengthUnit.inch.format(1200), '47.24 in');
    });

    test('typed text becomes millimetres', () {
      expect(LengthUnit.centimetre.parseToMillimetres('120'), 1200);
      expect(LengthUnit.metre.parseToMillimetres('1.2'), closeTo(1200, 1e-9));
      // A comma decimal separator is what many of these users will type.
      expect(LengthUnit.metre.parseToMillimetres('1,2'), closeTo(1200, 1e-9));
    });

    test('text that is not a number stays unknown rather than becoming zero', () {
      // Defaulting to 0 here would invent a dimension (spec section 2).
      for (final text in ['', '   ', 'abc', '12mm', '--4']) {
        expect(
          LengthUnit.millimetre.parseToMillimetres(text),
          isNull,
          reason: '"$text" must not parse',
        );
      }
    });
  });

  test('a measurement survives a save and reload', () {
    const original = Measurement.derived(830, explanation: 'Equal split of 1660.');
    final restored = Measurement.fromJson(original.toJson());

    expect(restored.millimetres, 830);
    expect(restored.source, MeasurementSource.derived);
    expect(restored.explanation, 'Equal split of 1660.');
  });

  test('a damaged measurement is refused, not rounded to zero', () {
    expect(
      () => Measurement.fromJson({'mm': 'wide', 'source': 'confirmed'}),
      throwsFormatException,
    );
    expect(
      () => Measurement.fromJson({'mm': 100, 'source': 'invented'}),
      throwsFormatException,
    );
  });
}

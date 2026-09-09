import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/dimensions/dimension_resolver.dart';
import 'package:proframe/features/recognition/handwriting_recognizer.dart';
import 'package:proframe/features/recognition/stroke_recognizer.dart';
import 'package:proframe/features/recognition/structure_interpreter.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/primitives.dart';
import 'package:proframe/shared/models/scale_calibration.dart';
import 'package:proframe/shared/models/sketch.dart';

import '../support/sketch_builders.dart';

void main() {
  const recognizer = StrokeRecognizer();
  const interpreter = StructureInterpreter();
  const resolver = DimensionResolver();

  ({double width, double height, ScaleCalibration scale, DimensionResolution full}) resolve(
    Sketch sketch, {
    double? explicitWidth,
  }) {
    final primitives = recognizer.recognizeAll(sketch);
    final structure = interpreter.interpret(primitives, kind: OpeningKind.window);
    final resolution = resolver.resolve(
      structure: structure,
      dimensions: primitives.whereType<DimensionPrimitive>().toList(),
      explicitWidthMm: explicitWidth,
    );
    return (
      width: resolution.width.millimetres,
      height: resolution.height.millimetres,
      scale: resolution.calibration,
      full: resolution,
    );
  }

  group('scale calibration', () {
    test('600 canvas units labelled 1200 mm gives 0.5 units per mm', () {
      final calibration = ScaleCalibration.fromMeasurement(
        sketchUnits: 600,
        millimetres: 1200,
      );

      expect(calibration.pxPerMm, 0.5);
      expect(calibration.toMm(300), 600);
      expect(calibration.toSketchUnits(1000), 500);
      expect(calibration.isCalibrated, isTrue);
    });

    test('an uncalibrated drawing is marked as assumed', () {
      expect(ScaleCalibration.assumed.isCalibrated, isFalse);
    });

    test('a drawn dimension sets the scale for the whole drawing', () {
      final result = resolve(twoPanelWindowSketch());

      expect(result.scale.source, ScaleSource.drawnDimension);
      expect(result.scale.pxPerMm, closeTo(0.5, 0.001));
    });
  });

  group('two ways to give the same measurement', () {
    test('a drawn dimension is used exactly as entered', () {
      final result = resolve(twoPanelWindowSketch());

      expect(result.width, 1200);
      expect(result.height, 800);
      expect(result.full.width.isMeasured, isTrue);
      expect(result.full.fullyMeasured, isTrue);
    });

    test('a typed value overrides the drawing', () {
      final result = resolve(twoPanelWindowSketch(), explicitWidth: 1350);

      expect(result.width, 1350);
      expect(result.full.width.origin, DimensionOrigin.measured);
    });

    test('an unmeasured drawing derives a size and says it is derived', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..dimension(0, -60, 600, -60, 1200))
          .build();

      // Height was never measured — it must be derived from the scale, and
      // flagged as such rather than presented as fact.
      final result = resolve(sketch);
      expect(result.full.height.origin, DimensionOrigin.derivedFromScale);
      expect(result.height, closeTo(800, 1));
      expect(result.full.notes.any((n) => n.contains('worked out')), isTrue);
    });

    test('a dimension line with no value is reported, not guessed', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..twoPoint(SketchTool.dimension, 0, -60, 600, -60))
          .build();

      final primitives = recognizer.recognizeAll(sketch);
      final structure = interpreter.interpret(primitives, kind: OpeningKind.window);
      final resolution = resolver.resolve(
        structure: structure,
        dimensions: primitives.whereType<DimensionPrimitive>().toList(),
      );

      expect(resolution.width.isMeasured, isFalse);
      expect(resolution.notes.any((n) => n.contains('needs a measurement')), isTrue);
    });
  });

  group('round-number suggestions are offered, never applied', () {
    test('1098 suggests 1100', () {
      expect(DimensionResolver.roundSuggestion(1098), 1100);
    });

    test('an already round number suggests nothing', () {
      expect(DimensionResolver.roundSuggestion(1200), isNull);
    });

    test('a value far from round suggests nothing', () {
      expect(DimensionResolver.roundSuggestion(1163), isNull);
    });
  });

  group('measurement shorthand', () {
    test('parses the units people actually write', () {
      expect(TypedValueRecognizer.parseMeasurement('1200'), 1200);
      expect(TypedValueRecognizer.parseMeasurement('120cm'), 1200);
      expect(TypedValueRecognizer.parseMeasurement('1.2 m'), 1200);
      expect(TypedValueRecognizer.parseMeasurement('48"'), closeTo(1219.2, 0.01));
      expect(TypedValueRecognizer.parseMeasurement('about a metre'), isNull);
    });

    test('the shipped recogniser is honest about not reading ink', () {
      const recogniser = TypedValueRecognizer();
      expect(recogniser.canReadInk, isFalse);
      expect(recogniser.capabilityDescription, contains('not read automatically'));
    });
  });
}

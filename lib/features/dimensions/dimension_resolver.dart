import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/primitives.dart';
import '../../shared/models/scale_calibration.dart';

/// Where a millimetre value came from. The UI shows this so the user can tell
/// a measured size from a derived one at a glance.
enum DimensionOrigin { measured, derivedFromScale, assumed }

class ResolvedDimension {
  final double millimetres;
  final DimensionOrigin origin;

  /// A tidier value the app offers when the derived number is suspiciously
  /// close to a round one — offered, never applied silently (§10).
  final double? suggestion;

  const ResolvedDimension({
    required this.millimetres,
    required this.origin,
    this.suggestion,
  });

  bool get isMeasured => origin == DimensionOrigin.measured;
  bool get hasSuggestion => suggestion != null;
}

class DimensionResolution {
  final ScaleCalibration calibration;
  final ResolvedDimension width;
  final ResolvedDimension height;
  final List<String> notes;

  const DimensionResolution({
    required this.calibration,
    required this.width,
    required this.height,
    this.notes = const [],
  });

  bool get fullyMeasured => width.isMeasured && height.isMeasured;
}

/// Works out how big the drawing actually is.
///
/// Two routes into the same number (§8): a dimension line drawn across the
/// design with a value typed on it, or a value the user types directly into
/// the editor. Anything not measured is derived from the calibration and
/// clearly labelled — the app never quietly invents a size.
class DimensionResolver {
  /// How close a dimension line has to be to a span, as a fraction of that
  /// span, before it is taken to be measuring it.
  final double matchTolerance;

  const DimensionResolver({this.matchTolerance = 0.18});

  DimensionResolution resolve({
    required GeometryStructure structure,
    required List<DimensionPrimitive> dimensions,
    ScaleCalibration? existing,
    double? explicitWidthMm,
    double? explicitHeightMm,
  }) {
    final notes = <String>[];
    final outline = structure.outline;
    final valued = dimensions.where((d) => d.hasValue).toList();

    // 1. Calibrate from the longest dimension line that carries a value.
    var calibration = existing ?? ScaleCalibration.assumed;
    DimensionPrimitive? calibrationSource;
    for (final d in valued) {
      if (calibrationSource == null || d.pixelLength > calibrationSource.pixelLength) {
        calibrationSource = d;
      }
    }
    if (calibrationSource != null) {
      calibration = ScaleCalibration.fromMeasurement(
        sketchUnits: calibrationSource.pixelLength,
        millimetres: calibrationSource.valueMm!,
      );
      notes.add(
        'Scale set from a ${calibrationSource.valueMm!.round()} mm dimension: '
        '1 mm = ${calibration.pxPerMm.toStringAsFixed(3)} canvas units.',
      );
    }

    // 2. Width — an explicit value wins, then a dimension that spans the
    //    outline horizontally, then the calibration.
    final width = _resolveSpan(
      explicit: explicitWidthMm,
      spanUnits: outline.width,
      axis: DimensionAxis.horizontal,
      dimensions: valued,
      outline: outline,
      calibration: calibration,
    );

    final height = _resolveSpan(
      explicit: explicitHeightMm,
      spanUnits: outline.height,
      axis: DimensionAxis.vertical,
      dimensions: valued,
      outline: outline,
      calibration: calibration,
    );

    if (!width.isMeasured || !height.isMeasured) {
      notes.add(
        'Some sizes were worked out from the drawing scale rather than measured. '
        'Check them before you build.',
      );
    }
    final unvalued = dimensions.length - valued.length;
    if (unvalued > 0) {
      notes.add('$unvalued dimension line${unvalued == 1 ? '' : 's'} '
          'still ${unvalued == 1 ? 'needs' : 'need'} a measurement.');
    }

    return DimensionResolution(
      calibration: calibration,
      width: width,
      height: height,
      notes: notes,
    );
  }

  ResolvedDimension _resolveSpan({
    required double? explicit,
    required double spanUnits,
    required DimensionAxis axis,
    required List<DimensionPrimitive> dimensions,
    required Box2 outline,
    required ScaleCalibration calibration,
  }) {
    if (explicit != null && explicit > 0) {
      return ResolvedDimension(millimetres: explicit, origin: DimensionOrigin.measured);
    }

    DimensionPrimitive? best;
    for (final d in dimensions) {
      if (d.axis != axis) continue;
      final overlaps = axis == DimensionAxis.horizontal
          ? _covers(d.bounds.left, d.bounds.right, outline.left, outline.right, spanUnits)
          : _covers(d.bounds.top, d.bounds.bottom, outline.top, outline.bottom, spanUnits);
      if (!overlaps) continue;
      if (best == null || d.pixelLength > best.pixelLength) best = d;
    }
    if (best != null) {
      return ResolvedDimension(
        millimetres: GeometryMath.roundMm(best.valueMm!),
        origin: DimensionOrigin.measured,
      );
    }

    final derived = GeometryMath.roundMm(calibration.toMm(spanUnits), decimals: 0);
    return ResolvedDimension(
      millimetres: derived,
      origin: calibration.isCalibrated
          ? DimensionOrigin.derivedFromScale
          : DimensionOrigin.assumed,
      suggestion: roundSuggestion(derived),
    );
  }

  bool _covers(double aStart, double aEnd, double bStart, double bEnd, double span) {
    if (span <= 0) return false;
    final tolerance = span * matchTolerance;
    return (aStart - bStart).abs() <= tolerance && (aEnd - bEnd).abs() <= tolerance;
  }

  /// "Did you mean 1100 mm?" — offered when a derived size lands within 2 % of
  /// a round manufacturing figure.
  static double? roundSuggestion(double value) {
    if (value <= 0) return null;
    // Only offer a tidier number when the derived value is *nearly* round —
    // within 1 % and within a quarter of the step. Anything looser starts
    // changing sizes the user did not ask to change.
    for (final step in const [100.0, 50.0, 25.0]) {
      final rounded = (value / step).round() * step;
      if (rounded <= 0) continue;
      final tolerance = math.min(value * 0.01, step * 0.25);
      if ((rounded - value).abs() <= tolerance) {
        return rounded == value ? null : rounded;
      }
    }
    return null;
  }
}

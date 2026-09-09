/// How many sketch units correspond to one millimetre.
///
/// The app never guesses a size out of nowhere. Until the user supplies one
/// real measurement, the calibration is [assumed] and every derived dimension
/// is flagged as inferred (§10, §12).
class ScaleCalibration {
  final double pxPerMm;
  final ScaleSource source;

  const ScaleCalibration({required this.pxPerMm, required this.source});

  /// The starting assumption before any measurement exists: a comfortable
  /// on-screen sketch of roughly 600 units wide standing for a 1200 mm unit.
  static const ScaleCalibration assumed =
      ScaleCalibration(pxPerMm: 0.5, source: ScaleSource.assumed);

  bool get isCalibrated => source != ScaleSource.assumed;

  double toMm(double sketchUnits) => pxPerMm <= 0 ? 0 : sketchUnits / pxPerMm;

  double toSketchUnits(double mm) => mm * pxPerMm;

  /// Builds a calibration from a measured span: "this 600 unit line is
  /// 1200 mm" (§9).
  factory ScaleCalibration.fromMeasurement({
    required double sketchUnits,
    required double millimetres,
    ScaleSource source = ScaleSource.drawnDimension,
  }) {
    if (sketchUnits <= 0 || millimetres <= 0) return assumed;
    return ScaleCalibration(pxPerMm: sketchUnits / millimetres, source: source);
  }

  ScaleCalibration copyWith({double? pxPerMm, ScaleSource? source}) =>
      ScaleCalibration(pxPerMm: pxPerMm ?? this.pxPerMm, source: source ?? this.source);

  Map<String, dynamic> toJson() => {'pxPerMm': pxPerMm, 'source': source.name};

  factory ScaleCalibration.fromJson(Map<String, dynamic> json) => ScaleCalibration(
        pxPerMm: (json['pxPerMm'] as num?)?.toDouble() ?? assumed.pxPerMm,
        source: ScaleSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => ScaleSource.assumed,
        ),
      );

  @override
  String toString() =>
      'ScaleCalibration(${pxPerMm.toStringAsFixed(4)} units/mm, ${source.name})';
}

enum ScaleSource { assumed, drawnDimension, manual }

extension ScaleSourceInfo on ScaleSource {
  String get label => switch (this) {
        ScaleSource.assumed => 'Assumed — no measurement given yet',
        ScaleSource.drawnDimension => 'From a dimension you drew',
        ScaleSource.manual => 'Set by hand',
      };
}

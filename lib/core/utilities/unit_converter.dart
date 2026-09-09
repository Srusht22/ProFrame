/// Length units the UI can display. All internal storage and calculation
/// stays in millimeters ([LengthUnit.mm]) — see spec principle: "always
/// convert internally to standardized units". Conversion only happens at
/// the input/output boundary (text fields, PDF, labels).
enum LengthUnit {
  mm('mm', 1.0),
  cm('cm', 10.0),
  m('m', 1000.0),
  inch('in', 25.4);

  /// Short display label.
  final String label;

  /// Multiply a value expressed in this unit by [factorToMm] to get mm.
  final double factorToMm;

  const LengthUnit(this.label, this.factorToMm);

  double toMm(double value) => value * factorToMm;

  double fromMm(double valueMm) => valueMm / factorToMm;

  /// Formats a millimeter value in this unit with sensible precision.
  String format(double valueMm, {int? decimals}) {
    final converted = fromMm(valueMm);
    final d = decimals ?? (this == LengthUnit.mm ? 0 : 2);
    return '${converted.toStringAsFixed(d)} $label';
  }
}

/// Simple mm <-> m^2 helpers used throughout the pricing/manufacturing
/// engines to avoid repeating the /1,000,000 conversion inline.
class AreaConverter {
  AreaConverter._();

  static double squareMetersFromMm(double widthMm, double heightMm) {
    return (widthMm * heightMm) / 1000000.0;
  }

  static double metersFromMm(double lengthMm) => lengthMm / 1000.0;
}

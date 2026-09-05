enum LengthUnit {
  mm('mm', 'Millimeters', 1.0),
  cm('cm', 'Centimeters', 10.0),
  meter('m', 'Meters', 1000.0),
  inch('in', 'Inches', 25.4);

  final String symbol;
  final String label;
  final double toCanonicalFactor; // 1 unit in this enum = factor mm

  const LengthUnit(this.symbol, this.label, this.toCanonicalFactor);

  /// Converts a value in canonical millimeters into this unit
  double fromCanonicalMm(double mm) {
    return mm / toCanonicalFactor;
  }

  /// Converts a value in this unit into canonical millimeters
  double toCanonicalMm(double value) {
    return value * toCanonicalFactor;
  }

  /// Formats value for display, e.g. "1200 mm", "120.0 cm", "1.20 m", "47.2 in"
  String format(double canonicalMm, {int? decimals}) {
    final val = fromCanonicalMm(canonicalMm);
    final d = decimals ?? (this == LengthUnit.meter ? 2 : (this == LengthUnit.inch ? 1 : 0));
    if (d == 0) {
      return '${val.round()} $symbol';
    }
    return '${val.toStringAsFixed(d)} $symbol';
  }
}

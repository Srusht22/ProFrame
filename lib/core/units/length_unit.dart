import '../i18n/numerals.dart';

/// Display and input units.
///
/// The model stores millimetres and only millimetres (spec section 3D). This
/// enum exists so a user can *type* and *read* a different unit; nothing
/// downstream of the text field ever sees anything but millimetres.
enum LengthUnit {
  millimetre('mm', 1, 0),
  centimetre('cm', 10, 1),
  metre('m', 1000, 3),
  inch('in', 25.4, 2);

  /// How many millimetres one of this unit is.
  final double millimetresPer;

  /// Decimal places to show. Millimetres are whole numbers because that is the
  /// resolution the factory works to; inches need two to stay useful.
  final int decimals;

  final String symbol;

  const LengthUnit(this.symbol, this.millimetresPer, this.decimals);

  double fromMillimetres(double millimetres) => millimetres / millimetresPer;

  double toMillimetres(double value) => value * millimetresPer;

  /// Formats [millimetres] in this unit, without the symbol.
  String formatValue(double millimetres) =>
      fromMillimetres(millimetres).toStringAsFixed(decimals);

  /// Formats [millimetres] in this unit, with the symbol.
  String format(double millimetres) => '${formatValue(millimetres)} $symbol';

  /// Reads a number the user typed in this unit and returns millimetres, or
  /// null when the text is not a number.
  ///
  /// Returning null rather than throwing or defaulting is deliberate: a field
  /// that cannot be parsed must stay unconfirmed rather than quietly becoming
  /// zero (spec section 2).
  double? parseToMillimetres(String text) {
    // Arabic-Indic digits are accepted whatever the numeral setting says: the
    // keyboard in someone's hand is not always the one the setting expects.
    final cleaned =
        NumeralSystem.toWestern(text.trim()).replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite) return null;
    return toMillimetres(value);
  }
}

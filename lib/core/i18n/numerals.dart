/// Which digits numbers are written with.
///
/// The model never stores a formatted number, so this changes nothing but
/// what is on the screen — and what a user is allowed to type, which is both
/// sets whatever this is set to.
enum NumeralSystem {
  /// 0 1 2 3 4 5 6 7 8 9
  western('0123456789'),

  /// ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ — the digits used across Iraq, in Arabic and in
  /// Kurdish alike.
  arabicIndic('٠١٢٣٤٥٦٧٨٩');

  final String digits;

  const NumeralSystem(this.digits);

  /// Rewrites the digits of [text] in this system, leaving everything else —
  /// decimal points, units, words — exactly as it was.
  String format(String text) {
    if (this == NumeralSystem.western) return text;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final value = rune - 0x30;
      buffer.write(value >= 0 && value <= 9 ? digits[value] : String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  /// Rewrites any digits in [text] as plain 0-9, whichever set they were
  /// typed in.
  ///
  /// Every numeral system the app offers is accepted here whatever the setting
  /// says: a keyboard is not always the one the setting expects, and refusing
  /// a number because of the shape of its digits would be absurd.
  static String toWestern(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      buffer.write(_westernDigit(rune) ?? String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  /// The plain digit [rune] stands for, or null when it is not a digit.
  static String? _westernDigit(int rune) {
    // Arabic-Indic ٠-٩, then the Persian/Urdu variants ۰-۹, which share a
    // keyboard with them and are easy to send by accident.
    for (final start in [0x0660, 0x06F0]) {
      if (rune >= start && rune <= start + 9) return '${rune - start}';
    }
    return null;
  }
}

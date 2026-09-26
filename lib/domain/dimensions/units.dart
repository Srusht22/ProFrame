/// The unit the user works in.
///
/// Geometry is held in millimetres throughout the domain, because that is
/// what a workshop cuts to and it keeps every tolerance an integer count of
/// something real. The user does not type millimetres: they say a door is
/// 210 cm tall, not 2100 mm. So every number that reaches a person, and
/// every number a person types, is centimetres, and this is the one place
/// the two meet.
///
/// Converting is not rounding. A value typed in centimetres is exact in
/// millimetres: 72.25 cm is 722.5 mm and stays 722.5 mm.
///
/// Figures are *written* to the tenth of a centimetre, which is the
/// millimetre — what a workshop cuts to, and the finest distinction worth
/// quoting on a drawing. That is a matter of how many digits are printed,
/// not of what the design is: 96.4 cm is never written as 96, and a design
/// that is 90 cm tall is never written as 89.7.
abstract final class Units {
  static const double mmPerCm = 10;

  /// The unit as it is written beside a number.
  static const String symbol = 'cm';

  /// [mm] millimetres in centimetres.
  static double toCm(double mm) => mm / mmPerCm;

  /// [cm] centimetres in millimetres.
  static double toMm(double cm) => cm * mmPerCm;

  /// [mm] as a bare number of centimetres: `1050` → `105`, `964` → `96.4`,
  /// `1401` → `140.1`.
  ///
  /// Trailing zeros go, because `105` reads better than `105.0` and means
  /// exactly the same thing. Nothing else is dropped: a design that is
  /// 96.4 cm tall is not written down as 96.
  static String format(double mm) {
    final cm = toCm(mm);
    if (!cm.isFinite) return '—';
    var text = cm.toStringAsFixed(1);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text == '-0' ? '0' : text;
  }

  /// [mm] as a number of centimetres with the unit on it: `96.4 cm`.
  static String label(double mm) => '${format(mm)} $symbol';

  /// A typed number of centimetres, in millimetres. Null when it is not a
  /// number, so the field can put back what was there rather than guessing
  /// at what was meant.
  static double? parse(String text) {
    final cm = double.tryParse(text.trim().replaceAll(',', '.'));
    return cm == null ? null : toMm(cm);
  }
}

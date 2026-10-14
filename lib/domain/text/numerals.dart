/// Figures as the application reads them, whichever keyboard typed them.
///
/// **Every figure is shown in Latin digits, in English and in Kurdish
/// alike** — a price, a size, a date, a figure on the technical drawing.
/// That is deliberate: the drawing, the units (`cm`, `m²`), the currency
/// codes and the trade's own figures are Latin, and a screen that wrote
/// some figures one way and some the other would be harder to read than
/// either. No stored figure is ever written in any other digits.
///
/// But a Kurdish keyboard types Eastern Arabic digits (`٠١٢٣`), and a
/// Persian one the Persian forms (`۰۱۲۳`), with `٫` for the decimal point
/// and `٬` for thousands. Refusing them would refuse the figure the user
/// meant, so everything that reads a typed figure reads it through
/// [latin] first: the same value, in the digits the rest of the
/// application keeps.
abstract final class Numerals {
  static const _arabicZero = 0x0660;
  static const _persianZero = 0x06F0;

  /// [text] with every Eastern Arabic and Persian digit written as the
  /// Latin digit it is, the Arabic decimal separator as `.` and the Arabic
  /// thousands separator as `,`. Anything else is left as it was.
  static String latin(String text) {
    if (!_needed.hasMatch(text)) return text;
    final out = StringBuffer();
    for (final c in text.runes) {
      if (c >= _arabicZero && c <= _arabicZero + 9) {
        out.writeCharCode(0x30 + c - _arabicZero);
      } else if (c >= _persianZero && c <= _persianZero + 9) {
        out.writeCharCode(0x30 + c - _persianZero);
      } else if (c == 0x066B) {
        out.write('.');
      } else if (c == 0x066C) {
        out.write(',');
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  static final _needed = RegExp('[٠-٩۰-۹٫٬]');
}

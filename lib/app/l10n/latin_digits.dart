import 'package:flutter/services.dart';

import '../../domain/text/numerals.dart';

/// Turns a figure typed on a Kurdish or Persian keyboard — `١٢٫٥` — into
/// the digits the application writes and keeps, `12.5`, as it is typed.
///
/// It goes first on every field that takes a figure, before any filter
/// that would otherwise refuse the digits outright. Each digit is one
/// character either way, so where the cursor stands does not move. See
/// [Numerals] for why figures are kept and shown in Latin digits.
class LatinDigits extends TextInputFormatter {
  const LatinDigits();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = Numerals.latin(newValue.text);
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}

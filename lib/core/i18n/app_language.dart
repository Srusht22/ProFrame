import 'package:flutter/widgets.dart';

import 'numerals.dart';

/// The languages the app is written in.
///
/// Each one names itself in its own script: a user looking for Kurdish is
/// looking for کوردی, not for the word "Kurdish" in a language they may not
/// read (spec section 7).
enum AppLanguage {
  english('en', 'English', 'English', TextDirection.ltr, NumeralSystem.western),
  arabic('ar', 'Arabic', 'العربية', TextDirection.rtl, NumeralSystem.arabicIndic),
  kurdish('ckb', 'Kurdish (Sorani)', 'کوردی', TextDirection.rtl,
      NumeralSystem.arabicIndic);

  /// The language tag, as stored and as handed to Flutter.
  final String code;

  /// The name in English, for a support call.
  final String englishName;

  /// The name in the language itself.
  final String nativeName;

  /// Which way the script runs. Arabic and Kurdish are both right to left.
  final TextDirection direction;

  /// The digits this language is normally written with. A starting point
  /// only — the numeral setting is the user's, not the language's.
  final NumeralSystem defaultNumerals;

  const AppLanguage(
    this.code,
    this.englishName,
    this.nativeName,
    this.direction,
    this.defaultNumerals,
  );

  bool get isRightToLeft => direction == TextDirection.rtl;

  Locale get locale => Locale(code);

  /// The language stored under [code], or null when it is not one of ours.
  static AppLanguage? byCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

import 'package:flutter/widgets.dart';

import '../units/length_unit.dart';
import 'app_language.dart';
import 'numerals.dart';
import 'string_keys.dart';
import 'translations_ar.dart';
import 'translations_ckb.dart';
import 'translations_en.dart';

export 'string_keys.dart';

/// Every phrase the app says, in the language the user chose.
///
/// The tables are plain maps rather than generated code so a factory can read
/// them and correct a word without a build step. English is the fallback: a
/// phrase nobody has translated yet is shown in English rather than left
/// blank or shown as a key, because a user can act on an English sentence and
/// cannot act on `T.saveFailed` (spec section 7).
@immutable
class AppStrings {
  final AppLanguage language;
  final NumeralSystem numerals;

  const AppStrings({
    this.language = AppLanguage.english,
    this.numerals = NumeralSystem.western,
  });

  static const Map<AppLanguage, Map<T, String>> _tables = {
    AppLanguage.english: englishStrings,
    AppLanguage.arabic: arabicStrings,
    AppLanguage.kurdish: kurdishStrings,
  };

  /// The table for [language], for tests that check coverage.
  static Map<T, String> tableFor(AppLanguage language) =>
      _tables[language] ?? englishStrings;

  TextDirection get direction => language.direction;

  /// The phrase for [key], with `{name}` placeholders replaced from [args].
  String call(T key, [Map<String, Object?> args = const {}]) {
    final template =
        _tables[language]?[key] ?? englishStrings[key] ?? key.name;
    if (args.isEmpty) return template;
    var text = template;
    for (final entry in args.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return text;
  }

  /// A number, in the user's digits.
  String number(num value, {int decimals = 0}) =>
      numerals.format(value.toStringAsFixed(decimals));

  /// A count and the thing being counted, e.g. "3 panels".
  String count(int value, T singular, T plural) =>
      '${number(value)} ${call(value == 1 ? singular : plural)}';

  /// A length in millimetres, written in [unit] with its symbol.
  String length(double millimetres, LengthUnit unit) =>
      '${numerals.format(unit.formatValue(millimetres))} ${unitSymbol(unit)}';

  /// A length without its symbol — for a text field, where the unit is
  /// written beside the box.
  String lengthValue(double millimetres, LengthUnit unit) =>
      numerals.format(unit.formatValue(millimetres));

  String unitSymbol(LengthUnit unit) => call(switch (unit) {
        LengthUnit.millimetre => T.unitMillimetre,
        LengthUnit.centimetre => T.unitCentimetre,
        LengthUnit.metre => T.unitMetre,
        LengthUnit.inch => T.unitInch,
      });

  AppStrings copyWith({AppLanguage? language, NumeralSystem? numerals}) =>
      AppStrings(
        language: language ?? this.language,
        numerals: numerals ?? this.numerals,
      );

  @override
  bool operator ==(Object other) =>
      other is AppStrings &&
      other.language == language &&
      other.numerals == numerals;

  @override
  int get hashCode => Object.hash(language, numerals);
}

/// Carries the chosen language down the widget tree.
///
/// An inherited widget rather than a provider lookup, so a plain
/// [StatelessWidget] deep in a dialog can read it without being rewritten to
/// take a `ref`.
class AppStringsScope extends InheritedWidget {
  final AppStrings strings;

  const AppStringsScope({
    required this.strings,
    required super.child,
    super.key,
  });

  /// The strings in scope.
  ///
  /// Falls back to English when there is no scope — a widget pumped on its own
  /// in a test still reads correctly, and the app's own wiring is asserted by
  /// a test rather than by a crash in front of a user.
  static AppStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppStringsScope>()
          ?.strings ??
      const AppStrings();

  @override
  bool updateShouldNotify(AppStringsScope old) => old.strings != strings;
}

extension AppStringsContext on BuildContext {
  /// The app's phrases: `context.s(T.save)`.
  AppStrings get s => AppStringsScope.of(this);
}

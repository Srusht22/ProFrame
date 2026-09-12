import 'dart:convert';

import 'app_language.dart';
import 'numerals.dart';

/// What language the app speaks and what digits it writes.
///
/// Kept apart from the factory's settings on purpose: those are starting
/// points for a *design*, while these are about the person holding the phone.
/// Two people sharing a workshop can read the app in different languages
/// without either of them changing how the factory measures.
class AppPreferences {
  static const int currentVersion = 1;

  final AppLanguage language;
  final NumeralSystem numerals;

  const AppPreferences({
    this.language = AppLanguage.english,
    this.numerals = NumeralSystem.western,
  });

  static const AppPreferences standard = AppPreferences();

  /// The preferences a user gets when they first pick [language] — its own
  /// digits, which they can then change.
  AppPreferences withLanguage(AppLanguage language) => AppPreferences(
        language: language,
        numerals: language.defaultNumerals,
      );

  AppPreferences withNumerals(NumeralSystem numerals) =>
      AppPreferences(language: language, numerals: numerals);

  String encode() => jsonEncode({
        'version': currentVersion,
        'language': language.code,
        'numerals': numerals.name,
      });

  /// Reads stored preferences. Anything unreadable falls back to the
  /// standard ones: refusing to start over a damaged preference would be out
  /// of all proportion.
  static AppPreferences decode(String? raw) {
    if (raw == null) return standard;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return standard;
      final stored = json['language'];
      final language =
          AppLanguage.byCode(stored is String ? stored : null) ??
              standard.language;
      final numerals = NumeralSystem.values
              .where((n) => n.name == json['numerals'])
              .firstOrNull ??
          language.defaultNumerals;
      return AppPreferences(language: language, numerals: numerals);
    } on Object {
      return standard;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.language == language &&
      other.numerals == numerals;

  @override
  int get hashCode => Object.hash(language, numerals);
}

extension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

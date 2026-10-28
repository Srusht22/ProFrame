import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/text/words.dart';
import '../l10n/app_localizations.dart';
import '../l10n/arb_words.dart';

/// The languages the application is written in.
///
/// English is where it starts and what anything missing falls back to;
/// Central Kurdish (Sorani) is written in its own Arabic-based script and
/// runs right to left. Each is named in itself — a language's own name is
/// what somebody who reads it looks for — so the two names here are the
/// same whichever language is showing, and they are not translated.
enum AppLanguage {
  english('en', 'English'),
  centralKurdish('ckb', 'کوردی (سۆرانی)');

  /// The locale's language code, as `flutter gen-l10n` and the device know
  /// it, and as it is kept.
  final String code;

  /// The language's own name for itself.
  final String endonym;

  const AppLanguage(this.code, this.endonym);

  Locale get locale => Locale(code);

  /// The language kept as [code], or null for anything else.
  static AppLanguage? of(Object? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// The language the application is shown in.
///
/// English until the user chooses otherwise; the choice is kept on the
/// device, beside the appearance, and never in a design or a customer, so
/// changing it changes nothing anybody has made.
final languageProvider = NotifierProvider<Language, AppLanguage>(Language.new);

/// The language read from the device before the first frame, where `main`
/// could read it, so the first screen is already in it.
final savedLanguageProvider = Provider<AppLanguage?>((ref) => null);

class Language extends Notifier<AppLanguage> {
  /// Where the choice is kept.
  static const key = 'proframe.language';

  /// Whether the user has chosen since this was built, so a choice made
  /// while the kept one is still being read is not overwritten by it.
  bool _chosen = false;

  /// The language kept on the device, or null where none is.
  static Future<AppLanguage?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppLanguage.of(prefs.getString(key));
    } on Object {
      return null;
    }
  }

  @override
  AppLanguage build() {
    final saved = ref.read(savedLanguageProvider);
    if (saved != null) return saved;
    _restore();
    return AppLanguage.english;
  }

  Future<void> _restore() async {
    final kept = await read();
    if (_chosen || kept == null) return;
    state = kept;
  }

  Future<void> choose(AppLanguage language) async {
    _chosen = true;
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, language.code);
    } on Object {
      // Keeping it is a convenience; the choice stands for this session.
    }
  }
}

/// The words of the language chosen, for what has no `BuildContext` to ask
/// — a controller saying how something went.
extension LanguageWords on Ref {
  AppLocalizations get l10n =>
      lookupAppLocalizations(read(languageProvider).locale);

  /// What the domain says, in the same language.
  Words get words => ArbWords(l10n);
}

/// The same, for what a widget does with its `ref` after an `await`, when
/// its `BuildContext` may no longer be asked.
extension LanguageWordsOfWidget on WidgetRef {
  AppLocalizations get l10n =>
      lookupAppLocalizations(read(languageProvider).locale);

  Words get words => ArbWords(l10n);
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/i18n/app_language.dart';
import 'package:proframe/core/i18n/app_preferences.dart';
import 'package:proframe/core/i18n/numerals.dart';
import 'package:proframe/core/i18n/strings.dart';
import 'package:proframe/core/units/length_unit.dart';

void main() {
  group('every language says everything', () {
    test('no key is missing from any table', () {
      for (final language in AppLanguage.values) {
        final table = AppStrings.tableFor(language);
        final missing =
            T.values.where((key) => !table.containsKey(key)).toList();
        expect(
          missing,
          isEmpty,
          reason: 'Untranslated in ${language.englishName}: '
              '${missing.map((k) => k.name).join(', ')}',
        );
      }
    });

    test('no phrase is left blank', () {
      for (final language in AppLanguage.values) {
        for (final entry in AppStrings.tableFor(language).entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: '${entry.key.name} is empty in ${language.englishName}',
          );
        }
      }
    });

    test('a phrase with a placeholder keeps it in every language', () {
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in T.values) {
        final expected = placeholder
            .allMatches(AppStrings.tableFor(AppLanguage.english)[key]!)
            .map((m) => m.group(1))
            .toSet();
        for (final language in AppLanguage.values) {
          final actual = placeholder
              .allMatches(AppStrings.tableFor(language)[key]!)
              .map((m) => m.group(1))
              .toSet();
          expect(
            actual,
            expected,
            reason: '${key.name} in ${language.englishName} does not fill in '
                'the same values as the English',
          );
        }
      }
    });

    test('the translations are actually translations, not copies', () {
      // A handful of words are the same in every language on purpose: the
      // app's own name, and the digits shown as an example.
      const shared = {T.appName, T.numeralsWestern, T.numeralsArabicIndic};
      for (final language in AppLanguage.values) {
        if (language == AppLanguage.english) continue;
        final copied = T.values
            .where((key) => !shared.contains(key))
            .where((key) =>
                AppStrings.tableFor(language)[key] ==
                AppStrings.tableFor(AppLanguage.english)[key])
            .toList();
        expect(
          copied,
          isEmpty,
          reason: 'Still in English in ${language.englishName}: '
              '${copied.map((k) => k.name).join(', ')}',
        );
      }
    });
  });

  group('looking a phrase up', () {
    test('it comes back in the chosen language', () {
      expect(const AppStrings()(T.save), 'Save');
      expect(
        const AppStrings(language: AppLanguage.arabic)(T.save),
        arabicStringsSave,
      );
    });

    test('placeholders are filled in', () {
      expect(
        const AppStrings()(T.projectSaved, {'name': 'Kitchen'}),
        'Saved "Kitchen".',
      );
    });

    test('an unknown placeholder is left alone rather than blanked', () {
      expect(
        const AppStrings()(T.projectSaved, {'other': 'x'}),
        contains('{name}'),
      );
    });
  });

  group('Arabic and Kurdish read right to left', () {
    test('the direction comes from the language', () {
      expect(AppLanguage.english.direction, TextDirection.ltr);
      expect(AppLanguage.arabic.direction, TextDirection.rtl);
      expect(AppLanguage.kurdish.direction, TextDirection.rtl);
      expect(AppLanguage.kurdish.isRightToLeft, isTrue);
    });

    test('each language names itself in its own script', () {
      expect(AppLanguage.arabic.nativeName, 'العربية');
      expect(AppLanguage.kurdish.nativeName, 'کوردی');
    });

    test('a language is found again by the code it was stored under', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.byCode(language.code), language);
      }
      expect(AppLanguage.byCode('fr'), isNull);
      expect(AppLanguage.byCode(null), isNull);
    });
  });

  group('numerals', () {
    test('digits are rewritten and nothing else is', () {
      expect(NumeralSystem.arabicIndic.format('1200 mm'), '١٢٠٠ mm');
      expect(NumeralSystem.arabicIndic.format('12.5'), '١٢.٥');
      expect(NumeralSystem.western.format('1200'), '1200');
    });

    test('typing in either set of digits is understood', () {
      expect(LengthUnit.centimetre.parseToMillimetres('١٢٠'), 1200);
      expect(LengthUnit.centimetre.parseToMillimetres('120'), 1200);
      // Persian digits share a keyboard with the Arabic ones.
      expect(LengthUnit.centimetre.parseToMillimetres('۱۲۰'), 1200);
      expect(LengthUnit.centimetre.parseToMillimetres('١٢٠٫٥'.replaceAll('٫', '.')),
          1205);
    });

    test('something that is not a number is still refused', () {
      expect(LengthUnit.centimetre.parseToMillimetres('توري'), isNull);
      expect(LengthUnit.centimetre.parseToMillimetres(''), isNull);
    });

    test('a length is written in the chosen digits and unit', () {
      const arabic = AppStrings(
        language: AppLanguage.arabic,
        numerals: NumeralSystem.arabicIndic,
      );
      expect(arabic.length(1200, LengthUnit.millimetre), '١٢٠٠ ملم');
      expect(arabic.length(1200, LengthUnit.centimetre), '١٢٠.٠ سم');
      expect(
        const AppStrings().length(1200, LengthUnit.centimetre),
        '120.0 cm',
      );
    });
  });

  group('preferences', () {
    test('they survive a round trip', () {
      const preferences = AppPreferences(
        language: AppLanguage.kurdish,
        numerals: NumeralSystem.western,
      );
      expect(AppPreferences.decode(preferences.encode()), preferences);
    });

    test('choosing a language brings its own digits with it', () {
      expect(
        const AppPreferences().withLanguage(AppLanguage.arabic).numerals,
        NumeralSystem.arabicIndic,
      );
      // And they can then be changed back without changing the language.
      final chosen = const AppPreferences()
          .withLanguage(AppLanguage.arabic)
          .withNumerals(NumeralSystem.western);
      expect(chosen.language, AppLanguage.arabic);
      expect(chosen.numerals, NumeralSystem.western);
    });

    test('a damaged preference falls back rather than refusing to start', () {
      expect(AppPreferences.decode('not json'), AppPreferences.standard);
      expect(AppPreferences.decode(null), AppPreferences.standard);
      expect(AppPreferences.decode('{"language":"fr"}'), AppPreferences.standard);
    });
  });
}

/// Written out so the expectation is readable in the failure message.
const String arabicStringsSave = 'حفظ';

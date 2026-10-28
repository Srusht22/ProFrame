import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/l10n/arb_words.dart';
import 'package:proframe/app/l10n/l10n.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/domain/model/customer_discount.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/profile_category.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/domain/text/names.dart';
import 'package:proframe/domain/text/words.dart';

import '../../tool/apply_approved_translations.dart' as review;
import '../../tool/generate_domain_words.dart' as generator;
import 'the_launch_test.dart' show glyphsIn;

// The words of the application are one set, in two languages.
//
// English is written once, in lib/app/l10n/app_en.arb, and Central Kurdish
// once, in app_ckb.arb. The domain says its words through `Words`, made
// from the same English by tool/generate_domain_words.dart. These hold that
// the two files say the same things, that what was generated from them is
// current, that the English the domain's own tests read is the English the
// screen shows, and that every letter of the Kurdish has a glyph to be
// drawn with.

Map<String, Object?> arb(String code) =>
    jsonDecode(File('lib/app/l10n/app_$code.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> keysOf(Map<String, Object?> file) => {
  for (final k in file.keys)
    if (!k.startsWith('@')) k,
};

/// The names of the placeholders in [message] — `{name}`, and the variable
/// of a plural, `{count, plural, …}`.
Set<String> placeholdersOf(String message) => {
  for (final m in RegExp(r'\{(\w+)(?:,|\})').allMatches(message)) m.group(1)!,
};

void main() {
  final en = arb('en');
  final ckb = arb('ckb');

  test('every English message has its Kurdish, and nothing more', () {
    expect(keysOf(ckb), keysOf(en));
  });

  test('a Kurdish message names the same placeholders as its English', () {
    for (final key in keysOf(en)) {
      expect(
        placeholdersOf(ckb[key]! as String),
        placeholdersOf(en[key]! as String),
        reason: key,
      );
    }
  });

  test('no Kurdish message is empty or the name of its key', () {
    for (final key in keysOf(ckb)) {
      final said = ckb[key]! as String;
      expect(said.trim(), isNotEmpty, reason: key);
      expect(said, isNot(key), reason: key);
    }
  });

  test('in Kurdish a figure is kept left to right inside a sentence', () {
    // `140.00 USD` in a right-to-left sentence would be read backwards and
    // split from its unit; isolated, it is one run. A message added later
    // is held to the same.
    for (final key in keysOf(ckb)) {
      final said = ckb[key]! as String;
      expect(said, review.markFigures(said), reason: key);
    }
  });

  test('every English message says what it is for', () {
    for (final key in keysOf(en)) {
      final about = en['@$key'];
      expect(about, isA<Map<String, Object?>>(), reason: key);
      expect(
        ((about! as Map<String, Object?>)['description'] as String?) ?? '',
        isNotEmpty,
        reason: key,
      );
    }
  });

  test('the domain words and their adapter are current with the ARB', () {
    // Run `dart run tool/generate_domain_words.dart`, then
    // `flutter gen-l10n`, where this fails.
    final made = generator.generate(File(generator.arbPath).readAsStringSync());
    expect(File(generator.domainPath).readAsStringSync(), made.domain);
    expect(File(generator.adapterPath).readAsStringSync(), made.adapter);
  });

  test('the generated localizations hold every message of the ARB', () {
    final source = File('lib/app/l10n/app_localizations_ckb.dart')
        .readAsStringSync();
    for (final key in keysOf(en)) {
      expect(source, contains(' $key'), reason: key);
    }
  });

  group('the English the domain reads is the English the screen shows', () {
    final shown = ArbWords(english);
    const read = EnglishWords();

    void same<T>(
      List<T> values,
      String Function(T, Words) say, [
      String Function(T)? label,
    ]) {
      for (final v in values) {
        expect(say(v, shown), say(v, read), reason: '$v');
        if (label != null) expect(say(v, read), label(v), reason: '$v');
      }
    }

    test('categories', () {
      same(DesignKind.values, (k, w) => k.labelIn(w), (k) => k.label);
      same(DesignKind.values, (k, w) => k.nounIn(w), (k) => k.noun);
    });
    test('materials and their looks', () {
      same(MaterialKind.values, (m, w) => m.labelIn(w), (m) => m.label);
      same(GlassLook.values, (g, w) => g.labelIn(w), (g) => g.label);
      same(PanelColour.values, (c, w) => c.labelIn(w), (c) => c.label);
      same(HardwareColour.values, (c, w) => c.labelIn(w), (c) => c.label);
      same(Construction.values, (c, w) => c.labelIn(w), (c) => c.label);
    });
    test('openings and ironmongery', () {
      same(OpeningMechanism.values, (m, w) => m.labelIn(w), (m) => m.label);
      same(
        OpeningMechanism.values,
        (m, w) => m.descriptionIn(w),
        (m) => m.description,
      );
      same(HardwareKind.values, (k, w) => k.labelIn(w), (k) => k.label);
    });
    test('money', () {
      same(PaymentType.values, (t, w) => t.labelIn(w), (t) => t.label);
      same(PaymentMethod.values, (m, w) => m.labelIn(w), (m) => m.label);
      same(DiscountKind.values, (k, w) => k.labelIn(w), (k) => k.label);
      same(PriceGroup.values, (g, w) => g.labelIn(w), (g) => g.label);
      same(QuotationStatus.values, (s, w) => s.labelIn(w), (s) => s.label);
      same(ProfileCategory.values, (c, w) => c.labelIn(w), (c) => c.label);
      same(ProfilePart.values, (p, w) => p.labelIn(w), (p) => p.label);
    });
  });

  test('Kurdish is a language of its own, not English under another name', () {
    final kurdish = lookupAppLocalizations(const Locale('ckb'));
    expect(kurdish.localeName, 'ckb');
    expect(kurdish.customersTitle, isNot(english.customersTitle));
    expect(
      DesignKind.door.labelIn(ArbWords(kurdish)),
      isNot(DesignKind.door.label),
    );
    // And the domain's English is the default wherever nothing is said.
    expect(DesignKind.door.labelIn(const EnglishWords()), 'Door');
  });

  test('each language is named in itself, in Settings', () {
    expect(AppLanguage.english.endonym, 'English');
    expect(AppLanguage.centralKurdish.endonym, 'کوردی (سۆرانی)');
    expect(AppLanguage.of('ckb'), AppLanguage.centralKurdish);
    expect(AppLanguage.of('fr'), isNull);
  });

  test('every letter of the Kurdish has a glyph to be drawn with', () {
    final glyphs = {
      ...glyphsIn(File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync()),
      ...glyphsIn(
        File('assets/fonts/NotoSansArabic-Regular.ttf').readAsBytesSync(),
      ),
    };
    final missing = <String>{};
    for (final key in keysOf(ckb)) {
      for (final c in (ckb[key]! as String).runes) {
        // Space, the line break and the joiners need no glyph of their own.
        if (c == 0x20 || c == 0x0A || c == 0x200C || c == 0x200D) continue;
        // Nor the left-to-right mark that keeps a figure one run in a
        // Kurdish sentence (U+200E): it is never drawn.
        if (c == 0x200E) continue;
        if (!glyphs.contains(c)) {
          missing.add('U+${c.toRadixString(16).toUpperCase()} in $key');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('two adapters of one language are the same words', () {
    expect(ArbWords(english), ArbWords(english));
    expect(
      ArbWords(lookupAppLocalizations(const Locale('ckb'))),
      isNot(ArbWords(english)),
    );
  });
}

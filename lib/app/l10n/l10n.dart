import 'package:flutter/widgets.dart';

import '../../domain/text/words.dart';
import 'app_localizations.dart';
import 'arb_words.dart';

export 'app_localizations.dart';

/// The application's words, in the language it is shown in.
extension L10n on BuildContext {
  /// The localizations in scope, or English where there are none — a
  /// widget pumped on its own in a test, or a painter's context outside the
  /// application. Never a missing word: English is the fallback.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? english;

  /// What the domain says, in the same language.
  Words get words => ArbWords(l10n);
}

/// The English words, for anything that has no context to ask.
final AppLocalizations english = lookupAppLocalizations(const Locale('en'));

/// The month [month] (1 to 12) as a date on a card writes it.
String shortMonth(AppLocalizations l, int month) =>
    l.fwShortMonths.split(',')[month - 1];

/// Whether [text] holds any letter of a right-to-left script — Arabic,
/// which Central Kurdish is written in, or Hebrew. A figure, a unit and a
/// currency code hold none.
bool hasRightToLeft(String text) => RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]').hasMatch(text);

/// How a figure is kept readable in a right-to-left line.
extension Figures on BuildContext {
  /// [text] — a figure with its unit, `7.000 m × 20.00`, `140.00 USD` —
  /// kept as one left-to-right run where the line it is set in runs right
  /// to left, so it is not read backwards or split around the words beside
  /// it: a left-to-right mark (U+200E) either side of it. Left to right, it
  /// is [text] exactly.
  String figure(String text) =>
      Directionality.maybeOf(this) == TextDirection.rtl
      ? '\u200E$text\u200E'
      : text;

  /// [text] with every figure in it — `150.0 × 200.0 cm`, `? cm`, `7°` —
  /// kept as one left-to-right run, as [figure] keeps one, where the line
  /// runs right to left; the words round them are left as they are. Left
  /// to right, it is [text] exactly.
  String figures(String text) =>
      Directionality.maybeOf(this) == TextDirection.rtl
      ? text.replaceAllMapped(_figureRun, (m) => '\u200E${m[0]}\u200E')
      : text;

  /// The direction to set [text] in: left to right for a figure that has
  /// no right-to-left letter in it, whichever way the screen runs; and the
  /// screen's own for words.
  TextDirection? directionOf(String text) =>
      hasRightToLeft(text) ? null : TextDirection.ltr;
}

/// A figure as the application writes one: digits or `?`, perhaps joined
/// by `×`, perhaps with its unit after it.
final _figureRun = RegExp(
  r'[?\d][\d.,]*(?:\s*×\s*[?\d][\d.,]*)*(?:\s*(?:cm|mm|m²|m|USD|°|%))?',
);

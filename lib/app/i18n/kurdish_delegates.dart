import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter's own translations for Kurdish, borrowed from Arabic.
///
/// `flutter_localizations` has no Kurdish (ckb) yet. Without these, choosing
/// Kurdish would throw — there would be no `MaterialLocalizations` for the
/// locale — so the framework's own handful of words (the tooltip on a back
/// arrow, the text-selection menu) are taken from Arabic, which shares the
/// script and the direction. Everything the app itself says is Kurdish.
class KurdishMaterialLocalisations
    extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalisations();

  static const Locale _borrowedFrom = Locale('ar');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_borrowedFrom);

  @override
  bool shouldReload(KurdishMaterialLocalisations old) => false;
}

/// The same borrowing for the widgets layer — which is also what makes the
/// whole app lay itself out right to left in Kurdish.
class KurdishWidgetLocalisations
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetLocalisations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(KurdishWidgetLocalisations old) => false;
}

class KurdishCupertinoLocalisations
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalisations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(KurdishCupertinoLocalisations old) => false;
}

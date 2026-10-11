import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Flutter's own words — a back button's tooltip, a date picker, the menu
/// over selected text — for Central Kurdish, which `flutter_localizations`
/// does not carry.
///
/// Without these the application would have no Material localizations in
/// Kurdish and every dialog would fail; with English ones in their place it
/// would also run left to right. So the widgets' direction is right to left
/// here, and the framework's words come from the same ARB file as the
/// application's (`fw…`), so all the Kurdish is in one place for review.
/// Anything not overridden stays Flutter's English, which is the fallback
/// the application promises.
abstract final class KurdishFramework {
  static const List<LocalizationsDelegate<Object>> delegates = [
    _MaterialDelegate(),
    _WidgetsDelegate(),
    _CupertinoDelegate(),
  ];

  static bool _isKurdish(Locale locale) => locale.languageCode == 'ckb';
}

class _MaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialDelegate();

  @override
  bool isSupported(Locale locale) => KurdishFramework._isKurdish(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(KurdishMaterialLocalizations(lookupAppLocalizations(
        locale,
      )));

  @override
  bool shouldReload(_MaterialDelegate old) => false;
}

class _WidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsDelegate();

  @override
  bool isSupported(Locale locale) => KurdishFramework._isKurdish(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const KurdishWidgetsLocalizations());

  @override
  bool shouldReload(_WidgetsDelegate old) => false;
}

class _CupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoDelegate();

  @override
  bool isSupported(Locale locale) => KurdishFramework._isKurdish(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultCupertinoLocalizations());

  @override
  bool shouldReload(_CupertinoDelegate old) => false;
}

/// Kurdish runs right to left; everything else is Flutter's default.
class KurdishWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const KurdishWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

/// The Material words the application's screens actually show, in Kurdish.
///
/// Figures stay in the digits the rest of the application writes them in,
/// so a date reads the same way as a price beside it.
class KurdishMaterialLocalizations extends DefaultMaterialLocalizations {
  final AppLocalizations l;

  const KurdishMaterialLocalizations(this.l);

  List<String> get _months => [
    l.fwJanuary,
    l.fwFebruary,
    l.fwMarch,
    l.fwApril,
    l.fwMay,
    l.fwJune,
    l.fwJuly,
    l.fwAugust,
    l.fwSeptember,
    l.fwOctober,
    l.fwNovember,
    l.fwDecember,
  ];

  /// Monday first, as [DateTime.weekday] counts.
  List<String> get _weekdays => [
    l.fwMonday,
    l.fwTuesday,
    l.fwWednesday,
    l.fwThursday,
    l.fwFriday,
    l.fwSaturday,
    l.fwSunday,
  ];

  @override
  List<String> get narrowWeekdays => l.fwNarrowWeekdays.split(',');

  @override
  String formatMonthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  @override
  String formatMediumDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}، ${date.day} ${_months[date.month - 1]}';

  @override
  String formatFullDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}، ${date.day} '
      '${_months[date.month - 1]} ${date.year}';

  @override
  String formatShortMonthDay(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  @override
  String formatShortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  @override
  String formatCompactDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  String get dateHelpText => l.fwDateFormat;
  @override
  String get backButtonTooltip => l.fwBack;
  @override
  String get closeButtonTooltip => l.fwClose;
  @override
  String get closeButtonLabel => l.fwClose;
  @override
  String get cancelButtonLabel => l.fwCancel;
  @override
  String get okButtonLabel => l.fwOk;
  @override
  String get saveButtonLabel => l.fwSave;
  @override
  String get continueButtonLabel => l.fwContinue;
  @override
  String get deleteButtonTooltip => l.fwDelete;
  @override
  String get moreButtonTooltip => l.fwMore;
  @override
  String get showMenuTooltip => l.fwShowMenu;
  @override
  String get searchFieldLabel => l.fwSearch;
  @override
  String get clearButtonTooltip => l.fwClearText;
  @override
  String get modalBarrierDismissLabel => l.fwDismiss;
  @override
  String get menuDismissLabel => l.fwDismiss;
  @override
  String get dialogLabel => l.fwDialog;
  @override
  String get alertDialogLabel => l.fwAlert;
  @override
  String get popupMenuLabel => l.fwPopupMenu;
  @override
  String get bottomSheetLabel => l.fwBottomSheet;
  @override
  String get datePickerHelpText => l.fwSelectDate;
  @override
  String get dateInputLabel => l.fwEnterDate;
  @override
  String get invalidDateFormatLabel => l.fwInvalidDate;
  @override
  String get dateOutOfRangeLabel => l.fwDateOutOfRange;
  @override
  String get calendarModeButtonLabel => l.fwToCalendar;
  @override
  String get inputDateModeButtonLabel => l.fwToInput;
  @override
  String get nextMonthTooltip => l.fwNextMonth;
  @override
  String get previousMonthTooltip => l.fwPreviousMonth;
  @override
  String get selectYearSemanticsLabel => l.fwSelectYear;
  @override
  String get currentDateLabel => l.fwToday;
  @override
  String get selectedDateLabel => l.fwSelected;
  @override
  String get copyButtonLabel => l.fwCopy;
  @override
  String get cutButtonLabel => l.fwCut;
  @override
  String get pasteButtonLabel => l.fwPaste;
  @override
  String get selectAllButtonLabel => l.fwSelectAll;
  @override
  String get expandedIconTapHint => l.fwCollapse;
  @override
  String get collapsedIconTapHint => l.fwExpand;
  @override
  String get refreshIndicatorSemanticLabel => l.fwRefresh;
}

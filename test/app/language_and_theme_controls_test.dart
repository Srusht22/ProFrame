import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/l10n/app_localizations.dart';
import 'package:proframe/app/l10n/errors.dart';
import 'package:proframe/app/l10n/kurdish_framework.dart';
import 'package:proframe/app/l10n/latin_digits.dart';
import 'package:proframe/app/l10n/name_text.dart';
import 'package:proframe/app/screens/appearance_button.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/language_button.dart';
import 'package:proframe/app/state/appearance.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/text/refusal.dart';
import 'package:proframe/infrastructure/keep_failed.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'financial_records_on_screen_test.dart' show overflowing;
import 'the_designs_screen_test.dart' as screen;

// Phase 35: the language and the appearance, each on a button of its own —
// a translate mark and a sun or moon, never one gear for both — each
// taking effect at once, each kept, and neither touching the other. Then
// what was left of Phase 34: figures typed on a Kurdish keyboard, errors
// said in the language shown, Flutter's own words in Kurdish, and an
// English name in a Kurdish title laid out as itself.

final kurdish = lookupAppLocalizations(const Locale('ckb'));

Future<Map<String, Object?>> device() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)};
}

Future<void> chooseLanguage(WidgetTester tester, AppLanguage language) async {
  await tester.tap(find.byKey(LanguageButton.buttonKey).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LanguageButton.optionKey(language)).last);
  await tester.pumpAndSettle();
}

Future<void> chooseAppearance(WidgetTester tester, ThemeMode mode) async {
  await tester.tap(find.byKey(AppearanceButton.buttonKey).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AppearanceButton.optionKey(mode)).last);
  await tester.pumpAndSettle();
}

TextDirection directionOn(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(CustomersScreen)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('two controls, each recognisable', () {
    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(1280, 820),
    ]) {
      testWidgets('at ${size.width.round()} wide: a translate mark and a '
          'sun or moon, side by side, each saying what it does', (
        tester,
      ) async {
        await screen.openTheApp(tester, size: size);
        final language = find.byKey(LanguageButton.buttonKey);
        final appearance = find.byKey(AppearanceButton.buttonKey);
        expect(language, findsOneWidget);
        expect(appearance, findsOneWidget);
        expect(
          find.descendant(of: language, matching: find.byIcon(Icons.translate)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: appearance,
            matching: find.byIcon(Icons.translate),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: appearance,
            matching: find.byIcon(Appearance.icons[ThemeMode.system]!),
          ),
          findsOneWidget,
        );
        // Said for a screen reader and on hover.
        expect(find.bySemanticsLabel('Language — now English'), findsWidgets);
        expect(
          find.bySemanticsLabel('Change appearance — now Match device'),
          findsWidgets,
        );
        expect(find.byTooltip('Change language'), findsOneWidget);
        expect(overflowing(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the language button offers the two languages, each named '
        'in itself, the one in use ticked, and no flag', (tester) async {
      await screen.openTheApp(tester, size: const Size(390, 844));
      await tester.tap(find.byKey(LanguageButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('کوردی (سۆرانی)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LanguageButton.optionKey(AppLanguage.english)),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('the appearance button offers light, dark and the device, '
        'the one in use ticked', (tester) async {
      await screen.openTheApp(tester, size: const Size(390, 844));
      await tester.tap(find.byKey(AppearanceButton.buttonKey));
      await tester.pumpAndSettle();
      for (final mode in ThemeMode.values) {
        expect(find.byKey(AppearanceButton.optionKey(mode)), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(AppearanceButton.optionKey(ThemeMode.system)),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });
  });

  group('each takes effect at once, is kept, and leaves the other alone', () {
    testWidgets('Kurdish from the language button: right to left at once, '
        'kept; the appearance not touched', (tester) async {
      final c = await screen.openTheApp(tester, size: const Size(390, 844));
      await chooseLanguage(tester, AppLanguage.centralKurdish);
      expect(directionOn(tester), TextDirection.rtl);
      expect(find.text(kurdish.customersTitle), findsWidgets);
      expect(c.read(appearanceProvider), ThemeMode.system);
      final kept = await tester.runAsync(device);
      expect(kept![Language.key], 'ckb');
      expect(kept.containsKey(Appearance.key), isFalse);
      // And the controls are still there, and still two, in Kurdish.
      expect(find.byKey(LanguageButton.buttonKey), findsOneWidget);
      expect(find.byKey(AppearanceButton.buttonKey), findsOneWidget);
      expect(overflowing(tester), isEmpty);
    });

    testWidgets('Dark from the appearance button: dark at once, kept; the '
        'language not touched', (tester) async {
      final c = await screen.openTheApp(tester, size: const Size(390, 844));
      await chooseAppearance(tester, ThemeMode.dark);
      expect(c.read(appearanceProvider), ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(CustomersScreen))).brightness,
        Brightness.dark,
      );
      expect(c.read(languageProvider), AppLanguage.english);
      expect(directionOn(tester), TextDirection.ltr);
      final kept = await tester.runAsync(device);
      expect(kept![Appearance.key], 'dark');
      expect(kept.containsKey(Language.key), isFalse);
    });

    testWidgets('both chosen, then the app opened again from the device: '
        'both as they were', (tester) async {
      await screen.openTheApp(tester, size: const Size(390, 844));
      await chooseLanguage(tester, AppLanguage.centralKurdish);
      await chooseAppearance(tester, ThemeMode.light);
      await tester.pumpWidget(const SizedBox());

      final again = await screen.openTheApp(tester, size: const Size(390, 844));
      // The appearance is read as the app opens.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(again.read(languageProvider), AppLanguage.centralKurdish);
      expect(again.read(appearanceProvider), ThemeMode.light);
      expect(directionOn(tester), TextDirection.rtl);
      expect(
        find.bySemanticsLabel(kurdish.lbCurrent('کوردی (سۆرانی)')),
        findsWidgets,
      );
    });

    testWidgets('choosing either changes nothing anybody made', (tester) async {
      await screen.keepThree();
      await screen.openTheApp(tester, size: const Size(390, 844));
      final before = await tester.runAsync(device);
      await chooseLanguage(tester, AppLanguage.centralKurdish);
      await chooseAppearance(tester, ThemeMode.dark);
      final after = (await tester.runAsync(device))!
        ..remove(Language.key)
        ..remove(Appearance.key);
      expect(after, before);
    });
  });

  group('what Phase 34 left', () {
    testWidgets('a figure typed on a Kurdish keyboard is the figure, in the '
        'digits the application keeps', (tester) async {
      final field = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: field,
              inputFormatters: const [LatinDigits()],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '١٢٠٫٥');
      expect(field.text, '120.5');
      await tester.enterText(find.byType(TextField), '۲۵');
      expect(field.text, '25');
    });

    testWidgets('an English name in a Kurdish title is laid out as itself, '
        'at the start of the line, cut at its own end', (tester) async {
      const name = 'Basement Door - New PVC entrance with a long name';
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(width: 160, child: NameText(name, maxLines: 2)),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(name));
      expect(text.data, name, reason: 'never changed, never reversed');
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.right);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);

      // A Kurdish name on an English screen, the other way round.
      expect(
        NameText.directionOf('دەرگای ژێرزەمین', TextDirection.ltr),
        TextDirection.rtl,
      );
      expect(NameText.directionOf('123', TextDirection.rtl), TextDirection.rtl);
    });

    testWidgets('an error reaching the user is said in their language, and '
        'a fault is never shown raw', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ckb'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            ...KurdishFramework.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        userMessageOf(ctx, Refusal((w) => w.rcpNotForRefund)),
        kurdish.rcpNotForRefund,
      );
      expect(userMessageOf(ctx, const KeepFailed('k')), kurdish.errNotKept);
      expect(
        userMessageOf(
          ctx,
          AccessDenied(WorkshopRole.staff, Capability.pricingEdit),
        ),
        isNot(contains('Capability')),
      );
      final fault = userMessageOf(ctx, Exception('socket closed at 0x1f'));
      expect(fault, kurdish.errSomethingWrong);
      expect(fault, isNot(contains('socket')));
    });

    test("Flutter's own words that a phone shows are Kurdish", () {
      final widgets = KurdishWidgetsLocalizations(kurdish);
      final cupertino = KurdishCupertinoLocalizations(kurdish);
      final material = KurdishMaterialLocalizations(kurdish);
      for (final said in [
        widgets.copyButtonLabel,
        widgets.pasteButtonLabel,
        widgets.lookUpButtonLabel,
        widgets.searchWebButtonLabel,
        widgets.shareButtonLabel,
        cupertino.copyButtonLabel,
        cupertino.selectAllButtonLabel,
        cupertino.alertDialogLabel,
        cupertino.modalBarrierDismissLabel,
        material.lookUpButtonLabel,
        material.drawerLabel,
        material.scrimOnTapHint('x'),
      ]) {
        expect(RegExp('[؀-ۿ]').hasMatch(said), isTrue, reason: said);
      }
      expect(widgets.textDirection, TextDirection.rtl);
      expect(const DefaultCupertinoLocalizations().copyButtonLabel, 'Copy');
    });

    test('a date typed in the Kurdish date picker is read the way it is '
        'written — day, month, year — in either digits', () {
      final material = KurdishMaterialLocalizations(kurdish);
      final date = DateTime(2026, 4, 3);
      final written = material.formatCompactDate(date);
      expect(written, '03/04/2026');
      expect(material.parseCompactDate(written), date);
      expect(material.parseCompactDate('٠٣/٠٤/٢٠٢٦'), date);
      expect(material.parseCompactDate('31/02/2026'), isNull);
      expect(material.parseCompactDate('nonsense'), isNull);
    });
  });
}

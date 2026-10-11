import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/app/l10n/app_localizations.dart';
import 'package:proframe/app/l10n/arb_words.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/settings_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_selection.dart';
import 'package:proframe/domain/text/words.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'the_designs_screen_test.dart' as screen;

// The application in Central Kurdish (Sorani), and English as it was.
//
// The language is chosen in Settings, takes effect at once, is kept on the
// device and is where the application opens next time; English is where it
// starts. Kurdish runs right to left. Choosing a language changes no
// customer, design, price or record — the device's storage is the same to
// the byte but for the choice itself — and every figure, price and
// measurement reads the same in either. The technical drawing is a drawing
// of the design and is never mirrored.

final kurdish = lookupAppLocalizations(const Locale('ckb'));
final inEnglish = lookupAppLocalizations(const Locale('en'));

/// Every key the device keeps, and what is kept under it.
Future<Map<String, Object?>> storage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)};
}

/// Settings opened from the customers' header, and [language] chosen.
Future<void> choose(WidgetTester tester, AppLanguage language) async {
  await tester.tap(find.byKey(SettingsButton.buttonKey).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SettingsScreen.languageOption(language)));
  await tester.pumpAndSettle();
  await back(tester);
}

/// Back a screen, as the bar's back arrow goes.
Future<void> back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

TextDirection directionOn(WidgetTester tester, Finder where) =>
    Directionality.of(tester.element(where.first));

/// Sara's window kept with its material and colour chosen and a price
/// calculated, so its card shows a figure.
Future<Design> keepAPricedWindow() async {
  final kept = await screen.keepThree();
  final window = kept.firstWhere((d) => d.kind == DesignKind.window);
  final starter = PriceList.starter;
  final white = starter.colours.first;
  final chosen = ProfileSelection.choose(
    window,
    material: MaterialKind.upvc,
    colour: white.swatch,
    colourId: white.id,
  );
  final saved = await DesignStore().save(chosen, by: WorkshopRole.owner);
  final record = PriceRecord.calculate(saved, starter);
  expect(record, isNotNull, reason: 'the window can be priced');
  await PriceRecordStore().save(saved.id, record!);
  return saved;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it opens in English, left to right', (tester) async {
    await screen.openTheApp(tester);
    expect(find.text(inEnglish.customersTitle), findsWidgets);
    expect(
      directionOn(tester, find.byType(CustomersScreen)),
      TextDirection.ltr,
    );
  });

  testWidgets('Settings offers the two languages, each named in itself', (
    tester,
  ) async {
    await screen.openTheApp(tester);
    await tester.tap(find.byKey(SettingsButton.buttonKey).first);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('کوردی (سۆرانی)'), findsOneWidget);
    // English is the one chosen.
    final group = tester.widget<RadioGroup<AppLanguage>>(
      find.byKey(SettingsScreen.languageKey),
    );
    expect(group.groupValue, AppLanguage.english);
  });

  testWidgets('Kurdish takes effect at once, right to left, and is kept', (
    tester,
  ) async {
    await screen.openTheApp(tester);
    await choose(tester, AppLanguage.centralKurdish);

    expect(find.text(kurdish.customersTitle), findsWidgets);
    expect(find.text(inEnglish.customersTitle), findsNothing);
    expect(
      directionOn(tester, find.byType(CustomersScreen)),
      TextDirection.rtl,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Language.key), 'ckb');

    // And back.
    await choose(tester, AppLanguage.english);
    expect(find.text(inEnglish.customersTitle), findsWidgets);
    expect(
      directionOn(tester, find.byType(CustomersScreen)),
      TextDirection.ltr,
    );
    expect(prefs.getString(Language.key), 'en');
  });

  testWidgets('the app opens next time in the language kept', (tester) async {
    SharedPreferences.setMockInitialValues({Language.key: 'ckb'});
    await screen.openTheApp(tester);
    expect(find.text(kurdish.customersTitle), findsWidgets);
    expect(
      directionOn(tester, find.byType(CustomersScreen)),
      TextDirection.rtl,
    );
  });

  testWidgets('a language this version does not know opens in English', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Language.key: 'fr'});
    await screen.openTheApp(tester);
    expect(find.text(inEnglish.customersTitle), findsWidgets);
  });

  testWidgets('choosing a language changes nothing anybody made', (
    tester,
  ) async {
    await keepAPricedWindow();
    await screen.openTheApp(tester);
    final before = await storage();

    await choose(tester, AppLanguage.centralKurdish);
    await screen.openCustomer(tester, 'Sara');
    await back(tester);
    await choose(tester, AppLanguage.english);

    final after = await storage();
    expect(after.remove(Language.key), 'en');
    expect(after, before, reason: 'every customer, design and price as kept');
  });

  testWidgets('a price reads the same figure in both languages', (
    tester,
  ) async {
    final window = await keepAPricedWindow();
    await screen.openTheApp(tester);

    String priceOnTheCard() => tester
        .widget<Text>(find.byKey(CustomerDesignCard.priceValueKey(window.id)))
        .data!;
    String figureIn(String words) =>
        RegExp(r'[\d,]+\.\d\d USD').firstMatch(words)!.group(0)!;

    await screen.openCustomer(tester, 'Sara');
    await tester.ensureVisible(
      find.byKey(CustomerDesignCard.priceValueKey(window.id)),
    );
    final english = figureIn(priceOnTheCard());
    await back(tester);

    await choose(tester, AppLanguage.centralKurdish);
    await screen.openCustomer(tester, 'Sara');
    await tester.ensureVisible(
      find.byKey(CustomerDesignCard.priceValueKey(window.id)),
    );
    final said = priceOnTheCard();
    expect(figureIn(said), english);
    // Said in Kurdish around the figure, which is not.
    expect(said, isNot(contains('Price')));
  });

  testWidgets('in Kurdish no key is shown in place of a message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Language.key: 'ckb'});
    await screen.keepThree();
    final container = await screen.openTheApp(tester);

    void noKeysShown(String where) {
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final said = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(arbKeys.contains(said), isFalse, reason: '$where: "$said"');
      }
    }

    noKeysShown('customers');
    await screen.openCustomer(tester, 'Sara');
    noKeysShown("Sara's page");
    final id = container.read(workspaceProvider).design.id;
    expect(id, isNotNull);
  });

  for (final size in const [Size(390, 844), Size(820, 1180), Size(1440, 900)]) {
    testWidgets('in Kurdish nothing overflows at ${size.width.round()} wide', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({Language.key: 'ckb'});
      final kept = await screen.keepThree();
      final container = await screen.openTheApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'customers');

      await tester.tap(find.byKey(SettingsButton.buttonKey).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'settings');
      await back(tester);

      final window = kept.firstWhere((d) => d.kind == DesignKind.window);
      await screen.openCustomer(tester, 'Sara');
      expect(tester.takeException(), isNull, reason: "Sara's page");
      await screen.openCard(tester, window.id);
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(
        directionOn(tester, find.byType(WorkspaceScreen)),
        TextDirection.rtl,
      );
      for (final view in WorkspaceView.values) {
        container.read(workspaceProvider.notifier).showView(view);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: view.name);
      }
    });
  }

  testWidgets('the technical drawing is not mirrored in Kurdish', (
    tester,
  ) async {
    final design = screen.drawn(
      customer: 'Sara',
      kind: DesignKind.window,
      edited: DateTime(2026),
    );
    // Its lines alone — no words, which are the language's.
    const layers = CadLayers(
      grid: false,
      dimensions: false,
      annotations: false,
      openings: false,
      grips: false,
    );
    final view = ViewTransform.fit(design.bounds, const Size(400, 300));
    Future<List<int>> paint(Words words) async {
      final recorder = ui.PictureRecorder();
      CadPainter(
        design: design,
        view: view,
        layers: layers,
        words: words,
      ).paint(Canvas(recorder), const Size(400, 300));
      final image = await recorder.endRecording().toImage(400, 300);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    late List<int> english;
    late List<int> sorani;
    await tester.runAsync(() async {
      english = await paint(const EnglishWords());
      sorani = await paint(ArbWords(kurdish));
    });
    expect(sorani, english);
  });

  testWidgets('a design is never renamed by the language', (tester) async {
    SharedPreferences.setMockInitialValues({Language.key: 'ckb'});
    final kept = await screen.keepThree();
    await screen.openTheApp(tester);
    await screen.openCustomer(tester, 'Sara');
    final window = kept.firstWhere((d) => d.kind == DesignKind.window);
    // Its own name, as the user typed it, whatever the language.
    expect(find.text(window.name), findsWidgets);
  });

  test('a container chooses English until told otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(languageProvider), AppLanguage.english);
    expect(container.read(savedLanguageProvider), isNull);
    expect(const ProFrameApp(), isA<ConsumerWidget>());
  });
}

/// Every message key, read from the English ARB on disk.
final Set<String> arbKeys = {
  for (final m in RegExp(
    r'^  "([a-zA-Z0-9]+)":',
    multiLine: true,
  ).allMatches(File('lib/app/l10n/app_en.arb').readAsStringSync()))
    m.group(1)!,
};

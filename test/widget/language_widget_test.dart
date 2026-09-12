import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/state/preferences_controller.dart';
import 'package:proframe/app/state/project_controller.dart';
import 'package:proframe/core/i18n/app_language.dart';
import 'package:proframe/core/i18n/numerals.dart';
import 'package:proframe/core/i18n/strings.dart';
import 'package:proframe/infrastructure/key_value_store.dart';

const phone = Size(390, 844);

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(InMemoryStore())],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ProFrameApp(idFactory: () => 'p1'),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The direction the app is actually laying itself out in.
TextDirection directionOf(WidgetTester tester) => Directionality.of(
      tester.element(find.byType(Scaffold).first),
    );

void main() {
  group('the app speaks the chosen language', () {
    testWidgets('it starts in English', (tester) async {
      await pumpApp(tester);

      expect(find.text('New design'), findsOneWidget);
      expect(directionOf(tester), TextDirection.ltr);
    });

    testWidgets('switching to Arabic changes the words and the direction',
        (tester) async {
      final container = await pumpApp(tester);

      await container
          .read(preferencesControllerProvider.notifier)
          .setLanguage(AppLanguage.arabic);
      await tester.pumpAndSettle();

      expect(find.text('New design'), findsNothing);
      expect(find.text('تصميم جديد'), findsOneWidget);
      expect(
        directionOf(tester),
        TextDirection.rtl,
        reason: 'Arabic must mirror the whole layout, not just the words',
      );
    });

    testWidgets('Kurdish works even though Flutter has no Kurdish',
        (tester) async {
      final container = await pumpApp(tester);

      await container
          .read(preferencesControllerProvider.notifier)
          .setLanguage(AppLanguage.kurdish);
      await tester.pumpAndSettle();

      // The framework's own localisations are borrowed from Arabic, which is
      // what keeps this from throwing.
      expect(tester.takeException(), isNull);
      expect(find.text('دیزاینی نوێ'), findsOneWidget);
      expect(directionOf(tester), TextDirection.rtl);
    });

    testWidgets('the choice is remembered', (tester) async {
      final store = InMemoryStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProFrameApp(idFactory: () => 'p1'),
        ),
      );
      await tester.pumpAndSettle();

      await container
          .read(preferencesControllerProvider.notifier)
          .setLanguage(AppLanguage.kurdish);
      await tester.pumpAndSettle();

      // A second run, reading the same device store.
      final second = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      await second.read(preferencesControllerProvider.future);

      expect(
        second.read(appPreferencesProvider).language,
        AppLanguage.kurdish,
      );
    });

    testWidgets('numbers are written in the chosen digits', (tester) async {
      final container = await pumpApp(tester);
      await container
          .read(preferencesControllerProvider.notifier)
          .setLanguage(AppLanguage.arabic);
      await tester.pumpAndSettle();

      expect(
        container.read(appStringsProvider).numerals,
        NumeralSystem.arabicIndic,
      );
      expect(
        container.read(appStringsProvider)(T.save),
        isNot('Save'),
      );
    });
  });
}

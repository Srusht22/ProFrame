import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/kurdish_framework.dart';
import 'l10n/l10n.dart';
import 'screens/customers_screen.dart';
import 'screens/launch_screen.dart';
import 'state/appearance.dart';
import 'state/language.dart';
import 'theme/app_theme.dart';

/// The application.
class ProFrameApp extends ConsumerWidget {
  const ProFrameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appTitle,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(appearanceProvider),
    // The language is the one chosen in Settings — English until then —
    // never worked out from the device, so the application opens in the
    // language its user left it in. Its direction comes with it: Kurdish
    // runs right to left (`KurdishWidgetsLocalizations`).
    locale: ref.watch(languageProvider).locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...KurdishFramework.delegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The workshop's mark plays once as the app opens, and then hands
    // over to the customers: a customer, then their designs.
    home: LaunchScreen(next: (_) => const CustomersScreen()),
  );
}

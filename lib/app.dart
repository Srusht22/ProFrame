import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/providers.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/app_settings.dart';
import 'shared/providers/settings_notifier.dart';

class ProFrameApp extends ConsumerWidget {
  const ProFrameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);

    return init.when(
      loading: () => const _SplashApp(),
      error: (error, stack) => _SplashApp(error: error.toString()),
      data: (_) => const _ReadyApp(),
    );
  }
}

class _SplashApp extends StatelessWidget {
  final String? error;
  const _SplashApp({this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: AppColors.brandDarkGreen,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brandCream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.window_rounded, color: AppColors.brandDarkGreenDeep, size: 36),
              ),
              const SizedBox(height: 24),
              if (error == null)
                const CircularProgressIndicator(color: AppColors.brandCream)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Could not start ProFrame.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyApp extends ConsumerWidget {
  const _ReadyApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ?? const AppSettings();

    return MaterialApp.router(
      title: 'ProFrame',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router,
      locale: Locale(settings.locale.code),
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('ckb')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: settings.locale.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

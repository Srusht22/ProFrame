import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/customers_screen.dart';
import 'screens/launch_screen.dart';
import 'state/appearance.dart';
import 'theme/app_theme.dart';

/// The application.
class ProFrameApp extends ConsumerWidget {
  const ProFrameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'ProFrame',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(appearanceProvider),
    // The workshop's mark plays once as the app opens, and then hands
    // over to the customers: a customer, then their designs.
    home: LaunchScreen(next: (_) => const CustomersScreen()),
  );
}

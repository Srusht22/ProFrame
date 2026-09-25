import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/designs_screen.dart';
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
    // over to the designs: carry on with one, or begin another.
    home: LaunchScreen(next: (_) => const DesignsScreen()),
  );
}

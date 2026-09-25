import 'package:flutter/material.dart';

import 'screens/launch_screen.dart';
import 'screens/start_screen.dart';
import 'theme/app_theme.dart';

/// The application.
class ProFrameApp extends StatelessWidget {
  const ProFrameApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ProFrame',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        // The workshop's mark plays once as the app opens, and then hands
        // over to the start screen.
        home: LaunchScreen(next: (_) => const StartScreen()),
      );
}

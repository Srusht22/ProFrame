import 'package:flutter/material.dart';

import 'screens/designs_screen.dart';
import 'screens/launch_screen.dart';
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
        // over to the designs: carry on with one, or begin another.
        home: LaunchScreen(next: (_) => const DesignsScreen()),
      );
}

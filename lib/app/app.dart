import 'package:flutter/material.dart';

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
        home: const StartScreen(),
      );
}

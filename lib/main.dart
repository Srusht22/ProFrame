import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/state/language.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The language is read before the first frame, so the application opens
  // in it rather than in English for a moment.
  final language = await Language.read();
  runApp(
    ProviderScope(
      overrides: [savedLanguageProvider.overrideWithValue(language)],
      child: const ProFrameApp(),
    ),
  );
}

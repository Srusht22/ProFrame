import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/state/project_controller.dart';
import 'infrastructure/key_value_store.dart';

/// Entry point only.
///
/// Nothing but wiring lives here (spec section 13): the widget tree is
/// `ProFrameApp`, state lives behind Riverpod providers, and the one thing
/// this file decides is which storage the app runs against.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame so the project list and any recoverable
  // draft are available immediately, rather than the app showing an empty list
  // and then filling it in.
  final store = await DevicePreferencesStore.open();

  runApp(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: ProFrameApp(idFactory: newProjectId),
    ),
  );
}

/// A project id that is unique on this device without needing a server.
///
/// Microsecond resolution plus a monotonic counter, so two designs created in
/// the same microsecond still differ.
String newProjectId() {
  _counter += 1;
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'p$stamp$_counter';
}

int _counter = 0;

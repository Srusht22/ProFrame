import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Entry point only.
///
/// Nothing but wiring lives here (spec section 9): the widget tree is
/// `ProFrameApp`, and state lives behind Riverpod providers.
void main() {
  runApp(
    ProviderScope(
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

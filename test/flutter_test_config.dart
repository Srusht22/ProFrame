import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Every test file starts with the device's storage in memory.
///
/// A test that sets its own (`setMockInitialValues` in its `setUp`) does as
/// it always did. One that does not used to reach the host's real storage
/// on disk, whose answer never comes inside a widget test's own clock — so
/// anything waiting on it waited for ever. Since Phase 33 that matters: who
/// is at the device is read from storage, and nothing that needs a
/// permission is offered until it is known (`Offering.offers`). In memory,
/// it is known at once, as it is on a device.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}

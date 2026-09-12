import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/product/factory_settings.dart';
import 'project_controller.dart';

/// The factory's defaults, loaded from the device store.
class SettingsController extends AsyncNotifier<FactorySettings> {
  static const String storeKey = 'proframe.factorySettings';

  @override
  Future<FactorySettings> build() async {
    final store = ref.watch(keyValueStoreProvider);
    return FactorySettings.decode(await store.read(storeKey));
  }

  /// Saves new defaults. Existing projects are untouched: these apply to the
  /// next design, not retroactively (spec section 10, no silent resets).
  ///
  /// Named `save` rather than `update` because `AsyncNotifier` already defines
  /// an `update` with a different shape.
  Future<void> save(FactorySettings settings) async {
    state = AsyncValue.data(settings);
    await ref.read(keyValueStoreProvider).write(storeKey, settings.encode());
  }

  Future<void> restoreDefaults() => save(FactorySettings.standard);
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, FactorySettings>(
  SettingsController.new,
);

/// The settings as a plain value, falling back to the standard ones while they
/// are still loading — so no screen has to handle a loading state for what is
/// only a set of starting points.
final factorySettingsProvider = Provider<FactorySettings>(
  (ref) =>
      ref.watch(settingsControllerProvider).value ?? FactorySettings.standard,
);

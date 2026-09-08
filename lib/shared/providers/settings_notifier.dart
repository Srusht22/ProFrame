import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/app_settings.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(appRepositoriesProvider).settings.get();
  }

  /// Applies [updater] to the current settings and persists the result.
  /// Named `edit` rather than `update` because `AsyncNotifier` already
  /// declares an `update` method with a different signature.
  Future<void> edit(AppSettings Function(AppSettings current) updater) async {
    final current = state.value ?? const AppSettings();
    final updated = updater(current);
    state = AsyncData(updated);
    await ref.read(appRepositoriesProvider).settings.save(updated);
  }
}

final settingsNotifierProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

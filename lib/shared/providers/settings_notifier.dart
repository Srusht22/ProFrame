import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/app_settings.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(appRepositoriesProvider).settings.get();
  }

  Future<void> update(AppSettings Function(AppSettings current) updater) async {
    final current = state.valueOrNull ?? const AppSettings();
    final updated = updater(current);
    state = AsyncData(updated);
    await ref.read(appRepositoriesProvider).settings.save(updated);
  }
}

final settingsNotifierProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

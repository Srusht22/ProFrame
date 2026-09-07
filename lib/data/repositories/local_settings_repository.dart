import 'dart:convert';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/key_value_store.dart';

class LocalSettingsRepository implements SettingsRepository {
  static const _key = 'app_settings';
  final IKeyValueStore keyValueStore;

  LocalSettingsRepository(this.keyValueStore);

  @override
  Future<AppSettings> get() async {
    final raw = await keyValueStore.read(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await keyValueStore.write(_key, jsonEncode(settings.toJson()));
  }
}

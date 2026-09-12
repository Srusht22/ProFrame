import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_preferences.dart';
import '../../core/i18n/numerals.dart';
import '../../core/i18n/strings.dart';
import 'project_controller.dart';

/// The language and numerals the user reads the app in.
class PreferencesController extends AsyncNotifier<AppPreferences> {
  static const String storeKey = 'proframe.appPreferences';

  @override
  Future<AppPreferences> build() async {
    final store = ref.watch(keyValueStoreProvider);
    return AppPreferences.decode(await store.read(storeKey));
  }

  Future<void> _save(AppPreferences preferences) async {
    state = AsyncValue.data(preferences);
    await ref.read(keyValueStoreProvider).write(storeKey, preferences.encode());
  }

  /// Switches language. The digits move with it, as a starting point the user
  /// can then change — nothing about any saved design is touched.
  Future<void> setLanguage(AppLanguage language) =>
      _save((state.value ?? AppPreferences.standard).withLanguage(language));

  Future<void> setNumerals(NumeralSystem numerals) =>
      _save((state.value ?? AppPreferences.standard).withNumerals(numerals));
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(
  PreferencesController.new,
);

/// The preferences as a plain value, falling back to the standard ones while
/// they load, so no screen has to handle a loading state to know what language
/// to draw itself in.
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) =>
      ref.watch(preferencesControllerProvider).value ?? AppPreferences.standard,
);

/// The phrases for the chosen language.
final appStringsProvider = Provider<AppStrings>((ref) {
  final preferences = ref.watch(appPreferencesProvider);
  return AppStrings(
    language: preferences.language,
    numerals: preferences.numerals,
  );
});

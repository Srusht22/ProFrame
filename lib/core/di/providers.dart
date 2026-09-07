import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/app_repositories.dart';
import '../../data/local/key_value_store.dart';
import '../../domain/pricing/pricing_rules.dart';
import '../../domain/services/manufacturing_engine.dart';
import '../../domain/services/pricing_engine.dart';
import '../../domain/services/validation_engine.dart';
import '../../shared/providers/settings_notifier.dart';

/// Root of the dependency graph. Everything else (repositories, engines,
/// entity notifiers) is derived from these two providers, so tests can
/// override [keyValueStoreProvider] with an in-memory fake without touching
/// any feature code.
final keyValueStoreProvider = Provider<IKeyValueStore>((ref) {
  return SharedPreferencesKeyValueStore();
});

final appRepositoriesProvider = Provider<AppRepositories>((ref) {
  return AppRepositories.local(ref.watch(keyValueStoreProvider));
});

/// Runs once at app start: seeds demo data if this is a fresh install.
/// The root widget waits on this before showing the shell.
final appInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(appRepositoriesProvider).seedDemoDataIfNeeded();
});

final validationEngineProvider = Provider<ValidationEngine>((ref) {
  return const ValidationEngine();
});

final manufacturingEngineProvider = Provider<ManufacturingEngine>((ref) {
  return const ManufacturingEngine();
});

/// Rebuilds whenever pricing rules change in Settings, so every screen
/// reading price always reflects the latest admin-configured rates.
final pricingEngineProvider = Provider<PricingEngine>((ref) {
  final settings = ref.watch(settingsNotifierProvider).valueOrNull;
  return PricingEngine(settings?.pricingRules ?? const PricingRules());
});

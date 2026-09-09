import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pricing/pricing_rules.dart';
import '../../features/projects/design_repository.dart';
import '../../features/recognition/interpretation_service.dart';
import '../constants/app_constants.dart';
import 'key_value_store.dart';

/// Overridden in tests with [InMemoryKeyValueStore] so nothing touches the
/// device.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SharedPreferencesStore());

final designRepositoryProvider =
    Provider<DesignRepository>((ref) => DesignRepository(ref.watch(keyValueStoreProvider)));

final interpretationServiceProvider =
    Provider<InterpretationService>((ref) => const InterpretationService());

class PricingRulesNotifier extends AsyncNotifier<PricingRules> {
  @override
  Future<PricingRules> build() async {
    final store = ref.watch(keyValueStoreProvider);
    final raw = await store.read(AppConstants.pricingKey);
    if (raw == null || raw.isEmpty) return const PricingRules();
    try {
      return PricingRules.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const PricingRules();
    }
  }

  Future<void> save(PricingRules rules) async {
    state = AsyncData(rules);
    await ref
        .read(keyValueStoreProvider)
        .write(AppConstants.pricingKey, jsonEncode(rules.toJson()));
  }
}

final pricingRulesProvider =
    AsyncNotifierProvider<PricingRulesNotifier, PricingRules>(PricingRulesNotifier.new);

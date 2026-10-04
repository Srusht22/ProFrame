import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/pricing_engine.dart';
import '../../infrastructure/price_list_store.dart';
import 'workspace.dart';

/// Where the price list is kept.
final priceListStoreProvider = Provider<PriceListStore>(
  (ref) => PriceListStore(),
);

/// The price list designs are priced by, as kept on the device. Read again
/// when the owner keeps a new one ([PriceListSaver]).
final priceListProvider = FutureProvider<PriceList>(
  (ref) => ref.watch(priceListStoreProvider).load(),
);

/// Who is using the device. Starts as staff — see [WorkshopRole].
final workshopRoleProvider = NotifierProvider<WorkshopRoleNow, WorkshopRole>(
  WorkshopRoleNow.new,
);

class WorkshopRoleNow extends Notifier<WorkshopRole> {
  @override
  WorkshopRole build() => WorkshopRole.staff;

  void become(WorkshopRole role) => state = role;
}

/// The engine every price is worked out by.
final pricingEngineProvider = Provider<PricingEngine>(
  (ref) => const PricingEngine(),
);

/// The price of the design open in the workspace, worked out afresh
/// whenever the design or the price list changes — a size, a material, a
/// colour, a glass, a hinge, an opening — and null while the list is still
/// being read. Nothing about it is kept: it is the design priced, now.
final designPriceProvider = Provider<PriceResult?>((ref) {
  final design = ref.watch(workspaceProvider.select((s) => s.design));
  final list = ref.watch(priceListProvider).value;
  if (list == null) return null;
  return ref.watch(pricingEngineProvider).price(design, list);
});

/// Keeps a new price list, as the role using the device, and has every
/// price worked out from it.
extension PriceListSaver on WidgetRef {
  Future<PriceList> savePriceList(PriceList list) async {
    final kept = await read(priceListStoreProvider)
        .save(list, by: read(workshopRoleProvider));
    invalidate(priceListProvider);
    return kept;
  }
}

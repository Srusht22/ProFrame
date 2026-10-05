import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/design.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/pricing_engine.dart';
import '../../infrastructure/price_list_store.dart';
import '../../infrastructure/price_record_store.dart';
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

/// The designs' kept prices left behind by deletes made before a delete
/// took its design's price with it, swept once a run
/// (`DesignStore.sweepOrphanPrices`), with whose they were. A failure to
/// sweep stops nothing: the prices stay where they are, unread.
final orphanPricesSweptProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.read(designStoreProvider).sweepOrphanPrices();
  } on Object {
    return const [];
  }
});

/// Where each design's calculated price is kept.
final priceRecordStoreProvider = Provider<PriceRecordStore>(
  (ref) => PriceRecordStore(),
);

/// Changes whenever a price is calculated, so everything showing one reads
/// it again.
final priceRecordsRevisionProvider = NotifierProvider<DesignsRevision, int>(
  DesignsRevision.new,
);

/// The price kept for the design [designId], if any.
final priceRecordProvider = FutureProvider.autoDispose
    .family<PriceRecord?, String>((ref, designId) {
      ref.watch(priceRecordsRevisionProvider);
      return ref.read(priceRecordStoreProvider).load(designId);
    });

/// Where the price of the design open in the workspace stands — the same
/// [DesignPriceState] its card and its customer's total read — worked out
/// afresh with every edit, so the price button is enabled exactly while
/// the design can be priced. Null while the price list or the kept price is
/// still being read.
final workspacePriceStateProvider = Provider<DesignPriceState?>((ref) {
  final design = ref.watch(workspaceProvider.select((s) => s.design));
  final list = ref.watch(priceListProvider);
  final record = ref.watch(priceRecordProvider(design.id));
  if (!list.hasValue || !record.hasValue) return null;
  return DesignPriceState.of(
    design,
    list.requireValue,
    record.requireValue,
    engine: ref.watch(pricingEngineProvider),
  );
});

/// A kept design and where its price stands, for its card: the design as
/// kept, read again whenever designs are kept, a price is calculated or
/// the price list changes. Null where the design cannot be read.
final keptDesignPriceProvider = FutureProvider.autoDispose
    .family<KeptDesignPrice?, String>((ref, designId) async {
      ref
        ..watch(designsRevisionProvider)
        ..watch(priceRecordsRevisionProvider);
      final list = await ref.watch(priceListProvider.future);
      final Design? design;
      try {
        design = await ref.read(designStoreProvider).load(designId);
      } on Object {
        return null;
      }
      if (design == null) return null;
      final record = await ref.read(priceRecordStoreProvider).load(designId);
      return KeptDesignPrice(
        design,
        DesignPriceState.of(
          design,
          list,
          record,
          engine: ref.read(pricingEngineProvider),
        ),
      );
    });

/// A design as kept, with where its price stands.
class KeptDesignPrice {
  final Design design;
  final DesignPriceState state;

  const KeptDesignPrice(this.design, this.state);
}

/// What customer [customerId]'s designs come to — each design's own price
/// state, from what is kept, and their sum where it is final. Worked out
/// afresh whenever a design is kept, a price calculated or the price list
/// changed; nothing of it is kept on the customer.
final customerPricingProvider = FutureProvider.autoDispose
    .family<CustomerPricing, String>((ref, customerId) async {
      ref
        ..watch(designsRevisionProvider)
        ..watch(priceRecordsRevisionProvider);
      final list = await ref.watch(priceListProvider.future);
      final store = ref.read(designStoreProvider);
      final records = ref.read(priceRecordStoreProvider);
      final page = await store.page(customerId: customerId, limit: 1 << 20);
      final designs = <(Design, PriceRecord?)>[];
      for (final s in page.items) {
        final d = await store.load(s.id);
        if (d != null) designs.add((d, await records.load(d.id)));
      }
      return CustomerPricing.of(
        designs,
        list,
        engine: ref.read(pricingEngineProvider),
      );
    });

/// Calculating a price: the one way a price is kept.
extension PriceCalculator on WidgetRef {
  /// [design] calculated from the price list now, by the one engine, and
  /// kept as its price — or null where it cannot be priced, when nothing is
  /// kept. It writes nothing to the design.
  Future<PriceRecord?> calculatePrice(Design design) async {
    final list = await read(priceListProvider.future);
    final record = PriceRecord.calculate(
      design,
      list,
      engine: read(pricingEngineProvider),
    );
    if (record == null) return null;
    await read(priceRecordStoreProvider).save(design.id, record);
    read(priceRecordsRevisionProvider.notifier).changed();
    return record;
  }

  /// [design]'s price as it now is: calculated and kept where it can be
  /// priced, and otherwise what stands in the way — for a sheet that shows
  /// either, never a price kept from before.
  Future<PriceResult?> priceNow(Design design) async {
    final record = await calculatePrice(design);
    if (record != null) return record.result;
    final list = await read(priceListProvider.future);
    return read(pricingEngineProvider).price(design, list);
  }

  /// Records that customer [customer] has paid [amount], and nothing else
  /// about them. It touches no design.
  Future<Customer> recordPaid(Customer customer, double amount) async {
    final kept = await read(
      customerStoreProvider,
    ).save(customer.copyWith(paid: (amount * 100).roundToDouble() / 100));
    read(customersRevisionProvider.notifier).changed();
    return kept;
  }
}

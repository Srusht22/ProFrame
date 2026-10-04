import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/pricing_engine.dart';
import '../inspector/price_panel.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';

/// **All designs** on a customer's page: what every design of theirs comes
/// to together, and what they measure together.
///
/// It is `customerPricingProvider` — each design priced on its own from
/// what is kept — and holds no figure of its own. Folded, it is the total
/// and the total profile; open, it lists every design's own total and the
/// measurements, profile in metres and glass and panel in square metres. A
/// design that cannot be priced is named and left out of the total, and the
/// heading says how many were priced.
class CustomerPriceCard extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerPriceCard({super.key, required this.customerId});

  static const cardKey = ValueKey('customer-price');
  static const totalKey = ValueKey('customer-price-total');
  static const toggleKey = ValueKey('customer-price-toggle');
  static ValueKey<String> designKey(String id) =>
      ValueKey('customer-price-design-$id');

  @override
  ConsumerState<CustomerPriceCard> createState() => _CustomerPriceCardState();
}

class _CustomerPriceCardState extends ConsumerState<CustomerPriceCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pricing = ref.watch(customerPricingProvider(widget.customerId)).value;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    if (pricing == null || pricing.designs.isEmpty) {
      return const SizedBox.shrink();
    }
    final currency = pricing.currency;
    final priced = pricing.priced.length;
    return Container(
      key: CustomerPriceCard.cardKey,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: CustomerPriceCard.toggleKey,
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All designs', style: text.titleSmall),
                      Text(
                        pricing.complete
                            ? 'Total profile '
                                  '${pricing.measurements.totalProfile.label}'
                            : '$priced of ${pricing.designs.length} '
                                  'designs priced',
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  PricePanel.money(pricing.total, currency),
                  key: CustomerPriceCard.totalKey,
                  style: text.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (final d in pricing.designs)
              _DesignLine(
                key: CustomerPriceCard.designKey(d.designId),
                d,
                currency,
              ),
            const Divider(height: 18),
            MeasurementRows(pricing.measurements),
          ],
        ],
      ),
    );
  }
}

class _DesignLine extends StatelessWidget {
  final DesignPrice design;
  final String currency;

  const _DesignLine(this.design, this.currency, {super.key});

  @override
  Widget build(BuildContext context) {
    final result = design.result;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final value = switch (result.status) {
      PriceStatus.priced => PricePanel.money(result.total!, currency),
      PriceStatus.unsupportedCategory => 'Price unavailable',
      PriceStatus.needsSizes => 'Sizes not given',
      PriceStatus.nothingToPrice => 'Nothing drawn',
      _ => 'Not priced',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(design.name, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/measurement.dart';
import '../../domain/pricing/price_result.dart';
import '../state/pricing.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// What the design open comes to, under **Price** in its own panel.
///
/// It shows the result the pricing engine gives for the design as it is
/// now (`designPriceProvider`) and works nothing out itself: no figure is
/// in this widget, and it changes nothing in the design but the one choice
/// it offers — whether installation is included, which is the user's to
/// make and never made for them. Where the design cannot be priced it says
/// why, in words, and shows no figure at all.
///
/// The full breakdown is folded under the total, by group. How a price is
/// presented will be refined later; what it is made of is already all here.
class PricePanel extends ConsumerStatefulWidget {
  const PricePanel({super.key});

  static const panelKey = ValueKey('price-panel');
  static const totalKey = ValueKey('price-total');
  static const installationKey = ValueKey('price-installation');
  static const breakdownKey = ValueKey('price-breakdown');

  /// [amount] in [currency], to the hundredth, with the thousands marked:
  /// `1,150.00 USD`.
  static String money(double amount, String currency) {
    final text = amount.toStringAsFixed(2);
    final parts = text.split('.');
    final digits = parts.first;
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0 && digits[i - 1] != '-') {
        grouped.write(',');
      }
      grouped.write(digits[i]);
    }
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    return '$grouped$fraction $currency';
  }

  /// What a line counts and at what: `7.60 m × 7.00`, `2.00 m² × 30.00`,
  /// `3 × 3.00`, `10% of 600.00`.
  static String quantity(PriceLine line) => switch (line.unit) {
    PriceUnit.metre =>
      '${Metres(line.quantity).label} × '
          '${line.rate.toStringAsFixed(2)}',
    PriceUnit.squareMetre =>
      '${SquareMetres(line.quantity).label} × '
          '${line.rate.toStringAsFixed(2)}',
    PriceUnit.each =>
      '${line.quantity.round()} × '
          '${line.rate.toStringAsFixed(2)}',
    PriceUnit.percent =>
      '${line.quantity}% of '
          '${line.rate.toStringAsFixed(2)}',
    PriceUnit.fixed => 'fixed',
  };

  @override
  ConsumerState<PricePanel> createState() => _PricePanelState();
}

class _PricePanelState extends ConsumerState<PricePanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(designPriceProvider);
    final starter = ref.watch(
      priceListProvider.select((l) => l.value?.isStarter ?? false),
    );
    final choices = ref.watch(
      workspaceProvider.select((s) => s.design.pricing),
    );
    final unsupported = ref.watch(
      workspaceProvider.select((s) => s.design.isUnsupported),
    );
    final text = Theme.of(context).textTheme;
    final p = context.palette;

    return Column(
      key: PricePanel.panelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PRICE', style: text.labelLarge),
        const SizedBox(height: 6),
        if (result == null)
          Text('Reading the price list…', style: text.bodySmall)
        else if (!result.isPriced) ...[
          Text(
            result.status == PriceStatus.unsupportedCategory
                ? 'Price unavailable'
                : 'Not priced yet',
            style: text.titleMedium,
          ),
          const SizedBox(height: 4),
          for (final issue in result.issues)
            Text(issue.message, style: text.bodySmall),
        ] else ...[
          MeasurementRows(result.measurements),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Total', style: text.titleMedium)),
              Text(
                PricePanel.money(result.total!, result.currency),
                key: PricePanel.totalKey,
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (result.discountAmount > 0) ...[
            _Row(
              'Subtotal',
              PricePanel.money(result.subtotal, result.currency),
            ),
            _Row(
              'Discount',
              '− ${PricePanel.money(result.discountAmount, result.currency)}',
            ),
          ],
          if (starter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Example prices — the workshop owner sets the real ones.',
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          TextButton.icon(
            key: PricePanel.breakdownKey,
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_open ? 'Hide the breakdown' : 'Show the breakdown'),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          ),
          if (_open)
            for (final group in PriceGroup.values)
              if (result.lines.any((l) => l.group == group)) ...[
                const SizedBox(height: 6),
                Text(group.label, style: text.labelMedium),
                for (final line in result.lines)
                  if (line.group == group)
                    _Row(
                      '${line.label} · ${PricePanel.quantity(line)}',
                      PricePanel.money(line.amount, result.currency),
                    ),
                _Row(
                  '${group.label} in all',
                  PricePanel.money(result.sumOf(group), result.currency),
                  strong: true,
                ),
              ],
        ],
        Row(
          children: [
            Expanded(
              child: Text('Include installation', style: text.bodyMedium),
            ),
            Switch(
              key: PricePanel.installationKey,
              value: choices.installation,
              onChanged: unsupported
                  ? null
                  : (on) => ref
                        .read(workspaceProvider.notifier)
                        .setPricing(choices.copyWith(installation: on)),
            ),
          ],
        ),
      ],
    );
  }
}

/// What a design, or a customer's designs, measure: each kind of profile
/// and the total profile in metres, then panel and glass in square metres —
/// two kinds of figure, each with its own unit, never added together.
class MeasurementRows extends StatelessWidget {
  final MeasurementSummary measurements;

  const MeasurementRows(this.measurements, {super.key});

  static const totalProfileKey = ValueKey('measure-total-profile');

  @override
  Widget build(BuildContext context) {
    final m = measurements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row('Normal profile', m.normalProfile.label),
        _Row('Opening profile', m.openingProfile.label),
        if (m.otherProfile.value > 0)
          _Row('Other profile', m.otherProfile.label),
        _Row(
          'Total profile',
          m.totalProfile.label,
          strong: true,
          valueKey: totalProfileKey,
        ),
        _Row('Panel', m.panelArea.label),
        _Row('Glass', m.glassArea.label),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Key? valueKey;

  const _Row(this.label, this.value, {this.strong = false, this.valueKey});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: strong ? FontWeight.w600 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, key: valueKey, style: style),
        ],
      ),
    );
  }
}

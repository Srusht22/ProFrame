import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/pricing/price_breakdown.dart';

/// The transparent line-by-line price breakdown the spec insists on
/// (§15) — never just a total.
class PriceBreakdownView extends StatelessWidget {
  final PriceBreakdown breakdown;

  const PriceBreakdownView({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, double amount, {bool bold = false, bool muted = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: bold
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium?.copyWith(color: muted ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : null),
            ),
            Text(
              breakdown.currency.format(amount),
              style: bold
                  ? theme.textTheme.titleMedium?.copyWith(color: AppColors.brandDarkGreen, fontWeight: FontWeight.w800)
                  : theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Materials', style: theme.textTheme.titleSmall),
        for (final line in breakdown.materialLines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.label, style: theme.textTheme.bodyMedium),
                      if (line.description != null)
                        Text(line.description!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                Text(breakdown.currency.format(line.amount), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        const Divider(height: AppSpacing.lg),
        row('Materials subtotal', breakdown.materialsSubtotal, muted: true),
        row('Labor', breakdown.labor),
        if (breakdown.finishing > 0) row('Finishing', breakdown.finishing),
        row('Waste', breakdown.waste),
        row('Overhead', breakdown.overhead),
        const Divider(height: AppSpacing.lg),
        row('Subtotal', breakdown.subtotal, muted: true),
        row('Profit', breakdown.profit),
        const Divider(height: AppSpacing.lg),
        row('Unit price', breakdown.unitPrice, bold: true),
        if (breakdown.quantity > 1) ...[
          const SizedBox(height: 4),
          row('× ${breakdown.quantity} units — line total', breakdown.lineTotal, bold: true),
        ],
      ],
    );
  }
}

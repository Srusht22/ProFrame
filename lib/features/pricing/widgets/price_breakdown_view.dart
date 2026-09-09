import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../pricing_engine.dart';
import '../screens/pricing_settings_screen.dart';

/// The price, worked out from the geometry that was actually generated —
/// profile lengths, glass areas, hardware counts (§42).
class PriceBreakdownView extends ConsumerWidget {
  final OpeningModel model;

  const PriceBreakdownView({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(pricingRulesProvider);
    final rules = rulesAsync.value;
    if (rules == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final breakdown = PricingEngine(rules: rules).price(model);
    final symbol = breakdown.currencySymbol;

    String money(double value) => '$symbol${value.toStringAsFixed(2)}';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          color: AppColors.brandDarkGreen,
          border: Border.all(color: AppColors.brandDarkGreen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated price',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: AppColors.brandCream),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(breakdown.total),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.brandCream,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${model.widthMm.round()} × ${model.heightMm.round()} mm · '
                '${model.areaM2.toStringAsFixed(2)} m²',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textOnDarkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Group(title: 'Materials', lines: breakdown.materials, money: money),
        _Group(title: 'Hardware', lines: breakdown.hardware, money: money),
        _Group(title: 'Labour', lines: breakdown.labour, money: money),
        const Divider(height: AppSpacing.lg),
        _TotalRow(label: 'Direct cost', value: money(breakdown.directTotal)),
        _TotalRow(
          label: 'Waste ${(rules.wasteRate * 100).round()}%',
          value: money(breakdown.wasteAmount),
        ),
        _TotalRow(
          label: 'Overhead ${(rules.overheadRate * 100).round()}%',
          value: money(breakdown.overheadAmount),
        ),
        _TotalRow(
          label: 'Margin ${(rules.profitRate * 100).round()}%',
          value: money(breakdown.profitAmount),
        ),
        const Divider(height: AppSpacing.lg),
        _TotalRow(label: 'Total', value: money(breakdown.total), emphasise: true),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => PricingSettingsScreen.show(context),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Edit rates'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Worked out from the generated geometry — profile metres, glazed '
          'area and hardware counts. An estimate, not a quotation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<PriceLine> lines;
  final String Function(double) money;

  const _Group({required this.title, required this.lines, required this.money});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.label, style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        '${line.quantity} ${line.unit} × ${money(line.rate)} · ${line.detail}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(money(line.total), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _TotalRow({required this.label, required this.value, this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    final style = emphasise
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

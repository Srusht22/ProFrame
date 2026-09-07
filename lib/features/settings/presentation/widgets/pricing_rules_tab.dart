import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/configuration/config_enums.dart';
import '../../../../domain/pricing/pricing_rules.dart';
import '../../../../shared/providers/settings_notifier.dart';
import '../../../../shared/widgets/async_value_view.dart';

class PricingRulesTab extends ConsumerWidget {
  const PricingRulesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    return AsyncValueView(
      value: settingsAsync,
      onRetry: () => ref.invalidate(settingsNotifierProvider),
      builder: (settings) => _PricingForm(rules: settings.pricingRules),
    );
  }
}

class _PricingForm extends ConsumerStatefulWidget {
  final PricingRules rules;
  const _PricingForm({required this.rules});

  @override
  ConsumerState<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends ConsumerState<_PricingForm> {
  late PricingRules _rules;

  @override
  void initState() {
    super.initState();
    _rules = widget.rules;
  }

  Future<void> _save() async {
    await ref.read(settingsNotifierProvider.notifier).update((current) => current.copyWith(pricingRules: _rules));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pricing rules saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Every rate here drives the live pricing engine — no prices are hard-coded in the app.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Cost structure (%)',
          child: Row(children: [
            Expanded(
              child: _PercentField(
                label: 'Labor',
                value: _rules.laborPercent,
                onChanged: (v) => setState(() => _rules = _rules.copyWith(laborPercent: v)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PercentField(
                label: 'Waste',
                value: _rules.wastePercent,
                onChanged: (v) => setState(() => _rules = _rules.copyWith(wastePercent: v)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PercentField(
                label: 'Overhead',
                value: _rules.overheadPercent,
                onChanged: (v) => setState(() => _rules = _rules.copyWith(overheadPercent: v)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PercentField(
                label: 'Profit',
                value: _rules.profitPercent,
                onChanged: (v) => setState(() => _rules = _rules.copyWith(profitPercent: v)),
              ),
            ),
          ]),
        ),
        _SectionCard(
          title: 'Frame — price per meter',
          child: _RateGrid<FrameMaterial>(
            values: FrameMaterial.values,
            labelOf: (v) => v.label,
            rates: _rules.framePricePerMeter,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(framePricePerMeter: m)),
          ),
        ),
        _SectionCard(
          title: 'Glass — price per m²',
          child: _RateGrid<GlassType>(
            values: GlassType.values,
            labelOf: (v) => v.label,
            rates: _rules.glassPricePerSqm,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(glassPricePerSqm: m)),
          ),
        ),
        _SectionCard(
          title: 'Panel — price per m²',
          child: _RateGrid<PanelType>(
            values: PanelType.values,
            labelOf: (v) => v.label,
            rates: _rules.panelPricePerSqm,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(panelPricePerSqm: m)),
          ),
        ),
        _SectionCard(
          title: 'Locks',
          child: _RateGrid<LockType>(
            values: LockType.values,
            labelOf: (v) => v.label,
            rates: _rules.lockPrice,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(lockPrice: m)),
          ),
        ),
        _SectionCard(
          title: 'Door closers',
          child: _RateGrid<DoorCloserType>(
            values: DoorCloserType.values,
            labelOf: (v) => v.label,
            rates: _rules.doorCloserPrice,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(doorCloserPrice: m)),
          ),
        ),
        _SectionCard(
          title: 'Hardware & accessories — flat rates',
          child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            _SingleRateField(label: 'Hinge (each)', value: _rules.hingePriceEach, onChanged: (v) => setState(() => _rules = _rules.copyWith(hingePriceEach: v))),
            _SingleRateField(label: 'Handle (base)', value: _rules.handleBasePrice, onChanged: (v) => setState(() => _rules = _rules.copyWith(handleBasePrice: v))),
            _SingleRateField(label: 'Accessory (flat)', value: _rules.accessoryFlatPrice, onChanged: (v) => setState(() => _rules = _rules.copyWith(accessoryFlatPrice: v))),
            _SingleRateField(label: 'Mosquito net /m²', value: _rules.mosquitoNetPricePerSqm, onChanged: (v) => setState(() => _rules = _rules.copyWith(mosquitoNetPricePerSqm: v))),
            _SingleRateField(label: 'Seal /m', value: _rules.sealPricePerMeter, onChanged: (v) => setState(() => _rules = _rules.copyWith(sealPricePerMeter: v))),
            _SingleRateField(label: 'Installation /unit', value: _rules.installationPricePerUnit, onChanged: (v) => setState(() => _rules = _rules.copyWith(installationPricePerUnit: v))),
            _SingleRateField(label: 'Delivery (flat)', value: _rules.deliveryFlatPrice, onChanged: (v) => setState(() => _rules = _rules.copyWith(deliveryFlatPrice: v))),
          ]),
        ),
        _SectionCard(
          title: 'Finish multiplier',
          child: _RateGrid<FrameColor>(
            values: FrameColor.values,
            labelOf: (v) => v.label,
            rates: _rules.finishMultiplier,
            onChanged: (m) => setState(() => _rules = _rules.copyWith(finishMultiplier: m)),
            decimals: 2,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: _save, child: const Text('Save pricing rules')),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _PercentField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: (value * 100).toStringAsFixed(1),
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed / 100);
      },
    );
  }
}

class _SingleRateField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SingleRateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextFormField(
        initialValue: value.toStringAsFixed(2),
        decoration: InputDecoration(labelText: label, prefixText: '\$'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _RateGrid<T extends Enum> extends StatelessWidget {
  final List<T> values;
  final String Function(T) labelOf;
  final Map<T, double> rates;
  final ValueChanged<Map<T, double>> onChanged;
  final int decimals;

  const _RateGrid({
    required this.values,
    required this.labelOf,
    required this.rates,
    required this.onChanged,
    this.decimals = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final v in values)
          SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: (rates[v] ?? 0).toStringAsFixed(decimals),
              decoration: InputDecoration(labelText: labelOf(v), prefixText: '\$'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed == null) return;
                onChanged({...rates, v: parsed});
              },
            ),
          ),
      ],
    );
  }
}

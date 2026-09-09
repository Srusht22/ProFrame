import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../pricing_rules.dart';

/// Every rate the pricing engine uses, editable and saved to the device.
///
/// Nothing here is hard-coded in the UI — the engine reads these values, so a
/// factory can price with its own numbers without touching source code (§66).
class PricingSettingsScreen extends ConsumerWidget {
  const PricingSettingsScreen({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.92,
          child: PricingSettingsScreen(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(pricingRulesProvider);
    final rules = rulesAsync.value;
    if (rules == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final notifier = ref.read(pricingRulesProvider.notifier);
    void save(PricingRules updated) => notifier.save(updated);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionHeader(
          title: 'Pricing rates',
          subtitle: 'Used for every design on this device',
        ),
        _CurrencyField(
          value: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(currencySymbol: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Profile, per linear metre'),
        for (final material in FrameMaterial.values)
          _RateGroup(
            title: material.label,
            rows: [
              (
                'Outer frame',
                rules.framePerMetre[material] ?? 0,
                (double v) => save(rules.withFrameRate(material, v)),
              ),
              (
                'Sash / leaf',
                rules.sashPerMetre[material] ?? 0,
                (double v) => save(rules.withSashRate(material, v)),
              ),
              (
                'Mullion / transom',
                rules.barPerMetre[material] ?? 0,
                (double v) => save(rules.withBarRate(material, v)),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Glazing, per square metre'),
        for (final glass in GlassType.values)
          _RateField(
            label: glass.label,
            value: rules.glassPerSquareMetre[glass] ?? 0,
            symbol: rules.currencySymbol,
            onChanged: (value) => save(rules.withGlassRate(glass, value)),
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Solid infill, per square metre'),
        for (final panel in PanelMaterial.values)
          _RateField(
            label: panel.label,
            value: rules.panelPerSquareMetre[panel] ?? 0,
            symbol: rules.currencySymbol,
            onChanged: (value) => save(rules.withPanelRate(panel, value)),
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Hardware'),
        _RateField(
          label: 'Hinge, each',
          value: rules.hingeEach,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(hingeEach: value)),
        ),
        _RateField(
          label: 'Handle, each',
          value: rules.handleEach,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(handleEach: value)),
        ),
        _RateField(
          label: 'Lock, each',
          value: rules.lockEach,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(lockEach: value)),
        ),
        _RateField(
          label: 'Sliding track, per metre',
          value: rules.slidingTrackPerMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(slidingTrackPerMetre: value)),
        ),
        _RateField(
          label: 'Weather seal, per metre',
          value: rules.sealPerMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(sealPerMetre: value)),
        ),
        _RateField(
          label: 'Threshold, per metre',
          value: rules.thresholdPerMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(thresholdPerMetre: value)),
        ),
        _RateField(
          label: 'Window sill, per metre',
          value: rules.sillPerMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(sillPerMetre: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Labour, per square metre'),
        _RateField(
          label: 'Fabrication',
          value: rules.labourPerSquareMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) => save(rules.copyWith(labourPerSquareMetre: value)),
        ),
        _RateField(
          label: 'Installation',
          value: rules.installationPerSquareMetre,
          symbol: rules.currencySymbol,
          onChanged: (value) =>
              save(rules.copyWith(installationPerSquareMetre: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Margins',
          subtitle: 'Applied in order: waste, then overhead, then margin',
        ),
        _PercentSlider(
          label: 'Waste',
          value: rules.wasteRate,
          onChanged: (value) => save(rules.copyWith(wasteRate: value)),
        ),
        _PercentSlider(
          label: 'Overhead',
          value: rules.overheadRate,
          onChanged: (value) => save(rules.copyWith(overheadRate: value)),
        ),
        _PercentSlider(
          label: 'Margin',
          value: rules.profitRate,
          onChanged: (value) => save(rules.copyWith(profitRate: value)),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => save(const PricingRules()),
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset to the shipped rates'),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

typedef _RateRow = (String label, double value, ValueChanged<double> onChanged);

class _RateGroup extends StatelessWidget {
  final String title;
  final List<_RateRow> rows;

  const _RateGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final row in rows)
              _RateField(label: row.$1, value: row.$2, onChanged: row.$3),
          ],
        ),
      ),
    );
  }
}

/// A money field that commits on submit or focus loss, so typing never
/// re-prices on every keystroke.
class _RateField extends StatefulWidget {
  final String label;
  final double value;
  final String? symbol;
  final ValueChanged<double> onChanged;

  const _RateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.symbol,
  });

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.toStringAsFixed(2));
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _RateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != oldWidget.value) {
      _controller.text = widget.value.toStringAsFixed(2);
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      _controller.text = widget.value.toStringAsFixed(2);
      return;
    }
    if (parsed != widget.value) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _commit(),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixText: widget.symbol,
            isDense: true,
          ),
        ),
      );
}

class _CurrencyField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CurrencyField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        for (final symbol in const [r'$', '€', '£', '﷼', 'IQD ', 'د.ع '])
          ChoiceChip(
            label: Text(symbol.trim()),
            selected: symbol == value,
            onSelected: (_) => onChanged(symbol),
          ),
      ],
    );
  }
}

class _PercentSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _PercentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(
              '${(value * 100).round()}%',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0.0, 0.6).toDouble(),
          max: 0.6,
          divisions: 60,
          label: '${(value * 100).round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

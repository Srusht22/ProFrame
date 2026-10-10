import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/measurement.dart';
import '../../domain/pricing/price_readiness.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/profile_selection.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'extra_charges.dart';
import 'price_actions.dart';
import 'pricing_options.dart';
import 'profile_chooser.dart';

/// What the design open comes to, under **Price** in its own panel.
///
/// It shows where the design's price stands (`workspacePriceStateProvider`,
/// the same state its card and its customer's total read): what it
/// measures while it can be measured, the price while the one calculated
/// is current, **Calculate price** — enabled only while the design can be
/// priced — and why not where it cannot. A price calculated before the
/// design changed is shown only as a previous calculation, struck through.
/// No figure is in this widget, and it changes nothing in the design but
/// the one choice it offers — whether installation is included.
class PricePanel extends ConsumerStatefulWidget {
  const PricePanel({super.key});

  static const panelKey = ValueKey('price-panel');
  static const totalKey = ValueKey('price-total');
  static const installationKey = ValueKey('price-installation');
  static const breakdownKey = ValueKey('price-breakdown');
  static const calculateKey = ValueKey('price-calculate');
  static const stateKey = ValueKey('price-state');
  static const profileKey = ValueKey('price-profile');
  static const previousKey = ValueKey('price-previous');
  static const migratedKey = ValueKey('price-migrated');

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

/// Calculates the price of the design open in the workspace, keeps it, and
/// shows it: what **Calculate price** does, on the bar and in the panel.
Future<void> calculateOpenDesign(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(workspaceProvider.notifier);
  final design = ref.read(workspaceProvider).design;
  // Kept as it is — nothing in it changed — so its card shows the price
  // just calculated.
  await controller.keep();
  final result = await ref.priceNow(design);
  if (result == null || !context.mounted) return;
  await DesignPriceSheet.show(
    context,
    design: design,
    result: result,
    onChoose: (ref, material, colour, colourId) async {
      final controller = ref.read(workspaceProvider.notifier)
        ..chooseProfile(
          material: material,
          colour: colour,
          colourId: colourId,
        );
      await controller.keep();
      final now = ref.read(workspaceProvider).design;
      final priced = await ref.priceNow(now);
      return priced == null ? null : (now, priced);
    },
    // An extra or the discount changed on the sheet goes into the design
    // in hand as its pricing alone, is kept, and is priced afresh.
    onPricing: (ref, changed) async {
      final controller = ref.read(workspaceProvider.notifier)
        ..setPricing(changed.pricing);
      await controller.keep();
      final now = ref.read(workspaceProvider).design;
      final priced = await ref.priceNow(now);
      return priced == null ? null : (now, priced);
    },
  );
}

/// **Calculate price** on the workspace's bar, beside Save: always there,
/// and enabled only while the design open can be priced.
class WorkspacePriceButton extends ConsumerWidget {
  final bool compact;
  final Color? colour;

  const WorkspacePriceButton({super.key, this.compact = false, this.colour});

  static const buttonKey = ValueKey('workspace-calculate-price');

  @override
  Widget build(BuildContext context, WidgetRef ref) => PriceButton(
    key: buttonKey,
    state: ref.watch(workspacePriceStateProvider),
    compact: compact,
    colour: colour,
    allowed: ref.watch(actorProvider).can(Capability.pricingView),
    onPressed: () => calculateOpenDesign(context, ref),
  );
}

class _PricePanelState extends ConsumerState<PricePanel> {
  bool _open = false;

  Future<void> _calculate() => calculateOpenDesign(context, ref);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspacePriceStateProvider);
    // What the design measures, while it can be measured: a fact about
    // its geometry, never a price.
    final live = ref.watch(designPriceProvider);
    final starter = ref.watch(
      priceListProvider.select((l) => l.value?.isStarter ?? false),
    );
    final migration = ref.watch(
      priceListProvider.select(
        (l) => l.value?.migratedFrom == null ? null : l.value!.migrationNotes,
      ),
    );
    final choices = ref.watch(
      workspaceProvider.select((s) => s.design.pricing),
    );
    final unsupported = ref.watch(
      workspaceProvider.select((s) => s.design.isUnsupported),
    );
    // The profile its price reads: the frame's finish, and whether it was
    // chosen.
    ref.watch(
      workspaceProvider.select(
        (s) => (s.design.frame?.finish, s.design.profileChosen),
      ),
    );
    final design = ref.read(workspaceProvider).design;
    final list = ref.watch(priceListProvider).value;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final result = state?.isCurrent ?? false ? state!.record!.result : null;
    final currency = live?.currency ?? result?.currency ?? '';

    return Column(
      key: PricePanel.panelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PRICE', style: text.labelLarge),
        const SizedBox(height: 6),
        // What the design is made of, chosen here as in the frame's own
        // panel: the material and colour whose rates its price reads.
        if (list != null && design.frame != null && !unsupported) ...[
          ProfileChooser(
            key: PricePanel.profileKey,
            selection: ProfileSelection.of(design),
            current: design.frame!.finish,
            list: list,
            onChanged: (material, colour, colourId) => ref
                .read(workspaceProvider.notifier)
                .chooseProfile(
                  material: material,
                  colour: colour,
                  colourId: colourId,
                ),
          ),
          const SizedBox(height: 10),
          PricingOptions(
            design: design,
            onChange: !ref.offers(Capability.designsEdit)
                ? null
                : (change) async {
                    final by = await ref.actorNow();
                    final Design changed;
                    try {
                      changed = change(by);
                    } on AccessDenied catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                      return;
                    }
                    ref
                        .read(workspaceProvider.notifier)
                        .setPricing(changed.pricing);
                  },
          ),
          const SizedBox(height: 10),
        ],
        if (state == null)
          Text('Reading the price list…', style: text.bodySmall)
        else ...[
          if (live != null && live.isPriced) ...[
            MeasurementRows(live.measurements),
            const SizedBox(height: 6),
          ],
          if (result != null)
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
            )
          else ...[
            Text(
              state.note,
              key: PricePanel.stateKey,
              style: text.titleMedium,
            ),
            if (state.status != DesignPriceStatus.notCalculated &&
                state.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  // A problem with the geometry is said in full under the
                  // drawing; here it is pointed to, not said twice.
                  state.readiness.missing.firstOrNull?.kind ==
                          PriceRequirementKind.geometry
                      ? 'Please correct the geometry shown under the '
                            'drawing to calculate the price.'
                      : state.message,
                  style: text.bodySmall,
                ),
              ),
            // A price calculated before the design changed is that, and
            // never the price.
            if (state.previous case final previous?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Previous calculation: '
                  '${PricePanel.money(previous, currency)} — not current',
                  key: PricePanel.previousKey,
                  style: text.bodySmall?.copyWith(
                    color: p.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PriceButton(
              key: PricePanel.calculateKey,
              state: state,
              onPressed: _calculate,
            ),
          ),
          if (result != null) ...[
            if (result.discountAmount > 0) ...[
              PriceRow(
                'Subtotal',
                PricePanel.money(result.subtotal, result.currency),
              ),
              PriceRow(
                'Discount',
                '− ${PricePanel.money(result.discountAmount, result.currency)}',
              ),
            ],
            TextButton.icon(
              key: PricePanel.breakdownKey,
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_open ? 'Hide the breakdown' : 'Show the breakdown'),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
            if (_open) PriceBreakdown(result),
          ],
          if (starter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Example prices — the workshop owner sets the real ones.',
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          // Prices read from a list kept by an earlier version: said, with
          // what it held that has no place now.
          if (migration != null)
            Padding(
              key: PricePanel.migratedKey,
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  'Prices carried over from an older price list.',
                  ...migration,
                ].join(' '),
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ),
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
  static const borderKey = ValueKey('measure-border');
  static const linesKey = ValueKey('measure-lines');
  static const combinedKey = ValueKey('measure-combined-profile');

  @override
  Widget build(BuildContext context) {
    final m = measurements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The border and the lines share a rate and are still two
        // measurements: each its own row, then the two together.
        if (m.splitsBorder) ...[
          PriceRow('Border length', m.borderLength.label, valueKey: borderKey),
          PriceRow(
            'Internal line length',
            m.lineLength.label,
            valueKey: linesKey,
          ),
          PriceRow(
            'Combined profile length',
            m.normalProfile.label,
            valueKey: combinedKey,
          ),
        ] else
          // A price kept before the two were measured apart says only what
          // it measured.
          PriceRow('Border and internal lines', m.normalProfile.label),
        PriceRow('Opening profile', m.openingProfile.label),
        if (m.otherProfile.value > 0)
          PriceRow('Other profile', m.otherProfile.label),
        PriceRow(
          'Total profile',
          m.totalProfile.label,
          strong: true,
          valueKey: totalProfileKey,
        ),
        PriceRow('Panel', m.panelArea.label),
        PriceRow('Glass', m.glassArea.label),
      ],
    );
  }
}

class PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Key? valueKey;

  const PriceRow(
    this.label,
    this.value, {
    super.key,
    this.strong = false,
    this.valueKey,
  });

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
          Expanded(flex: 3, child: Text(label, style: style)),
          const SizedBox(width: 12),
          // A figure is short; words — why there is no price — wrap
          // rather than run off a narrow screen.
          Flexible(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Text(
                value,
                key: valueKey,
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

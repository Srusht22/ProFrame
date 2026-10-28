import 'package:flutter/material.dart';

import '../../domain/pricing/extra_charge.dart';
import '../../domain/pricing/measurement.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/profile_category.dart';
import '../../domain/text/names.dart';
import '../../domain/text/words.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'extra_charges.dart';
import 'price_panel.dart';

// A design's price, laid out so that it can be read at a glance:
//
// ```
// PROFILES AND FRAME            260.00 USD
//   System Aluminium — Border        96.00 USD
//   12.000 m × 8.00 USD/m
//   …
// PANELS · GLASS · HARDWARE · LABOUR AND INSTALLATION
// EXTRA CHARGES · DISCOUNT
// FINAL CALCULATION
// ```
//
// Every figure is the [PriceResult]'s — the engine's — as it was worked
// out. Nothing is added up here but the sum of a section's own lines, which
// are whole cents, so the sections add up to the design cost written under
// them to the cent.

/// One line of cost: what it is, how it is worked out, and what it comes
/// to.
///
/// The name and the amount share the top line; how it is worked out —
/// `12.000 m × 8.00 USD/m` — is under the name, in a lighter hand, so a
/// long Sorani name wraps without running into the figures.
class CostRow extends StatelessWidget {
  final String title;

  /// How it is worked out, or why it is what it is; null where there is
  /// nothing to say.
  final String? detail;
  final String amount;
  final Key? amountKey;
  final bool strong;

  /// Buttons at its end — edit and remove an extra.
  final List<Widget> actions;

  const CostRow({
    super.key,
    required this.title,
    required this.amount,
    this.detail,
    this.amountKey,
    this.strong = false,
    this.actions = const [],
  });

  /// How [line] is worked out, with the rate's unit and currency:
  /// `12.000 m × 8.00 USD/m`, `1.4296 m² × 45.00 USD/m²`, `3 × 15.00 USD`,
  /// `10% of 600.00`, *fixed*.
  static String detailOf(PriceLine line, String currency, Words w) {
    final rate = line.rate.toStringAsFixed(2);
    return switch (line.unit) {
      PriceUnit.metre => '${Metres(line.quantity).label} × $rate $currency/m',
      PriceUnit.squareMetre =>
        '${SquareMetres(line.quantity).label} × $rate $currency/m²',
      PriceUnit.each => '${line.quantity.round()} × $rate $currency',
      PriceUnit.percent => w.ppPercentOf('${line.quantity}', rate),
      PriceUnit.fixed => w.ppFixed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final figures = const [FontFeature.tabularFigures()];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (detail case final detail? when detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail,
                      // A calculation is figures and is read left to
                      // right; an explanation in the screen's direction.
                      textDirection: context.directionOf(detail),
                      style: text.bodySmall?.copyWith(
                        color: p.muted,
                        fontFeatures: figures,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            key: amountKey,
            textDirection: context.directionOf(amount),
            style: text.bodyMedium?.copyWith(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: figures,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A part of the summary: a heading with what the part comes to beside it,
/// then its lines. A tap on the heading folds it away and opens it again;
/// every part starts open, so nothing is hidden until the user hides it.
class CostSection extends StatefulWidget {
  final String title;
  final IconData icon;

  /// What it comes to, or what it says where it comes to nothing.
  final String value;
  final Key? valueKey;
  final List<Widget> children;

  const CostSection({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.children,
    this.valueKey,
  });

  @override
  State<CostSection> createState() => _CostSectionState();
}

class _CostSectionState extends State<CostSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Tooltip(
              message: _open
                  ? l.psCollapse(widget.title)
                  : l.psExpand(widget.title),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    14,
                    12,
                    8,
                    12,
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 20, color: p.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // At the end of the row, as wide as it is — and, for
                      // words such as why glass is not charged, at most
                      // half the row, wrapping rather than crowding the
                      // heading.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                        ),
                        child: Text(
                          widget.value,
                          key: widget.valueKey,
                          textAlign: TextAlign.end,
                          textDirection: context.directionOf(widget.value),
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: p.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_open && widget.children.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(height: 1, color: p.hairline),
                    const SizedBox(height: 4),
                    ...widget.children,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A line in a part that says what something is, rather than a cost: why
/// glass is not charged, that the border and the lines share a rate.
class CostNote extends StatelessWidget {
  final String words;
  final Key? noteKey;

  const CostNote(this.words, {super.key, this.noteKey});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      words,
      key: noteKey,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.palette.muted),
    ),
  );
}

/// One design's price, as parts a person can read one at a time — profiles,
/// panels, glass, hardware, labour, extras, discount — each with what it
/// comes to, then the final calculation.
///
/// The figures are [result]'s, as it was worked out; nothing is priced
/// here. The buttons are only offered where a callback is given — which the
/// caller decides by what the person may do.
class PriceBreakdown extends StatelessWidget {
  final PriceResult result;
  final VoidCallback? onAddExtra;
  final void Function(ExtraCharge extra)? onEditExtra;
  final void Function(ExtraCharge extra)? onRemoveExtra;
  final VoidCallback? onDiscount;

  const PriceBreakdown(
    this.result, {
    super.key,
    this.onAddExtra,
    this.onEditExtra,
    this.onRemoveExtra,
    this.onDiscount,
  });

  static const profilesKey = ValueKey('summary-profiles');
  static const hardwareKey = ValueKey('summary-hardware');
  static const labourKey = ValueKey('summary-labour');
  static const glassNoteKey = ValueKey('summary-glass-note');
  static const calculationKey = ValueKey('summary-calculation');

  /// The groups each part is made of.
  static const profileGroups = {
    PriceGroup.normalProfile,
    PriceGroup.openingProfile,
    PriceGroup.otherProfile,
    PriceGroup.colour,
  };
  static const labourGroups = {PriceGroup.labour, PriceGroup.installation};

  @override
  Widget build(BuildContext context) {
    final currency = result.currency;
    final l = context.l10n;
    final w = context.words;
    String money(int cents) => PricePanel.money(cents / 100, currency);
    List<PriceLine> linesOf(Set<PriceGroup> groups) => [
      for (final line in result.lines)
        if (groups.contains(line.group)) line,
    ];
    int centsOf(List<PriceLine> lines) =>
        lines.fold(0, (sum, line) => sum + line.amountCents);
    Widget row(PriceLine line, {Key? key}) => CostRow(
      title: line.labelIn(w),
      detail: context.figure(CostRow.detailOf(line, currency, w)),
      amount: money(line.amountCents),
      amountKey: key,
    );

    final profiles = linesOf(profileGroups);
    final normal = linesOf({PriceGroup.normalProfile});
    final panels = linesOf({PriceGroup.panel});
    final glass = linesOf({PriceGroup.glass});
    final hardware = linesOf({PriceGroup.hardware});
    final labour = linesOf(labourGroups);
    final area = result.measurements.glassArea;
    final discount = result.discount;
    final glassState = result.glassState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profiles.isNotEmpty)
          CostSection(
            key: profilesKey,
            title: l.psProfiles,
            icon: Icons.border_outer,
            value: money(centsOf(profiles)),
            children: [
              for (final line in profiles)
                row(
                  line,
                  key: line.part == null
                      ? null
                      : ExtraKeys.profileLine(
                          '${line.category?.name ?? 'all'}.${line.part!.name}',
                        ),
                ),
              // The border and the lines are two measurements at the rate
              // they share: said once, and what they come to together.
              if (normal.any((x) => x.part == ProfilePart.border) &&
                  normal.any((x) => x.part == ProfilePart.lines)) ...[
                CostRow(
                  title: l.psCombinedProfile,
                  amount: money(centsOf(normal)),
                  amountKey: ExtraKeys.combinedProfile,
                  strong: true,
                ),
                CostNote(l.psSharedRate),
              ],
            ],
          ),
        CostSection(
          title: l.psPanels,
          icon: Icons.crop_square,
          value: panels.isEmpty ? l.pbNotUsed : money(centsOf(panels)),
          valueKey: ExtraKeys.panel,
          children: [
            for (final line in panels) row(line),
            if (panels.isEmpty) CostNote(l.psNoPanel),
          ],
        ),
        CostSection(
          title: l.psGlass,
          icon: Icons.window_outlined,
          value: switch (glassState) {
            GlassState.charged => money(centsOf(glass)),
            GlassState.notUsed => l.pbNotUsed,
            final state => state.wordsIn(w),
          },
          valueKey: ExtraKeys.glass,
          children: [
            for (final line in glass) row(line),
            // Where nothing is charged it says why, and how much glass
            // there is: the glass is still the design's.
            if (glassState != GlassState.charged)
              CostNote(
                switch (glassState) {
                  GlassState.notIncluded => l.psGlassNotIncluded(
                    context.figure(area.label),
                  ),
                  GlassState.disabled => l.psGlassDisabled(
                    context.figure(area.label),
                  ),
                  GlassState.nothingToCharge => l.psGlassNothing,
                  _ => l.psNoGlass,
                },
                noteKey: glassNoteKey,
              ),
          ],
        ),
        if (hardware.isNotEmpty)
          CostSection(
            key: hardwareKey,
            title: l.psHardware,
            icon: Icons.hardware_outlined,
            value: money(centsOf(hardware)),
            children: [for (final line in hardware) row(line)],
          ),
        if (labour.isNotEmpty)
          CostSection(
            key: labourKey,
            title: l.psLabour,
            icon: Icons.handyman_outlined,
            value: money(centsOf(labour)),
            children: [for (final line in labour) row(line)],
          ),
        CostSection(
          title: l.psExtras,
          icon: Icons.add_shopping_cart_outlined,
          value: money(result.extrasCents),
          valueKey: ExtraKeys.extrasCost,
          children: [
            if (result.extras.isEmpty) CostNote(l.pbNoExtras),
            for (final e in result.extras)
              ExtraRow(
                e,
                onEdit: onEditExtra == null ? null : () => onEditExtra!(e),
                onRemove: onRemoveExtra == null
                    ? null
                    : () => onRemoveExtra!(e),
              ),
            if (onAddExtra != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ExtraKeys.add,
                  onPressed: onAddExtra,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.psAddExtra),
                ),
              ),
          ],
        ),
        CostSection(
          title: discount == null
              ? l.psDiscount
              : l.finDiscountOf(discount.describe(money)),
          icon: Icons.sell_outlined,
          value: discount == null
              ? l.discountNoneChoice
              : '−${money(result.discountCents)}',
          valueKey: ExtraKeys.discountAmount,
          children: [
            if (onDiscount != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ExtraKeys.discount,
                  onPressed: onDiscount,
                  icon: Icon(
                    discount == null ? Icons.add : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(discount == null ? l.pbGive : l.pbChange),
                ),
              ),
          ],
        ),
        CostSection(
          key: calculationKey,
          title: l.psCalculation,
          icon: Icons.functions,
          value: result.total == null
              ? '—'
              : PricePanel.money(result.total!, currency),
          children: [
            CostRow(
              title: l.pbDesignCost,
              amount: money(result.designCostCents),
              amountKey: ExtraKeys.designCost,
            ),
            CostRow(title: l.pbExtrasCost, amount: '+ ${money(result.extrasCents)}'),
            CostRow(
              title: l.finSubtotal,
              amount: money(result.subtotalCents),
              amountKey: ExtraKeys.subtotal,
              strong: true,
            ),
            if (discount != null)
              CostRow(
                title: l.psDiscount,
                amount: '−${money(result.discountCents)}',
              ),
            CostRow(
              title: l.psFinalTotal,
              amount: result.total == null
                  ? '—'
                  : PricePanel.money(result.total!, currency),
              strong: true,
            ),
          ],
        ),
      ],
    );
  }
}

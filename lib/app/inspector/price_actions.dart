import 'package:flutter/material.dart';

import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/price_result.dart';
import '../theme/app_theme.dart';
import 'price_panel.dart';

/// The price action, wherever a design is: **Calculate price** in the
/// workspace and **Price** on a design's card.
///
/// **Enabled by the design's own [DesignPriceState] and nothing else**, so
/// the workspace and the card cannot disagree. Where the design cannot be
/// priced the button stays where it is, plainly disabled — there is a
/// price, and the design has to be completed first — and a press on it
/// says exactly what is still to be completed, never a guess and never a
/// partial price.
class PriceButton extends StatelessWidget {
  /// Where the price stands; null while it is still being read.
  final DesignPriceState? state;
  final VoidCallback onPressed;
  final String label;

  /// An icon alone, for a bar with no room for words.
  final bool compact;

  /// Whether the words carry the icon too; a card has room for the word
  /// alone.
  final bool withIcon;

  /// The colour it is drawn in: the bar's lettering on the bar, the house
  /// colour on a card.
  final Color? colour;

  const PriceButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.label = 'Calculate price',
    this.compact = false,
    this.withIcon = true,
    this.colour,
  });

  /// The words said when a disabled price button is pressed.
  static const messageKey = ValueKey('price-unavailable-message');

  bool get enabled => state?.canCalculate ?? false;

  /// Says why [state] cannot be priced, over the screen [context] is on.
  static void explain(BuildContext context, DesignPriceState? state) {
    final message = state == null
        ? 'The price is still being worked out.'
        : (state.message.isEmpty
              ? 'Please complete the incomplete part of the design to '
                    'calculate the price.'
              : state.message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message, key: messageKey)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = colour ?? p.primary;
    final shown = enabled ? ink : ink.withValues(alpha: 0.38);
    final tip = enabled ? label : '$label — ${state?.message ?? ''}';
    final style = OutlinedButton.styleFrom(
      foregroundColor: ink,
      disabledForegroundColor: shown,
      side: BorderSide(color: shown.withValues(alpha: enabled ? 0.7 : 0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      minimumSize: const Size(40, 36),
    );
    final icon = Icon(Icons.calculate_outlined, size: 18, color: shown);
    final button = compact
        ? OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: style,
            child: icon,
          )
        : withIcon
        ? OutlinedButton.icon(
            onPressed: enabled ? onPressed : null,
            style: style,
            icon: icon,
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: style,
            child: Text(label, maxLines: 1),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: tip,
        // A disabled button takes no press of its own, so the press falls
        // through to here and is answered with what is missing.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: enabled ? null : () => explain(context, state),
          child: button,
        ),
      ),
    );
  }
}

/// One design's price, laid out as the factory reads it: what it measures,
/// each kind in its own unit, then what each costs, then the total.
class DesignPriceSheet extends StatelessWidget {
  final String name;
  final PriceResult result;

  const DesignPriceSheet({super.key, required this.name, required this.result});

  static const sheetKey = ValueKey('design-price-sheet');
  static const totalKey = ValueKey('design-price-sheet-total');

  /// Shows [result] — a calculated price — for the design called [name].
  static Future<void> show(
    BuildContext context, {
    required String name,
    required PriceResult result,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) => DesignPriceSheet(name: name, result: result),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final currency = result.currency;
    Widget heading(String words) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        words,
        style: text.labelMedium?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: p.muted,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 640,
      ),
      child: SingleChildScrollView(
        key: sheetKey,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DESIGN PRICE', style: text.labelMedium),
            Text(name, style: text.titleLarge),
            heading('MATERIAL MEASUREMENTS'),
            MeasurementRows(result.measurements),
            heading('COST BREAKDOWN'),
            for (final group in PriceGroup.values)
              if (result.lines.any((l) => l.group == group)) ...[
                const SizedBox(height: 4),
                PriceRow(
                  group.label,
                  PricePanel.money(result.sumOf(group), currency),
                  strong: true,
                ),
                for (final line in result.lines)
                  if (line.group == group)
                    PriceRow(
                      '   ${line.label} · ${PricePanel.quantity(line)}',
                      PricePanel.money(line.amount, currency),
                    ),
              ],
            if (result.discountAmount > 0) ...[
              const SizedBox(height: 6),
              PriceRow('Subtotal', PricePanel.money(result.subtotal, currency)),
              PriceRow(
                'Discount',
                '− ${PricePanel.money(result.discountAmount, currency)}',
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text('DESIGN TOTAL', style: text.titleMedium)),
                Text(
                  PricePanel.money(result.total!, currency),
                  key: totalKey,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

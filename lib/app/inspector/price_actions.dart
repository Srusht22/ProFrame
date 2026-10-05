import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/design.dart';
import '../../domain/model/materials.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/profile_selection.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'price_panel.dart';
import 'profile_chooser.dart';

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

  /// Pressable while the design can be priced — or while all it lacks is
  /// its material and colour, which the sheet it opens is where they are
  /// chosen.
  bool get enabled =>
      (state?.canCalculate ?? false) || (state?.needsOnlyProfile ?? false);

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

/// What choosing a design's profile does where the sheet was opened: puts
/// the choice into the design, works its price out again, and gives back
/// the design and its price as they now are.
///
/// It is handed the sheet's own [WidgetRef], which stands for as long as the
/// sheet is open — the screen it was opened from can rebuild beneath it as
/// the price it shows is kept.
typedef ProfileChoice =
    Future<(Design, PriceResult)?> Function(
      WidgetRef ref,
      MaterialKind material,
      int colour,
    );

/// One design's price, laid out as the factory reads it: the design — its
/// category, and the material and colour its profile is made in — what it
/// measures, each kind in its own unit, then what each costs, then the
/// total.
///
/// **The price is worked out, never typed.** Choosing another material or
/// colour here puts it into the design ([onChoose]) and works the price out
/// again from the price list, so the figure shown is always the price of
/// the design as it now is — never the old figure beside a new material.
class DesignPriceSheet extends ConsumerStatefulWidget {
  final Design design;
  final PriceResult result;

  /// How a choice of profile is put into the design and priced; null where
  /// it cannot be changed from here.
  final ProfileChoice? onChoose;

  const DesignPriceSheet({
    super.key,
    required this.design,
    required this.result,
    this.onChoose,
  });

  static const sheetKey = ValueKey('design-price-sheet');
  static const totalKey = ValueKey('design-price-sheet-total');
  static const categoryKey = ValueKey('design-price-sheet-category');

  /// What the sheet says where the design as it now is cannot be priced.
  static const unavailableKey = ValueKey('design-price-sheet-unavailable');

  /// Shows [result] — a calculated price — for [design].
  static Future<void> show(
    BuildContext context, {
    required Design design,
    required PriceResult result,
    ProfileChoice? onChoose,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) =>
        DesignPriceSheet(design: design, result: result, onChoose: onChoose),
  );

  @override
  ConsumerState<DesignPriceSheet> createState() => _DesignPriceSheetState();
}

class _DesignPriceSheetState extends ConsumerState<DesignPriceSheet> {
  late Design _design = widget.design;
  late PriceResult _result = widget.result;
  bool _working = false;

  Future<void> _choose(MaterialKind material, int colour) async {
    final choose = widget.onChoose;
    if (choose == null || _working) return;
    setState(() => _working = true);
    final now = await choose(ref, material, colour);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (now != null) {
        _design = now.$1;
        _result = now.$2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final result = _result;
    final design = _design;
    final list = ref.watch(priceListProvider).value;
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
        key: DesignPriceSheet.sheetKey,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DESIGN PRICE', style: text.labelMedium),
            Text(design.shownName, style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Category: ${design.kind.label}',
              key: DesignPriceSheet.categoryKey,
              style: text.bodyMedium,
            ),
            if (list != null && design.frame != null && !design.isUnsupported)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ProfileChooser(
                  selection: ProfileSelection.of(design),
                  current: design.frame!.finish,
                  list: list,
                  onChanged: widget.onChoose == null || _working
                      ? null
                      : _choose,
                ),
              ),
            if (_working)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
            if (!result.isPriced) ...[
              heading('PRICE'),
              Text(
                result.issues.isEmpty
                    ? 'This design cannot be priced as it is.'
                    : result.issues.first.message,
                key: DesignPriceSheet.unavailableKey,
                style: text.bodyMedium,
              ),
            ] else ...[
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
                PriceRow(
                  'Subtotal',
                  PricePanel.money(result.subtotal, currency),
                ),
                PriceRow(
                  'Discount',
                  '− ${PricePanel.money(result.discountAmount, currency)}',
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('DESIGN TOTAL', style: text.titleMedium),
                  ),
                  Text(
                    PricePanel.money(result.total!, currency),
                    key: DesignPriceSheet.totalKey,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

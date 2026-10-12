import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer_discount.dart';
import '../../domain/model/design.dart';
import '../../domain/model/design_completion.dart';
import '../../domain/model/materials.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/design_pricing.dart';
import '../../domain/pricing/extra_catalog.dart';
import '../../domain/pricing/extra_charge.dart';
import '../../domain/pricing/measurement.dart';
import '../../domain/pricing/price_result.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/profile_selection.dart';
import '../../domain/text/names.dart';
import '../l10n/l10n.dart';
import '../l10n/name_text.dart';
import '../screens/factory_prices_screen.dart';
import '../screens/finance_documents.dart' show DiscountAnswer, DiscountDialog;
import '../state/access.dart';
import '../state/language.dart';
import '../state/pricing.dart';
import '../state/workspace.dart' show customerNameProvider;
import '../theme/app_theme.dart';
import 'extra_charges.dart';
import 'price_panel.dart';
import 'price_summary.dart';
import 'pricing_options.dart';
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
  /// What it says; *Calculate price* in the language shown where not given.
  final String? label;

  /// An icon alone, for a bar with no room for words.
  final bool compact;

  /// Whether the words carry the icon too; a card has room for the word
  /// alone.
  final bool withIcon;

  /// The colour it is drawn in: the bar's lettering on the bar, the house
  /// colour on a card.
  final Color? colour;

  /// Whether whoever is at the device may see prices (`pricing.view`).
  /// Where they may not, it is disabled and says so.
  final bool allowed;

  const PriceButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.label,
    this.compact = false,
    this.withIcon = true,
    this.colour,
    this.allowed = true,
  });

  /// What a press on it says where prices may not be seen.
  static const notAllowed = 'You do not have permission to view prices.';

  /// The words said when a disabled price button is pressed.
  static const messageKey = ValueKey('price-unavailable-message');

  /// Pressable while the design can be priced — or while all it lacks is
  /// its material and colour, which the sheet it opens is where they are
  /// chosen.
  bool get enabled =>
      allowed &&
      ((state?.canCalculate ?? false) || (state?.needsOnlyProfile ?? false));

  /// Says why [state] cannot be priced, over the screen [context] is on.
  static void explain(
    BuildContext context,
    DesignPriceState? state, {
    bool allowed = true,
  }) {
    final l = context.l10n;
    final said = state?.messageIn(context.words) ?? '';
    final message = !allowed
        ? l.paNotAllowed
        : state == null
        ? l.paWorkingOut
        : (said.isEmpty ? l.paCompleteDesign : said);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message, key: messageKey)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = colour ?? p.primary;
    final shown = enabled ? ink : ink.withValues(alpha: 0.38);
    final label = this.label ?? context.l10n.paCalculate;
    final tip = enabled
        ? label
        : '$label — ${allowed ? state?.messageIn(context.words) ?? '' : context.l10n.paNotAllowed}';
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
          onTap: enabled
              ? null
              : () => explain(context, state, allowed: allowed),
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
/// How a design whose pricing alone changed is kept and priced afresh:
/// the design as kept and its new price, or null where it cannot be.
typedef PricingChange =
    Future<(Design, PriceResult)?> Function(WidgetRef ref, Design changed);

typedef ProfileChoice =
    Future<(Design, PriceResult)?> Function(
      WidgetRef ref,
      MaterialKind material,
      int colour,
      String? colourId,
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

  /// How a design whose pricing alone was changed here — an extra added,
  /// changed or removed, its discount given or taken away — is kept and
  /// priced afresh; null where its pricing cannot be changed from here.
  final PricingChange? onPricing;

  const DesignPriceSheet({
    super.key,
    required this.design,
    required this.result,
    this.onChoose,
    this.onPricing,
  });

  static const sheetKey = ValueKey('design-price-sheet');
  static const totalKey = ValueKey('design-price-sheet-total');
  static const categoryKey = ValueKey('design-price-sheet-category');
  static const nameKey = ValueKey('design-price-sheet-name');
  static const closeKey = ValueKey('design-price-sheet-close');
  static const editPricingKey = ValueKey('design-price-sheet-edit-pricing');
  static const measurementsKey = ValueKey('design-price-sheet-measurements');

  /// What the sheet says where the design as it now is cannot be priced.
  static const unavailableKey = ValueKey('design-price-sheet-unavailable');

  /// Shows [result] — a calculated price — for [design].
  static Future<void> show(
    BuildContext context, {
    required Design design,
    required PriceResult result,
    ProfileChoice? onChoose,
    PricingChange? onPricing,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) => DesignPriceSheet(
      design: design,
      result: result,
      onChoose: onChoose,
      onPricing: onPricing,
    ),
  );

  @override
  ConsumerState<DesignPriceSheet> createState() => _DesignPriceSheetState();
}

class _DesignPriceSheetState extends ConsumerState<DesignPriceSheet> {
  late Design _design = widget.design;
  late PriceResult _result = widget.result;
  bool _working = false;

  Future<void> _choose(
    MaterialKind material,
    int colour,
    String? colourId,
  ) async {
    final choose = widget.onChoose;
    if (choose == null || _working) return;
    setState(() => _working = true);
    final now = await choose(ref, material, colour, colourId);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (now != null) {
        _design = now.$1;
        _result = now.$2;
      }
    });
  }

  /// [change] made to the design as it is in the sheet, by whoever is at
  /// the device — refused by [DesignPricing] where they may not — then
  /// kept and priced afresh through [DesignPriceSheet.onPricing].
  Future<void> _pricing(
    ({Design? design, String? problem}) Function(Authority by) change,
  ) async {
    final keep = widget.onPricing;
    if (keep == null || _working) return;
    final by = await ref.actorNow();
    final ({Design? design, String? problem}) made;
    try {
      made = change(by);
    } on AccessDenied catch (e) {
      if (mounted) _say(e.messageIn(context.words));
      return;
    }
    if (made.design == null) {
      if (mounted && made.problem != null) _say(made.problem!);
      return;
    }
    setState(() => _working = true);
    final now = await keep(ref, made.design!);
    if (!mounted) return;
    setState(() {
      _working = false;
      if (now != null) {
        _design = now.$1;
        _result = now.$2;
      }
    });
  }

  void _say(String words) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(words)));

  String _money(int cents) => PricePanel.money(cents / 100, _result.currency);

  Future<void> _extra([ExtraCharge? editing]) async {
    // The factory's items in this price's currency, read before the form
    // opens.
    final items = ExtraCatalog.offeredIn(
      await ref.read(extraCatalogProvider.future),
      _result.currency,
    );
    if (!mounted) return;
    final answer = await ExtraDialog.show(
      context,
      newId: _design.pricing.extras.nextExtraId(DateTime.now()),
      currency: _result.currency,
      scope: ExtraScope.design,
      by: ref.read(actorProvider).label,
      where: _design.shownNameIn(context.words),
      editing: editing,
      calculated: _result.lines,
      items: items,
    );
    if (answer == null) return;
    await _pricing(
      (by) => DesignPricing.putExtra(
        _design,
        answer.extra,
        by: by,
        calculated: _result.lines,
        additional: answer.additional,
        money: _money,
        words: ref.words,
      ),
    );
  }

  Future<void> _remove(ExtraCharge extra) async {
    if (!await confirmRemoveExtra(
      context,
      extra,
      context.l10n.paThisDesign,
    )) {
      return;
    }
    await _pricing(
      (by) => (
        design: DesignPricing.removeExtra(_design, extra.id, by: by),
        problem: null,
      ),
    );
  }

  Future<void> _discount() async {
    final list = ref.read(priceListProvider).value;
    if (list == null) return;
    final d = _design.pricing.discount;
    final answer = await showDialog<DiscountAnswer>(
      context: context,
      builder: (_) => DiscountDialog(
        title: context.l10n.paDiscountOn(_design.shownNameIn(context.words)),
        caption: context.l10n.paDesignAlone,
        currency: _result.currency,
        subtotalCents: DesignPricing.subtotalCentsOf(_design, list),
        kind: d == null
            ? null
            : d.percent > 0
            ? DiscountKind.percent
            : DiscountKind.fixed,
        valueText: d == null
            ? ''
            : d.percent > 0
            ? d.describe(_money).replaceAll('%', '')
            : d.amount.toStringAsFixed(2),
      ),
    );
    if (answer == null) return;
    await _pricing(
      (by) => DesignPricing.setDiscount(
        _design,
        kind: answer.kind,
        value: answer.value,
        list: list,
        by: by,
        money: _money,
        words: ref.words,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final l = context.l10n;
    final w = context.words;
    final result = _result;
    final edits = widget.onPricing != null && !_design.isUnsupported;
    bool may(Capability c) => edits && ref.offers(c);
    final design = _design;
    final list = ref.watch(priceListProvider).value;
    final currency = result.currency;
    final customer = design.customerId == null
        ? null
        : ref.watch(customerNameProvider(design.customerId!)).value;
    final who = customer ?? design.customer;
    final status = DesignCompletion.isCompleted(design)
        ? l.stageCompleted
        : l.stageDraft;

    // What can be chosen about the design's price: its profile's material
    // and colour, its aluminium type and whether its glass is charged.
    final choices = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.paCategory(design.kind.labelIn(w)),
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
              onChanged: widget.onChoose == null || _working ? null : _choose,
            ),
          ),
        // Which aluminium profile it is, and whether its glass is
        // charged: said here, as the material is.
        if (design.frame != null && !design.isUnsupported)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PricingOptions(
              design: design,
              factoryChargesGlass: list?.chargesGlass ?? true,
              onChange: !may(Capability.designsEdit) || _working
                  ? null
                  : (change) =>
                        _pricing((by) => (design: change(by), problem: null)),
            ),
          ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        maxWidth: 680,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Which design this is the price of, and the way out.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.psTitle,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      NameText(
                        design.shownNameIn(w),
                        key: DesignPriceSheet.nameKey,
                        maxLines: 2,
                        whole: true,
                        style: text.titleMedium,
                      ),
                      Text(
                        [
                          if (who != null && who.trim().isNotEmpty)
                            l.psFor(who),
                          design.kind.labelIn(w),
                          status,
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: DesignPriceSheet.closeKey,
                  tooltip: MaterialLocalizations.of(context)
                      .closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          if (_working) const LinearProgressIndicator(minHeight: 2),
          Divider(height: 1, color: p.hairline),
          Flexible(
            child: SingleChildScrollView(
              key: DesignPriceSheet.sheetKey,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!result.isPriced)
                    _Notice(
                      title: l.ppPrice,
                      child: Text(
                        result.issues.isEmpty
                            ? l.paCannot
                            : result.issues.first.messageIn(w),
                        key: DesignPriceSheet.unavailableKey,
                        style: text.bodyMedium,
                      ),
                    )
                  else ...[
                    FinalTotal(result: result),
                    PriceBreakdown(
                      result,
                      onAddExtra: may(Capability.extrasCreate) ? _extra : null,
                      onEditExtra: may(Capability.extrasEdit) ? _extra : null,
                      onRemoveExtra:
                          may(Capability.extrasDelete) ? _remove : null,
                      onDiscount:
                          may(Capability.discountsApply) ? _discount : null,
                    ),
                  ],
                  CostSection(
                    title: l.psChoices,
                    icon: Icons.tune,
                    value: '',
                    children: [const SizedBox(height: 6), choices],
                  ),
                  if (result.isPriced)
                    _Measurements(result.measurements),
                  // The factory's rates are changed on their own screen,
                  // never in this list, and only by whoever may.
                  if (ref.offers(Capability.pricingEdit))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          key: DesignPriceSheet.editPricingKey,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FactoryPricesScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.price_change_outlined),
                          label: Text(l.psEditPricing),
                        ),
                      ),
                    ),
                  if (list?.isStarter ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l.ppExamplePrices,
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ),
                  // Kept for the eye: the currency every figure is in.
                  if (result.isPriced && currency.isNotEmpty)
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The figure the summary is for, at the head of it: what the design
/// comes to, in its currency, and — where one was taken — the discount it
/// is after. It is the engine's total, never one worked out here.
class FinalTotal extends StatelessWidget {
  final PriceResult result;

  const FinalTotal({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final l = context.l10n;
    final total = PricePanel.money(result.total!, result.currency);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.band,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.psFinalTotal,
              style: text.labelLarge?.copyWith(
                color: p.onBand.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                total,
                key: DesignPriceSheet.totalKey,
                textDirection: TextDirection.ltr,
                style: text.headlineMedium?.copyWith(
                  color: p.onBand,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (result.discountCents > 0)
              Text(
                l.psIncludesDiscount(
                  context.figure(
                    PricePanel.money(result.discountAmount, result.currency),
                  ),
                ),
                style: text.bodySmall?.copyWith(
                  color: p.onBand.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Why there is no price, said where the total would be.
class _Notice extends StatelessWidget {
  final String title;
  final Widget child;

  const _Notice({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.notice,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: p.onNotice,
              ),
            ),
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: TextStyle(color: p.onNotice),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the design measures — the border and the lines apart, the opening
/// profile, panel and glass in square metres — folded away until asked
/// for: the figures each cost is worked out from are already on its line.
class _Measurements extends StatefulWidget {
  final MeasurementSummary measurements;

  const _Measurements(this.measurements);

  @override
  State<_Measurements> createState() => _MeasurementsState();
}

class _MeasurementsState extends State<_Measurements> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: DesignPriceSheet.measurementsKey,
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _open ? l.psHideMeasurements : l.psShowMeasurements,
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
            child: MeasurementRows(widget.measurements),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/pricing/extra_charge.dart';
import '../../domain/pricing/price_result.dart';
import '../theme/app_theme.dart';
import 'price_panel.dart';

// The extra charges a factory adds to a job by hand — silicone, labour, a
// trip — and the breakdown that sets them beside what the design's own
// geometry costs. Every extra is the same `ExtraCharge`: quantity × unit
// price. Nothing here knows of silicone.

/// The fields and buttons of the extra-charge form and the breakdown.
abstract final class ExtraKeys {
  static const dialog = ValueKey('extra-dialog');
  static const name = ValueKey('extra-name');
  static const category = ValueKey('extra-category');
  static const quantity = ValueKey('extra-quantity');
  static const unit = ValueKey('extra-unit');
  static const customUnit = ValueKey('extra-custom-unit');
  static const price = ValueKey('extra-price');
  static const note = ValueKey('extra-note');
  static const total = ValueKey('extra-total');
  static const problem = ValueKey('extra-problem');
  static const overlap = ValueKey('extra-overlap');
  static const additional = ValueKey('extra-additional');
  static const save = ValueKey('extra-save');
  static const confirmRemove = ValueKey('extra-confirm-remove');

  static const add = ValueKey('breakdown-add-extra');
  static const discount = ValueKey('breakdown-discount');
  static const designCost = ValueKey('breakdown-design-cost');
  static const extrasCost = ValueKey('breakdown-extras-cost');
  static const subtotal = ValueKey('breakdown-subtotal');
  static const discountAmount = ValueKey('breakdown-discount-amount');
  static const glass = ValueKey('breakdown-glass');
  static const panel = ValueKey('breakdown-panel');
  static ValueKey<String> row(String id) => ValueKey('breakdown-extra-$id');
  static ValueKey<String> edit(String id) => ValueKey('breakdown-edit-$id');
  static ValueKey<String> remove(String id) => ValueKey('breakdown-remove-$id');
}

/// What the extra form answers: the extra as written, and whether the user
/// said it is an additional charge on top of one already worked out.
typedef ExtraAnswer = ({ExtraCharge extra, bool additional});

/// **Add extra** / **Edit extra**: a name, a category, a quantity, a unit
/// and a unit price, the total worked out as they are typed, and nothing
/// kept until the form is complete.
class ExtraDialog extends StatefulWidget {
  /// The extra being changed; null for a new one.
  final ExtraCharge? editing;

  /// The id a new extra is given.
  final String newId;
  final String currency;
  final ExtraScope scope;

  /// Who is writing it.
  final String by;

  /// What the price already works out from the design — so an extra that
  /// would charge for the same thing again has to be said to be additional.
  final List<PriceLine> calculated;

  /// Where it goes, said under the title: *Front Entrance Door*,
  /// *Adam's whole job*.
  final String where;

  final DateTime Function() clock;

  const ExtraDialog({
    super.key,
    required this.newId,
    required this.currency,
    required this.scope,
    required this.by,
    required this.where,
    this.editing,
    this.calculated = const [],
    this.clock = DateTime.now,
  });

  static Future<ExtraAnswer?> show(
    BuildContext context, {
    required String newId,
    required String currency,
    required ExtraScope scope,
    required String by,
    required String where,
    ExtraCharge? editing,
    List<PriceLine> calculated = const [],
  }) => showDialog<ExtraAnswer>(
    context: context,
    builder: (_) => ExtraDialog(
      newId: newId,
      currency: currency,
      scope: scope,
      by: by,
      where: where,
      editing: editing,
      calculated: calculated,
    ),
  );

  @override
  State<ExtraDialog> createState() => _ExtraDialogState();
}

class _ExtraDialogState extends State<ExtraDialog> {
  static const _other = '';

  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late ExtraCategory _category =
      widget.editing?.category ?? ExtraCategory.material;
  late final _quantity = TextEditingController(
    text: widget.editing?.quantityText ?? '',
  );
  late String _unit = _initialUnit();
  late final _customUnit = TextEditingController(
    text: _unit == _other ? widget.editing?.unit ?? '' : '',
  );
  late final _price = TextEditingController(
    text: widget.editing == null
        ? ''
        : (widget.editing!.unitPriceCents / 100).toStringAsFixed(2),
  );
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  bool _additional = false;
  String? _problem;

  String _initialUnit() {
    final kept = widget.editing?.unit;
    if (kept == null) return ExtraUnit.piece.label;
    return ExtraUnit.of(kept)?.label ?? _other;
  }

  @override
  void dispose() {
    for (final c in [_name, _quantity, _customUnit, _price, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _money(int cents) => PricePanel.money(cents / 100, widget.currency);

  String get _unitText => _unit == _other ? _customUnit.text.trim() : _unit;

  List<PriceLine> get _overlap =>
      ExtraCharge.alreadyCalculated(_name.text, _category, widget.calculated);

  void _save() {
    final q = ExtraCharge.readQuantity(_quantity.text);
    final p = ExtraCharge.readPrice(_price.text);
    final problem =
        (_name.text.trim().isEmpty ? 'Enter what the extra is.' : null) ??
        q.problem ??
        (_unitText.isEmpty ? 'Choose or type the unit.' : null) ??
        p.problem ??
        ExtraCharge.problemWith(
          name: _name.text,
          quantityMilli: q.value,
          unit: _unitText,
          unitPriceCents: p.value,
        ) ??
        (_overlap.isNotEmpty && !_additional
            ? 'Tick "This is an additional charge" to add it on top.'
            : null);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final now = widget.clock();
    final was = widget.editing;
    final extra = ExtraCharge(
      id: was?.id ?? widget.newId,
      name: _name.text.trim(),
      category: _category,
      quantityMilli: q.value!,
      unit: _unitText,
      unitPriceCents: p.value!,
      currency: was?.currency ?? widget.currency,
      scope: was?.scope ?? widget.scope,
      createdAt: was?.createdAt ?? now,
      updatedAt: now,
      note: _note.text.trim(),
      by: widget.by,
    );
    Navigator.of(context)
        .pop<ExtraAnswer>((extra: extra, additional: _additional));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = ExtraCharge.readQuantity(_quantity.text).value;
    final p = ExtraCharge.readPrice(_price.text).value;
    final overlap = _overlap;
    void changed(_) => setState(() => _problem = null);
    return AlertDialog(
      key: ExtraKeys.dialog,
      scrollable: true,
      title: Text(widget.editing == null ? 'Add extra' : 'Edit extra'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.where, style: text.bodySmall),
            const SizedBox(height: 8),
            TextField(
              key: ExtraKeys.name,
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Silicone, labour, transport…',
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ExtraCategory>(
              key: ExtraKeys.category,
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ExtraCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() {
                _category = c ?? _category;
                _problem = null;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ExtraKeys.quantity,
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    onChanged: changed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ExtraKeys.unit,
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final u in ExtraUnit.values)
                        DropdownMenuItem(value: u.label, child: Text(u.label)),
                      const DropdownMenuItem(
                        value: _other,
                        child: Text('Other unit…'),
                      ),
                    ],
                    onChanged: (u) => setState(() {
                      _unit = u ?? _unit;
                      _problem = null;
                    }),
                  ),
                ),
              ],
            ),
            if (_unit == _other) ...[
              const SizedBox(height: 8),
              TextField(
                key: ExtraKeys.customUnit,
                controller: _customUnit,
                decoration: const InputDecoration(labelText: 'Unit, in words'),
                onChanged: changed,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: ExtraKeys.price,
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Unit price',
                suffixText: widget.editing?.currency ?? widget.currency,
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            TextField(
              key: ExtraKeys.note,
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 12),
            PriceRow(
              q != null && p != null && _unitText.isNotEmpty
                  ? '${ExtraCharge.quantityTextOf(q)} '
                        '${ExtraCharge.unitTextOf(_unitText, q)} × '
                        '${_money(p)}'
                  : 'Total',
              q != null && p != null ? _money(ExtraCharge.totalOf(q, p)) : '—',
              strong: true,
              valueKey: ExtraKeys.total,
            ),
            if (overlap.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ExtraCharge.alreadyCalculatedMessage(overlap, _money),
                key: ExtraKeys.overlap,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              CheckboxListTile(
                key: ExtraKeys.additional,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _additional,
                onChanged: (v) => setState(() {
                  _additional = v ?? false;
                  _problem = null;
                }),
                title: const Text('This is an additional charge'),
              ),
            ],
            if (_problem case final problem?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  problem,
                  key: ExtraKeys.problem,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: ExtraKeys.save,
          onPressed: _save,
          child: Text(widget.editing == null ? 'Add extra' : 'Save extra'),
        ),
      ],
    );
  }
}

/// Asks before [extra] is taken off [from] — it changes what is owed.
Future<bool> confirmRemoveExtra(
  BuildContext context,
  ExtraCharge extra,
  String from,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove extra'),
        content: Text(
          'Remove "${extra.name}" '
          '(${PricePanel.money(extra.totalCents / 100, extra.currency)}) '
          'from $from?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ExtraKeys.confirmRemove,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
    false;

/// One extra as a row: what it is, how it is worked out, what it comes to,
/// and — where allowed — edit and remove.
class ExtraRow extends StatelessWidget {
  final ExtraCharge extra;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const ExtraRow(this.extra, {super.key, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    String money(int cents) => PricePanel.money(cents / 100, extra.currency);
    return Padding(
      key: ExtraKeys.row(extra.id),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extra.name,
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${extra.category.label} · ${extra.sum(money)}'
                  '${extra.note.isEmpty ? '' : ' · ${extra.note}'}',
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          Text(
            money(extra.totalCents),
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onEdit != null)
            IconButton(
              key: ExtraKeys.edit(extra.id),
              tooltip: 'Edit ${extra.name}',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
          if (onRemove != null)
            IconButton(
              key: ExtraKeys.remove(extra.id),
              tooltip: 'Remove ${extra.name}',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// One design's price, laid out as the factory reads it:
///
/// ```
/// AUTOMATIC DESIGN COSTS   worked out from the design's geometry
///   …each group, Glass and Panel always — "Not used" where there is none
///   Design cost
/// EXTRA CHARGES            added by hand, quantity × unit price
///   Extras cost
/// SUBTOTAL · DISCOUNT · FINAL TOTAL
/// ```
///
/// The figures are [result]'s, as it was worked out; nothing is added up
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final currency = result.currency;
    String money(int cents) => PricePanel.money(cents / 100, currency);
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
    bool has(PriceGroup g) => result.lines.any((l) => l.group == g);
    final discount = result.discount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('AUTOMATIC DESIGN COSTS'),
        for (final group in PriceGroup.values)
          if (has(group)) ...[
            const SizedBox(height: 4),
            PriceRow(
              group.label,
              PricePanel.money(result.sumOf(group), currency),
              strong: true,
              valueKey: switch (group) {
                PriceGroup.glass => ExtraKeys.glass,
                PriceGroup.panel => ExtraKeys.panel,
                _ => null,
              },
            ),
            for (final line in result.lines)
              if (line.group == group)
                PriceRow(
                  '   ${line.label} · ${PricePanel.quantity(line)}',
                  PricePanel.money(line.amount, currency),
                ),
          ] else if (group == PriceGroup.glass || group == PriceGroup.panel)
            // Glass and panel are each only what the design actually
            // has: where it has none, it is said, and nothing is charged.
            PriceRow(
              group.label,
              'Not used',
              valueKey: group == PriceGroup.glass
                  ? ExtraKeys.glass
                  : ExtraKeys.panel,
            ),
        const SizedBox(height: 4),
        PriceRow(
          'Design cost',
          money(result.designCostCents),
          strong: true,
          valueKey: ExtraKeys.designCost,
        ),
        heading('EXTRA CHARGES'),
        if (result.extras.isEmpty)
          Text(
            'No extra charges.',
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        for (final e in result.extras)
          ExtraRow(
            e,
            onEdit: onEditExtra == null ? null : () => onEditExtra!(e),
            onRemove: onRemoveExtra == null ? null : () => onRemoveExtra!(e),
          ),
        if (onAddExtra != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: ExtraKeys.add,
              onPressed: onAddExtra,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add extra'),
            ),
          ),
        PriceRow(
          'Extras cost',
          money(result.extrasCents),
          strong: true,
          valueKey: ExtraKeys.extrasCost,
        ),
        const Divider(height: 20),
        PriceRow(
          'Subtotal',
          money(result.subtotalCents),
          valueKey: ExtraKeys.subtotal,
        ),
        Row(
          children: [
            Expanded(
              child: PriceRow(
                discount == null
                    ? 'Discount'
                    : 'Discount (${discount.describe(money)})',
                discount == null ? 'None' : '−${money(result.discountCents)}',
                valueKey: ExtraKeys.discountAmount,
              ),
            ),
            if (onDiscount != null)
              TextButton(
                key: ExtraKeys.discount,
                onPressed: onDiscount,
                child: Text(discount == null ? 'Give' : 'Change'),
              ),
          ],
        ),
      ],
    );
  }
}

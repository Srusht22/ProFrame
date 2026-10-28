import 'package:flutter/material.dart';

import '../../domain/pricing/extra_catalog.dart';
import '../../domain/pricing/extra_charge.dart';
import '../../domain/pricing/price_result.dart';
import '../l10n/l10n.dart';
import '../l10n/latin_digits.dart';
import 'price_panel.dart';
import 'price_summary.dart';

// The extra charges a factory adds to a job by hand — silicone, labour, a
// trip — and the breakdown that sets them beside what the design's own
// geometry costs. Every extra is the same `ExtraCharge`: quantity × unit
// price. Nothing here knows of silicone.

/// The fields and buttons of the extra-charge form and the breakdown.
abstract final class ExtraKeys {
  /// A line of the border and the lines in a breakdown, by its profile
  /// category's name (`all` for a material with none) and its part.
  static ValueKey<String> profileLine(String which) =>
      ValueKey('extra-keys-profile-$which');
  static const combinedProfile = ValueKey('extra-keys-combined-profile');

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

  /// The factory's items an extra can be added from — active, and in this
  /// price's currency (`ExtraCatalog.offeredIn`). Empty where it has none:
  /// the form is then the one-time charge it always was.
  final List<ExtraItem> items;

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
    this.items = const [],
  });

  static const itemKey = ValueKey('extra-item');
  static const factoryPriceKey = ValueKey('extra-factory-price');

  static Future<ExtraAnswer?> show(
    BuildContext context, {
    required String newId,
    required String currency,
    required ExtraScope scope,
    required String by,
    required String where,
    ExtraCharge? editing,
    List<PriceLine> calculated = const [],
    List<ExtraItem> items = const [],
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
      items: items,
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

  /// Whether the form has been answered: a second press does nothing.
  bool _done = false;

  /// The factory's item it is added from; null for a one-time charge.
  /// Editing a charge added from an item keeps the charge's own price —
  /// the one it was added at — until another item is chosen.
  late String? _itemId = widget.items.any((i) => i.id == widget.editing?.itemId)
      ? widget.editing!.itemId
      : null;

  ExtraItem? get _item =>
      widget.items.where((i) => i.id == _itemId).firstOrNull;

  /// [item] chosen, or none: its name, category, unit and price written
  /// into the form, where they cannot be typed over.
  void _choose(String? id) => setState(() {
    _problem = null;
    _itemId = id;
    final item = _item;
    if (item == null) return;
    _name.text = item.name;
    _category = item.category;
    _unit = ExtraUnit.of(item.unit)?.label ?? _other;
    _customUnit.text = _unit == _other ? item.unit : '';
    _price.text = (item.unitPriceCents / 100).toStringAsFixed(2);
  });

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
    if (_done) return;
    final w = context.words;
    final q = ExtraCharge.readQuantity(_quantity.text, w);
    final p = ExtraCharge.readPrice(_price.text, w);
    final problem =
        (_name.text.trim().isEmpty ? w.xNameNeeded : null) ??
        q.problem ??
        (_unitText.isEmpty ? w.xUnitNeeded : null) ??
        p.problem ??
        ExtraCharge.problemWith(
          name: _name.text,
          quantityMilli: q.value,
          unit: _unitText,
          unitPriceCents: p.value,
          words: w,
        ) ??
        (_overlap.isNotEmpty && !_additional
            ? context.l10n.xTickAdditional
            : null);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    final now = widget.clock();
    final was = widget.editing;
    _done = true;
    final item = _item;
    // From an item, it is the item's — at the price in the form, which is
    // the item's, or, unchanged since it was added, the charge's own.
    if (item != null) {
      final extra = item
          .chargeOf(
            id: was?.id ?? widget.newId,
            quantityMilli: q.value!,
            scope: was?.scope ?? widget.scope,
            now: now,
            note: _note.text.trim(),
            by: widget.by,
            createdAt: was?.createdAt,
          )
          .copyWith(unitPriceCents: p.value);
      Navigator.of(context)
          .pop<ExtraAnswer>((extra: extra, additional: _additional));
      return;
    }
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
    final locked = _item != null;
    void changed(_) => setState(() => _problem = null);
    final l = context.l10n;
    final w = context.words;
    return AlertDialog(
      key: ExtraKeys.dialog,
      scrollable: true,
      title: Text(widget.editing == null ? l.xAddTitle : l.xEditTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.where, style: text.bodySmall),
            const SizedBox(height: 8),
            if (widget.items.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                key: ExtraDialog.itemKey,
                initialValue: _itemId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.xFrom),
                items: [
                  for (final i in widget.items)
                    DropdownMenuItem<String?>(
                      value: i.id,
                      child: Text(i.name, overflow: TextOverflow.ellipsis),
                    ),
                  DropdownMenuItem<String?>(child: Text(l.xCustomItem)),
                ],
                onChanged: _choose,
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              key: ExtraKeys.name,
              controller: _name,
              readOnly: locked,
              enabled: !locked,
              autofocus: widget.items.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.xName,
                hintText: l.xNameHint,
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            // Read afresh when an item is chosen, which writes its own.
            KeyedSubtree(
              key: ValueKey(('category', _itemId)),
              child: DropdownButtonFormField<ExtraCategory>(
                key: ExtraKeys.category,
                initialValue: _category,
                decoration: InputDecoration(labelText: l.xCategory),
                items: [
                  for (final c in ExtraCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.labelIn(w))),
                ],
                onChanged: locked
                    ? null
                    : (c) => setState(() {
                        _category = c ?? _category;
                        _problem = null;
                      }),
              ),
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
                    inputFormatters: const [LatinDigits()],
                    decoration: InputDecoration(labelText: l.xQuantity),
                    onChanged: changed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(('unit', _itemId)),
                    child: DropdownButtonFormField<String>(
                      key: ExtraKeys.unit,
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.xUnit),
                      items: [
                        for (final u in ExtraUnit.values)
                          DropdownMenuItem(
                            value: u.label,
                            child: Text(u.sayIn(w)),
                          ),
                        DropdownMenuItem(
                          value: _other,
                          child: Text(l.xOtherUnit),
                        ),
                      ],
                      onChanged: locked
                          ? null
                          : (u) => setState(() {
                              _unit = u ?? _unit;
                              _problem = null;
                            }),
                    ),
                  ),
                ),
              ],
            ),
            if (_unit == _other) ...[
              const SizedBox(height: 8),
              TextField(
                key: ExtraKeys.customUnit,
                controller: _customUnit,
                readOnly: locked,
                enabled: !locked,
                decoration: InputDecoration(labelText: l.xUnitInWords),
                onChanged: changed,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: ExtraKeys.price,
              controller: _price,
              readOnly: locked,
              enabled: !locked,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [LatinDigits()],
              decoration: InputDecoration(
                labelText: l.xUnitPrice,
                suffixText: widget.editing?.currency ?? widget.currency,
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            TextField(
              key: ExtraKeys.note,
              controller: _note,
              decoration: InputDecoration(labelText: l.xNoteOptional),
            ),
            if (locked && p != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.xFactoryPrice(
                    context.figure(_money(p)),
                    ExtraCharge.unitTextOf(_unitText, 1000, w),
                  ),
                  key: ExtraDialog.factoryPriceKey,
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(l.xCalculated, style: text.labelMedium),
            PriceRow(
              q != null && p != null && _unitText.isNotEmpty
                  ? '${ExtraCharge.quantityTextOf(q)} '
                        '${ExtraCharge.unitTextOf(_unitText, q, w)} × '
                        '${_money(p)}'
                  : l.xTotal,
              q != null && p != null ? _money(ExtraCharge.totalOf(q, p)) : '—',
              strong: true,
              valueKey: ExtraKeys.total,
            ),
            if (overlap.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ExtraCharge.alreadyCalculatedMessage(overlap, _money, w),
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
                title: Text(l.xIsAdditional),
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
          child: Text(l.actCancel),
        ),
        FilledButton(
          key: ExtraKeys.save,
          onPressed: _save,
          child: Text(widget.editing == null ? l.xAddTitle : l.xSave),
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
        title: Text(context.l10n.xRemoveTitle),
        content: Text(
          context.l10n.xRemoveAsk(
            extra.name,
            PricePanel.money(extra.totalCents / 100, extra.currency),
            from,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.actCancel),
          ),
          FilledButton(
            key: ExtraKeys.confirmRemove,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.actRemove),
          ),
        ],
      ),
    ) ??
    false;

/// One extra as a row: what it is, how it is worked out — `5 bottles ×
/// 3.00 USD` — what it comes to, and, where allowed, edit and remove.
class ExtraRow extends StatelessWidget {
  final ExtraCharge extra;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const ExtraRow(this.extra, {super.key, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) {
    String money(int cents) => PricePanel.money(cents / 100, extra.currency);
    final l = context.l10n;
    final w = context.words;
    return CostRow(
      key: ExtraKeys.row(extra.id),
      title: extra.name,
      detail: [
        context.figure(extra.sum(money, w)),
        extra.category.labelIn(w),
        if (extra.itemId != null) l.psFromCatalog,
        if (extra.note.isNotEmpty) extra.note,
      ].join(' · '),
      amount: money(extra.totalCents),
      actions: [
        if (onEdit != null)
          IconButton(
            key: ExtraKeys.edit(extra.id),
            tooltip: l.xEditOf(extra.name),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
        if (onRemove != null)
          IconButton(
            key: ExtraKeys.remove(extra.id),
            tooltip: l.xRemoveOf(extra.name),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onRemove,
          ),
      ],
    );
  }
}

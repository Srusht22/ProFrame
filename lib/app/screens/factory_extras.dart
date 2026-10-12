import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/extra_catalog.dart';
import '../../domain/pricing/extra_charge.dart';
import '../inspector/price_panel.dart';
import '../l10n/errors.dart';
import '../l10n/l10n.dart';
import '../l10n/latin_digits.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';

/// **Extra items** in Factory prices: the extras the factory charges again
/// and again — silicone by the bottle, labour by the hour, a delivery by
/// the trip — each with its own price ([ExtraItem]).
///
/// Everybody reads it. Only whoever may change the factory's prices
/// (`pricing.edit`, which the store checks) adds an item, edits one or
/// stops offering one, and each change is kept at once. Nothing is deleted:
/// an item no longer offered stays, for the charges already added from it —
/// which never change with it, since each one copied the item's price.
class FactoryExtrasSection extends ConsumerWidget {
  /// The price list's currency, which a new item is priced in.
  final String currency;
  final bool editable;

  const FactoryExtrasSection({
    super.key,
    required this.currency,
    required this.editable,
  });

  static const sectionKey = ValueKey('factory-extras');
  static const addKey = ValueKey('factory-extras-add');
  static ValueKey<String> rowKey(String id) => ValueKey('factory-extra-$id');
  static ValueKey<String> editKey(String id) =>
      ValueKey('factory-extra-edit-$id');
  static ValueKey<String> retireKey(String id) =>
      ValueKey('factory-extra-retire-$id');
  static ValueKey<String> restoreKey(String id) =>
      ValueKey('factory-extra-restore-$id');
  static const confirmRetireKey = ValueKey('factory-extra-confirm-retire');

  /// What [item] costs, in words: *3.00 USD per bottle*.
  static String priceOf(BuildContext context, ExtraItem item) =>
      context.l10n.fxPerUnit(
        PricePanel.money(item.unitPriceCents / 100, item.currency),
        ExtraCharge.unitTextOf(item.unit, 1000, context.words),
      );

  Future<void> _keep(
    BuildContext context,
    WidgetRef ref,
    List<ExtraItem> items,
    String done,
  ) async {
    try {
      await ref.saveExtraCatalog(items);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageOf(context, e))));
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    List<ExtraItem> items, [
    ExtraItem? editing,
  ]) async {
    final item = await ExtraItemDialog.show(
      context,
      items: items,
      currency: editing?.currency ?? currency,
      by: ref.read(actorProvider).label,
      editing: editing,
    );
    if (item == null || !context.mounted) return;
    final next = ExtraCatalog.put(items, item, context.words);
    if (next.items == null) return;
    await _keep(
      context,
      ref,
      next.items!,
      editing == null ? context.l10n.fxAdded : context.l10n.fxSaved,
    );
  }

  Future<void> _retire(
    BuildContext context,
    WidgetRef ref,
    List<ExtraItem> items,
    ExtraItem item,
  ) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.fxRetireAsk(item.name)),
        content: SizedBox(width: 420, child: Text(context.l10n.fxRetireBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.actCancel),
          ),
          FilledButton(
            key: confirmRetireKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.fxRetire),
          ),
        ],
      ),
    );
    if (!(sure ?? false) || !context.mounted) return;
    await _keep(
      context,
      ref,
      ExtraCatalog.retire(items, item.id),
      context.l10n.fxRetired(item.name),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    List<ExtraItem> items,
    ExtraItem item,
  ) async {
    final back = ExtraCatalog.restore(items, item.id, context.words);
    if (back.items == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(back.problem!)));
      return;
    }
    await _keep(
      context,
      ref,
      back.items!,
      context.l10n.fcOfferedAgain(item.name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(extraCatalogProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final l = context.l10n;
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 2),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                l.fxTitle.toUpperCase(),
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              if (editable)
                OutlinedButton.icon(
                  key: addKey,
                  onPressed: () => _edit(context, ref, items),
                  icon: const Icon(Icons.add),
                  label: Text(l.fxAdd),
                ),
            ],
          ),
        ),
        Text(l.fxIntro, style: text.bodySmall?.copyWith(color: p.muted)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.fxNone, style: text.bodyMedium),
          ),
        for (final item in items)
          Card(
            key: rowKey(item.id),
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.active ? l.fcActive : l.fcRetiredStatus,
                              style: text.labelSmall?.copyWith(
                                color: item.active ? p.primary : p.muted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          [
                            priceOf(context, item),
                            item.category.labelIn(context.words),
                            if (item.note.isNotEmpty) item.note,
                          ].join(' · '),
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  if (editable) ...[
                    IconButton(
                      key: editKey(item.id),
                      tooltip: l.xEditOf(item.name),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _edit(context, ref, items, item),
                    ),
                    if (item.active)
                      IconButton(
                        key: retireKey(item.id),
                        tooltip: l.fxRetire,
                        icon: const Icon(Icons.block, size: 20),
                        onPressed: () => _retire(context, ref, items, item),
                      )
                    else
                      IconButton(
                        key: restoreKey(item.id),
                        tooltip: l.fcOfferAgain(item.name),
                        icon: const Icon(Icons.restore, size: 20),
                        onPressed: () => _restore(context, ref, items, item),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// **Add item** / **Edit item**: a name, a category, a unit, a unit price
/// and an explanation. Nothing is kept until it is complete and right.
class ExtraItemDialog extends StatefulWidget {
  final List<ExtraItem> items;
  final String currency;
  final String by;
  final ExtraItem? editing;
  final DateTime Function() clock;

  const ExtraItemDialog({
    super.key,
    required this.items,
    required this.currency,
    required this.by,
    this.editing,
    this.clock = DateTime.now,
  });

  static const nameKey = ValueKey('extra-item-name');
  static const categoryKey = ValueKey('extra-item-category');
  static const unitKey = ValueKey('extra-item-unit');
  static const customUnitKey = ValueKey('extra-item-custom-unit');
  static const priceKey = ValueKey('extra-item-price');
  static const noteKey = ValueKey('extra-item-note');
  static const problemKey = ValueKey('extra-item-problem');
  static const saveKey = ValueKey('extra-item-save');

  static Future<ExtraItem?> show(
    BuildContext context, {
    required List<ExtraItem> items,
    required String currency,
    required String by,
    ExtraItem? editing,
  }) => showDialog<ExtraItem>(
    context: context,
    builder: (_) => ExtraItemDialog(
      items: items,
      currency: currency,
      by: by,
      editing: editing,
    ),
  );

  @override
  State<ExtraItemDialog> createState() => _ExtraItemDialogState();
}

class _ExtraItemDialogState extends State<ExtraItemDialog> {
  static const _other = '';

  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late ExtraCategory _category =
      widget.editing?.category ?? ExtraCategory.material;
  late String _unit = widget.editing == null
      ? ExtraUnit.piece.label
      : ExtraUnit.of(widget.editing!.unit)?.label ?? _other;
  late final _customUnit = TextEditingController(
    text: _unit == _other ? widget.editing?.unit ?? '' : '',
  );
  late final _price = TextEditingController(
    text: widget.editing == null
        ? ''
        : (widget.editing!.unitPriceCents / 100).toStringAsFixed(2),
  );
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  String? _problem;

  @override
  void dispose() {
    for (final c in [_name, _customUnit, _price, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _unitText => _unit == _other ? _customUnit.text.trim() : _unit;

  void _save() {
    final w = context.words;
    final price = ExtraCharge.readPrice(_price.text, w);
    if (_name.text.trim().isEmpty) {
      setState(() => _problem = w.xNameNeeded);
      return;
    }
    if (_unitText.isEmpty) {
      setState(() => _problem = w.xUnitNeeded);
      return;
    }
    if (price.problem != null) {
      setState(() => _problem = price.problem);
      return;
    }
    final was = widget.editing;
    final item = ExtraItem(
      id: was?.id ?? ExtraCatalog.idFor(_name.text, widget.items),
      name: _name.text.trim(),
      category: _category,
      unit: _unitText,
      unitPriceCents: price.value!,
      currency: widget.currency,
      updatedAt: widget.clock(),
      note: _note.text.trim(),
      active: was?.active ?? true,
      by: widget.by,
    );
    final problem = ExtraCatalog.put(widget.items, item, w).problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = context.words;
    final text = Theme.of(context).textTheme;
    void changed(_) => setState(() => _problem = null);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.editing == null ? l.fxAdd : l.fxEditTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ExtraItemDialog.nameKey,
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.xName,
                hintText: l.xNameHint,
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ExtraCategory>(
              key: ExtraItemDialog.categoryKey,
              initialValue: _category,
              decoration: InputDecoration(labelText: l.xCategory),
              items: [
                for (final c in ExtraCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.labelIn(w))),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ExtraItemDialog.unitKey,
              initialValue: _unit,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.xUnit),
              items: [
                for (final u in ExtraUnit.values)
                  DropdownMenuItem(value: u.label, child: Text(u.sayIn(w))),
                DropdownMenuItem(value: _other, child: Text(l.xOtherUnit)),
              ],
              onChanged: (u) => setState(() {
                _unit = u ?? _unit;
                _problem = null;
              }),
            ),
            if (_unit == _other) ...[
              const SizedBox(height: 8),
              TextField(
                key: ExtraItemDialog.customUnitKey,
                controller: _customUnit,
                decoration: InputDecoration(labelText: l.xUnitInWords),
                onChanged: changed,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: ExtraItemDialog.priceKey,
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [LatinDigits()],
              decoration: InputDecoration(
                labelText: l.xUnitPrice,
                suffixText: widget.currency,
                helperText: l.fxCurrency(widget.currency),
              ),
              onChanged: changed,
            ),
            const SizedBox(height: 8),
            TextField(
              key: ExtraItemDialog.noteKey,
              controller: _note,
              decoration: InputDecoration(labelText: l.fxNote),
            ),
            if (_problem case final problem?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  problem,
                  key: ExtraItemDialog.problemKey,
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
          key: ExtraItemDialog.saveKey,
          onPressed: _save,
          child: Text(widget.editing == null ? l.fxAdd : l.xSave),
        ),
      ],
    );
  }
}

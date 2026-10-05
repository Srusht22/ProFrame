import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/model/materials.dart';
import '../../domain/pricing/colour_catalog.dart';
import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/profile_selection.dart';
import '../inspector/colour_picker.dart';
import '../inspector/price_panel.dart';
import '../inspector/profile_chooser.dart';
import '../theme/app_theme.dart';

/// The **Colours** of the factory's price list: every colour of its
/// catalog, in its order, each with its swatch, its name, what it adds on
/// each material it is sold in, and whether it is active or retired.
///
/// Everybody reads it. Only the owner adds a colour, edits one — its name,
/// swatch, materials and rates — or retires one, and each is a new version
/// of the list ([onChanged], which keeps it). Nothing here deletes a
/// colour: a retired one stays, for every design already in it.
class FactoryColoursSection extends StatelessWidget {
  final PriceList list;
  final bool editable;

  /// Keeps [list] as the next version; true where it was kept.
  final Future<bool> Function(PriceList list, String done) onChanged;

  const FactoryColoursSection({
    super.key,
    required this.list,
    required this.editable,
    required this.onChanged,
  });

  static const sectionKey = ValueKey('factory-colours');
  static const addKey = ValueKey('factory-colours-add');
  static ValueKey<String> rowKey(String id) => ValueKey('factory-colour-$id');
  static ValueKey<String> editKey(String id) =>
      ValueKey('factory-colour-edit-$id');
  static ValueKey<String> retireKey(String id) =>
      ValueKey('factory-colour-retire-$id');
  static ValueKey<String> restoreKey(String id) =>
      ValueKey('factory-colour-restore-$id');
  static ValueKey<String> statusKey(String id) =>
      ValueKey('factory-colour-status-$id');
  static ValueKey<String> ratesKey(String id) =>
      ValueKey('factory-colour-rates-$id');
  static const confirmRetireKey = ValueKey('factory-colour-confirm-retire');

  /// What [colour] adds on each material it is sold in, in words:
  /// *uPVC 1.00 USD/m · Aluminium 1.50 USD/m + 5%*.
  static String ratesOf(FactoryColour colour, String currency) => [
    for (final m in colour.materials)
      switch (colour.rateFor(m)) {
        null => '${m.label} not priced',
        final r =>
          '${m.label} ${PricePanel.money(r.perMetre, currency)}/m'
              '${r.percent > 0 ? ' + ${_figure(r.percent)}%' : ''}',
      },
  ].join(' · ');

  static String _figure(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  Future<void> _add(BuildContext context) async {
    final next = await ColourDialog.show(context, list: list);
    if (next == null) return;
    await onChanged(next, 'Colour added.');
  }

  Future<void> _edit(BuildContext context, FactoryColour colour) async {
    final next = await ColourDialog.show(context, list: list, editing: colour);
    if (next == null) return;
    await onChanged(next, 'Colour saved.');
  }

  Future<void> _retire(BuildContext context, FactoryColour colour) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retire ${colour.name}?'),
        content: const SizedBox(
          width: 420,
          child: Text(
            'It will no longer be offered for new designs. Every design '
            'already in it keeps it, is still shown in it and is still '
            'priced at its rate. Nothing is deleted, and it can be brought '
            'back.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: confirmRetireKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retire colour'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    await onChanged(
      ColourCatalog.retire(list, colour.id),
      '${colour.name} retired.',
    );
  }

  Future<void> _restore(BuildContext context, FactoryColour colour) async {
    final back = ColourCatalog.restore(list, colour.id);
    if (back.list == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(back.problems.values.first)));
      return;
    }
    await onChanged(back.list!, '${colour.name} is offered again.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'COLOURS',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              if (editable)
                OutlinedButton.icon(
                  key: addKey,
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add colour'),
                ),
            ],
          ),
        ),
        Text(
          'What each colour adds on each material it is sold in, by the '
          'metre of profile and as a share of the profile\'s price. A '
          'retired colour is not offered for new designs; designs already '
          'in it keep it.',
          style: text.bodySmall?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 6),
        if (list.colours.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No colours yet. Every colour is priced as any other colour.',
              style: text.bodyMedium,
            ),
          ),
        for (final c in list.colours)
          Card(
            key: rowKey(c.id),
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  colourSwatch(c.swatch),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              c.name,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              c.active ? 'Active' : 'Retired',
                              key: statusKey(c.id),
                              style: text.labelSmall?.copyWith(
                                color: c.active ? p.primary : p.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ratesOf(c, list.currency),
                          key: ratesKey(c.id),
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  if (editable) ...[
                    IconButton(
                      key: editKey(c.id),
                      tooltip: 'Edit ${c.name}',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, c),
                    ),
                    if (c.active)
                      IconButton(
                        key: retireKey(c.id),
                        tooltip: 'Retire ${c.name}',
                        icon: const Icon(Icons.archive_outlined),
                        onPressed: () => _retire(context, c),
                      )
                    else
                      IconButton(
                        key: restoreKey(c.id),
                        tooltip: 'Offer ${c.name} again',
                        icon: const Icon(Icons.unarchive_outlined),
                        onPressed: () => _restore(context, c),
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

/// Adds a colour to the catalog, or edits one: its name, its swatch,
/// whether it is a standard colour, the materials it is sold in and what it
/// adds on each. Returns the list with it, checked (`ColourCatalog`), or
/// null where nothing was kept.
class ColourDialog extends StatefulWidget {
  final PriceList list;
  final FactoryColour? editing;

  const ColourDialog({super.key, required this.list, this.editing});

  static const nameKey = ValueKey('colour-dialog-name');
  static const hexKey = ValueKey('colour-dialog-hex');
  static const standardKey = ValueKey('colour-dialog-standard');
  static const saveKey = ValueKey('colour-dialog-save');
  static const materialsProblemKey = ValueKey('colour-dialog-materials');
  static ValueKey<String> materialKey(MaterialKind m) =>
      ValueKey('colour-dialog-material-${m.name}');
  static ValueKey<String> metreKey(MaterialKind m) =>
      ValueKey('colour-dialog-metre-${m.name}');
  static ValueKey<String> percentKey(MaterialKind m) =>
      ValueKey('colour-dialog-percent-${m.name}');

  static Future<PriceList?> show(
    BuildContext context, {
    required PriceList list,
    FactoryColour? editing,
  }) => showDialog<PriceList>(
    context: context,
    builder: (_) => ColourDialog(list: list, editing: editing),
  );

  @override
  State<ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<ColourDialog> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late int _swatch = widget.editing?.swatch ?? 0xFF9C9C9C;
  late final _hex = TextEditingController(text: _hexOf(_swatch));
  late bool _standard = widget.editing?.grade == ColourGrade.standard;
  final _sold = <MaterialKind>{};
  final _metre = <MaterialKind, TextEditingController>{};
  final _percent = <MaterialKind, TextEditingController>{};
  Map<String, String> _problems = const {};

  late final List<MaterialKind> _materials = [
    ...profileMaterialsOf(widget.list),
    // A material the colour is sold in that the list no longer prices a
    // profile in is still shown, so it can be taken off.
    for (final m in widget.editing?.materials ?? const <MaterialKind>[])
      if (!widget.list.profiles.containsKey(m)) m,
  ];

  static String _hexOf(int colour) =>
      (colour & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static String _figure(double? v) {
    if (v == null) return '';
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  void initState() {
    super.initState();
    for (final m in _materials) {
      final rate = widget.editing?.rateFor(m);
      _metre[m] = TextEditingController(text: _figure(rate?.perMetre));
      _percent[m] = TextEditingController(
        text: rate == null || rate.percent == 0 ? '' : _figure(rate.percent),
      );
      if (widget.editing?.appliesTo(m) ?? false) _sold.add(m);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    for (final c in [..._metre.values, ..._percent.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final problems = <String, String>{};
    final rates = <MaterialKind, ColourSurcharge?>{};
    for (final m in _sold) {
      final metre = ColourCatalog.readRate(_metre[m]!.text);
      final percent = ColourCatalog.readRate(_percent[m]!.text);
      final typed = metre.problem ?? percent.problem;
      if (typed != null) {
        problems[ColourCatalog.rateField(m)] = typed;
        rates[m] = const ColourSurcharge();
        continue;
      }
      rates[m] = metre.value == null
          ? null
          : ColourSurcharge(
              perMetre: metre.value!,
              percent: percent.value ?? 0,
            );
    }
    final draft = ColourDraft(
      name: _name.text,
      swatch: _swatch,
      grade: _standard ? ColourGrade.standard : ColourGrade.nonStandard,
      rates: rates,
    );
    final editing = widget.editing;
    final done = editing == null
        ? ColourCatalog.add(widget.list, draft)
        : (() {
            final r = ColourCatalog.update(widget.list, editing.id, draft);
            return (list: r.list, problems: r.problems, id: editing.id);
          })();
    final all = {...done.problems, ...problems};
    if (all.isNotEmpty || done.list == null) {
      setState(() => _problems = all);
      return;
    }
    Navigator.of(context).pop(done.list);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final error = Theme.of(context).colorScheme.error;
    final editing = widget.editing;
    return AlertDialog(
      scrollable: true,
      title: Text(editing == null ? 'Add colour' : 'Edit ${editing.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ColourDialog.nameKey,
              controller: _name,
              autofocus: editing == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Colour name',
                errorText: _problems[ColourCatalog.nameField],
                errorMaxLines: 3,
              ),
            ),
            if (editing != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Renaming keeps it the same colour: every design in it '
                  'shows the new name.',
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
            const SizedBox(height: 14),
            Text('Swatch', style: text.labelMedium),
            const SizedBox(height: 6),
            ColourPicker(
              colour: _swatch,
              onChanged: (c) => setState(() {
                _swatch = c;
                _hex.text = _hexOf(c);
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                colourSwatch(_swatch),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: ColourDialog.hexKey,
                    controller: _hex,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: '#',
                      counterText: '',
                      labelText: 'Or its code',
                    ),
                    onChanged: (v) {
                      if (v.length == 6) {
                        setState(
                          () => _swatch = 0xFF000000 | int.parse(v, radix: 16),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: ColourDialog.standardKey,
              contentPadding: EdgeInsets.zero,
              value: _standard,
              title: const Text('Standard colour'),
              onChanged: (v) => setState(() => _standard = v),
            ),
            const SizedBox(height: 4),
            Text('Sold in, and what it adds', style: text.labelMedium),
            if (_problems[ColourCatalog.materialsField] case final problem?)
              Padding(
                key: ColourDialog.materialsProblemKey,
                padding: const EdgeInsets.only(top: 4),
                child: Text(problem, style: TextStyle(color: error)),
              ),
            for (final m in _materials) ...[
              CheckboxListTile(
                key: ColourDialog.materialKey(m),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _sold.contains(m),
                title: Text(m.label),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _sold.add(m);
                  } else {
                    _sold.remove(m);
                  }
                }),
              ),
              if (_sold.contains(m))
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextField(
                          key: ColourDialog.metreKey(m),
                          controller: _metre[m],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'A metre',
                            suffixText: '${widget.list.currency} / m',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          key: ColourDialog.percentKey(m),
                          controller: _percent[m],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'On the profile',
                            hintText: '0',
                            suffixText: '%',
                          ),
                        ),
                      ),
                      if (_problems[ColourCatalog.rateField(m)]
                          case final problem?)
                        Text(problem, style: TextStyle(color: error)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: ColourDialog.saveKey,
          onPressed: _save,
          child: Text(editing == null ? 'Add colour' : 'Save colour'),
        ),
      ],
    );
  }
}

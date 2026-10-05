import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/price_list_fields.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../infrastructure/owner_access_store.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'factory_colours.dart';

/// **Factory prices** on the customers' header: the workshop's price list.
class FactoryPricesButton extends StatelessWidget {
  final Color colour;

  const FactoryPricesButton({super.key, required this.colour});

  static const buttonKey = ValueKey('factory-prices');

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: 'Factory prices',
    icon: Icon(Icons.price_change_outlined, color: colour),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FactoryPricesScreen()),
    ),
  );
}

/// The factory's price list — what it charges for each material, colour,
/// glass, panel and piece of ironmongery — as the owner keeps it.
///
/// **Everybody can read it; only the owner changes it** ([WorkshopRole]).
/// Staff see every figure and a way to unlock as the owner; the owner
/// edits the figures and keeps them, and the list kept is a new version —
/// so every price worked out from the one before says it needs
/// recalculating, and no design is ever repriced behind anybody's back.
///
/// Every figure is a [RateField], so what is listed here is exactly what
/// the engine reads, and keeping the list drops nothing it held.
class FactoryPricesScreen extends ConsumerStatefulWidget {
  const FactoryPricesScreen({super.key});

  static const saveKey = ValueKey('factory-prices-save');
  static const unlockKey = ValueKey('factory-prices-unlock');
  static const lockKey = ValueKey('factory-prices-lock');
  static const pinKey = ValueKey('factory-prices-pin');
  static const pinAgainKey = ValueKey('factory-prices-pin-again');
  static const pinOkKey = ValueKey('factory-prices-pin-ok');
  static const readOnlyKey = ValueKey('factory-prices-read-only');

  static ValueKey<String> fieldKey(String id) => ValueKey('rate-$id');

  @override
  ConsumerState<FactoryPricesScreen> createState() =>
      _FactoryPricesScreenState();
}

class _FactoryPricesScreenState extends ConsumerState<FactoryPricesScreen> {
  final _text = <String, TextEditingController>{};
  final _problems = <String, String>{};
  PriceList? _shown;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _write(double? value, {bool whole = false}) {
    if (value == null) return '';
    if (whole) return value.round().toString();
    final s = value.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  /// The fields' words, put back to [list]'s figures — except, where
  /// [keepEdits], a figure the owner has typed over and not kept yet: a
  /// colour kept meanwhile does not throw it away.
  void _fill(PriceList list, {bool keepEdits = false}) {
    final was = _shown;
    _shown = list;
    _problems.clear();
    for (final f in RateField.of(list)) {
      final text = _text[f.id] ??= TextEditingController();
      final typedOver =
          keepEdits &&
          was != null &&
          text.text != _write(f.read(was), whole: f.whole);
      if (!typedOver) text.text = _write(f.read(list), whole: f.whole);
    }
  }

  /// Keeps [list] — a colour added, edited or retired — as the next version
  /// of the price list, and says [done] where it was kept.
  Future<bool> _keepColours(PriceList list, String done) async {
    try {
      final kept = await ref.savePriceList(list);
      if (!mounted) return true;
      setState(() => _fill(kept, keepEdits: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$done Prices kept as version ${kept.version}; every design '
            'priced before is now to be recalculated.',
          ),
        ),
      );
      return true;
    } on PricingAccessDenied catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    }
  }

  Future<void> _save(PriceList list) async {
    var next = list;
    final problems = <String, String>{};
    for (final f in RateField.of(list)) {
      final words = _text[f.id]?.text.trim() ?? '';
      final value = words.isEmpty ? null : double.tryParse(words);
      final problem = words.isNotEmpty && value == null
          ? 'Enter a figure.'
          : f.problemWith(value);
      if (problem != null) {
        problems[f.id] = problem;
        continue;
      }
      next = f.write(next, value);
    }
    setState(() {
      _problems
        ..clear()
        ..addAll(problems);
    });
    if (problems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${problems.length} '
            '${problems.length == 1 ? 'figure needs' : 'figures need'} '
            'correcting before the prices can be kept.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final kept = await ref.savePriceList(next);
      if (!mounted) return;
      _fill(kept);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prices kept. Every design priced before is now to be '
            'recalculated.',
          ),
        ),
      );
    } on PricingAccessDenied catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlock() async {
    final store = ref.read(ownerAccessStoreProvider);
    final hasPin = await store.hasPin();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => OwnerPinDialog(store: store, setting: !hasPin),
    );
    if (ok ?? false) ref.signInAsOwner();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(priceListProvider).value;
    final role = ref.watch(workshopRoleProvider);
    final owner = ref.watch(actorProvider).can(Capability.pricingEdit);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    if (list != null && !identical(list, _shown)) _fill(list, keepEdits: true);

    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(
        title: const Text('Factory prices'),
        actions: [
          if (role == WorkshopRole.owner)
            TextButton.icon(
              key: FactoryPricesScreen.lockKey,
              // The bar's own lettering, on the bar's green.
              style: TextButton.styleFrom(foregroundColor: p.onBand),
              onPressed: ref.signOut,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Lock'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (!owner)
                      Card(
                        key: FactoryPricesScreen.readOnlyKey,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Only the workshop owner can change prices.',
                                style: text.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'These are the rates every design is priced '
                                'by. Staff can read them and price designs '
                                'by them.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                key: FactoryPricesScreen.unlockKey,
                                onPressed: _unlock,
                                icon: const Icon(Icons.lock_open_outlined),
                                label: const Text('Unlock as owner'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (list.isStarter)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Example prices — the workshop owner sets the '
                          'real ones.',
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'In ${list.currency}. A figure left empty is not '
                        'priced: a design using it says so rather than '
                        'being priced at nothing.',
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ),
                    ..._sections(list, editable: owner),
                  ],
                ),
              ),
            ),
      floatingActionButton: owner && list != null
          ? FloatingActionButton.extended(
              key: FactoryPricesScreen.saveKey,
              onPressed: _saving ? null : () => _save(list),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Keep prices'),
            )
          : null,
    );
  }

  List<Widget> _sections(PriceList list, {required bool editable}) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final out = <Widget>[];
    String? section;
    var colours = false;
    for (final f in RateField.of(list)) {
      if (f.section != section) {
        section = f.section;
        // The colour catalog, before what a colour it does not name adds.
        if (!colours && f.id.startsWith('colour.')) {
          colours = true;
          out.add(
            FactoryColoursSection(
              list: list,
              editable: editable,
              onChanged: _keepColours,
            ),
          );
        }
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              f.section.toUpperCase(),
              style: text.labelMedium?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: p.muted,
              ),
            ),
          ),
        );
      }
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(f.label, style: text.bodyMedium),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: TextField(
                  key: FactoryPricesScreen.fieldKey(f.id),
                  controller: _text[f.id],
                  readOnly: !editable,
                  enabled: editable,
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: f.optional ? 'not priced' : null,
                    suffixText: f.unit,
                    errorText: _problems[f.id],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }
}

/// Asks for the owner's PIN — or, where none is set yet, has it set.
/// The owner's PIN: set the first time, asked for after.
class OwnerPinDialog extends StatefulWidget {
  final OwnerAccessStore store;
  final bool setting;

  const OwnerPinDialog({super.key, required this.store, required this.setting});

  @override
  State<OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<OwnerPinDialog> {
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    final pin = _pin.text.trim();
    if (widget.setting) {
      final problem =
          OwnerAccessStore.problemWith(pin) ??
          (pin == _again.text.trim() ? null : 'The two PINs are not the same.');
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
      final set = await widget.store.setPin(pin);
      if (!mounted) return;
      if (!set) {
        setState(() => _problem = 'An owner PIN is already set.');
        return;
      }
      Navigator.of(context).pop(true);
      return;
    }
    final right = await widget.store.verify(pin);
    if (!mounted) return;
    if (!right) {
      setState(() => _problem = 'That is not the owner PIN.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.setting ? 'Set the owner PIN' : 'Unlock as owner'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.setting
              ? 'No owner PIN is set on this device. The PIN you set now is '
                    'what signs the owner in from here on — to change the '
                    'factory prices, give discounts and manage staff.'
              : 'Enter the owner PIN.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: FactoryPricesScreen.pinKey,
          controller: _pin,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Owner PIN'),
          onSubmitted: (_) => _ok(),
        ),
        if (widget.setting)
          TextField(
            key: FactoryPricesScreen.pinAgainKey,
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'The PIN again'),
            onSubmitted: (_) => _ok(),
          ),
        if (_problem case final problem?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              problem,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: FactoryPricesScreen.pinOkKey,
        onPressed: _ok,
        child: Text(widget.setting ? 'Set PIN' : 'Unlock'),
      ),
    ],
  );
}

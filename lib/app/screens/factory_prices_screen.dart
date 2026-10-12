import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pricing/price_list.dart';
import '../../domain/pricing/price_list_fields.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/text/numerals.dart';
import '../../infrastructure/owner_access_store.dart';
import '../l10n/errors.dart';
import '../l10n/l10n.dart';
import '../l10n/latin_digits.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'factory_colours.dart';
import 'factory_extras.dart';

/// **Factory prices** on the customers' header: the workshop's price list.
class FactoryPricesButton extends StatelessWidget {
  final Color colour;

  const FactoryPricesButton({super.key, required this.colour});

  static const buttonKey = ValueKey('factory-prices');

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: context.l10n.fpTitle,
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

  static const chargesGlassKey = ValueKey('factory-prices-charges-glass');
  static const discardKey = ValueKey('factory-prices-discard');
  static const discardConfirmKey = ValueKey('factory-prices-discard-confirm');
  static const confirmKey = ValueKey('factory-prices-confirm');

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

  /// The factory's *Charge for glass*, as the form has it: kept with the
  /// figures, by **Keep prices**.
  bool? _chargesGlass;

  /// How many figures may change at once before keeping them is asked
  /// about first — enough for an ordinary price change, not a whole list.
  static const broadChange = 5;

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
    if (!keepEdits || was == null || _chargesGlass == was.chargesGlass) {
      _chargesGlass = list.chargesGlass;
    }
    for (final f in RateField.of(list, context.words)) {
      final text = _text[f.id] ??= TextEditingController();
      final typedOver =
          keepEdits &&
          was != null &&
          text.text != _write(f.read(was), whole: f.whole);
      if (!typedOver) text.text = _write(f.read(list), whole: f.whole);
    }
  }

  /// The figures typed over and not kept, by id.
  Set<String> _changed(PriceList list) => {
    for (final f in RateField.of(list, context.words))
      if ((_text[f.id]?.text.trim() ?? '') !=
          _write(f.read(list), whole: f.whole))
        f.id,
  };

  bool _dirty(PriceList list) =>
      _changed(list).isNotEmpty || _chargesGlass != list.chargesGlass;

  void _discard(PriceList list) => setState(() {
    _shown = null;
    _fill(list);
  });

  /// Keeps [list] — a colour added, edited or retired — as the next version
  /// of the price list, and says [done] where it was kept.
  Future<bool> _keepColours(PriceList list, String done) async {
    try {
      final kept = await ref.savePriceList(list);
      if (!mounted) return true;
      setState(() => _fill(kept, keepEdits: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.fpColoursKept(done, kept.version))),
      );
      return true;
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageOf(context, e))),
        );
      }
      return false;
    }
  }

  Future<void> _save(PriceList list) async {
    if (_saving) return;
    var next = list.copyWith(chargesGlass: _chargesGlass);
    final problems = <String, String>{};
    for (final f in RateField.of(list, context.words)) {
      final words = Numerals.latin(_text[f.id]?.text ?? '').trim();
      final value = words.isEmpty ? null : double.tryParse(words);
      final problem = words.isNotEmpty && (value == null || !value.isFinite)
          ? context.words.ccEnterFigure
          : f.problemWith(value, context.words);
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
        SnackBar(content: Text(context.l10n.fpNeedCorrecting(problems.length))),
      );
      return;
    }
    // A change of many figures at once, or of whether glass is charged at
    // all, reaches every design: asked about before it is kept.
    final changes =
        _changed(list).length + (_chargesGlass != list.chargesGlass ? 1 : 0);
    if (changes >= broadChange || _chargesGlass != list.chargesGlass) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.fpConfirmTitle(changes)),
          content: SizedBox(
            width: 420,
            child: Text(context.l10n.fpConfirmBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.actCancel),
            ),
            FilledButton(
              key: FactoryPricesScreen.confirmKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.fpKeep),
            ),
          ],
        ),
      );
      if (!(sure ?? false) || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final kept = await ref.savePriceList(next);
      if (!mounted) return;
      _fill(kept);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.fpKept)));
    } on Object catch (e) {
      // Not kept: every figure typed stays in its field, and the list on
      // the device is what it was. Nobody is told it was kept.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageOf(context, e))));
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

  /// Asked before leaving with figures typed and not kept.
  Future<void> _leave(PriceList? list) async {
    if (list == null || !_dirty(list)) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.fpDiscardAsk),
        content: Text(context.l10n.fpDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.fpKeepEditing),
          ),
          FilledButton(
            key: FactoryPricesScreen.discardConfirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.fpDiscard),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(priceListProvider).value;
    final role = ref.watch(workshopRoleProvider);
    final owner = ref.watch(actorProvider).can(Capability.pricingEdit);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    if (list != null && !identical(list, _shown)) _fill(list, keepEdits: true);
    final dirty = owner && list != null && _dirty(list);

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _leave(list);
      },
      child: Scaffold(
        backgroundColor: p.shell,
        appBar: AppBar(
          title: Text(context.l10n.fpTitle),
          actions: [
            if (dirty)
              TextButton.icon(
                key: FactoryPricesScreen.discardKey,
                style: TextButton.styleFrom(foregroundColor: p.onBand),
                onPressed: _saving ? null : () => _discard(list),
                icon: const Icon(Icons.undo),
                label: Text(context.l10n.fpDiscard),
              ),
            if (role == WorkshopRole.owner)
              TextButton.icon(
                key: FactoryPricesScreen.lockKey,
                // The bar's own lettering, on the bar's green.
                style: TextButton.styleFrom(foregroundColor: p.onBand),
                onPressed: ref.signOut,
                icon: const Icon(Icons.lock_outline),
                label: Text(context.l10n.fpLock),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                                  context.l10n.fpOnlyOwner,
                                  style: text.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.fpRatesNote,
                                  style: text.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  key: FactoryPricesScreen.unlockKey,
                                  onPressed: _unlock,
                                  icon: const Icon(Icons.lock_open_outlined),
                                  label: Text(context.l10n.fpUnlock),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (list.isStarter)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.l10n.ppExamplePrices,
                            style: text.bodySmall?.copyWith(color: p.muted),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${context.l10n.fpIntro} '
                          '${context.l10n.fpInCurrency(list.currency)}',
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                      ),
                      ..._sections(list, editable: owner),
                      FactoryExtrasSection(
                        currency: list.currency,
                        editable: owner,
                      ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: owner && list != null
            ? FloatingActionButton.extended(
                key: FactoryPricesScreen.saveKey,
                onPressed: _saving ? null : () => _save(list),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? context.l10n.fpSaving : context.l10n.fpKeep,
                ),
              )
            : null,
      ),
    );
  }

  /// The factory's *Charge for glass*: off for a new configuration, and
  /// while off, no glass rate is asked for — the figures are kept as they
  /// are, only not shown.
  Widget _glassSwitch({required bool editable}) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final on = _chargesGlass ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          key: FactoryPricesScreen.chargesGlassKey,
          value: on,
          onChanged: editable
              ? (v) => setState(() => _chargesGlass = v)
              : null,
          title: Text(
            context.l10n.fpChargeGlass,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            on ? context.l10n.fpChargeGlassOn : context.l10n.fpChargeGlassOff,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(PriceList list, {required bool editable}) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final out = <Widget>[];
    String? section;
    var colours = false;
    var glass = false;
    for (final f in RateField.of(list, context.words)) {
      final isGlass = f.id.startsWith('glass.');
      if (isGlass && !glass) {
        glass = true;
        out.add(_glassSwitch(editable: editable));
      }
      // While glass is not charged its rates are not asked for; they are
      // kept as they are, and shown again when it is.
      if (isGlass && !(_chargesGlass ?? false)) continue;
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
            padding: const EdgeInsets.only(top: 20, bottom: 2),
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
        if (f.about case final about?) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                about,
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          );
        }
      }
      // The unit with the currency an amount is in: `USD / m`, `USD each`.
      final unit = f.isMoney ? '${list.currency} ${f.unit}' : f.unit;
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
                width: 170,
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
                    const LatinDigits(),
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  // Room above the keyboard for the field and its message.
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onChanged: (_) => setState(() => _problems.remove(f.id)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: f.optional ? context.l10n.fpNotPriced : null,
                    suffixText: unit,
                    errorText: _problems[f.id],
                    errorMaxLines: 3,
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
          OwnerAccessStore.problemWith(pin, context.words) ??
          (pin == _again.text.trim() ? null : context.l10n.pinNotSame);
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
      final set = await widget.store.setPin(pin);
      if (!mounted) return;
      if (!set) {
        setState(() => _problem = context.l10n.pinAlreadySet);
        return;
      }
      Navigator.of(context).pop(true);
      return;
    }
    final right = await widget.store.verify(pin);
    if (!mounted) return;
    if (!right) {
      setState(() => _problem = context.l10n.pinWrong);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.setting ? context.l10n.pinSetTitle : context.l10n.fpUnlock,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.setting ? context.l10n.pinSetNote : context.l10n.pinEnterOwner,
        ),
        const SizedBox(height: 12),
        TextField(
          key: FactoryPricesScreen.pinKey,
          controller: _pin,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
           const LatinDigits(),
            const LatinDigits(),
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(labelText: context.l10n.pinOwner),
          onSubmitted: (_) => _ok(),
        ),
        if (widget.setting)
          TextField(
            key: FactoryPricesScreen.pinAgainKey,
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
           const LatinDigits(),
            const LatinDigits(),
            FilteringTextInputFormatter.digitsOnly,
          ],
            decoration: InputDecoration(labelText: context.l10n.pinAgain),
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
        child: Text(context.l10n.actCancel),
      ),
      FilledButton(
        key: FactoryPricesScreen.pinOkKey,
        onPressed: _ok,
        child: Text(
          widget.setting ? context.l10n.pinSet : context.l10n.pinUnlock,
        ),
      ),
    ],
  );
}

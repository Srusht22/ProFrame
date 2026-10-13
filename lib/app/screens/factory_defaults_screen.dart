import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurement_defaults.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/model/materials.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/text/names.dart';
import '../l10n/errors.dart';
import '../l10n/l10n.dart';
import '../l10n/latin_digits.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'factory_prices_screen.dart';

/// The factory's own figures, on the first screen: one button, opening
/// [FactoryDefaultsScreen].
class FactoryButton extends StatelessWidget {
  final Color colour;

  const FactoryButton({super.key, required this.colour});

  static const buttonKey = ValueKey('factory-defaults');

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: context.l10n.fdTitle,
    style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
    icon: Icon(Icons.factory_outlined, color: colour, size: 22),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FactoryDefaultsScreen()),
    ),
  );
}

/// What the factory sets once and every design starts from, in two parts
/// kept apart: its **default measurements** — the border, the bars and the
/// depth of each kind of profile — and its **default prices** — the rate of
/// each kind of profile and of each of its colours, and the rest of the
/// price list.
class FactoryDefaultsScreen extends StatelessWidget {
  const FactoryDefaultsScreen({super.key});

  static const measurementsKey = ValueKey('factory-defaults-measurements');
  static const pricesKey = ValueKey('factory-defaults-prices');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(title: Text(l.fdTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.fdIntro, style: TextStyle(fontSize: 14, color: p.muted)),
              const SizedBox(height: 16),
              _Choice(
                key: measurementsKey,
                icon: Icons.straighten,
                title: l.fdMeasurements,
                line: l.fdMeasurementsLine,
                open: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MeasurementDefaultsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Choice(
                key: pricesKey,
                icon: Icons.price_change_outlined,
                title: l.fdPrices,
                line: l.fdPricesLine,
                open: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FactoryPricesScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  final VoidCallback open;

  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.line,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: p.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(line, style: TextStyle(fontSize: 13, color: p.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The factory's usual border, bar thickness and depth for each kind of
/// profile it sells (`MeasurementDefaults`), in centimetres.
///
/// Everybody may read them; only whoever holds `pricing.edit` changes
/// them, and the store refuses anybody else. They fill nothing by
/// themselves: the sizes form offers them for each design.
class MeasurementDefaultsScreen extends ConsumerStatefulWidget {
  const MeasurementDefaultsScreen({super.key});

  static const saveKey = ValueKey('measurement-defaults-save');
  static const unlockKey = ValueKey('measurement-defaults-unlock');

  static ValueKey<String> fieldKey(MaterialKind m, String which) =>
      ValueKey('measurement-default-${m.name}-$which');

  @override
  ConsumerState<MeasurementDefaultsScreen> createState() =>
      _MeasurementDefaultsScreenState();
}

class _MeasurementDefaultsScreenState
    extends ConsumerState<MeasurementDefaultsScreen> {
  static const _which = ['border', 'bars', 'depth'];

  final _text = <String, TextEditingController>{};
  final _problems = <String, String>{};
  MeasurementDefaults? _shown;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _id(MaterialKind m, String which) => '${m.name}.$which';

  static double? _figure(ProfileDefaults d, String which) => switch (which) {
    'border' => d.borderMm,
    'bars' => d.barMm,
    _ => d.depthMm,
  };

  static String _write(double? mm) {
    if (mm == null) return '';
    final cm = mm / 10;
    final s = cm.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  void _fill(MeasurementDefaults kept, List<MaterialKind> materials) {
    _shown = kept;
    _problems.clear();
    for (final m in materials) {
      for (final w in _which) {
        (_text[_id(m, w)] ??= TextEditingController()).text = _write(
          _figure(kept.of(m), w),
        );
      }
    }
  }

  Future<void> _save(List<MaterialKind> materials) async {
    if (_saving) return;
    var next = _shown ?? MeasurementDefaults.none;
    final problems = <String, String>{};
    for (final m in materials) {
      final read = <String, double?>{};
      for (final w in _which) {
        final value = MeasurementDefaults.readCm(_text[_id(m, w)]?.text ?? '');
        if (value == MeasurementDefaults.invalid) {
          problems[_id(m, w)] = context.l10n.mdInvalid;
        }
        read[w] = value == MeasurementDefaults.invalid ? null : value;
      }
      next = next.withMaterial(
        m,
        ProfileDefaults(
          borderMm: read['border'],
          barMm: read['bars'],
          depthMm: read['depth'],
        ),
      );
    }
    setState(() {
      _problems
        ..clear()
        ..addAll(problems);
    });
    if (problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final kept = await ref.saveMeasurementDefaults(next);
      if (!mounted) return;
      setState(() => _fill(kept, materials));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.mdKept)));
    } on Object catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final kept = ref.watch(measurementDefaultsProvider).value;
    final list = ref.watch(priceListProvider).value;
    final may = ref.watch(actorProvider).can(Capability.pricingEdit);
    // The kinds of profile the factory sells: the price list's materials.
    final materials = [
      for (final m in MaterialKind.values)
        if (list?.profiles.containsKey(m) ?? false) m,
    ];
    if (kept != null && list != null && !identical(kept, _shown)) {
      _fill(kept, materials);
    }
    final ready = kept != null && list != null;

    Widget field(MaterialKind m, String which, String label) {
      final id = _id(m, which);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14.5, color: p.ink),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: TextField(
                key: MeasurementDefaultsScreen.fieldKey(m, which),
                controller: _text[id],
                enabled: may && !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  const LatinDigits(),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: l.mdNotSet,
                  suffixText: Units.symbol,
                  errorText: _problems[id],
                  errorMaxLines: 3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(title: Text(l.fdMeasurements)),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    Text(
                      l.mdIntro,
                      style: TextStyle(fontSize: 13.5, color: p.muted),
                    ),
                    if (!may) ...[
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.mdOnlyOwner),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                key: MeasurementDefaultsScreen.unlockKey,
                                onPressed: _unlock,
                                icon: const Icon(Icons.lock_open_outlined),
                                label: Text(l.fpUnlock),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    for (final m in materials)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  m.labelIn(context.words),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                                field(
                                  m,
                                  'border',
                                  context.words.measFrameBorder,
                                ),
                                field(
                                  m,
                                  'bars',
                                  context.words.measBarThickness,
                                ),
                                field(m, 'depth', l.mdDepth),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: may && ready
          ? FloatingActionButton.extended(
              key: MeasurementDefaultsScreen.saveKey,
              onPressed: _saving ? null : () => _save(materials),
              icon: const Icon(Icons.save_outlined),
              label: Text(l.mdKeep),
            )
          : null,
    );
  }
}

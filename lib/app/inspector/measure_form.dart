import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurement_defaults.dart';
import '../../domain/dimensions/measurements.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
import '../../domain/model/materials.dart';
import '../../domain/pricing/profile_selection.dart';
import '../../domain/text/names.dart';
import '../l10n/l10n.dart';
import '../l10n/latin_digits.dart';
import '../state/pricing.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// The real size of every part, asked for once the drawing is read.
///
/// The user's words: *never write any number for width and height as a
/// guess — ask the width and height of everything: the border, the opening
/// part, the glass, a line in the opening.* A sketch has proportions and no
/// scale, so this is where the scale comes from: the frame's border and its
/// bars, the overall size, then every light in the order the drawing reads
/// and every pane drawn inside an opening.
///
/// **The factory's usual sizes are offered, never put in by themselves.**
/// Where the factory has set default measurements for a kind of profile
/// (`MeasurementDefaults`), **Fill from factory defaults** puts its
/// border, bar thickness and depth into the fields — at once for a design
/// whose profile is already chosen and has none of them yet — and the user
/// can type over any of them for this design before **Apply**.
///
/// **What follows from the rest is worked out, not asked.** The last light
/// in a row is what is left of the width once the others are given, so it
/// is shown as it comes out rather than asked for and then contradicted. A
/// field left empty stays `?` everywhere, and the form can be opened again
/// from the bar at the top to finish it.
class MeasureForm extends ConsumerStatefulWidget {
  const MeasureForm({super.key});

  /// The width below which it fills the screen.
  static const fullScreenBelow = 600.0;

  /// The field for the frame's depth, which every design has.
  static const depthKey = ValueKey('measure-depth');

  /// The button filling the fields from the factory's defaults for [m].
  static ValueKey<String> defaultsKey(MaterialKind m) =>
      ValueKey('measure-defaults-${m.name}');

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => const MeasureForm(),
  );

  @override
  ConsumerState<MeasureForm> createState() => _MeasureFormState();
}

class _MeasureFormState extends ConsumerState<MeasureForm> {
  final _fields = <String, TextEditingController>{};
  Map<String, String> _problems = const {};

  /// The nearest size that fits, by key, for each size that did not.
  Map<String, double> _suggestions = const {};

  /// The sizes made as typed although something did not fit, by key, with
  /// the size made.
  Map<String, double> _applied = const {};

  /// What the drawing itself warns about, said beside a size that did not
  /// fit, since it may be what is in the way.
  String? _alsoCheck;

  /// The first size still to give, which the form opens on — after a line
  /// is drawn and read, the one new size can be anywhere down the list.
  String? _first;

  /// The frame's depth, in centimetres as typed.
  final _depth = TextEditingController();

  /// The kind of profile whose factory defaults were last put in.
  MaterialKind? _filledFrom;

  /// Whether the defaults have been offered to a design whose profile is
  /// chosen — once, the first time they are known.
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    final design = ref.read(workspaceProvider).design;
    _depth
      ..text = Units.format(design.depthMm)
      ..addListener(() => setState(() {}));
    final all = Measurements.of(design);
    for (final m in all) {
      if (!m.asked) continue;
      final known = Measurements.knows(design, m, all);
      _fields[m.key] = TextEditingController(
        text: known ? Units.format(m.currentMm(design)) : '',
      )..addListener(() => setState(() {}));
      if (!known) _first ??= m.key;
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _depth.dispose();
    super.dispose();
  }

  /// [defaults] put into the fields they are for; nothing is applied until
  /// **Apply**.
  void _fill(MaterialKind material, ProfileDefaults defaults) {
    setState(() {
      _filledFrom = material;
      if (defaults.borderMm case final mm?) {
        _fields[Measurements.profileKey]?.text = Units.format(mm);
      }
      if (defaults.barMm case final mm?) {
        _fields[Measurements.barsKey]?.text = Units.format(mm);
      }
      if (defaults.depthMm case final mm?) _depth.text = Units.format(mm);
    });
  }

  /// The depth typed, in millimetres, where it is a size and not the
  /// design's own.
  double? _depthTyped(Design design) {
    final value = Units.parse(_depth.text);
    if (value == null || value <= 0) return null;
    if ((value - design.depthMm).abs() < 0.05) return null;
    return value;
  }

  /// What has been typed, in millimetres, leaving out what is blank, what
  /// is not a number and what is unchanged from a size already given.
  Map<String, double> _typed(Design design, List<Measure> all) {
    final values = <String, double>{};
    for (final m in all) {
      final field = _fields[m.key];
      if (field == null) continue;
      final value = Units.parse(field.text);
      if (value == null || value <= 0) continue;
      final given = Measurements.knows(design, m, all);
      if (given && (value - m.currentMm(design)).abs() < 0.05) continue;
      values[m.key] = value;
    }
    return values;
  }

  void _apply(Design design, List<Measure> all) {
    final values = _typed(design, all);
    final controller = ref.read(workspaceProvider.notifier);
    if (_depthTyped(design) case final depth?) controller.setDepth(depth);
    final outcome = controller.measured(values);
    if (outcome.problems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final feedback = ref.read(workspaceProvider).geometryFeedback;
    setState(() {
      _problems = outcome.problems;
      _suggestions = outcome.suggestions;
      _applied = {for (final key in outcome.applied) key: ?values[key]};
      _alsoCheck = feedback.notices.firstOrNull?.messageIn(context.words);
    });
  }

  /// [key]'s field given the size suggested for it, and its suggestion put
  /// away: the user still presses **Apply**.
  void _use(String key, double mm) {
    _fields[key]?.text = Units.format(mm);
    setState(() {
      _problems = {..._problems}..remove(key);
      _suggestions = {..._suggestions}..remove(key);
      _applied = {..._applied}..remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final design = ref.watch(workspaceProvider.select((s) => s.design));
    final all = Measurements.of(design);
    final defaults = ref.watch(measurementDefaultsProvider).value;
    final list = ref.watch(priceListProvider).value;
    // The kinds of profile with defaults set, in the price list's order.
    final offered = defaults == null
        ? const <MaterialKind>[]
        : defaults.said([
            for (final m in MaterialKind.values)
              if (list?.profiles.containsKey(m) ?? true) m,
          ]);
    // A design whose profile is chosen and has neither its border nor its
    // bars yet is given its own kind's defaults the first time they are
    // known — shown in the fields, still to be applied.
    if (defaults != null && !_offered) {
      _offered = true;
      final chosen = ProfileSelection.of(design).material;
      final unknown = [
        for (final key in const [Measurements.profileKey, Measurements.barsKey])
          if (all.where((m) => m.key == key).firstOrNull case final m?)
            !Measurements.knows(design, m, all),
      ];
      if (chosen != null &&
          offered.contains(chosen) &&
          unknown.isNotEmpty &&
          unknown.every((u) => u)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fill(chosen, defaults.of(chosen));
        });
      }
    }
    final typed = _typed(design, all);
    // What the sizes typed so far make of the design, so what follows from
    // them can be shown as it will come out.
    final preview = typed.isEmpty
        ? design
        : Measurements.apply(design, typed).design;
    final previewAll = Measurements.of(preview);

    final groups = <String, List<Measure>>{};
    for (final m in all) {
      (groups[m.group] ??= []).add(m);
    }
    // By the room the form is actually given, not by the device, as the
    // workspace is laid out: a phone-sized window on a laptop is a phone.
    return LayoutBuilder(
      builder: (context, room) => _build(
        context,
        room,
        design,
        all,
        typed,
        groups,
        preview,
        previewAll,
        defaults,
        offered,
      ),
    );
  }

  Widget _build(
    BuildContext context,
    BoxConstraints room,
    Design design,
    List<Measure> all,
    Map<String, double> typed,
    Map<String, List<Measure>> groups,
    Design preview,
    List<Measure> previewAll,
    MeasurementDefaults? defaults,
    List<MaterialKind> offered,
  ) {
    final full = room.maxWidth < MeasureForm.fullScreenBelow;
    final depthChanged = _depthTyped(design) != null;
    final p = context.palette;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.straighten, color: p.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.mfTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: context.l10n.actClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: !full,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            children: [
              Text(
                context.l10n.mfIntro,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (defaults != null)
                _Defaults(
                  offered: offered,
                  filledFrom: _filledFrom,
                  onFill: (m) => _fill(m, defaults.of(m)),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    entry.value.first.groupIn(context.words),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final m in entry.value)
                  if (m.asked)
                    _SizeField(
                      key: ValueKey('measure-${m.key}'),
                      label: m.labelIn(context.words),
                      controller: _fields[m.key]!,
                      first: m.key == _first,
                      problem: _problems[m.key],
                      suggestion: _suggestions[m.key],
                      applied: _applied[m.key],
                      alsoCheck: _alsoCheck,
                      onUse: (mm) => _use(m.key, mm),
                    )
                  else
                    _Follows(
                      label: m.labelIn(context.words),
                      value: _followed(preview, previewAll, m),
                    ),
                // Every design has a depth; it is the frame's, so it is
                // given with the frame's border and bars.
                if (all.isNotEmpty && entry.key == all.first.group)
                  _SizeField(
                    key: MeasureForm.depthKey,
                    label: context.l10n.mdDepth,
                    controller: _depth,
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _outstanding(context.l10n, preview, previewAll),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.actNotNow),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: typed.isEmpty && !depthChanged
                    ? null
                    : () => _apply(design, all),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                child: Text(context.l10n.actApply),
              ),
            ],
          ),
        ),
      ],
    );

    if (full) {
      return Dialog.fullscreen(
        backgroundColor: p.surface,
        child: SafeArea(child: content),
      );
    }
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: room.maxHeight * 0.86,
        ),
        child: content,
      ),
    );
  }

  /// A size that follows from the others, as the sizes typed so far make
  /// it — or `?` while something it follows from is still missing.
  String _followed(Design preview, List<Measure> previewAll, Measure m) {
    final now =
        previewAll.where((p) => p.key == m.key).firstOrNull ??
        previewAll
            .where(
              (p) =>
                  m.sectionId != null &&
                  p.sectionId == m.sectionId &&
                  p.axis == m.axis,
            )
            .firstOrNull;
    if (now == null || !Measurements.knows(preview, now, previewAll)) {
      return '? ${Units.symbol}';
    }
    return Units.label(now.currentMm(preview));
  }

  String _outstanding(
    AppLocalizations l,
    Design preview,
    List<Measure> previewAll,
  ) {
    final left = previewAll
        .where((m) => m.asked && !Measurements.knows(preview, m, previewAll))
        .length;
    if (left == 0) return l.mfAllGiven;
    return l.mfLeft(left);
  }
}

/// **Fill from factory defaults**, one button a kind of profile the factory
/// has set sizes for — or, where it has set none, where to set them.
class _Defaults extends StatelessWidget {
  final List<MaterialKind> offered;
  final MaterialKind? filledFrom;
  final ValueChanged<MaterialKind> onFill;

  const _Defaults({
    required this.offered,
    required this.filledFrom,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: p.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: offered.isEmpty
            ? Text(
                l.mfDefaultsNone,
                style: TextStyle(fontSize: 12.5, color: p.muted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.mfDefaultsFrom,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final m in offered)
                        ChoiceChip(
                          key: MeasureForm.defaultsKey(m),
                          label: Text(m.labelIn(context.words)),
                          selected: m == filledFrom,
                          onSelected: (_) => onFill(m),
                        ),
                    ],
                  ),
                  if (filledFrom case final m?) ...[
                    const SizedBox(height: 6),
                    Text(
                      l.mfDefaultsUsed(m.labelIn(context.words)),
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SizeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  /// What keeps the size typed here from being made, said as a suggestion
  /// under the field rather than as an error on it.
  final String? problem;

  /// The nearest size that fits, offered as a button.
  final double? suggestion;

  /// The size made as typed although something did not fit.
  final double? applied;

  /// The drawing's own warning, said with [problem] as what may be in the
  /// way.
  final String? alsoCheck;

  final ValueChanged<double>? onUse;

  /// Whether the form opens with the cursor here.
  final bool first;

  const _SizeField({
    super.key,
    required this.label,
    required this.controller,
    this.problem,
    this.suggestion,
    this.applied,
    this.alsoCheck,
    this.onUse,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: TextField(
                controller: controller,
                autofocus: first,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  const LatinDigits(),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: '?',
                  suffixText: Units.symbol,
                ),
              ),
            ),
          ],
        ),
        if (problem case final said?)
          SizeSuggestion(
            message: said,
            suggestion: suggestion,
            applied: applied,
            alsoCheck: alsoCheck,
            onUse: onUse,
          ),
      ],
    ),
  );
}

/// What a size that does not fit does to the design, said as a suggestion:
/// that the size was made as typed where it was, the cause, the drawing's
/// own warning where it has one, and the nearest size that keeps every
/// part as a button that puts it in the field — never an error, and never
/// a size put in for the user.
class SizeSuggestion extends StatelessWidget {
  static const useKey = Key('size-suggestion-use');
  static const appliedKey = Key('size-suggestion-applied');

  final String message;
  final double? suggestion;

  /// The size made as typed, where it was.
  final double? applied;
  final String? alsoCheck;
  final ValueChanged<double>? onUse;

  const SizeSuggestion({
    super.key,
    required this.message,
    this.suggestion,
    this.applied,
    this.alsoCheck,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: p.notice,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: p.onNotice),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (applied case final mm?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      context.l10n.mfAppliedAnyway(Units.label(mm)),
                      key: appliedKey,
                      style: text.bodySmall?.copyWith(
                        color: p.onNotice,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: p.onNotice),
                ),
                if (alsoCheck case final check?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.mfAlsoCheck(check),
                      style: text.bodySmall?.copyWith(color: p.onNotice),
                    ),
                  ),
                if (suggestion case final mm? when onUse != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: useKey,
                      onPressed: () => onUse!(mm),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(context.l10n.mfUseSize(Units.label(mm))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Follows extends StatelessWidget {
  final String label;
  final String value;

  const _Follows({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: p.shell,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.figures(value),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  context.l10n.mfFromOthers,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

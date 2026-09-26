import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurements.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
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
/// **What follows from the rest is worked out, not asked.** The last light
/// in a row is what is left of the width once the others are given, so it
/// is shown as it comes out rather than asked for and then contradicted. A
/// field left empty stays `?` everywhere, and the form can be opened again
/// from the bar at the top to finish it.
class MeasureForm extends ConsumerStatefulWidget {
  const MeasureForm({super.key});

  /// The width below which it fills the screen.
  static const fullScreenBelow = 600.0;

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

  /// The first size still to give, which the form opens on — after a line
  /// is drawn and read, the one new size can be anywhere down the list.
  String? _first;

  @override
  void initState() {
    super.initState();
    final design = ref.read(workspaceProvider).design;
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
    super.dispose();
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
    final problems = ref.read(workspaceProvider.notifier).measure(values);
    if (problems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _problems = problems);
  }

  @override
  Widget build(BuildContext context) {
    final design = ref.watch(workspaceProvider.select((s) => s.design));
    final all = Measurements.of(design);
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
  ) {
    final full = room.maxWidth < MeasureForm.fullScreenBelow;
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
                  'Measurements',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Close',
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
                'Enter the real size of each part in centimetres. Nothing '
                'is guessed from the sketch; a size that follows from the '
                'others is worked out for you.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final m in entry.value)
                  if (m.asked)
                    _SizeField(
                      key: ValueKey('measure-${m.key}'),
                      label: m.label,
                      controller: _fields[m.key]!,
                      first: m.key == _first,
                      problem: _problems[m.key],
                    )
                  else
                    _Follows(
                      label: m.label,
                      value: _followed(preview, previewAll, m),
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
                  _outstanding(preview, previewAll),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: typed.isEmpty ? null : () => _apply(design, all),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('Apply'),
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
    final now = previewAll
        .where((p) => p.sectionId == m.sectionId && p.axis == m.axis)
        .firstOrNull;
    if (now == null || !Measurements.knows(preview, now, previewAll)) {
      return '? ${Units.symbol}';
    }
    return Units.label(now.currentMm(preview));
  }

  String _outstanding(Design preview, List<Measure> previewAll) {
    final left = previewAll
        .where((m) => m.asked && !Measurements.knows(preview, m, previewAll))
        .length;
    if (left == 0) return 'Every size is given.';
    return left == 1 ? '1 size still to give.' : '$left sizes still to give.';
  }
}

class _SizeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? problem;

  /// Whether the form opens with the cursor here.
  final bool first;

  const _SizeField({
    super.key,
    required this.label,
    required this.controller,
    this.problem,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: TextField(
            controller: controller,
            autofocus: first,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textInputAction: TextInputAction.next,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: '?',
              suffixText: Units.symbol,
              errorText: problem,
              errorMaxLines: 3,
            ),
          ),
        ),
      ],
    ),
  );
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
                  value,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'from the others',
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/numerals.dart';
import '../../core/i18n/strings.dart';
import '../../core/units/length_unit.dart';

/// Asks for a length with a numeric keypad.
///
/// Centimetres, because that is what the factory says out loud and what is
/// written on the paper sketches (spec Phase 2, item 4). The value handed back
/// is millimetres — the only unit the model stores (spec section 3D).
///
/// Returns null when the user cancels or types something that is not a number.
/// It never falls back to a default: a dimension nobody entered stays unknown
/// (spec section 2).
Future<double?> askForLengthMm(
  BuildContext context, {
  required String title,
  required String helper,
  double? currentMm,
  LengthUnit unit = LengthUnit.centimetre,
}) =>
    showDialog<double>(
      context: context,
      builder: (context) => _LengthDialog(
        title: title,
        helper: helper,
        currentMm: currentMm,
        unit: unit,
        numerals: context.s.numerals,
      ),
    );

class _LengthDialog extends StatefulWidget {
  final String title;
  final String helper;
  final double? currentMm;
  final LengthUnit unit;
  final NumeralSystem numerals;

  const _LengthDialog({
    required this.title,
    required this.helper,
    required this.unit,
    required this.numerals,
    this.currentMm,
  });

  @override
  State<_LengthDialog> createState() => _LengthDialogState();
}

class _LengthDialogState extends State<_LengthDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentMm == null
        ? ''
        : widget.numerals.format(widget.unit.formatValue(widget.currentMm!)),
  );

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final millimetres = widget.unit.parseToMillimetres(_controller.text);
    if (millimetres == null) {
      setState(
        () => _error = context.s(T.typeANumber, {
          'example': context.s.number(120),
        }),
      );
      return;
    }
    if (millimetres <= 0) {
      setState(() => _error = context.s(T.sizeMustBePositive));
      return;
    }
    Navigator.of(context).pop(millimetres);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.helper),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              autofocus: true,
              // The numeric keypad, not a full keyboard: these users are
              // entering a number with gloves on.
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // Both sets of digits: the setting says what is *shown*, not
                // what a keyboard is allowed to send.
                FilteringTextInputFormatter.allow(
                  RegExp('[0-9${NumeralSystem.arabicIndic.digits}.,]'),
                ),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                suffixText: context.s.unitSymbol(widget.unit),
                errorText: _error,
                labelText: context.s(T.size),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.s(T.cancel)),
          ),
          FilledButton(onPressed: _submit, child: Text(context.s(T.set))),
        ],
      );
}

/// Asks for free text — a panel note or the design note.
///
/// Multi-line and unconstrained on purpose: the factory's shorthand is its
/// own, often Arabic or Kurdish, and a note the app cannot parse is still a
/// note the fabricator can read (spec Phase 2, items 5 and 6).
Future<String?> askForNote(
  BuildContext context, {
  required String title,
  required String helper,
  String current = '',
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(
        title: title,
        helper: helper,
        current: current,
      ),
    );

class _NoteDialog extends StatefulWidget {
  final String title;
  final String helper;
  final String current;

  const _NoteDialog({
    required this.title,
    required this.helper,
    required this.current,
  });

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.helper),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              // No textDirection is set: Flutter resolves it per paragraph
              // from the text itself, so a note written in another language
              // than the app is set to still lays out the right way round.
              decoration: InputDecoration(labelText: context.s(T.note)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.s(T.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: Text(context.s(T.saveNote)),
          ),
        ],
      );
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/unit_converter.dart';

/// Asks for a measurement. Shown the moment a dimension line is drawn, so the
/// real number is captured while the user is still thinking about it — and so
/// the app never has to guess one (§10).
class MeasurementDialog extends StatefulWidget {
  final String title;
  final String message;
  final double? initialMm;
  final double? suggestionMm;

  const MeasurementDialog({
    super.key,
    this.title = 'Measurement',
    this.message = 'How long is this in real life?',
    this.initialMm,
    this.suggestionMm,
  });

  static Future<double?> show(
    BuildContext context, {
    String title = 'Measurement',
    String message = 'How long is this in real life?',
    double? initialMm,
    double? suggestionMm,
  }) =>
      showDialog<double>(
        context: context,
        builder: (_) => MeasurementDialog(
          title: title,
          message: message,
          initialMm: initialMm,
          suggestionMm: suggestionMm,
        ),
      );

  @override
  State<MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<MeasurementDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialMm == null ? '' : widget.initialMm!.round().toString(),
  );
  LengthUnit _unit = LengthUnit.mm;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Enter a number greater than zero.');
      return;
    }
    Navigator.of(context).pop(_unit.toMm(parsed));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Size',
                    errorText: _error,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<LengthUnit>(
                  initialValue: _unit,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                  items: LengthUnit.values
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
            ],
          ),
          if (widget.suggestionMm != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(widget.suggestionMm),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text('Use ${widget.suggestionMm!.round()} mm'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip')),
        FilledButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}

/// Free-text note capture for the note tool.
class NoteDialog extends StatefulWidget {
  final String? initialText;

  const NoteDialog({super.key, this.initialText});

  static Future<String?> show(BuildContext context, {String? initialText}) =>
      showDialog<String>(
        context: context,
        builder: (_) => NoteDialog(initialText: initialText),
      );

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: const InputDecoration(
          hintText: 'e.g. frosted glass, opens to balcony',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/elements.dart';
import '../../domain/model/materials.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'colour_picker.dart';

/// The panel on the right: what is selected, and everything about it that
/// can be changed.
///
/// Every field here changes exactly the thing it names. Nothing on this
/// panel adjusts anything else to compensate.
class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);
    final selected = state.selected;

    return Container(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          _Heading(
            selected == null ? 'Design' : selected.label,
            subtitle: selected == null
                ? 'Tap any part of the drawing to change it.'
                : null,
          ),
          const SizedBox(height: 14),
          if (selected == null)
            _DesignFields(state: state, controller: controller)
          else
            ..._fieldsFor(context, selected, state, controller),
        ],
      ),
    );
  }

  List<Widget> _fieldsFor(
    BuildContext context,
    DesignElement element,
    WorkspaceState state,
    WorkspaceController controller,
  ) =>
      switch (element) {
        FrameElement() => [
            _NumberField(
              label: 'Width',
              valueMm: element.widthMm,
              onSet: (v) => controller.resizeFrame(widthMm: v),
            ),
            _NumberField(
              label: 'Height',
              valueMm: element.heightMm,
              onSet: (v) => controller.resizeFrame(heightMm: v),
            ),
            _NumberField(
              label: 'Frame profile',
              valueMm: element.profileMm,
              onSet: controller.setProfile,
            ),
            _NumberField(
              label: 'Depth',
              valueMm: state.design.depthMm,
              onSet: controller.setDepth,
            ),
            const SizedBox(height: 8),
            _FinishFields(
              finish: element.finish,
              onChanged: (f) => controller.setFinish(element.id, f),
              glazing: false,
            ),
          ],
        DividerElement() => [
            _Readout('Length', '${element.lengthMm.round()} mm'),
            _Readout(
              'Angle',
              '${element.segment.headingDegrees.toStringAsFixed(1)}°',
            ),
            _NumberField(
              label: 'Bar width',
              valueMm: element.widthMm,
              onSet: (v) => controller.setBarWidth(element.id, v),
            ),
            const SizedBox(height: 8),
            _FinishFields(
              finish: element.finish,
              onChanged: (f) => controller.setFinish(element.id, f),
              glazing: false,
            ),
            const SizedBox(height: 14),
            _DeleteButton(
              label: 'Delete this bar',
              onPressed: controller.deleteSelected,
            ),
          ],
        SectionElement() => [
            _NumberField(
              label: 'Width',
              valueMm: element.widthMm,
              onSet: (v) => controller.setSectionWidth(element.id, v),
            ),
            _NumberField(
              label: 'Height',
              valueMm: element.heightMm,
              onSet: (v) => controller.setSectionHeight(element.id, v),
            ),
            const SizedBox(height: 8),
            _FinishFields(
              finish: element.finish,
              onChanged: (f) => controller.setFinish(element.id, f),
              glazing: true,
            ),
            const SizedBox(height: 16),
            _OpeningField(section: element, state: state, controller: controller),
            const SizedBox(height: 16),
            _HardwareField(section: element, controller: controller),
          ],
        HardwareElement() => [
            _Readout('Position',
                '${element.at.x.round()}, ${element.at.y.round()} mm'),
            _NumberField(
              label: 'Angle',
              valueMm: element.rotation,
              unit: '°',
              onSet: (v) => controller.select(element.id),
            ),
            const SizedBox(height: 8),
            _FinishFields(
              finish: element.finish,
              onChanged: (f) => controller.setFinish(element.id, f),
              glazing: false,
            ),
            const SizedBox(height: 14),
            _DeleteButton(
              label: 'Remove this ${element.kind.label.toLowerCase()}',
              onPressed: controller.deleteSelected,
            ),
          ],
        DimensionElement() => [
            _Readout('As drawn', '${element.measuredMm.round()} mm'),
            _NumberField(
              label: 'Real size',
              valueMm: element.valueMm,
              help: 'Type the true measurement. The whole design is scaled '
                  'to match it, in proportion — nothing moves relative to '
                  'anything else.',
              onSet: (v) => controller.setDimensionValue(element.id, v),
            ),
            const SizedBox(height: 14),
            _DeleteButton(
              label: 'Delete this dimension',
              onPressed: controller.deleteSelected,
            ),
          ],
        TextElement() => [
            _Readout('Note', element.text),
            const SizedBox(height: 14),
            _DeleteButton(
              label: 'Delete this note',
              onPressed: controller.deleteSelected,
            ),
          ],
        ArrowElement() => [
            const _Readout('Arrow', 'Drag it to move it.'),
            const SizedBox(height: 14),
            _DeleteButton(
              label: 'Delete this arrow',
              onPressed: controller.deleteSelected,
            ),
          ],
        OpeningElement() => [
            _Readout('Opens', element.mechanism.description),
          ],
      };
}

class _DesignFields extends StatelessWidget {
  final WorkspaceState state;
  final WorkspaceController controller;

  const _DesignFields({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final design = state.design;
    if (design.frame == null) {
      return Text(
        'Draw the outline of your ${design.kind.label.toLowerCase()}, then '
        'read the drawing. Whatever you draw is what gets built — nothing is '
        'assumed and nothing is filled in for you.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberField(
          label: 'Overall width',
          valueMm: design.widthMm,
          help: 'Setting this scales the whole design in proportion.',
          onSet: controller.setRealWidth,
        ),
        _NumberField(
          label: 'Overall height',
          valueMm: design.heightMm,
          onSet: controller.setRealHeight,
        ),
        const SizedBox(height: 10),
        _Readout('Sections', '${design.sections.length}'),
        _Readout('Bars', '${design.dividers.length}'),
        _Readout('Openings', '${design.openings.length}'),
      ],
    );
  }
}

class _OpeningField extends StatelessWidget {
  final SectionElement section;
  final WorkspaceState state;
  final WorkspaceController controller;

  const _OpeningField({
    required this.section,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final opening = state.design.openingOf(section.id);
    final mechanism = opening?.mechanism ?? OpeningMechanism.fixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Opens'),
        const SizedBox(height: 6),
        DropdownButtonFormField<OpeningMechanism>(
          initialValue: mechanism,
          isExpanded: true,
          items: [
            for (final option in OpeningMechanism.values)
              DropdownMenuItem(
                value: option,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.setOpening(section.id, value);
          },
        ),
        if (opening != null) ...[
          const SizedBox(height: 8),
          Text(
            opening.mechanism.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<OpeningDirection>(
            segments: const [
              ButtonSegment(
                value: OpeningDirection.inward,
                label: Text('Inward'),
              ),
              ButtonSegment(
                value: OpeningDirection.outward,
                label: Text('Outward'),
              ),
            ],
            selected: {opening.direction},
            showSelectedIcon: false,
            onSelectionChanged: (values) => controller.setOpening(
              section.id,
              opening.mechanism,
              direction: values.first,
            ),
          ),
        ],
      ],
    );
  }
}

class _HardwareField extends StatelessWidget {
  final SectionElement section;
  final WorkspaceController controller;

  const _HardwareField({required this.section, required this.controller});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Add hardware here'),
          const SizedBox(height: 4),
          Text(
            'Nothing is added on its own. What you add goes in the middle of '
            'this section, and you can drag it where you want it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in [
                HardwareKind.lever,
                HardwareKind.handle,
                HardwareKind.knob,
                HardwareKind.lock,
              ])
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: AppTheme.buttonLabel.copyWith(fontSize: 13),
                  ),
                  onPressed: () => controller.addHardware(
                    kind,
                    section.outline.centroid,
                  ),
                  child: Text(kind.label),
                ),
            ],
          ),
        ],
      );
}

class _FinishFields extends StatelessWidget {
  final Finish finish;
  final ValueChanged<Finish> onChanged;
  final bool glazing;

  const _FinishFields({
    required this.finish,
    required this.onChanged,
    required this.glazing,
  });

  @override
  Widget build(BuildContext context) {
    final materials = glazing
        ? [
            MaterialKind.clearGlass,
            MaterialKind.frostedGlass,
            MaterialKind.tintedGlass,
            MaterialKind.panel,
            MaterialKind.louvre,
            MaterialKind.mesh,
          ]
        : [
            MaterialKind.upvc,
            MaterialKind.aluminium,
            MaterialKind.wood,
            MaterialKind.steel,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Material'),
        const SizedBox(height: 6),
        DropdownButtonFormField<MaterialKind>(
          initialValue:
              materials.contains(finish.material) ? finish.material : null,
          isExpanded: true,
          items: [
            for (final material in materials)
              DropdownMenuItem(value: material, child: Text(material.label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(finish.copyWith(material: value));
          },
        ),
        const SizedBox(height: 14),
        const _Label('Colour'),
        const SizedBox(height: 6),
        ColourPicker(
          colour: finish.colour,
          onChanged: (colour) => onChanged(finish.copyWith(colour: colour)),
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final double valueMm;
  final String unit;
  final String? help;
  final ValueChanged<double> onSet;

  const _NumberField({
    required this.label,
    required this.valueMm,
    required this.onSet,
    this.unit = 'mm',
    this.help,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _field =
      TextEditingController(text: widget.valueMm.round().toString());
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus &&
        (widget.valueMm - old.valueMm).abs() > 0.5) {
      _field.text = widget.valueMm.round().toString();
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final value = double.tryParse(_field.text.trim());
    if (value == null) {
      _field.text = widget.valueMm.round().toString();
      return;
    }
    if ((value - widget.valueMm).abs() < 0.5) return;
    widget.onSet(value);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(widget.label),
            const SizedBox(height: 6),
            TextField(
              controller: _field,
              focusNode: _focus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(suffixText: widget.unit),
            ),
            if (widget.help != null) ...[
              const SizedBox(height: 5),
              Text(
                widget.help!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
}

class _Readout extends StatelessWidget {
  final String label;
  final String value;
  const _Readout(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Label(label)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge,
      );
}

class _Heading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _Heading(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

class _DeleteButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _DeleteButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.delete_outline, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
      );
}

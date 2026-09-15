import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/editing/design_edits.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../../domain/model/materials.dart';
import '../../domain/sections/section_bands.dart';
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
        FrameMemberElement() => [
            _Readout('Length', '${element.lengthMm.round()} mm'),
            _Readout(
              'Angle',
              '${element.run.headingDegrees.toStringAsFixed(1)}°',
            ),
            _Readout(
              'From',
              '${element.run.a.x.round()}, ${element.run.a.y.round()} mm',
            ),
            _Readout(
              'To',
              '${element.run.b.x.round()}, ${element.run.b.y.round()} mm',
            ),
            const SizedBox(height: 6),
            Text(
              'Drag its handle to move this side of the frame square to '
              'itself. The other sides stay where they are.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (state.design.frame case final frame?) ...[
              _NumberField(
                label: 'Frame profile',
                valueMm: frame.profileMm,
                help: 'One figure for the whole frame, as it is cut from one '
                    'section of material.',
                onSet: controller.setProfile,
              ),
              _FinishFields(
                finish: frame.finish,
                onChanged: (f) => controller.setFinish(frame.id, f),
                glazing: false,
              ),
            ],
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
            const SizedBox(height: 16),
            _BelongsTo(divider: element, state: state, controller: controller),
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
            _OpeningFields(
              opening: element,
              state: state,
              controller: controller,
            ),
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

/// Everything about a selected opening.
///
/// Which way it opens, what kind it is, how big the section holding it is,
/// and which section that is. Each field changes the one thing it names and
/// the drawing and the model follow it. Nothing else is touched.
/// Whether a bar divides the whole design or one section of it.
///
/// The drawing settles this on its own: a line drawn inside a marked region
/// belongs to that region. Where the drawing cannot say — the mark was made
/// after the lines, say — this is where the user says.
class _BelongsTo extends StatelessWidget {
  final DividerElement divider;
  final WorkspaceState state;
  final WorkspaceController controller;

  const _BelongsTo({
    required this.divider,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final containers =
        DesignEdits.containersFor(state.design, divider.id);
    if (containers.isEmpty && divider.parentId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Divides'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: divider.parentId ?? '',
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('The whole design'),
            ),
            for (final section in containers)
              DropdownMenuItem(
                value: section.id,
                child: Text(
                  state.design.openingOf(section.id) != null
                      ? 'Inside the opening — '
                          '${describeSection(section, state.design)}'
                      : 'Inside ${describeSection(section, state.design)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => controller.setDividerParent(
            divider.id,
            value == null || value.isEmpty ? null : value,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          divider.isInternal
              ? 'This line is inside that section. It divides that section '
                  'only, and travels with it.'
              : 'This line divides the design itself.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _OpeningFields extends StatelessWidget {
  final OpeningElement opening;
  final WorkspaceState state;
  final WorkspaceController controller;

  const _OpeningFields({
    required this.opening,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final section = state.design.sectionById(opening.sectionId);
    final drawn = opening.markGlyph;
    final now = opening.mechanism.glyph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Direction'),
        const SizedBox(height: 7),
        _DirectionPicker(
          mechanism: opening.mechanism,
          onChanged: (mechanism) =>
              controller.setOpeningMechanism(opening.id, mechanism),
        ),
        if (drawn != null && now != null && drawn != now) ...[
          const SizedBox(height: 7),
          Text(
            'You drew $drawn here. You have since changed it to $now.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else if (drawn != null) ...[
          const SizedBox(height: 7),
          Text(
            'You marked this section with a $drawn.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 18),
        const _Label('Opening type'),
        const SizedBox(height: 6),
        DropdownButtonFormField<OpeningMechanism>(
          initialValue: opening.mechanism,
          isExpanded: true,
          items: [
            for (final option in OpeningMechanism.values)
              if (option != OpeningMechanism.fixed)
                DropdownMenuItem(
                  value: option,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.setOpeningMechanism(opening.id, value);
            }
          },
        ),
        const SizedBox(height: 7),
        Text(
          opening.mechanism.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
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
          onSelectionChanged: (values) =>
              controller.setOpeningSwing(opening.id, values.first),
        ),
        if (section != null) ...[
          const SizedBox(height: 20),
          _NumberField(
            label: 'Width',
            valueMm: section.widthMm,
            onSet: (v) => controller.setSectionWidth(section.id, v),
          ),
          _NumberField(
            label: 'Height',
            valueMm: section.heightMm,
            onSet: (v) => controller.setSectionHeight(section.id, v),
          ),
        ],
        const SizedBox(height: 6),
        const _Label('Position'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: opening.sectionId,
          isExpanded: true,
          items: [
            for (final option in state.design.sections)
              DropdownMenuItem(
                value: option.id,
                child: Text(
                  describeSection(option, state.design),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.moveOpeningToSection(opening.id, value);
            }
          },
        ),
        const SizedBox(height: 7),
        Text(
          'Moving the opening changes which section opens. Neither section '
          'changes shape.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _DeleteButton(
          label: 'This section does not open',
          onPressed: () => controller.setOpeningMechanism(
            opening.id,
            OpeningMechanism.fixed,
          ),
        ),
      ],
    );
  }
}

/// The four marks, as buttons.
class _DirectionPicker extends StatelessWidget {
  final OpeningMechanism mechanism;
  final ValueChanged<OpeningMechanism> onChanged;

  const _DirectionPicker({
    required this.mechanism,
    required this.onChanged,
  });

  static const _options = <OpeningMechanism>[
    OpeningMechanism.hingedRight,
    OpeningMechanism.hingedLeft,
    OpeningMechanism.bottomHung,
    OpeningMechanism.topHung,
  ];

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final option in _options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Tooltip(
                  message: '${option.glyph}  ${option.description}',
                  child: Material(
                    color: option == mechanism
                        ? AppTheme.primary
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onChanged(option),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: option == mechanism
                                ? AppTheme.primary
                                : AppTheme.hairline,
                            width: 1.4,
                          ),
                        ),
                        child: Text(
                          option.glyph ?? '?',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: option == mechanism
                                ? AppTheme.accent
                                : AppTheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// A section named the way somebody would point at it.
String describeSection(SectionElement section, Design design) {
  final frame = design.frame;
  final where = StringBuffer();
  if (frame != null) {
    final middleY = (frame.outline.top + frame.outline.bottom) / 2;
    final middleX = (frame.outline.left + frame.outline.right) / 2;
    final centre = section.outline.centroid;
    if (SectionBands.rows(design) > 1) {
      where.write(centre.y < middleY ? 'Upper ' : 'Lower ');
    }
    if (SectionBands.columns(design) > 1) {
      where.write(centre.x < middleX ? 'left' : 'right');
    }
  }
  final place = where.toString().trim();
  final size = '${section.widthMm.round()} × ${section.heightMm.round()} mm';
  return place.isEmpty ? size : '$place section — $size';
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
        if (opening != null) ...[
          OutlinedButton.icon(
            onPressed: () => controller.select(opening.id),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Edit this opening'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              textStyle: AppTheme.buttonLabel.copyWith(fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (opening?.markGlyph != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Text(
                  opening!.markGlyph!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'You marked this section with a '
                    '${opening.markGlyph}. Nothing else opens.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary.withValues(alpha: 0.85),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
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
              for (final kind in HardwareKind.values)
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

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../option_card.dart';
import '../step_scaffold.dart';

class FrameStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const FrameStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDoor = config.category == ProductCategory.door;
    return StepScaffold(
      title: 'Frame & sections',
      helperText: isDoor
          ? 'Frame construction and how the leaf/leaves are arranged.'
          : 'Frame construction and how the window is divided into sections.',
      children: [
        FieldGroup(
          label: 'Frame material',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final material in FrameMaterial.values)
                OptionCard(
                  icon: Icons.view_agenda_outlined,
                  label: material.label,
                  subtitle: material.description,
                  selected: config.frame.material == material,
                  onTap: () => onChanged(config.copyWith(frame: config.frame.copyWith(material: material))),
                ),
            ],
          ),
        ),
        FieldGroup(
          label: 'Profile system',
          child: TextFormField(
            initialValue: config.frame.profileSystem,
            decoration: const InputDecoration(hintText: 'e.g. Standard 55, Slim 45'),
            onChanged: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(profileSystem: v))),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FieldGroup(
                label: 'Frame depth (mm)',
                child: _NumberStepper(
                  value: config.frame.frameDepthMm,
                  step: 5,
                  onChanged: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(frameDepthMm: v))),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FieldGroup(
                label: 'Frame thickness (mm)',
                child: _NumberStepper(
                  value: config.frame.frameThicknessMm,
                  step: 5,
                  onChanged: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(frameThicknessMm: v))),
                ),
              ),
            ),
          ],
        ),
        FieldGroup(
          label: 'Frame construction',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilterChip(
                label: const Text('Inner frame'),
                selected: config.frame.hasInnerFrame,
                onSelected: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(hasInnerFrame: v))),
              ),
              FilterChip(
                label: const Text('Outer frame'),
                selected: config.frame.hasOuterFrame,
                onSelected: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(hasOuterFrame: v))),
              ),
              FilterChip(
                label: const Text('Border'),
                selected: config.frame.hasBorder,
                onSelected: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(hasBorder: v))),
              ),
              if (isDoor) ...[
                FilterChip(
                  label: const Text('Door jamb'),
                  selected: config.frame.hasDoorJamb,
                  onSelected: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(hasDoorJamb: v))),
                ),
                FilterChip(
                  label: const Text('Threshold'),
                  selected: config.frame.hasThreshold,
                  onSelected: (v) => onChanged(config.copyWith(frame: config.frame.copyWith(hasThreshold: v))),
                ),
              ],
            ],
          ),
        ),
        if (isDoor) _DoorLeafFields(config: config, onChanged: onChanged) else _WindowSectionFields(config: config, onChanged: onChanged),
      ],
    );
  }
}

class _DoorLeafFields extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;
  const _DoorLeafFields({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldGroup(
          label: 'Leaf arrangement',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final arrangement in LeafArrangement.values)
                OptionCard(
                  icon: Icons.door_sliding_outlined,
                  label: arrangement.label,
                  selected: config.leaf.arrangement == arrangement,
                  onTap: () => onChanged(config.copyWith(
                    leaf: config.leaf.copyWith(
                      arrangement: arrangement,
                      leafCount: arrangement.operableLeaves,
                    ),
                  )),
                ),
            ],
          ),
        ),
        FieldGroup(
          label: 'Opening direction',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final direction in [OpeningDirection.leftHinge, OpeningDirection.rightHinge])
                OptionCard(
                  icon: Icons.rotate_right_rounded,
                  label: direction.label,
                  subtitle: direction.description,
                  selected: config.leaf.openingDirection == direction,
                  onTap: () => onChanged(config.copyWith(leaf: config.leaf.copyWith(openingDirection: direction))),
                ),
            ],
          ),
        ),
        if (config.leaf.arrangement == LeafArrangement.unequalDouble)
          FieldGroup(
            label: 'Primary leaf width share',
            child: Slider(
              value: config.leaf.primaryLeafRatio,
              min: 0.3,
              max: 0.8,
              divisions: 10,
              label: '${(config.leaf.primaryLeafRatio * 100).round()}%',
              onChanged: (v) => onChanged(config.copyWith(leaf: config.leaf.copyWith(primaryLeafRatio: v))),
            ),
          ),
      ],
    );
  }
}

class _WindowSectionFields extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;
  const _WindowSectionFields({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldGroup(
          label: 'Sections (vertical mullions = sections − 1)',
          child: _NumberStepper(
            value: config.sections.toDouble(),
            step: 1,
            min: 1,
            max: 8,
            onChanged: (v) => onChanged(config.copyWith(sections: v.round())),
          ),
        ),
        FieldGroup(
          label: 'Horizontal transoms',
          child: _NumberStepper(
            value: config.transomFractions.length.toDouble(),
            step: 1,
            min: 0,
            max: 3,
            onChanged: (v) {
              final count = v.round();
              final fractions = List.generate(count, (i) => (i + 1) / (count + 1));
              onChanged(config.copyWith(transomFractions: fractions));
            },
          ),
        ),
        FieldGroup(
          label: 'Primary opening direction',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final direction in [
                OpeningDirection.slideLeft,
                OpeningDirection.slideRight,
                OpeningDirection.bothActive,
                OpeningDirection.fixed,
              ])
                OptionCard(
                  icon: Icons.swap_horiz_rounded,
                  label: direction.label,
                  subtitle: direction.description,
                  selected: config.leaf.openingDirection == direction,
                  onTap: () => onChanged(config.copyWith(leaf: config.leaf.copyWith(openingDirection: direction))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final double value;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _NumberStepper({
    required this.value,
    required this.step,
    this.min = 0,
    this.max = 400,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(value.toStringAsFixed(step < 1 ? 1 : 0), style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

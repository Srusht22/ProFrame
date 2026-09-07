import 'package:flutter/material.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../option_card.dart';
import '../step_scaffold.dart';

class HardwareStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const HardwareStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDoor = config.category == ProductCategory.door;
    return StepScaffold(
      title: 'Hardware',
      helperText: 'Hinges, handles, locks and closers — the 3D preview updates the count and placement live.',
      children: [
        if (isDoor)
          FieldGroup(
            label: 'Hinges',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  onPressed: config.hardware.hingeCount > 2
                      ? () => onChanged(config.copyWith(hardware: config.hardware.copyWith(hingeCount: config.hardware.hingeCount - 1)))
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('${config.hardware.hingeCount}', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton.outlined(
                  onPressed: config.hardware.hingeCount < 6
                      ? () => onChanged(config.copyWith(hardware: config.hardware.copyWith(hingeCount: config.hardware.hingeCount + 1)))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        FieldGroup(
          label: 'Handle',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final model in HandleModel.values)
                OptionCard(
                  icon: Icons.door_back_door_outlined,
                  label: model.label,
                  selected: config.hardware.handleModel == model,
                  onTap: () => onChanged(config.copyWith(hardware: config.hardware.copyWith(handleModel: model))),
                ),
            ],
          ),
        ),
        FieldGroup(
          label: 'Handle color',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in FrameColor.values)
                OptionCard(
                  colorSwatch: color.swatch,
                  label: color.label,
                  selected: config.hardware.handleColor == color,
                  onTap: () => onChanged(config.copyWith(hardware: config.hardware.copyWith(handleColor: color))),
                ),
            ],
          ),
        ),
        if (isDoor) ...[
          FieldGroup(
            label: 'Lock',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final lock in LockType.values)
                  OptionCard(
                    icon: Icons.lock_outline_rounded,
                    label: lock.label,
                    selected: config.hardware.lockType == lock,
                    onTap: () => onChanged(config.copyWith(hardware: config.hardware.copyWith(lockType: lock))),
                  ),
              ],
            ),
          ),
          FieldGroup(
            label: 'Door closer',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final closer in DoorCloserType.values)
                  OptionCard(
                    icon: Icons.settings_input_component_outlined,
                    label: closer.label,
                    selected: config.hardware.doorCloser == closer,
                    onTap: () => onChanged(config.copyWith(hardware: config.hardware.copyWith(doorCloser: closer))),
                  ),
              ],
            ),
          ),
          FieldGroup(
            label: 'Pull handle (exterior)',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add architectural pull handle'),
              value: config.hardware.hasPullHandle,
              onChanged: (v) => onChanged(config.copyWith(hardware: config.hardware.copyWith(hasPullHandle: v))),
            ),
          ),
        ],
      ],
    );
  }
}

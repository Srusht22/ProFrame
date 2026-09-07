import 'package:flutter/material.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../step_scaffold.dart';

class AccessoriesStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const AccessoriesStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final a = config.accessories;
    return StepScaffold(
      title: 'Additional options',
      helperText: 'Optional add-ons — each priced individually in the summary.',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mosquito net'),
          subtitle: const Text('Priced per m² of the finished opening'),
          value: a.mosquitoNet,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(mosquitoNet: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Safety lock'),
          value: a.safetyLock,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(safetyLock: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound insulation'),
          value: a.soundInsulation,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(soundInsulation: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Thermal insulation'),
          value: a.thermalInsulation,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(thermalInsulation: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Decorative strips'),
          value: a.decorativeStrips,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(decorativeStrips: v))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Weather sealing (EPDM gasket)'),
          subtitle: const Text('Priced per meter of perimeter'),
          value: a.weatherSealing,
          onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(weatherSealing: v))),
        ),
        FieldGroup(
          label: 'Custom engraving (optional)',
          child: TextFormField(
            initialValue: a.customEngraving ?? '',
            decoration: const InputDecoration(hintText: 'Text to engrave on hardware/glass'),
            onChanged: (v) => onChanged(config.copyWith(accessories: a.copyWith(customEngraving: v))),
          ),
        ),
      ],
    );
  }
}

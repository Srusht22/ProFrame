import 'package:flutter/material.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../option_card.dart';
import '../step_scaffold.dart';

class FinishStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const FinishStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: 'Color & finish',
      helperText: 'The frame color drives both the 3D preview material and the pricing finish multiplier.',
      children: [
        FieldGroup(
          label: 'Frame color',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in FrameColor.values)
                OptionCard(
                  colorSwatch: color.swatch,
                  label: color.label,
                  selected: config.finish.frameColor == color,
                  onTap: () => onChanged(config.copyWith(finish: config.finish.copyWith(frameColor: color))),
                ),
            ],
          ),
        ),
        if (config.finish.frameColor == FrameColor.custom)
          FieldGroup(
            label: 'Custom hex color',
            child: TextFormField(
              initialValue: config.finish.customHexColor ?? '#888888',
              decoration: const InputDecoration(hintText: '#RRGGBB'),
              onChanged: (v) => onChanged(config.copyWith(finish: config.finish.copyWith(customHexColor: v))),
            ),
          ),
        FieldGroup(
          label: 'Finish name',
          child: TextFormField(
            initialValue: config.finish.finishName,
            decoration: const InputDecoration(hintText: 'e.g. Powder Coated Matte, Anodized Satin'),
            onChanged: (v) => onChanged(config.copyWith(finish: config.finish.copyWith(finishName: v))),
          ),
        ),
      ],
    );
  }
}

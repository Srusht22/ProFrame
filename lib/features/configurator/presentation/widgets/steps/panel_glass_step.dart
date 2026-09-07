import 'package:flutter/material.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../option_card.dart';
import '../step_scaffold.dart';

class PanelGlassStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const PanelGlassStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isGlass = config.panel.type == PanelType.glass;
    return StepScaffold(
      title: 'Panel & glass',
      helperText: 'Choose the panel material, then the glass specification if it is glazed.',
      children: [
        FieldGroup(
          label: 'Panel type',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in PanelType.values)
                OptionCard(
                  icon: Icons.crop_square_rounded,
                  label: type.label,
                  subtitle: type.description,
                  selected: config.panel.type == type,
                  onTap: () => onChanged(config.copyWith(panel: config.panel.copyWith(type: type))),
                ),
            ],
          ),
        ),
        if (config.panel.rows * config.panel.columns > 1 || config.panel.type != PanelType.glass)
          Row(
            children: [
              Expanded(
                child: FieldGroup(
                  label: 'Panel rows',
                  child: Slider(
                    value: config.panel.rows.toDouble(),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    label: '${config.panel.rows}',
                    onChanged: (v) => onChanged(config.copyWith(panel: config.panel.copyWith(rows: v.round()))),
                  ),
                ),
              ),
              Expanded(
                child: FieldGroup(
                  label: 'Panel columns',
                  child: Slider(
                    value: config.panel.columns.toDouble(),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    label: '${config.panel.columns}',
                    onChanged: (v) => onChanged(config.copyWith(panel: config.panel.copyWith(columns: v.round()))),
                  ),
                ),
              ),
            ],
          ),
        if (isGlass) ...[
          FieldGroup(
            label: 'Glass type',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in GlassType.values)
                  OptionCard(
                    colorSwatch: type.previewColor,
                    label: type.label,
                    subtitle: type.description,
                    selected: config.glass.type == type,
                    onTap: () {
                      final panes = type == GlassType.tripleGlazed ? 3 : (type == GlassType.doubleGlazed ? 2 : 1);
                      onChanged(config.copyWith(glass: config.glass.copyWith(type: type, panesCount: panes)));
                    },
                  ),
              ],
            ),
          ),
          FieldGroup(
            label: 'Glass thickness (mm)',
            child: Slider(
              value: config.glass.thicknessMm.clamp(4, 32).toDouble(),
              min: 4,
              max: 32,
              divisions: 28,
              label: config.glass.thicknessMm.toStringAsFixed(1),
              onChanged: (v) => onChanged(config.copyWith(glass: config.glass.copyWith(thicknessMm: v))),
            ),
          ),
          FieldGroup(
            label: 'Number of panes',
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Single')),
                ButtonSegment(value: 2, label: Text('Double')),
                ButtonSegment(value: 3, label: Text('Triple')),
              ],
              selected: {config.glass.panesCount.clamp(1, 3).toInt()},
              onSelectionChanged: (s) => onChanged(config.copyWith(glass: config.glass.copyWith(panesCount: s.first))),
            ),
          ),
        ],
      ],
    );
  }
}

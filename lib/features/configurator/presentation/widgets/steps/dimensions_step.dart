import 'package:flutter/material.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/unit_converter.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/dimension_limits.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../step_scaffold.dart';

class DimensionsStep extends StatefulWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const DimensionsStep({super.key, required this.config, required this.onChanged});

  @override
  State<DimensionsStep> createState() => _DimensionsStepState();
}

class _DimensionsStepState extends State<DimensionsStep> {
  LengthUnit _unit = LengthUnit.mm;

  ProductLimits get _limits => widget.config.category == ProductCategory.door
      ? ProductLimits.forDoor(widget.config.doorType ?? DoorType.custom)
      : ProductLimits.forWindow(widget.config.windowType ?? WindowType.custom);

  @override
  Widget build(BuildContext context) {
    final limits = _limits;
    return StepScaffold(
      title: 'Dimensions',
      helperText: 'All figures are stored in millimeters internally — pick a display unit for entry only.',
      children: [
        FieldGroup(
          label: 'Display unit',
          child: SegmentedButton<LengthUnit>(
            segments: const [
              ButtonSegment(value: LengthUnit.mm, label: Text('mm')),
              ButtonSegment(value: LengthUnit.cm, label: Text('cm')),
              ButtonSegment(value: LengthUnit.m, label: Text('m')),
              ButtonSegment(value: LengthUnit.inch, label: Text('in')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
        ),
        FieldGroup(
          label: 'Width (${limits.width.minMm.toInt()}–${limits.width.maxMm.toInt()} mm)',
          child: _DimensionField(
            valueMm: widget.config.widthMm,
            unit: _unit,
            min: limits.width.minMm,
            max: limits.width.maxMm,
            onChanged: (v) => widget.onChanged(widget.config.copyWith(widthMm: v)),
          ),
        ),
        FieldGroup(
          label: 'Height (${limits.height.minMm.toInt()}–${limits.height.maxMm.toInt()} mm)',
          child: _DimensionField(
            valueMm: widget.config.heightMm,
            unit: _unit,
            min: limits.height.minMm,
            max: limits.height.maxMm,
            onChanged: (v) => widget.onChanged(widget.config.copyWith(heightMm: v)),
          ),
        ),
        FieldGroup(
          label: 'Wall opening width',
          child: _DimensionField(
            valueMm: widget.config.wallOpeningWidthMm,
            unit: _unit,
            min: widget.config.widthMm,
            max: widget.config.widthMm + 300,
            onChanged: (v) => widget.onChanged(widget.config.copyWith(wallOpeningWidthMm: v)),
          ),
        ),
        FieldGroup(
          label: 'Wall opening height',
          child: _DimensionField(
            valueMm: widget.config.wallOpeningHeightMm,
            unit: _unit,
            min: widget.config.heightMm,
            max: widget.config.heightMm + 300,
            onChanged: (v) => widget.onChanged(widget.config.copyWith(wallOpeningHeightMm: v)),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Finished size: ${widget.config.formattedDimensions(_unit)} · Area: ${widget.config.areaM2.toStringAsFixed(2)} m²',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionField extends StatefulWidget {
  final double valueMm;
  final LengthUnit unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _DimensionField({
    required this.valueMm,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_DimensionField> createState() => _DimensionFieldState();
}

class _DimensionFieldState extends State<_DimensionField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.unit.fromMm(widget.valueMm).toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant _DimensionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final displayed = widget.unit.fromMm(widget.valueMm);
    if (oldWidget.unit != widget.unit || (double.tryParse(_controller.text) ?? 0) != displayed) {
      final selection = _controller.selection;
      _controller.text = displayed.toStringAsFixed(1);
      if (selection.start <= _controller.text.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minDisplay = widget.unit.fromMm(widget.min);
    final maxDisplay = widget.unit.fromMm(widget.max);
    final valueDisplay = widget.unit.fromMm(widget.valueMm).clamp(minDisplay, maxDisplay).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(suffixText: widget.unit.label),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) widget.onChanged(widget.unit.toMm(parsed));
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Slider(
            value: valueDisplay,
            min: minDisplay,
            max: maxDisplay,
            onChanged: (v) {
              widget.onChanged(widget.unit.toMm(v));
              _controller.text = v.toStringAsFixed(1);
            },
          ),
        ),
      ],
    );
  }
}

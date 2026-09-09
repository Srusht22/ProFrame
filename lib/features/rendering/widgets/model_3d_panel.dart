import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/models/scene_3d.dart';
import '../three_d/opening_3d_view.dart';
import '../three_d/scene_builder.dart';
import '../three_d/scene_bridge.dart';

/// The 3D panel: a real WebGL assembly of the product, with the camera
/// controls the spec asks for (§25).
class Model3DPanel extends StatefulWidget {
  final OpeningModel model;
  final RenderStyle style;
  final bool showDimensions;
  final bool autoRotate;
  final String? highlightCellPath;
  final ValueChanged<RenderStyle>? onStyleChanged;
  final VoidCallback? onToggleDimensions;
  final VoidCallback? onToggleAutoRotate;

  const Model3DPanel({
    super.key,
    required this.model,
    this.style = RenderStyle.realistic,
    this.showDimensions = false,
    this.autoRotate = false,
    this.highlightCellPath,
    this.onStyleChanged,
    this.onToggleDimensions,
    this.onToggleAutoRotate,
  });

  @override
  State<Model3DPanel> createState() => _Model3DPanelState();
}

class _Model3DPanelState extends State<Model3DPanel> {
  final SceneBridge _bridge = SceneBridge();
  final SceneBuilder _builder = const SceneBuilder();
  late Scene3D _scene;
  CameraPreset _preset = CameraPreset.perspective;

  @override
  void initState() {
    super.initState();
    _scene = _builder.build(widget.model, style: widget.style);
  }

  @override
  void didUpdateWidget(covariant Model3DPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model || oldWidget.style != widget.style) {
      // A new Scene3D instance is what tells the viewer to re-upload geometry.
      setState(() => _scene = _builder.build(widget.model, style: widget.style));
    }
    if (oldWidget.highlightCellPath != widget.highlightCellPath) {
      _bridge.highlightCell(widget.highlightCellPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opening3DView(
            scene: _scene,
            bridge: _bridge,
            autoRotate: widget.autoRotate,
            showDimensions: widget.showDimensions,
          ),
        ),
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: _Controls(
            preset: _preset,
            style: widget.style,
            showDimensions: widget.showDimensions,
            autoRotate: widget.autoRotate,
            onPreset: (preset) {
              setState(() => _preset = preset);
              _bridge.setCameraPreset(preset);
            },
            onStyle: (style) {
              widget.onStyleChanged?.call(style);
              _bridge.setStyle(style);
            },
            onDimensions: () {
              widget.onToggleDimensions?.call();
              _bridge.toggleDimensions(!widget.showDimensions);
            },
            onAutoRotate: () {
              widget.onToggleAutoRotate?.call();
              _bridge.toggleAutoRotate(!widget.autoRotate);
            },
            onReset: () {
              setState(() => _preset = CameraPreset.perspective);
              _bridge.resetView();
            },
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final CameraPreset preset;
  final RenderStyle style;
  final bool showDimensions;
  final bool autoRotate;
  final ValueChanged<CameraPreset> onPreset;
  final ValueChanged<RenderStyle> onStyle;
  final VoidCallback onDimensions;
  final VoidCallback onAutoRotate;
  final VoidCallback onReset;

  const _Controls({
    required this.preset,
    required this.style,
    required this.showDimensions,
    required this.autoRotate,
    required this.onPreset,
    required this.onStyle,
    required this.onDimensions,
    required this.onAutoRotate,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in CameraPreset.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: option == preset,
                      onSelected: (_) => onPreset(option),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Realistic view'),
                  selected: style == RenderStyle.realistic,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) => onStyle(
                    selected ? RenderStyle.realistic : RenderStyle.technical,
                  ),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Dimensions'),
                  selected: showDimensions,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onDimensions(),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Spin'),
                  selected: autoRotate,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onAutoRotate(),
                ),
                const SizedBox(width: 4),
                ActionChip(
                  avatar: const Icon(Icons.restart_alt, size: 15),
                  label: const Text('Reset'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onReset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/materials.dart';
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

  /// A section the user tapped in the 3D view, so selection matches the 2D
  /// drawing's behaviour.
  final ValueChanged<String?>? onSelectRegion;

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
    this.onSelectRegion,
  });

  @override
  State<Model3DPanel> createState() => _Model3DPanelState();
}

class _Model3DPanelState extends State<Model3DPanel> {
  final SceneBridge _bridge = SceneBridge();
  final SceneBuilder _builder = const SceneBuilder();
  late Scene3D _scene;
  CameraPreset _preset = CameraPreset.perspective;
  TappedPart? _tapped;

  @override
  void initState() {
    super.initState();
    _scene = _builder.build(widget.model, style: widget.style);
    _bridge.onPartTapped = (part) {
      if (!mounted) return;
      setState(() => _tapped = part.isNothing ? null : part);
      // Frame parts do not belong to a section; tapping one clears the
      // selection rather than picking an unrelated section.
      widget.onSelectRegion?.call(part.cellPath);
    };
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
        if (_tapped != null)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: _SelectionChip(
              part: _tapped!,
              model: widget.model,
              onClear: () {
                setState(() => _tapped = null);
                widget.onSelectRegion?.call(null);
              },
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


/// "Selected: Glass · 1200 × 800 mm" — what the user just tapped in 3D.
class _SelectionChip extends StatelessWidget {
  final TappedPart part;
  final OpeningModel model;
  final VoidCallback onClear;

  const _SelectionChip({
    required this.part,
    required this.model,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final region = part.cellPath == null ? null : model.region(part.cellPath!);
    final detail = region != null
        ? '${region.rect.width.round()} × ${region.rect.height.round()} mm'
        : switch (part.role) {
            'frameHead' || 'frameSill' || 'frameJambLeft' || 'frameJambRight' =>
              '${model.frameFaceMm.round()} mm face · '
                  '${model.frameDepthMm.round()} mm deep',
            'mullion' || 'transom' => '${model.mullionFaceMm.round()} mm face',
            _ => model.material.label,
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.brandDarkGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Selected: ${part.label}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                detail,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

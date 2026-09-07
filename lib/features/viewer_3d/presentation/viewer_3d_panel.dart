import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/configuration/product_configuration.dart';
import '../bridge/webgl_bridge.dart';
import '../models/camera_preset.dart';
import '../viewer/product_3d_viewer.dart';

/// The full 3D pane: viewport + a clean camera control panel (spec §71 —
/// orbit/zoom/pan via touch/mouse, plus explicit preset buttons, dimension
/// toggle, auto-rotate, reset, and full screen).
class Viewer3DPanel extends StatefulWidget {
  final ProductConfiguration configuration;

  const Viewer3DPanel({super.key, required this.configuration});

  @override
  State<Viewer3DPanel> createState() => _Viewer3DPanelState();
}

class _Viewer3DPanelState extends State<Viewer3DPanel> {
  final WebGLBridge _bridge = WebGLBridge();
  bool _showDimensions = true;
  bool _autoRotate = false;

  @override
  void dispose() {
    _bridge.detach();
    super.dispose();
  }

  void _showFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('3D preview')),
          body: Viewer3DPanel(configuration: widget.configuration),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final preset in CameraPreset.values)
                IconButton(
                  tooltip: preset.label,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(preset.icon, size: 19),
                  onPressed: () => _bridge.setCameraPreset(preset),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _showDimensions ? 'Hide measurements' : 'Show measurements',
                visualDensity: VisualDensity.compact,
                icon: Icon(_showDimensions ? Icons.straighten_rounded : Icons.straighten_outlined, size: 19),
                onPressed: () {
                  setState(() => _showDimensions = !_showDimensions);
                  _bridge.toggleDimensions(_showDimensions);
                },
              ),
              IconButton(
                tooltip: _autoRotate ? 'Stop rotation' : 'Auto-rotate',
                visualDensity: VisualDensity.compact,
                icon: Icon(_autoRotate ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 19),
                onPressed: () {
                  setState(() => _autoRotate = !_autoRotate);
                  _bridge.toggleAutoRotate(_autoRotate);
                },
              ),
              IconButton(
                tooltip: 'Full screen',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.fullscreen_rounded, size: 19),
                onPressed: _showFullscreen,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              color: AppColors.neutralSurface,
            ),
            clipBehavior: Clip.antiAlias,
            child: Product3DViewer(configuration: widget.configuration, bridge: _bridge, autoRotate: _autoRotate),
          ),
        ),
      ],
    );
  }
}

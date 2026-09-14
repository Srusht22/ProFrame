import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/solid/camera.dart';
import '../../domain/solid/mesh_builder.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'display_style.dart';
import 'model_painter.dart';

/// The model, and the means to walk round it.
///
/// Everything here is built from the design's own geometry: the frame along
/// the outline that was drawn, a bar for every bar, a pane for every section
/// the bars enclose. Tapping a face picks the part of the design it came
/// from, so the model is another way into the same document.
class ModelView extends ConsumerStatefulWidget {
  const ModelView({super.key});

  @override
  ConsumerState<ModelView> createState() => _ModelViewState();
}

enum _Drag { orbit, pan }

class _ModelViewState extends ConsumerState<ModelView> {
  Offset? _from;
  _Drag _mode = _Drag.orbit;
  double _mmPerPixel = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);

    if (state.design.frame == null) return const _NothingYet();

    final mesh = MeshBuilder.build(
      state.design,
      openFraction: state.openFraction,
    );
    final faces = state.camera.project(mesh);

    return Column(
      children: [
        _ViewToolbar(
          camera: state.camera,
          style: state.displayStyle,
          groundPlane: state.groundPlane,
          controller: controller,
          // A named view frames the model from that side, because a window
          // seen from the side is seventy millimetres deep and would
          // otherwise arrive as a sliver in the middle of an empty screen.
          onLook: (view) {
            final looking = state.camera.lookingFrom(view);
            controller.lookFrom(
              view,
              zoom: looking.zoomToFit(mesh),
            );
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final painter = ModelPainter(
                faces: faces,
                size: size,
                viewSpan: Camera.viewSpan(mesh),
                style: state.displayStyle,
                groundPlane: state.groundPlane,
                selectedId: state.selectedId,
              );
              _mmPerPixel = painter.millimetresPerPixel;

              return Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    controller.zoomCamera(
                      event.scrollDelta.dy > 0 ? 0.9 : 1.1,
                    );
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _from = details.localFocalPoint;
                    // Two fingers pan and zoom, one orbits — the same
                    // division the drawing sheet uses, so the hands do not
                    // have to learn two habits.
                    _mode =
                        details.pointerCount >= 2 ? _Drag.pan : _Drag.orbit;
                  },
                  onScaleUpdate: (details) {
                    final from = _from ?? details.localFocalPoint;
                    final delta = details.localFocalPoint - from;
                    _from = details.localFocalPoint;

                    if (details.pointerCount >= 2) {
                      _mode = _Drag.pan;
                      if (details.scale != 1) {
                        controller
                            .zoomCamera(1 + (details.scale - 1) * 0.28);
                      }
                    }

                    switch (_mode) {
                      case _Drag.orbit:
                        // Well inside a right angle: past about fifty
                        // degrees a window is being looked at edge on, which
                        // tells the user nothing.
                        controller.orbit(delta.dx * 0.28, -delta.dy * 0.18);
                      case _Drag.pan:
                        controller.panCamera(
                          delta.dx * _mmPerPixel,
                          delta.dy * _mmPerPixel,
                        );
                    }
                  },
                  onScaleEnd: (_) => _from = null,
                  onTapUp: (details) =>
                      controller.select(painter.elementAt(details.localPosition)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(size: size, painter: painter),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _Navigation(
                          onIn: () => controller.zoomCamera(1.25),
                          onOut: () => controller.zoomCamera(0.8),
                          onExtents: () =>
                              controller.zoomToFit(state.camera.zoomToFit(mesh)),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        bottom: 12,
                        child: _Readout(state: state),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The views, the projection and the way the model is drawn.
class _ViewToolbar extends StatelessWidget {
  final Camera camera;
  final DisplayStyle style;
  final bool groundPlane;
  final WorkspaceController controller;
  final ValueChanged<Camera> onLook;

  const _ViewToolbar({
    required this.camera,
    required this.style,
    required this.groundPlane,
    required this.controller,
    required this.onLook,
  });

  static const _views = <(String, Camera, IconData)>[
    ('Iso', Camera.isometric, Icons.view_in_ar_outlined),
    ('Front', Camera.front, Icons.crop_square),
    ('Back', Camera.back, Icons.flip_to_back),
    ('Left', Camera.left, Icons.chevron_left),
    ('Right', Camera.right, Icons.chevron_right),
    ('Top', Camera.top, Icons.vertical_align_top),
    ('Bottom', Camera.bottom, Icons.vertical_align_bottom),
  ];

  bool _isAt(Camera view) =>
      (camera.yawDegrees - view.yawDegrees).abs() < 0.5 &&
      (camera.pitchDegrees - view.pitchDegrees).abs() < 0.5;

  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Icons alone for the views: seven labels will not fit beside
              // the projection and the styles on a tablet, and a scrolling
              // toolbar hides the very controls it holds.
              for (final (label, view, icon) in _views)
                _Chip(
                  icon: icon,
                  on: _isAt(view),
                  tooltip: '$label view',
                  onTap: () => onLook(view),
                ),
              const SizedBox(width: 6),
              const SizedBox(height: 22, child: VerticalDivider(width: 12)),
              _Chip(
                label: camera.projection.label,
                icon: camera.projection == Projection.perspective
                    ? Icons.filter_center_focus
                    : Icons.grid_goldenratio,
                on: true,
                onTap: () => controller.setProjection(
                  camera.projection == Projection.perspective
                      ? Projection.parallel
                      : Projection.perspective,
                ),
              ),
              const SizedBox(width: 6),
              const SizedBox(height: 22, child: VerticalDivider(width: 12)),
              for (final option in DisplayStyle.values)
                _Chip(
                  label: option == style ? option.label : null,
                  icon: switch (option) {
                    DisplayStyle.shaded => Icons.format_color_fill,
                    DisplayStyle.shadedWithEdges => Icons.deblur,
                    DisplayStyle.wireframe => Icons.grid_on,
                    DisplayStyle.monochrome => Icons.contrast,
                  },
                  on: style == option,
                  tooltip: option.hint,
                  onTap: () => controller.setDisplayStyle(option),
                ),
              const SizedBox(width: 6),
              const SizedBox(height: 22, child: VerticalDivider(width: 12)),
              _Chip(
                tooltip: 'Ground plane',
                icon: Icons.horizontal_rule,
                on: groundPlane,
                onTap: () => controller.setGroundPlane(!groundPlane),
              ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  /// Shown beside the icon. Left off where the icon and a tooltip say it.
  final String? label;
  final IconData icon;
  final bool on;
  final String? tooltip;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.on,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color:
            on ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 9 : 10,
              vertical: 7,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: on ? AppTheme.primary : AppTheme.muted,
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? AppTheme.primary : AppTheme.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class _Navigation extends StatelessWidget {
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onExtents;

  const _Navigation({
    required this.onIn,
    required this.onOut,
    required this.onExtents,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onIn,
              icon: const Icon(Icons.add),
              tooltip: 'Zoom in',
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onOut,
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom out',
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onExtents,
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: 'Zoom extents',
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

/// Where the view is, and how big the thing being looked at is.
class _Readout extends StatelessWidget {
  final WorkspaceState state;
  const _Readout({required this.state});

  @override
  Widget build(BuildContext context) {
    final design = state.design;
    final camera = state.camera;
    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 11.5,
        color: AppTheme.muted,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${design.widthMm.round()} × ${design.heightMm.round()} × '
                '${design.depthMm.round()} mm'),
            const SizedBox(height: 2),
            Text('${design.sections.length} sections · '
                '${design.dividers.length} bars'),
            const SizedBox(height: 2),
            Text('yaw ${camera.yawDegrees.round()}°  '
                'pitch ${camera.pitchDegrees.round()}°  '
                '×${camera.zoom.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_outlined,
                  size: 44, color: AppTheme.muted),
              const SizedBox(height: 14),
              Text(
                'Nothing to show yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Draw an outline and read the drawing. The model is built '
                'from your lines — there is no stock model to show in the '
                'meantime.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

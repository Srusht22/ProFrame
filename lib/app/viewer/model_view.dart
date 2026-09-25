import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurements.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
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
/// The parts of an opening, when an opening is what is selected.
///
/// An opening is one thing made of several — its sash, the bars drawn inside
/// it, the panes those bars make, its hinges and its handle — so picking it
/// picks all of them and the model outlines all of them. Read straight off
/// the design's own hierarchy by `Design.contentsOf`: nothing here works out
/// what belongs to what, and nothing outside the opening can appear in the
/// set because nothing outside it names the opening as its parent.
///
/// Selecting one pane, or one bar, stays that one part. The whole is picked
/// by picking the whole.
Set<String> partsOfOpening(Design design, String? selectedId) {
  if (selectedId == null) return const {};
  final element = design.elementById(selectedId);
  if (element is! OpeningElement) return const {};
  return {
    element.parentId,
    for (final part in design.contentsOf(element)) part.id,
  };
}

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
        _SolidBar(
          design: state.design,
          openFraction: state.openFraction,
          controller: controller,
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
                highlighted: partsOfOpening(state.design, state.selectedId),
                palette: context.palette,
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

/// The parts of the design that belong to the solid, edited where they can
/// be seen, and the one control that is only a way of looking.
///
/// Depth and profile are the design, not the view: changing either here
/// changes the same object the technical drawing is drawn from, so the
/// drawing changes with them. How far the leaves are swung is a way of
/// looking at the model and changes nothing.
class _SolidBar extends StatelessWidget {
  final Design design;
  final double openFraction;
  final WorkspaceController controller;

  const _SolidBar({
    required this.design,
    required this.openFraction,
    required this.controller,
  });

  /// **The bar flows onto a second line rather than running off the edge.**
  /// Its fields and its slider are fixed widths, and a `Row` has no answer
  /// to a view narrower than their sum but to overflow — which is what the
  /// view did the moment the list of parts was opened beside it, and put a
  /// striped error over the model. The note is bounded so it wraps within
  /// its own share of a line instead of taking all of one.
  @override
  Widget build(BuildContext context) => Container(
        color: context.palette.surface,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SolidNumber(
              label: 'Depth',
              valueMm: design.depthMm,
              onSet: controller.setDepth,
            ),
            if (design.frame case final frame?)
              _SolidNumber(
                label: 'Profile',
                valueMm: frame.profileMm,
                known: Measurements.knowsKey(
                  design,
                  Measurements.profileKey,
                ),
                onSet: controller.setProfile,
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                'Both are the design. The drawing changes with them.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (design.openings.isNotEmpty)
              Tooltip(
                message: 'How far the leaves are swung. A way of looking at '
                    'the model; it changes nothing.',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 128,
                      child: Slider(
                        value: openFraction,
                        onChanged: controller.setOpenFraction,
                      ),
                    ),
                    _PlayOpening(controller: controller),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// A small number field for a millimetre figure.
class _SolidNumber extends StatefulWidget {
  final String label;
  final double valueMm;
  final ValueChanged<double> onSet;

  /// False for a size nobody has given: shown empty, as `?`, rather than as
  /// the sketch's guess.
  final bool known;

  const _SolidNumber({
    required this.label,
    required this.valueMm,
    required this.onSet,
    this.known = true,
  });

  @override
  State<_SolidNumber> createState() => _SolidNumberState();
}

class _SolidNumberState extends State<_SolidNumber> {
  String get _shown => widget.known ? Units.format(widget.valueMm) : '';

  late final TextEditingController _field =
      TextEditingController(text: _shown);
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  @override
  void didUpdateWidget(_SolidNumber old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus &&
        ((widget.valueMm - old.valueMm).abs() > 0.05 ||
            widget.known != old.known)) {
      _field.text = _shown;
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final value = Units.parse(_field.text);
    if (value == null) {
      _field.text = _shown;
      return;
    }
    if (widget.known && (value - widget.valueMm).abs() < 0.05) return;
    widget.onSet(value);
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.palette.muted,
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 92,
            child: TextField(
              controller: _field,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onSubmitted: (_) => _commit(),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
              ),
              decoration: const InputDecoration(
                hintText: '?',
                suffixText: Units.symbol,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
          ),
        ],
      );
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
        color: context.palette.surface,
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
            on ? context.palette.primary.withValues(alpha: 0.1) : Colors.transparent,
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
                  color: on ? context.palette.primary : context.palette.muted,
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? context.palette.primary : context.palette.muted,
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
        color: context.palette.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onIn,
              icon: const Icon(Icons.add),
              tooltip: 'Zoom in',
              color: context.palette.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onOut,
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom out',
              color: context.palette.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onExtents,
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: 'Zoom extents',
              color: context.palette.primary,
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
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 11.5,
        color: context.palette.muted,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_given(design, design.widthMm, MeasureAxis.across)} × '
                '${_given(design, design.heightMm, MeasureAxis.down)} × '
                '${Units.label(design.depthMm)}'),
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
              Icon(Icons.view_in_ar_outlined,
                  size: 44, color: context.palette.muted),
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

/// Plays the leaves open, holds them there a moment, and closes them again
/// — once, and then it is still.
///
/// It is the **Open** slider moved for the user, so it is a way of looking
/// at the model like the slider and changes nothing in the design. Every
/// leaf moves as it would by hand: a sliding panel along its track, a
/// hinged one about its hinges.
class _PlayOpening extends StatefulWidget {
  final WorkspaceController controller;

  const _PlayOpening({required this.controller});

  /// Opening, holding and closing, end to end.
  static const cycle = Duration(milliseconds: 4200);

  @override
  State<_PlayOpening> createState() => _PlayOpeningState();
}

class _PlayOpeningState extends State<_PlayOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _PlayOpening.cycle,
  )..addListener(_step);

  // Opening takes the first part, a pause at full open, then closing.
  static const _open = Interval(0, 0.38, curve: Curves.easeInOutCubic);
  static const _close = Interval(0.62, 1, curve: Curves.easeInOutCubic);

  void _step() {
    final t = _clock.value;
    final open = t < 0.62 ? _open.transform(t) : 1 - _close.transform(t);
    widget.controller.setOpenFraction(open);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Open, pause and close',
        visualDensity: VisualDensity.compact,
        onPressed: _clock.isAnimating
            ? null
            : () {
                if (MediaQuery.of(context).disableAnimations) return;
                setState(() {});
                _clock.forward(from: 0).whenComplete(() {
                  if (mounted) setState(() {});
                });
              },
        icon: Icon(
          _clock.isAnimating
              ? Icons.hourglass_top_rounded
              : Icons.play_circle_outline_rounded,
          color: context.palette.primary,
        ),
      );
}

/// [mm] as a bare figure where the user has given it, and `?` where not.
String _given(Design design, double mm, MeasureAxis axis) =>
    Measurements.knowsOverall(design, axis) ? Units.format(mm) : '?';

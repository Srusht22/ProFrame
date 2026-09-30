import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/measurements.dart';
import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../../domain/solid/camera.dart';
import '../../domain/solid/mesh.dart';
import '../../domain/solid/mesh_builder.dart';
import '../../domain/solid/studio.dart';
import '../state/everything_shown.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'model_painter.dart';
import 'view_mode.dart';
import 'view_mode_switch.dart';

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

/// The overall sizes the technical mode writes on the model: the width
/// along the foot of the drawn face, the height up one side of it and the
/// depth along the foot of the side that is seen — each placed where
/// [camera] puts that edge of the frame.
///
/// **Every figure is the design's**, never measured off the picture: the
/// frame's own width and height, written to the millimetre as the technical
/// drawing writes them and `?` where the size has not been given, and the
/// design's depth. The depth is left off where the camera sees no side, and
/// the height goes up the side the depth is not on, so the two never meet.
List<ModelDimension> overallSizesOn(Design design, Camera camera, Mesh mesh) {
  final outline = design.frame?.outline;
  if (outline == null || outline.isEmpty || mesh.isEmpty) return const [];
  // The very transform the faces are projected by, so a figure stands on
  // the edge it measures.
  final eye = camera.eyeSpaceFor(mesh);
  final l = outline.left, r = outline.right;
  final t = outline.top, b = outline.bottom;
  final back = -design.depthMm;
  final middle = eye.place(Vec3((l + r) / 2, (t + b) / 2, back / 2));
  if (middle == null) return const [];

  // Which side is seen: the left where the eye looks across towards +x.
  final leftSeen = eye.lookingAt(Vec3(l, (t + b) / 2, back / 2)).x > 0;
  final rightSeen = eye.lookingAt(Vec3(r, (t + b) / 2, back / 2)).x < 0;
  final depthAt = leftSeen ? l : rightSeen ? r : null;
  final heightAt = depthAt == l ? r : l;

  ModelDimension? of(Vec3 a, Vec3 z, String label) {
    final from = eye.place(a), to = eye.place(z);
    if (from == null || to == null) return null;
    return ModelDimension(from: from, to: to, label: label, awayFrom: middle);
  }

  return [
    ?of(
      Vec3(l, b, 0),
      Vec3(r, b, 0),
      Measurements.figure(
        outline.width,
        known: Measurements.knowsOverall(design, MeasureAxis.across),
        places: 1,
      ),
    ),
    ?of(
      Vec3(heightAt, t, 0),
      Vec3(heightAt, b, 0),
      Measurements.figure(
        outline.height,
        known: Measurements.knowsOverall(design, MeasureAxis.down),
        places: 1,
      ),
    ),
    if (depthAt != null)
      ?of(
        Vec3(depthAt, b, 0),
        Vec3(depthAt, b, back),
        '${Units.formatTo(design.depthMm, 1)} ${Units.symbol}',
      ),
  ];
}

class ModelView extends ConsumerStatefulWidget {
  const ModelView({super.key});

  /// How much of the top of the view the projection switch lies over, and
  /// of the foot the view's buttons: the model is fitted between them, so
  /// no part of it is ever under a control.
  static const double controlsTop = 52;
  static const double controlsBottom = 60;

  @override
  ConsumerState<ModelView> createState() => _ModelViewState();
}

enum _Drag { orbit, pan }

class _ModelViewState extends ConsumerState<ModelView> {
  Offset? _from;
  _Drag _mode = _Drag.orbit;

  /// Whether the middle mouse button is down: it pans, and the drag it
  /// makes is not also an orbit.
  bool _middle = false;
  double _mmPerPixel = 1;

  /// The size of the view the model was last laid out in, for the controls
  /// outside it that frame the model — a named view.
  Size _size = Size.zero;

  // **The solid is built from the design and the leaves' swing, and from
  // nothing else**, so it is built again when either changes and kept while
  // neither does. Turning the model, zooming it, picking a part or changing
  // how it is drawn rebuilt it — and the floor's shadow, worked out by rays
  // against every member — for every pointer move. A design is never
  // changed in place, so the same object is the same design.
  Design? _builtFrom;
  double? _builtOpen;
  Mesh? _mesh;
  Floor? _floor;
  bool _floorMade = false;

  Mesh _meshOf(Design design, double openFraction) {
    if (_mesh == null ||
        !identical(design, _builtFrom) ||
        openFraction != _builtOpen) {
      _mesh = MeshBuilder.build(design, openFraction: openFraction);
      _builtFrom = design;
      _builtOpen = openFraction;
      _floorMade = false;
    }
    return _mesh!;
  }

  /// The floor under [mesh], worked out once for it.
  Floor? _floorUnder(Mesh mesh) {
    if (!_floorMade) {
      _floor = Floor.under(mesh);
      _floorMade = true;
    }
    return _floor;
  }

  /// What the camera is framed for: this design, at its own size, in a view
  /// this size. When any of it changes the model is fitted to the view
  /// again; a view the user has turned, zoomed or panned is theirs until
  /// then.
  static String framingOf(Design design, Size size) {
    final frame = design.frame!;
    return [
      design.id,
      frame.outline.toJson(),
      design.depthMm,
      size.width.round(),
      size.height.round(),
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);

    if (state.design.frame == null) return const _NothingYet();

    final mesh = _meshOf(state.design, state.openFraction);

    /// [camera] framing the model in the view as it was last laid out,
    /// between the controls over its top and its foot.
    Camera framed(Camera camera) => camera.framing(
      mesh,
      width: _size.width,
      height: _size.height,
      top: ModelView.controlsTop,
      bottom: ModelView.controlsBottom,
    );

    // Simple unless the user asked for everything: the model and how far
    // its leaves are open; the camera's views, the display styles and the
    // solid's own figures under **More**.
    final everything = ref.watch(everythingShownProvider);

    return Column(
      children: [
        if (everything) ...[
        _ViewToolbar(
          camera: state.camera,
          groundPlane: state.groundPlane,
          controller: controller,
          // A named view frames the model from that side, because a window
          // seen from the side is seventy millimetres deep and would
          // otherwise arrive as a sliver in the middle of an empty screen.
          onLook: (view) => controller.frame(
            framed(state.camera.lookingFrom(view)),
            what: framingOf(state.design, _size),
          ),
        ),
        const Divider(height: 1),
        ],
        if (everything || state.design.openings.isNotEmpty) ...[
          _SolidBar(
            design: state.design,
            openFraction: state.openFraction,
            controller: controller,
            everything: everything,
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              _size = size;

              // **The model is fitted to the view without being asked**:
              // when the view first opens on this design, when the view
              // changes size, and when the design's own size does. It is
              // painted framed at once, and the framing then kept, so the
              // user never has to go looking for it.
              final what = framingOf(state.design, size);
              var camera = state.camera;
              if (state.framedFor != what && size.shortestSide > 0) {
                camera = framed(camera);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (ref.read(workspaceProvider).framedFor == what) return;
                  controller.frame(camera, what: what);
                });
              }
              final faces = camera.project(mesh);
              final painter = ModelPainter(
                faces: faces,
                floor: state.groundPlane && state.viewMode.drawsFloor
                    ? _floorUnder(mesh)?.seenBy(camera, mesh)
                    : null,
                size: size,
                viewSpan: Camera.viewSpan(mesh),
                mode: state.viewMode,
                dimensions: state.viewMode.isTechnical
                    ? overallSizesOn(state.design, camera, mesh)
                    : const [],
                groundPlane: state.groundPlane,
                selectedId: state.selectedId,
                highlighted: partsOfOpening(state.design, state.selectedId),
                palette: context.palette,
              );
              // Millimetres of model a pixel covers at the target, as the
              // view is zoomed now — so a drag moves the model exactly as far
              // as the pointer, at every zoom.
              _mmPerPixel = painter.millimetresPerPixel / camera.zoom;
              Offset fromMiddle(Offset at) =>
                  (at - size.center(Offset.zero)) * _mmPerPixel;

              return Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    // Towards the pointer: what is under it stays under it.
                    final off = fromMiddle(event.localPosition);
                    controller.zoomCameraToward(
                      event.scrollDelta.dy > 0 ? 0.9 : 1.1,
                      acrossMm: off.dx,
                      downMm: off.dy,
                    );
                  }
                },
                // The middle button pans, as it does in every modelling
                // program — and only pans: the gestures below hear the same
                // drag, and are told to leave it alone.
                onPointerDown: (event) => _middle =
                    event.kind == PointerDeviceKind.mouse &&
                    event.buttons & kMiddleMouseButton != 0,
                onPointerUp: (_) => _middle = false,
                onPointerCancel: (_) => _middle = false,
                onPointerMove: (event) {
                  if (event.kind == PointerDeviceKind.mouse &&
                      event.buttons & kMiddleMouseButton != 0) {
                    controller.panCamera(
                      event.delta.dx * _mmPerPixel,
                      event.delta.dy * _mmPerPixel,
                    );
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _from = details.localFocalPoint;
                    // Two fingers pan and zoom, one orbits — the same
                    // division the drawing sheet uses, so the hands do not
                    // have to learn two habits. With a mouse, holding Shift
                    // pans.
                    _mode = details.pointerCount >= 2 ||
                            HardwareKeyboard.instance.isShiftPressed
                        ? _Drag.pan
                        : _Drag.orbit;
                  },
                  onScaleUpdate: (details) {
                    if (_middle) return;
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
                        // Down the screen rises over the model, as turning a thing
                        // in the hand tips its top towards you.
                        controller.orbit(delta.dx * 0.28, delta.dy * 0.18);
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
                      // How the model is shown, and how it is projected,
                      // across the top band the model is framed clear of —
                      // the projection first, and the modes in the room
                      // left beside it. Both only ways of looking.
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: ViewModeSwitch(
                                mode: state.viewMode,
                                modes: [
                                  ...ViewMode.shown,
                                  if (everything) ViewMode.wireframe,
                                ],
                                onChanged: controller.setViewMode,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ProjectionSwitch(
                              projection: camera.projection,
                              onChanged: controller.setProjection,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _Navigation(
                          onIn: () => controller.zoomCamera(1.25),
                          onOut: () => controller.zoomCamera(0.8),
                          onFit: () => controller.frame(
                            framed(camera),
                            what: what,
                          ),
                          // The view the design was first shown from, in the
                          // projection the user has chosen, framed.
                          onReset: () => controller.frame(
                            framed(
                              Camera.presentation.copyWith(
                                projection: camera.projection,
                              ),
                            ),
                            what: what,
                          ),
                        ),
                      ),
                      if (everything)
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

  /// False while the workspace is simple: then only the opening's slider.
  final bool everything;

  const _SolidBar({
    required this.design,
    required this.openFraction,
    required this.controller,
    this.everything = true,
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
            if (everything) ...[
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
            ],
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
  final bool groundPlane;
  final WorkspaceController controller;
  final ValueChanged<Camera> onLook;

  const _ViewToolbar({
    required this.camera,
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

/// The buttons over the model: closer, further, the whole model, and the
/// view it was first shown from.
class _Navigation extends StatelessWidget {
  // A row along the foot of the view rather than a column up its side, so
  // the band it lies over is one the model is fitted clear of.
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;
  final VoidCallback onReset;

  const _Navigation({
    required this.onIn,
    required this.onOut,
    required this.onFit,
    required this.onReset,
  });

  static const fitKey = ValueKey('camera-fit');
  static const resetKey = ValueKey('camera-reset');

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Row(
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
              key: fitKey,
              onPressed: onFit,
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: 'Fit the model to the view',
              color: context.palette.primary,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              key: resetKey,
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Reset the view',
              color: context.palette.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

/// Perspective or orthographic: the two ways of looking through the
/// camera, side by side and named, always on the view.
///
/// Perspective is how the thing looks; orthographic keeps parallel edges
/// parallel, so sizes can be compared across the model — for inspecting it.
/// Only a way of looking: it changes nothing in the design.
class _ProjectionSwitch extends StatelessWidget {
  final Projection projection;
  final ValueChanged<Projection> onChanged;

  const _ProjectionSwitch({required this.projection, required this.onChanged});

  static Key keyOf(Projection p) => ValueKey('camera-${p.name}');

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in Projection.values)
                InkWell(
                  key: keyOf(p),
                  borderRadius: BorderRadius.circular(8),
                  // The chosen one takes its tap too, rather than letting it
                  // through to the model, where it would put down whatever
                  // was picked.
                  onTap: () {
                    if (p != projection) onChanged(p);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p == projection
                          ? context.palette.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: p == projection
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: p == projection
                            ? context.palette.primary
                            : context.palette.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

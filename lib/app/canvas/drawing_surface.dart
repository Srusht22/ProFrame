import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/recognition/stroke_fit.dart';
import '../../domain/sketch/stroke.dart';
import '../state/tools.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'design_painter.dart';
import 'view_transform.dart';

/// The sheet: where the user draws, and where the design appears.
///
/// It takes finger, stylus and mouse alike. A stylus is trusted to be
/// drawing; a finger is trusted to be drawing too, because on a tablet that
/// is what a finger on the sheet means — panning and zooming are two-finger
/// gestures, which a pen cannot make by accident.
class DrawingSurface extends ConsumerStatefulWidget {
  final Set<String> highlighted;

  /// True for the clean 2D design: the geometry on its own, with the ink put
  /// away and the pen tools off. The drawing is still there — this is a way
  /// of looking at the design, not a different document.
  final bool planOnly;

  const DrawingSurface({
    super.key,
    this.highlighted = const {},
    this.planOnly = false,
  });

  @override
  ConsumerState<DrawingSurface> createState() => _DrawingSurfaceState();
}

class _DrawingSurfaceState extends ConsumerState<DrawingSurface> {
  ViewTransform? _view;
  Size _size = Size.zero;
  Polygon? _fittedTo;

  final _live = <StrokeSample>[];
  final _polyline = <Vec2>[];
  int? _startedAtMs;

  /// How long the pen rests, still down, before the line it has drawn is
  /// straightened. The user's own figure: long enough that the pauses of
  /// ordinary drawing do not trigger it, short enough to feel like asking.
  static const _pause = Duration(seconds: 1);

  /// How far a resting pen may still wander on the **screen** and count as
  /// resting. A hand held still trembles by a few pixels whatever the zoom,
  /// so this is in screen pixels and not in millimetres of the design.
  static const double _stillPx = 6;

  /// How close together the samples of a straightened line are laid, on the
  /// screen — about what a pen lays down, so the eraser finds it anywhere
  /// along its length.
  static const double _inkSpacingPx = 6;

  Timer? _hold;
  Offset? _restingAt;
  bool _straightened = false;
  bool _oneRun = false;

  Vec2? _dragFrom;
  Offset? _panFrom;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  ViewTransform get _transform => _view ?? ViewTransform.fit(_fittedTo, _size);

  /// Refits when the design first appears or changes size a lot, and leaves
  /// the view alone once the user has moved it themselves.
  void _fitIfNeeded(Polygon? content) {
    if (content == null) return;
    final previous = _fittedTo;
    final changed =
        previous == null ||
        (previous.width - content.width).abs() > previous.width * 0.35 ||
        (previous.height - content.height).abs() > previous.height * 0.35;
    if (!changed) return;
    _fittedTo = content;
    _view = ViewTransform.fit(content, _size);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          _view ??= ViewTransform.fit(_fittedTo, size);
        }
        _fitIfNeeded(state.design.bounds);
        final view = _transform;

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(child: _Sheet(view: view)),
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) => _down(event, view, controller),
                  onPointerMove: (event) => _move(event, view, controller),
                  onPointerUp: (_) => _up(controller),
                  onPointerCancel: (_) => _up(controller),
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      setState(() {
                        _view = view.zoomed(
                          event.scrollDelta.dy > 0 ? 0.92 : 1.08,
                          event.localPosition,
                        );
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      if (details.pointerCount < 2) return;
                      _panFrom = details.localFocalPoint;
                      _live.clear();
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount < 2) return;
                      final from = _panFrom ?? details.localFocalPoint;
                      setState(() {
                        _view = _transform
                            .panned(details.localFocalPoint - from)
                            .zoomed(
                              details.scale == 0
                                  ? 1
                                  : 1 + (details.scale - 1) * 0.2,
                              details.localFocalPoint,
                            );
                      });
                      _panFrom = details.localFocalPoint;
                    },
                    onScaleEnd: (_) => _panFrom = null,
                    child: CustomPaint(
                      size: size,
                      painter: DesignPainter(
                        design: state.design,
                        view: view,
                        selectedId: state.selectedId,
                        showSketch: state.showSketch && !widget.planOnly,
                        liveStroke: [for (final s in _live) s.at, ..._polyline],
                        liveColour: state.penColour,
                        highlighted: widget.highlighted,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomButtons(
                  onIn: () => setState(
                    () => _view = _transform.zoomed(
                      1.25,
                      size.center(Offset.zero),
                    ),
                  ),
                  onOut: () => setState(
                    () => _view = _transform.zoomed(
                      0.8,
                      size.center(Offset.zero),
                    ),
                  ),
                  onFit: () => setState(() {
                    _fittedTo = state.design.bounds;
                    _view = ViewTransform.fit(state.design.bounds, size);
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- pointers

  void _down(
    PointerDownEvent event,
    ViewTransform view,
    WorkspaceController controller,
  ) {
    final state = ref.read(workspaceProvider);
    final at = view.toSheet(event.localPosition);

    if (widget.planOnly) {
      controller.selectAt(at, slopMm: view.lengthToSheet(14));
      _dragFrom = at;
      return;
    }

    switch (state.tool) {
      case Tool.select:
        controller.selectAt(at, slopMm: view.lengthToSheet(14));
        _dragFrom = at;
      case Tool.eraser:
        _erase(at, view, controller);
      case Tool.text:
        _askForNote(at, controller);
      case Tool.polyline:
        setState(() {
          if (_polyline.isNotEmpty &&
              _polyline.first.distanceTo(at) < view.lengthToSheet(24)) {
            _finishPolyline(controller, closing: true);
          } else {
            _polyline.add(at);
          }
        });
      default:
        _startedAtMs = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _live
            ..clear()
            ..add(StrokeSample(at, pressure: _pressureOf(event)));
        });
        if (state.tool == Tool.pen) {
          _straightened = false;
          _restingAt = event.localPosition;
          _waitForRest(view);
        }
    }
  }

  // --------------------------------------------------- pause to straighten

  /// Starts, or starts again, the wait for the pen to rest.
  void _waitForRest(ViewTransform view) {
    _hold?.cancel();
    _hold = Timer(_pause, () => _straighten(view));
  }

  /// The line drawn so far, straightened where it lies.
  ///
  /// **The user asked for this by pausing, and it is the reading drawn back
  /// onto the sheet.** `StrokeFitter.straightRuns` is the same fit the
  /// design is built from, so what snaps is exactly what gets built: the
  /// wobble along each run comes out, every corner stays at the angle it was
  /// drawn, and both ends stay where the pen put them. A stroke too short or
  /// too scribbled to be a line is left as it was — there is nothing to
  /// straighten, and inventing a line would be drawing for the user.
  void _straighten(ViewTransform view) {
    if (!mounted || _straightened || _live.length < 2) return;
    final corners = StrokeFitter.straightRuns(
      Stroke(id: 'live', samples: List.of(_live)),
    );
    if (corners == null) return;
    final pressure =
        _live.map((s) => s.pressure).reduce((a, b) => a + b) / _live.length;
    setState(() {
      _live
        ..clear()
        ..addAll(
          StrokeFitter.samplesAlong(
            corners,
            spacingMm: view.lengthToSheet(_inkSpacingPx),
            pressure: pressure,
          ),
        );
      _straightened = true;
      _oneRun = corners.length == 2;
    });
    HapticFeedback.selectionClick();
  }

  void _move(
    PointerMoveEvent event,
    ViewTransform view,
    WorkspaceController controller,
  ) {
    final state = ref.read(workspaceProvider);
    final at = view.toSheet(event.localPosition);

    if (widget.planOnly || state.tool == Tool.select) {
      final from = _dragFrom;
      if (from == null || state.selectedId == null) return;
      controller.dragSelected(at - from);
      _dragFrom = at;
      return;
    }

    if (_live.isEmpty) return;

    // A straight line, a rectangle and a dimension are two points: the
    // pen's own path between them is not what the user is asking for.
    if (state.tool == Tool.line ||
        state.tool == Tool.dimension ||
        state.tool == Tool.arrow) {
      setState(() {
        _live
          ..removeRange(1, _live.length)
          ..add(StrokeSample(at, pressure: _pressureOf(event)));
      });
      return;
    }

    if (state.tool == Tool.rectangle) {
      final start = _live.first.at;
      setState(() {
        _live
          ..removeRange(1, _live.length)
          ..addAll([
            StrokeSample(Vec2(at.x, start.y)),
            StrokeSample(at),
            StrokeSample(Vec2(start.x, at.y)),
            StrokeSample(start),
          ]);
      });
      return;
    }

    if (state.tool == Tool.pen) {
      if (_straightened) {
        // Once straightened, a single line swings from where it started to
        // wherever the pen goes next, squared near the axes as the reading
        // squares it; a shape of several runs stays as it snapped.
        if (_oneRun) {
          final run = StrokeFitter.straightened(Segment(_live.first.at, at));
          final pressure = _live.first.pressure;
          setState(() {
            _live
              ..clear()
              ..addAll(
                StrokeFitter.samplesAlong(
                  [run.a, run.b],
                  spacingMm: view.lengthToSheet(_inkSpacingPx),
                  pressure: pressure,
                ),
              );
          });
        }
        return;
      }
      final resting = _restingAt;
      if (resting == null ||
          (event.localPosition - resting).distance > _stillPx) {
        _restingAt = event.localPosition;
        _waitForRest(view);
      }
    }

    setState(() {
      _live.add(
        StrokeSample(
          at,
          atMs: DateTime.now().millisecondsSinceEpoch - (_startedAtMs ?? 0),
          pressure: _pressureOf(event),
        ),
      );
    });
  }

  void _up(WorkspaceController controller) {
    final state = ref.read(workspaceProvider);
    _hold?.cancel();
    _hold = null;
    _restingAt = null;
    _straightened = false;
    _dragFrom = null;
    controller.endGesture();

    if (_live.length >= 2) {
      controller.addStroke(List.of(_live), tool: state.tool);
    }
    if (_live.isNotEmpty) setState(_live.clear);
  }

  double _pressureOf(PointerEvent event) {
    if (event.pressureMax <= event.pressureMin) return 1;
    final span = event.pressureMax - event.pressureMin;
    return ((event.pressure - event.pressureMin) / span).clamp(0.05, 1.0);
  }

  void _finishPolyline(WorkspaceController controller, {bool closing = false}) {
    if (_polyline.length < 2) {
      _polyline.clear();
      return;
    }
    final points = [..._polyline, if (closing) _polyline.first];
    controller.addStroke([
      for (final p in points) StrokeSample(p),
    ], tool: Tool.polyline);
    _polyline.clear();
  }

  void _erase(Vec2 at, ViewTransform view, WorkspaceController controller) {
    final state = ref.read(workspaceProvider);
    final reach = view.lengthToSheet(18);
    String? nearest;
    var best = double.infinity;
    for (final stroke in state.design.sketch.strokes) {
      for (final sample in stroke.samples) {
        final distance = sample.at.distanceTo(at);
        if (distance < best && distance <= reach) {
          best = distance;
          nearest = stroke.id;
        }
      }
    }
    if (nearest != null) controller.eraseStroke(nearest);
  }

  Future<void> _askForNote(Vec2 at, WorkspaceController controller) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final field = TextEditingController();
        return AlertDialog(
          title: const Text('Note'),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type your note'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(field.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (text != null) controller.addNote(text, at);
  }
}

/// The paper: a faint grid so the user can see scale and squareness without
/// anything snapping to it.
class _Sheet extends StatelessWidget {
  final ViewTransform view;
  const _Sheet({required this.view});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GridPainter(view), size: Size.infinite);
}

class _GridPainter extends CustomPainter {
  final ViewTransform view;
  const _GridPainter(this.view);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppTheme.canvas);

    // A grid line every 100 mm, and a stronger one every metre, as long as
    // they are far enough apart on screen to be worth drawing.
    for (final (step, alpha) in [(100.0, 0.055), (1000.0, 0.13)]) {
      final spacing = view.lengthToScreen(step);
      if (spacing < 9) continue;
      final paint = Paint()
        ..strokeWidth = 1
        ..color = AppTheme.primary.withValues(alpha: alpha);

      final firstX = view.origin.dx % spacing;
      for (var x = firstX; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      final firstY = view.origin.dy % spacing;
      for (var y = firstY; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.view.scale != view.scale || old.view.origin != view.origin;
}

class _ZoomButtons extends StatelessWidget {
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  const _ZoomButtons({
    required this.onIn,
    required this.onOut,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surface,
    elevation: 1,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(2),
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
            onPressed: onFit,
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit',
            color: AppTheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );
}

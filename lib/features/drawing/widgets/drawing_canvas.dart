import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/sketch.dart';
import '../../recognition/snapping_engine.dart';
import '../painters/sketch_painter.dart';
import '../state/drawing_controller.dart';

/// The drawing surface: an effectively unlimited sheet the user can pan and
/// zoom, drawn on with a finger, a mouse or a stylus.
///
/// One finger draws. Two fingers pan and zoom, so switching tools is never
/// needed just to move around the sheet (§6).
class DrawingCanvas extends StatefulWidget {
  final DrawingController controller;
  final TransformationController transformationController;

  /// Asked for a measurement as soon as a dimension line is drawn, and again
  /// whenever an existing dimension is tapped with the select tool — the app
  /// never invents the number (§10).
  final Future<double?> Function(Stroke stroke)? onDimensionDrawn;

  /// Asked for the text when the note tool is tapped.
  final Future<String?> Function()? onNoteRequested;

  final double sheetWidth;
  final double sheetHeight;

  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.transformationController,
    this.onDimensionDrawn,
    this.onNoteRequested,
    this.sheetWidth = 4000,
    this.sheetHeight = 3000,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final Set<int> _activePointers = {};
  int? _drawingPointer;

  DrawingController get _controller => widget.controller;

  double _pressureOf(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return 1.0;
    }
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return 1.0;
    return ((event.pressure - event.pressureMin) / range).clamp(0.05, 1.0).toDouble();
  }

  Vec2 _toSketch(Offset local) => Vec2(local.dx, local.dy);

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      // A second finger means the user wants to move the sheet, not draw.
      _controller.cancelStroke();
      _drawingPointer = null;
      return;
    }
    if (_controller.tool == SketchTool.pan) return;

    final point = _toSketch(event.localPosition);
    switch (_controller.tool) {
      case SketchTool.select:
        _controller.selectAt(point);
        // Tapping a dimension is how its measurement gets set or corrected.
        final selected = _controller.selectedStroke;
        if (selected != null && selected.tool == SketchTool.dimension) {
          _requestDimension(selected);
        }
      case SketchTool.eraser:
        _drawingPointer = event.pointer;
        _controller.erase(point);
      case SketchTool.note:
        _requestNote(point);
      default:
        _drawingPointer = event.pointer;
        _controller.beginStroke(point, pressure: _pressureOf(event));
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_drawingPointer != event.pointer || _activePointers.length > 1) return;
    final point = _toSketch(event.localPosition);
    if (_controller.tool == SketchTool.eraser) {
      _controller.erase(point);
      return;
    }
    _controller.extendStroke(point, pressure: _pressureOf(event));
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_drawingPointer != event.pointer) return;
    _drawingPointer = null;
    if (_controller.tool == SketchTool.eraser) return;

    final stroke = _controller.endStroke();
    if (stroke != null && stroke.tool == SketchTool.dimension) {
      _requestDimension(stroke);
    }
  }

  Future<void> _requestDimension(Stroke stroke) async {
    final callback = widget.onDimensionDrawn;
    if (callback == null) return;
    final value = await callback(stroke);
    if (value != null && value > 0) {
      _controller.setDimensionValue(stroke.id, value);
    }
  }

  Future<void> _requestNote(Vec2 position) async {
    final callback = widget.onNoteRequested;
    if (callback == null) return;
    final text = await callback();
    if (text != null && text.trim().isNotEmpty) {
      _controller.addNote(position, text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final panEnabled = _controller.tool == SketchTool.pan;

    return ColoredBox(
      color: AppColors.neutralOffWhite,
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        constrained: false,
        panEnabled: panEnabled,
        scaleEnabled: true,
        minScale: AppConstants.minZoom,
        maxScale: AppConstants.maxZoom,
        boundaryMargin: const EdgeInsets.all(600),
        child: SizedBox(
          width: widget.sheetWidth,
          height: widget.sheetHeight,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (event) {
              _activePointers.remove(event.pointer);
              if (_drawingPointer == event.pointer) {
                _drawingPointer = null;
                _controller.cancelStroke();
              }
            },
            child: Stack(
              children: [
                RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => CustomPaint(
                      size: Size(widget.sheetWidth, widget.sheetHeight),
                      isComplex: true,
                      willChange: false,
                      painter: SketchPainter(
                        strokes: _controller.strokes,
                        selectedStrokeId: _controller.selectedStrokeId,
                        showGrid: _controller.gridVisible,
                        gridSpacing: AppConstants.gridSpacing,
                      ),
                    ),
                  ),
                ),
                // Live ink on its own layer: a finger moving repaints only
                // this, never the whole drawing.
                RepaintBoundary(
                  child: _LiveInkLayer(
                    controller: _controller,
                    size: Size(widget.sheetWidth, widget.sheetHeight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveInkLayer extends StatelessWidget {
  final DrawingController controller;
  final Size size;

  const _LiveInkLayer({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Stroke?>(
      valueListenable: controller.preview,
      builder: (context, stroke, _) => ValueListenableBuilder<SnapResult?>(
        valueListenable: controller.snapIndicator,
        builder: (context, snap, _) => CustomPaint(
          size: size,
          willChange: true,
          painter: LiveStrokePainter(stroke: stroke, snap: snap),
        ),
      ),
    );
  }
}

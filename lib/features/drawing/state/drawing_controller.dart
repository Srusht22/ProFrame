import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/primitives.dart';
import '../../../shared/models/sketch.dart';
import '../../recognition/snapping_engine.dart';
import '../../recognition/stroke_recognizer.dart';

/// Owns the ink.
///
/// The stroke being drawn lives in [preview], a separate [ValueNotifier], so a
/// finger moving across the screen repaints only the live-ink layer — the
/// committed drawing, the toolbars and the rest of the app are untouched
/// (§55).
class DrawingController extends ChangeNotifier {
  DrawingController({Sketch sketch = const Sketch()}) : _strokes = [...sketch.strokes];

  final StrokeRecognizer _recognizer = const StrokeRecognizer();

  List<Stroke> _strokes;
  final List<List<Stroke>> _undoStack = [];
  final List<List<Stroke>> _redoStack = [];
  List<SketchPrimitive>? _primitiveCache;
  int _idCounter = 0;

  SketchTool _tool = SketchTool.pen;
  double _penWidth = 2.6;
  bool _gridVisible = true;
  bool _snapEnabled = true;
  bool _precisionMode = false;
  String? _selectedStrokeId;

  /// The stroke currently under the finger. Never part of [strokes] until it
  /// is committed.
  final ValueNotifier<Stroke?> preview = ValueNotifier<Stroke?>(null);

  /// What the current point snapped to, for the on-canvas guide.
  final ValueNotifier<SnapResult?> snapIndicator = ValueNotifier<SnapResult?>(null);

  List<StrokePoint> _activePoints = const [];
  StrokePoint? _skippedTail;
  bool _drawing = false;

  /// The selected stroke as it was when a move or resize began. Every step of
  /// the drag is computed from this, so dragging back and forth cannot
  /// accumulate rounding drift.
  Stroke? _transformSnapshot;

  // -- state ----------------------------------------------------------------

  Sketch get sketch => Sketch(strokes: List.unmodifiable(_strokes));
  List<Stroke> get strokes => List.unmodifiable(_strokes);
  bool get isEmpty => _strokes.isEmpty;
  bool get isDrawing => _drawing;

  SketchTool get tool => _tool;
  set tool(SketchTool value) {
    if (_tool == value) return;
    _tool = value;
    if (value != SketchTool.select) _selectedStrokeId = null;
    notifyListeners();
  }

  double get penWidth => _penWidth;
  set penWidth(double value) {
    _penWidth = value.clamp(1.0, 10.0).toDouble();
    notifyListeners();
  }

  bool get gridVisible => _gridVisible;
  set gridVisible(bool value) {
    _gridVisible = value;
    notifyListeners();
  }

  bool get snapEnabled => _snapEnabled;
  set snapEnabled(bool value) {
    _snapEnabled = value;
    notifyListeners();
  }

  /// Precision mode keeps every stroke exactly where it was drawn — no axis
  /// straightening, no snapping. Freehand and precision live side by side
  /// rather than being separate apps (§7).
  bool get precisionMode => _precisionMode;
  set precisionMode(bool value) {
    _precisionMode = value;
    notifyListeners();
  }

  String? get selectedStrokeId => _selectedStrokeId;
  Stroke? get selectedStroke =>
      _strokes.where((s) => s.id == _selectedStrokeId).firstOrNull;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  SnappingEngine get _snapping => SnappingEngine(
        gridEnabled: _gridVisible,
        gridSpacing: AppConstants.gridSpacing,
        tolerance: _snapEnabled ? 14 : 0,
      );

  /// Recognised primitives of the committed strokes, cached until the ink
  /// changes. Used for snapping and for the live read-back.
  List<SketchPrimitive> get primitives =>
      _primitiveCache ??= _recognizer.recognizeAll(sketch);

  // -- drawing --------------------------------------------------------------

  void beginStroke(Vec2 point, {double pressure = 1.0}) {
    if (!_tool.producesInk) return;
    final snapped = _snapPoint(point);
    _drawing = true;
    _skippedTail = null;
    _activePoints = [
      StrokePoint(
        x: snapped.x,
        y: snapped.y,
        pressure: pressure,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      )
    ];
    preview.value = _buildPreview();
  }

  void extendStroke(Vec2 point, {double pressure = 1.0}) {
    if (!_drawing) return;
    final Vec2 resolved;
    if (_tool.isTwoPoint) {
      final anchor = _activePoints.first.position;
      final snap = _snapEnabled && !_precisionMode
          ? _snapping.snapSegmentEnd(anchor, point, primitives)
          : SnapResult(point: point);
      snapIndicator.value = snap.snapped ? snap : null;
      resolved = snap.point;
      _activePoints = [
        _activePoints.first,
        StrokePoint(x: resolved.x, y: resolved.y, pressure: pressure),
      ];
    } else {
      resolved = point;
      // Drop samples that are too close together; a finger produces far more
      // points than the geometry needs.
      final last = _activePoints.last.position;
      if (last.distanceTo(resolved) < 1.2) {
        // Remember it: the very last sample must not be thrown away, or the
        // stroke would end short of where the finger actually lifted.
        _skippedTail = StrokePoint(x: resolved.x, y: resolved.y, pressure: pressure);
        return;
      }
      _skippedTail = null;
      _activePoints = [
        ..._activePoints,
        StrokePoint(x: resolved.x, y: resolved.y, pressure: pressure),
      ];
    }
    preview.value = _buildPreview();
  }

  /// Commits the live stroke. Returns it so the caller can immediately ask for
  /// a dimension value or note text.
  Stroke? endStroke() {
    if (!_drawing) return null;
    _drawing = false;
    snapIndicator.value = null;
    final tail = _skippedTail;
    final points = tail == null ? _activePoints : [..._activePoints, tail];
    _activePoints = const [];
    _skippedTail = null;
    preview.value = null;

    if (points.length < 2) {
      // A tap with a two-point tool is not a stroke; with the pen it is a dot.
      if (_tool.isTwoPoint || points.isEmpty) return null;
    }

    var finalPoints = points;
    if (_tool.isTwoPoint) {
      final start = points.first.position;
      final end = points.last.position;
      if (start.distanceTo(end) < 4) return null;
      finalPoints = [points.first, points.last];
    }

    final stroke = Stroke(
      id: _nextId(),
      tool: _tool,
      points: finalPoints,
      width: _penWidth,
    );
    _pushUndo();
    _strokes = [..._strokes, stroke];
    _invalidate();
    return stroke;
  }

  void cancelStroke() {
    _drawing = false;
    _activePoints = const [];
    preview.value = null;
    snapIndicator.value = null;
  }

  Stroke? _buildPreview() => _activePoints.isEmpty
      ? null
      : Stroke(id: '__preview__', tool: _tool, points: _activePoints, width: _penWidth);

  Vec2 _snapPoint(Vec2 point) {
    if (!_snapEnabled || _precisionMode) return point;
    final snap = _snapping.snapPoint(point, primitives);
    snapIndicator.value = snap.snapped ? snap : null;
    return snap.point;
  }

  // -- editing --------------------------------------------------------------

  /// Removes any stroke passing within [radius] of the point.
  bool erase(Vec2 point, {double radius = 16}) {
    final survivors = _strokes.where((s) => !_hits(s, point, radius)).toList();
    if (survivors.length == _strokes.length) return false;
    _pushUndo();
    _strokes = survivors;
    _invalidate();
    return true;
  }

  void selectAt(Vec2 point, {double radius = 18}) {
    Stroke? found;
    for (final stroke in _strokes.reversed) {
      if (_hits(stroke, point, radius)) {
        found = stroke;
        break;
      }
    }
    _selectedStrokeId = found?.id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedStrokeId == null) return;
    _selectedStrokeId = null;
    notifyListeners();
  }

  /// Starts a move or resize. One undo step covers the whole gesture.
  void beginTransform() {
    final stroke = selectedStroke;
    if (stroke == null) return;
    _transformSnapshot = stroke;
    _pushUndo();
  }

  void endTransform() => _transformSnapshot = null;

  bool get isTransforming => _transformSnapshot != null;

  /// Moves the selected stroke by [delta] from where it was when the gesture
  /// started.
  void moveSelectedBy(Vec2 delta) {
    final origin = _transformSnapshot;
    if (origin == null) return;
    _replace(
      origin.id,
      origin.copyWith(
        points: origin.points
            .map((p) => p.copyWith(x: p.x + delta.x, y: p.y + delta.y))
            .toList(),
      ),
    );
  }

  /// Resizes the selected stroke so its bounds become [bounds]. Used by the
  /// corner handles.
  ///
  /// An axis the stroke has no extent on — the height of a horizontal line —
  /// is left exactly as drawn rather than being stretched out of nothing, so
  /// lengthening a line does not also give it a thickness or shift it sideways.
  /// A target that would collapse the stroke, or turn it inside out by dragging
  /// a grip past the opposite edge, is ignored: the stroke stops rather than
  /// vanishing or mirroring itself.
  void resizeSelectedTo(Box2 bounds) {
    final origin = _transformSnapshot;
    if (origin == null) return;
    final from = origin.bounds;

    final flatX = from.width.abs() < 1e-6;
    final flatY = from.height.abs() < 1e-6;
    if (!flatX && bounds.width < 4) return;
    if (!flatY && bounds.height < 4) return;

    final scaleX = flatX ? 1.0 : bounds.width / from.width;
    final scaleY = flatY ? 1.0 : bounds.height / from.height;

    _replace(
      origin.id,
      origin.copyWith(
        points: origin.points
            .map((p) => p.copyWith(
                  x: flatX ? p.x : bounds.left + (p.x - from.left) * scaleX,
                  y: flatY ? p.y : bounds.top + (p.y - from.top) * scaleY,
                ))
            .toList(),
      ),
    );
  }

  void deleteSelected() {
    final id = _selectedStrokeId;
    if (id == null) return;
    _pushUndo();
    _strokes = _strokes.where((s) => s.id != id).toList();
    _selectedStrokeId = null;
    _invalidate();
  }

  void duplicateSelected({Vec2 offset = const Vec2(28, 28)}) {
    final stroke = selectedStroke;
    if (stroke == null) return;
    _pushUndo();
    final copy = stroke.copyWith(
      points: stroke.points
          .map((p) => p.copyWith(x: p.x + offset.x, y: p.y + offset.y))
          .toList(),
    );
    final duplicated = Stroke(
      id: _nextId(),
      tool: copy.tool,
      points: copy.points,
      width: copy.width,
      text: copy.text,
      dimensionMm: copy.dimensionMm,
    );
    _strokes = [..._strokes, duplicated];
    _selectedStrokeId = duplicated.id;
    _invalidate();
  }

  /// Rotates the selected stroke about its own centre.
  void rotateSelected({double degrees = 90}) {
    final stroke = selectedStroke;
    if (stroke == null) return;
    _pushUndo();
    final centre = stroke.bounds.center;
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final rotated = stroke.points.map((p) {
      final dx = p.x - centre.x;
      final dy = p.y - centre.y;
      return p.copyWith(x: centre.x + dx * cos - dy * sin, y: centre.y + dx * sin + dy * cos);
    }).toList();
    _replace(stroke.id, stroke.copyWith(points: rotated));
  }

  void setDimensionValue(String strokeId, double? millimetres) {
    final stroke = _strokes.where((s) => s.id == strokeId).firstOrNull;
    if (stroke == null) return;
    _pushUndo();
    _replace(
      strokeId,
      millimetres == null
          ? stroke.copyWith(clearDimension: true)
          : stroke.copyWith(dimensionMm: millimetres, text: '${millimetres.round()}'),
    );
  }

  void setNoteText(String strokeId, String text) {
    final stroke = _strokes.where((s) => s.id == strokeId).firstOrNull;
    if (stroke == null) return;
    _pushUndo();
    _replace(strokeId, stroke.copyWith(text: text));
  }

  /// Adds a note without a drag — the note tool places text at a tap.
  Stroke addNote(Vec2 position, String text) {
    _pushUndo();
    final stroke = Stroke(
      id: _nextId(),
      tool: SketchTool.note,
      points: [StrokePoint(x: position.x, y: position.y)],
      text: text,
    );
    _strokes = [..._strokes, stroke];
    _invalidate();
    return stroke;
  }

  void _replace(String id, Stroke replacement) {
    _strokes = _strokes.map((s) => s.id == id ? replacement : s).toList();
    _invalidate();
  }

  bool _hits(Stroke stroke, Vec2 point, double radius) {
    if (stroke.points.length == 1) {
      return stroke.points.first.position.distanceTo(point) <= radius;
    }
    final positions = _hitPath(stroke);
    for (var i = 1; i < positions.length; i++) {
      if (GeometryMath.distanceToSegment(point, positions[i - 1], positions[i]) <= radius) {
        return true;
      }
    }
    return false;
  }

  /// What the user can actually grab. A rectangle is stored as two opposite
  /// corners but drawn as four edges, so it has to be hit-tested on those
  /// edges — otherwise tapping the frame line misses and tapping the empty
  /// middle (on the diagonal) selects it.
  List<Vec2> _hitPath(Stroke stroke) {
    if (stroke.tool != SketchTool.rectangle) return stroke.positions;
    final box = Box2.fromCorners(stroke.start, stroke.end);
    return [
      Vec2(box.left, box.top),
      Vec2(box.right, box.top),
      Vec2(box.right, box.bottom),
      Vec2(box.left, box.bottom),
      Vec2(box.left, box.top),
    ];
  }

  // -- history --------------------------------------------------------------

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add([..._strokes]);
    _strokes = _undoStack.removeLast();
    _selectedStrokeId = null;
    _invalidate();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add([..._strokes]);
    _strokes = _redoStack.removeLast();
    _selectedStrokeId = null;
    _invalidate();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _pushUndo();
    _strokes = [];
    _selectedStrokeId = null;
    _invalidate();
  }

  void loadSketch(Sketch sketch) {
    _undoStack.clear();
    _redoStack.clear();
    _strokes = [...sketch.strokes];
    _selectedStrokeId = null;
    _idCounter = _strokes.length;
    _invalidate();
  }

  void _pushUndo() {
    _undoStack.add([..._strokes]);
    if (_undoStack.length > AppConstants.maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _invalidate() {
    _primitiveCache = null;
    notifyListeners();
  }

  String _nextId() =>
      's${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idCounter++}';

  @override
  void dispose() {
    preview.dispose();
    snapIndicator.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

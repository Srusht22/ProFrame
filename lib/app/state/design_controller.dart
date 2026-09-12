import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/units/length_unit.dart';
import '../../domain/design_document.dart';
import '../../domain/geometry/point2.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/layout/design_builder.dart';
import '../../domain/layout/note_resolver.dart';
import '../../domain/layout/width_solver.dart';
import '../../domain/panel.dart';
import '../../domain/panel_divider.dart';
import '../../domain/panel_note.dart';
import '../../domain/product/infill.dart';
import '../../domain/product/opening.dart';
import '../../domain/product/product_basics.dart';
import '../../domain/recognition/stroke_classifier.dart';
import '../../domain/recognition/stroke_intent.dart';
import '../../domain/sketch.dart';
import '../canvas/canvas_projection.dart';
import '../i18n/labels.dart';
import 'preferences_controller.dart';

/// What the finger does on the canvas.
///
/// Drawing and navigating are deliberately different modes rather than both
/// living on one gesture: the spec requires that panning cannot accidentally
/// create geometry and drawing cannot accidentally scroll (section 4).
enum CanvasTool {
  /// One finger draws ink, which is then classified.
  draw('Draw', 'Draw the frame, dividers and opening marks'),

  /// One finger moves the sheet. Two fingers always zoom, in either mode.
  pan('Move', 'Drag the sheet, pinch to zoom'),

  /// Tap to pick a panel or a divider, long-press for its properties, drag a
  /// note label to move it.
  select('Select', 'Tap a panel or a divider, drag a note to move it');

  final String label;
  final String hint;

  const CanvasTool(this.label, this.hint);

  bool get drawsInk => this == CanvasTool.draw;
}

/// Everything the canvas screen needs to render, in one immutable value.
class DesignState {
  final DesignDocument design;

  /// The panel the user last touched, if any.
  final String? selectedPanelId;

  /// The divider being moved, if any.
  final String? selectedDividerId;

  /// The last thing the app wants to tell the user — a refused width, a
  /// divider that would not fit. Cleared when they act again.
  final String? message;

  /// Which tool the finger is using.
  final CanvasTool tool;

  /// The view transform. Model coordinates never change with it.
  final double zoom;
  final Offset pan;

  /// Whether note labels are drawn on the canvas. Hiding is not deleting.
  final bool notesVisible;

  /// Whether there is anything to undo or redo.
  ///
  /// Part of the state rather than a getter on the controller, so the buttons
  /// enable and disable as a consequence of the state changing instead of
  /// relying on some other change happening to rebuild them.
  final bool canUndo;
  final bool canRedo;

  const DesignState({
    required this.design,
    this.selectedPanelId,
    this.selectedDividerId,
    this.message,
    this.canUndo = false,
    this.canRedo = false,
    this.tool = CanvasTool.draw,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.notesVisible = true,
  });

  DesignState copyWith({
    DesignDocument? design,
    String? selectedPanelId,
    String? selectedDividerId,
    String? message,
    bool? canUndo,
    bool? canRedo,
    CanvasTool? tool,
    double? zoom,
    Offset? pan,
    bool? notesVisible,
    bool clearSelection = false,
    bool clearMessage = false,
  }) =>
      DesignState(
        design: design ?? this.design,
        selectedPanelId:
            clearSelection ? null : (selectedPanelId ?? this.selectedPanelId),
        selectedDividerId:
            clearSelection ? null : (selectedDividerId ?? this.selectedDividerId),
        message: clearMessage ? null : (message ?? this.message),
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
        tool: tool ?? this.tool,
        zoom: zoom ?? this.zoom,
        pan: pan ?? this.pan,
        notesVisible: notesVisible ?? this.notesVisible,
      );
}

/// Owns the design while it is being drawn and edited.
///
/// Every change goes through here, and every change is undoable: the previous
/// document is pushed before the new one replaces it (spec Phase 2, item 8).
/// Because the whole design is one immutable value, undo is a stack of
/// documents rather than a log of reversible operations — there is no way for
/// an action to be half-undone.
///
/// No geometry is computed here. Classification lives in
/// [StrokeClassifier] and layout in [DesignBuilder], both pure domain code, so
/// the rules can be tested without a widget (spec section 9).
class DesignController extends Notifier<DesignState> {
  /// What the app says, in the user's language. Read fresh each time rather
  /// than cached, so a message written after a language change is in the new
  /// language.
  AppStrings get _strings => ref.read(appStringsProvider);

  final List<DesignDocument> _undoStack = [];
  final List<DesignDocument> _redoStack = [];
  int _idCounter = 0;

  /// A placeholder so the provider has a value before a design is opened.
  ///
  /// The canvas is only reachable after [open], so this is never drawn. It
  /// exists so the rest of the class can treat the design as non-null instead
  /// of threading a null check through every method.
  @override
  DesignState build() => DesignState(
        design: DesignDocument.blank(
          id: 'unopened',
          category: ProductCategory.window,
          material: FrameMaterial.pvc,
        ),
      );

  /// Opens [document] for editing and clears the history.
  ///
  /// History is cleared deliberately: undoing past the moment a design was
  /// opened would take the user into a different design.
  void open(DesignDocument document) {
    _undoStack.clear();
    _redoStack.clear();
    _idCounter = 0;
    state = DesignState(design: document);
  }

  // -- history --------------------------------------------------------------

  void undo() {
    if (_undoStack.isEmpty) return;
    endGesture();
    _redoStack.add(state.design);
    state = state.copyWith(
      design: _undoStack.removeLast(),
      clearSelection: true,
      clearMessage: true,
      canUndo: _undoStack.isNotEmpty,
      canRedo: true,
    );
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    endGesture();
    _undoStack.add(state.design);
    state = state.copyWith(
      design: _redoStack.removeLast(),
      clearSelection: true,
      clearMessage: true,
      canUndo: true,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  /// What the current drag is moving, or null between gestures.
  ///
  /// A drag arrives as dozens of small changes. They are one thing the user
  /// did, so they get one entry in the history, not one per frame.
  String? _gestureKey;

  /// The finger came off the glass: the next change starts a new history
  /// entry, even if it moves the same thing again.
  void endGesture() => _gestureKey = null;

  /// Records the current document so the next change can be undone.
  ///
  /// Callers set the new design straight after; the history flags are updated
  /// here so no caller can forget them.
  ///
  /// [coalesce] names what a drag is moving. While the same thing keeps
  /// moving, the snapshot taken when the drag began is the one kept, so a
  /// single undo puts the label — or the divider — back where it started.
  void _remember({String? coalesce}) {
    if (coalesce != null && coalesce == _gestureKey && _undoStack.isNotEmpty) {
      return;
    }
    _gestureKey = coalesce;
    _undoStack.add(state.design);
    _redoStack.clear();
    state = state.copyWith(canUndo: true, canRedo: false);
  }

  String _nextId(String prefix) => '$prefix${++_idCounter}';

  // -- drawing --------------------------------------------------------------

  /// Adds a finished stroke: keeps the ink, classifies it, applies what it
  /// meant.
  ///
  /// The stroke is kept whatever the classifier decides, so the user can
  /// always see what they drew and compare it against what was built
  /// (spec section 4).
  StrokeIntent addStroke(List<Point2> points) {
    if (points.length < 2) {
      return const DiscardedIntent('', 'A tap, not a stroke.');
    }

    final design = state.design;
    final stroke = Stroke(
      id: _nextId('ink'),
      points: points,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    final intent = StrokeClassifier(
      frame: design.outline,
      panels: design.panels,
    ).classify(stroke);

    _remember();
    final withInk = design.copyWith(sketch: design.sketch.withStroke(stroke));
    state = state.copyWith(
      design: DesignBuilder.apply(withInk, intent, _nextId),
      clearMessage: true,
    );
    return intent;
  }

  // -- dimensions -----------------------------------------------------------

  /// Confirms the overall width, rescaling the drawing to suit.
  void setOverallWidth(double millimetres) {
    _remember();
    state = state.copyWith(
      design: DesignBuilder.setOverallWidth(state.design, millimetres),
      clearMessage: true,
    );
  }

  void setOverallHeight(double millimetres) {
    _remember();
    state = state.copyWith(
      design: DesignBuilder.setOverallHeight(state.design, millimetres),
      clearMessage: true,
    );
  }

  /// Sets one panel's width, adjusting its neighbour.
  ///
  /// A width that cannot be applied is refused with an explanation and
  /// nothing changes — the user is never handed a number they did not type
  /// (spec section 2).
  void setPanelWidth(String panelId, double millimetres) {
    final row = _rowContaining(panelId);
    final outcome = WidthSolver.setWidth(row, panelId, millimetres);

    switch (outcome) {
      case final WidthRefused refused:
        state = state.copyWith(message: _strings.widthRefusal(refused));
      case WidthApplied(:final panels, :final adjustedPanelId, :final adjustmentMm):
        _remember();
        final updated = {for (final panel in panels) panel.id: panel};
        // Nothing moves unremarked: when a neighbour absorbed the change, say
        // which one and what it is now.
        final neighbour = updated[adjustedPanelId];
        state = state.copyWith(
          design: state.design.copyWith(
            panels: [
              for (final panel in state.design.panels)
                updated[panel.id] ?? panel,
            ],
          ),
          message: adjustmentMm == 0 || neighbour == null
              ? null
              : _strings(T.neighbourNowWide, {
                  'width': _strings.length(
                    neighbour.widthMm,
                    LengthUnit.millimetre,
                  ),
                }),
          clearMessage: adjustmentMm == 0 || neighbour == null,
        );
    }
  }

  /// The panels sharing a horizontal band with [panelId] — the row whose
  /// widths have to keep summing to the same span.
  List<Panel> _rowContaining(String panelId) {
    final target = state.design.panelById(panelId);
    if (target == null) return const [];
    final box = target.boundary;
    return state.design.panels.where((panel) {
      final other = panel.boundary;
      // Overlapping vertically by more than a hair means the same row.
      final overlap = (other.bottom < box.bottom ? other.bottom : box.bottom) -
          (other.top > box.top ? other.top : box.top);
      return overlap > 1;
    }).toList();
  }

  // -- panels ---------------------------------------------------------------

  void selectPanel(String? panelId) => state = state.copyWith(
        selectedPanelId: panelId,
        clearSelection: panelId == null,
        clearMessage: true,
      );

  /// Makes a panel fixed (CH).
  void makeFixed(String panelId) {
    final panel = state.design.panelById(panelId);
    if (panel == null || panel.behaviour.isFixed) return;
    _remember();
    state = state.copyWith(design: state.design.withPanel(panel.asFixed()));
  }

  /// Makes a panel opening (Z), or updates how it opens.
  void setOpening(String panelId, OpeningSpec spec) {
    final panel = state.design.panelById(panelId);
    if (panel == null) return;
    _remember();
    state = state.copyWith(design: state.design.withPanel(panel.asOpening(spec)));
  }

  void setMesh(String panelId, bool hasMesh) =>
      _editPanel(panelId, (panel) => panel.copyWith(hasMesh: hasMesh));

  void setEmpty(String panelId, bool isEmpty) =>
      _editPanel(panelId, (panel) => panel.copyWith(isEmpty: isEmpty));

  /// Adds a note to a panel, or removes it when the text is blank.
  ///
  /// Returns the note's id so the caller can move it afterwards.
  String? addPanelNote(String panelId, String text, {Point2? at}) {
    if (text.trim().isEmpty) return null;
    final note = PanelNote(
      id: _nextId('note'),
      text: text.trim(),
      position: at ?? const Point2(0.5, 0.5),
    );
    _editPanel(panelId, (panel) => panel.withNote(note));
    return note.id;
  }

  void editPanelNote(String panelId, String noteId, String text) {
    final panel = state.design.panelById(panelId);
    final note = panel?.noteById(noteId);
    if (panel == null || note == null) return;
    // Clearing the text deletes it: an empty note is not a note, and leaving
    // a blank marker on the drawing would be worse than removing it.
    if (text.trim().isEmpty) {
      removePanelNote(panelId, noteId);
      return;
    }
    _editPanel(
      panelId,
      (p) => p.withUpdatedNote(note.copyWith(text: text.trim())),
    );
  }

  void removePanelNote(String panelId, String noteId) =>
      _editPanel(panelId, (panel) => panel.withoutNote(noteId));

  /// Moves a note's label within its own panel. [at] is fractional.
  void movePanelNote(String panelId, String noteId, Point2 at) {
    final note = state.design.panelById(panelId)?.noteById(noteId);
    if (note == null) return;
    _editPanel(
      panelId,
      (panel) => panel.withUpdatedNote(note.copyWith(position: at)),
      coalesce: 'note:$panelId/$noteId',
    );
  }

  /// Shows or hides a note without deleting it (spec section 8B).
  void setNoteVisible(String panelId, String noteId, bool visible) {
    final note = state.design.panelById(panelId)?.noteById(noteId);
    if (note == null) return;
    _editPanel(
      panelId,
      (panel) => panel.withUpdatedNote(note.copyWith(isVisible: visible)),
    );
  }

  /// Hides or shows every note at once — the annotation overlay toggle.
  void setAllNotesVisible(bool visible) {
    _remember();
    state = state.copyWith(
      design: state.design.copyWith(
        panels: [
          for (final panel in state.design.panels)
            panel.copyWith(
              notes: [
                for (final note in panel.notes)
                  note.copyWith(isVisible: visible),
              ],
            ),
        ],
      ),
    );
  }

  void setInfill(String panelId, Infill infill) =>
      _editPanel(panelId, (panel) => panel.copyWith(infill: infill));

  void _editPanel(
    String panelId,
    Panel Function(Panel) edit, {
    String? coalesce,
  }) {
    final panel = state.design.panelById(panelId);
    if (panel == null) return;
    final updated = edit(panel);
    if (updated == panel) return;
    _remember(coalesce: coalesce);
    state = state.copyWith(design: state.design.withPanel(updated));
  }

  // -- design note ----------------------------------------------------------

  /// Renames the project.
  void rename(String name) {
    if (name.trim().isEmpty || name == state.design.name) return;
    _remember();
    state = state.copyWith(design: state.design.copyWith(name: name.trim()));
  }

  /// Stamps the document as changed now. Called before a save, so the project
  /// list orders by when work actually happened.
  void touch() => state = state.copyWith(
        design: state.design.copyWith(updatedAt: DateTime.now()),
      );

  void setDesignNote(String note) {
    if (note == state.design.designNote) return;
    _remember();
    state = state.copyWith(design: state.design.copyWith(designNote: note));
  }

  // -- dividers -------------------------------------------------------------

  void selectDivider(String? dividerId) => state = state.copyWith(
        selectedDividerId: dividerId,
        clearSelection: dividerId == null,
        clearMessage: true,
      );

  /// Moves a divider and re-cuts the panels on either side of it.
  ///
  /// The panels keep their ids, so a CH/Z choice made before the move survives
  /// it (spec section 10).
  void moveDivider(String dividerId, double toMm) {
    final divider = _dividerById(dividerId);
    if (divider == null) return;

    final vertical = divider.isVertical;
    final (before, after) = _panelsAround(divider);
    if (before == null || after == null) return;

    final low = vertical ? before.boundary.left : before.boundary.top;
    final high = vertical ? after.boundary.right : after.boundary.bottom;
    if (toMm - low < 50 || high - toMm < 50) {
      state = state.copyWith(
        message: _strings(T.dividerTooClose),
      );
      return;
    }

    _remember(coalesce: 'divider:$dividerId');
    final box = before.boundary;
    state = state.copyWith(
      design: state.design.copyWith(
        panels: [
          for (final panel in state.design.panels)
            if (panel.id == before.id)
              panel.copyWith(
                boundary: vertical
                    ? Polygon.rectangle(
                        width: toMm - box.left,
                        height: box.height,
                        topLeft: Point2(box.left, box.top),
                      )
                    : Polygon.rectangle(
                        width: box.width,
                        height: toMm - box.top,
                        topLeft: Point2(box.left, box.top),
                      ),
              )
            else if (panel.id == after.id)
              panel.copyWith(
                boundary: vertical
                    ? Polygon.rectangle(
                        width: after.boundary.right - toMm,
                        height: after.boundary.height,
                        topLeft: Point2(toMm, after.boundary.top),
                      )
                    : Polygon.rectangle(
                        width: after.boundary.width,
                        height: after.boundary.bottom - toMm,
                        topLeft: Point2(after.boundary.left, toMm),
                      ),
              )
            else
              panel,
        ],
        dividers: [
          for (final existing in state.design.dividers)
            if (existing.id == dividerId)
              existing.copyWith(
                start: vertical
                    ? Point2(toMm, existing.start.y)
                    : Point2(existing.start.x, toMm),
                end: vertical
                    ? Point2(toMm, existing.end.y)
                    : Point2(existing.end.x, toMm),
              )
            else
              existing,
        ],
      ),
      clearMessage: true,
    );
  }

  /// Deletes a divider, merging the two panels it separated back into one.
  ///
  /// The merged panel is a new panel with a new id: it is not either of the
  /// two that were there, and inheriting one of their CH/Z assignments would
  /// be a decision the user did not make (spec section 10).
  void deleteDivider(String dividerId) {
    final divider = _dividerById(dividerId);
    if (divider == null) return;
    final (before, after) = _panelsAround(divider);
    if (before == null || after == null) return;

    _remember();
    final merged = Panel.fixed(
      id: _nextId('panel'),
      boundary: Polygon.rectangle(
        width: divider.isVertical
            ? after.boundary.right - before.boundary.left
            : before.boundary.width,
        height: divider.isVertical
            ? before.boundary.height
            : after.boundary.bottom - before.boundary.top,
        topLeft: Point2(before.boundary.left, before.boundary.top),
      ),
      infill: before.infill,
      hasMesh: before.hasMesh || after.hasMesh,
      isEmpty: before.isEmpty && after.isEmpty,
    );

    // Both panels' notes come across, repositioned. Deciding that one of them
    // no longer applies is the user's call (spec section 8B).
    final resolved = NoteResolver.afterMerge([before, after], merged);
    final mergedWithNotes = resolved.panels.single;

    state = state.copyWith(
      design: state.design.copyWith(
        panels: [
          for (final panel in state.design.panels)
            if (panel.id == before.id)
              mergedWithNotes
            else if (panel.id != after.id)
              panel,
        ],
        dividers: [
          for (final existing in state.design.dividers)
            if (existing.id != dividerId) existing,
        ],
      ),
      clearSelection: true,
      message: _strings.noteTransfers(resolved.transfers),
      clearMessage: resolved.transfers.isEmpty,
    );
  }

  PanelDivider? _dividerById(String id) {
    for (final divider in state.design.dividers) {
      if (divider.id == id) return divider;
    }
    return null;
  }

  /// The panel on each side of [divider], by shared edge.
  (Panel?, Panel?) _panelsAround(PanelDivider divider) {
    final vertical = divider.isVertical;
    final at = vertical ? divider.start.x : divider.start.y;
    Panel? before;
    Panel? after;
    for (final panel in state.design.panels) {
      final box = panel.boundary;
      if (vertical) {
        if ((box.right - at).abs() < 1 && _overlapsSpan(divider, box, true)) {
          before = panel;
        }
        if ((box.left - at).abs() < 1 && _overlapsSpan(divider, box, true)) {
          after = panel;
        }
      } else {
        if ((box.bottom - at).abs() < 1 && _overlapsSpan(divider, box, false)) {
          before = panel;
        }
        if ((box.top - at).abs() < 1 && _overlapsSpan(divider, box, false)) {
          after = panel;
        }
      }
    }
    return (before, after);
  }

  bool _overlapsSpan(PanelDivider divider, Polygon box, bool vertical) {
    final low = vertical ? divider.start.y : divider.start.x;
    final high = vertical ? divider.end.y : divider.end.x;
    final boxLow = vertical ? box.top : box.left;
    final boxHigh = vertical ? box.bottom : box.right;
    final overlap = (high < boxHigh ? high : boxHigh) -
        (low > boxLow ? low : boxLow);
    return overlap > 1;
  }

  // -- the view -------------------------------------------------------------

  void selectTool(CanvasTool tool) =>
      state = state.copyWith(tool: tool, clearMessage: true);

  void setZoom(double zoom) => state = state.copyWith(
        zoom: zoom.clamp(CanvasProjection.minZoom, CanvasProjection.maxZoom),
      );

  void panBy(Offset delta) => state = state.copyWith(pan: state.pan + delta);

  void setView(double zoom, Offset pan) =>
      state = state.copyWith(zoom: zoom, pan: pan);

  /// Back to the whole sheet.
  void resetView() => state = state.copyWith(zoom: 1, pan: Offset.zero);

  /// Shows or hides every note label on the drawing.
  ///
  /// A *view* setting, not an edit: it is not undoable and it does not touch
  /// the design, because hiding a note must never risk losing it.
  void setNotesVisible(bool visible) =>
      state = state.copyWith(notesVisible: visible);

  /// Deletes whatever is selected — a divider, or a panel's opening marks.
  void deleteSelection() {
    final dividerId = state.selectedDividerId;
    if (dividerId != null) {
      deleteDivider(dividerId);
      return;
    }
    final panelId = state.selectedPanelId;
    if (panelId == null) {
      state = state.copyWith(message: _strings(T.tapSomethingFirst));
      return;
    }
    // A panel cannot be deleted — it is a region of the frame, not an object.
    // What can be removed is what was added to it.
    final panel = state.design.panelById(panelId);
    if (panel == null) return;
    if (panel.behaviour.isOpening) {
      makeFixed(panelId);
      state = state.copyWith(message: _strings(T.panelFixedAgain));
      return;
    }
    state = state.copyWith(
      message: _strings(T.panelIsPartOfFrame),
    );
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final designControllerProvider =
    NotifierProvider<DesignController, DesignState>(DesignController.new);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/providers.dart';
import '../../../shared/models/design_document.dart';
import '../../../shared/models/interpretation.dart';
import '../../../shared/models/opening_model.dart';
import '../../../shared/models/scene_3d.dart';
import '../../../shared/models/sketch.dart';
import '../../geometry/region_editor.dart';
import '../../projects/design_library.dart';
import '../../recognition/interpretation_service.dart';

/// Everything the editor needs for the design currently open.
class DesignSession {
  final DesignDocument? document;
  final InterpretationResult? interpretation;
  final bool isInterpreting;
  final bool isDirty;
  final String? selectedRegionId;
  final RenderStyle renderStyle;
  final bool showDimensions;
  final bool autoRotate;
  final String? error;

  const DesignSession({
    this.document,
    this.interpretation,
    this.isInterpreting = false,
    this.isDirty = false,
    this.selectedRegionId,
    this.renderStyle = RenderStyle.realistic,
    this.showDimensions = false,
    this.autoRotate = false,
    this.error,
  });

  bool get hasDocument => document != null;
  OpeningModel? get model => document?.model;
  InterpretationReport get report =>
      interpretation?.report ?? InterpretationReport.empty;

  DesignSession copyWith({
    DesignDocument? document,
    InterpretationResult? interpretation,
    bool clearInterpretation = false,
    bool? isInterpreting,
    bool? isDirty,
    String? selectedRegionId,
    bool clearSelection = false,
    RenderStyle? renderStyle,
    bool? showDimensions,
    bool? autoRotate,
    String? error,
    bool clearError = false,
  }) =>
      DesignSession(
        document: document ?? this.document,
        interpretation:
            clearInterpretation ? null : (interpretation ?? this.interpretation),
        isInterpreting: isInterpreting ?? this.isInterpreting,
        isDirty: isDirty ?? this.isDirty,
        selectedRegionId: clearSelection ? null : (selectedRegionId ?? this.selectedRegionId),
        renderStyle: renderStyle ?? this.renderStyle,
        showDimensions: showDimensions ?? this.showDimensions,
        autoRotate: autoRotate ?? this.autoRotate,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives the design being edited.
///
/// Every change lands on the parametric model, and the drawing, the 3D view
/// and the price all read back from it — there is no second copy of the truth
/// anywhere (§27).
class DesignSessionNotifier extends Notifier<DesignSession> {
  Timer? _autosaveTimer;
  final List<OpeningModel> _modelUndo = [];
  final List<OpeningModel> _modelRedo = [];

  @override
  DesignSession build() {
    ref.onDispose(() => _autosaveTimer?.cancel());
    return const DesignSession();
  }

  bool get canUndoModel => _modelUndo.isNotEmpty;
  bool get canRedoModel => _modelRedo.isNotEmpty;

  void open(DesignDocument document) {
    _modelUndo.clear();
    _modelRedo.clear();
    state = DesignSession(document: document);
  }

  void close() {
    _autosaveTimer?.cancel();
    _modelUndo.clear();
    _modelRedo.clear();
    state = const DesignSession();
  }

  void rename(String name) {
    final document = state.document;
    if (document == null) return;
    _touch(document.copyWith(name: name));
  }

  void updateSketch(Sketch sketch) {
    final document = state.document;
    if (document == null) return;
    _touch(document.copyWith(sketch: sketch));
  }

  /// Runs the whole understanding pipeline over the current ink.
  Future<InterpretationResult?> interpret() async {
    final document = state.document;
    if (document == null) return null;
    state = state.copyWith(isInterpreting: true, clearError: true);
    try {
      final result = await ref.read(interpretationServiceProvider).interpret(
            sketch: document.sketch,
            kind: document.kind,
            calibration: document.calibration,
            carryOver: document.model,
            modelId: document.id,
          );
      _modelUndo.clear();
      _modelRedo.clear();
      state = state.copyWith(
        document: document.copyWith(
          model: result.model,
          calibration: result.calibration,
        ),
        interpretation: result,
        isInterpreting: false,
        isDirty: true,
      );
      _scheduleAutosave();
      return result;
    } on AppException catch (error) {
      state = state.copyWith(isInterpreting: false, error: error.message);
      return null;
    } catch (error) {
      state = state.copyWith(
        isInterpreting: false,
        error: 'The drawing could not be interpreted: $error',
      );
      return null;
    }
  }

  /// Applies one answer from the interpretation screen. Nothing is applied
  /// until the user picks (§29).
  void applyChoice(InterpretationChoice choice) {
    final document = state.document;
    if (document == null) return;
    final payload = choice.payload;
    var model = document.model;

    switch (payload['kind']) {
      case 'width':
        model = RegionEditor.setOverallSize(
          model,
          widthMm: (payload['valueMm'] as num?)?.toDouble(),
        );
      case 'height':
        model = RegionEditor.setOverallSize(
          model,
          heightMm: (payload['valueMm'] as num?)?.toDouble(),
        );
      case 'operation':
        final cellId = payload['cellId'] as String?;
        final name = payload['operation'] as String?;
        if (cellId == null || name == null) return;
        final operation = CellOperation.values.firstWhere(
          (o) => o.name == name,
          orElse: () => CellOperation.fixed,
        );
        model = RegionEditor.setOperation(model, cellId, operation);
      default:
        return;
    }
    updateModel(model, resolvedItemId: _itemIdFor(payload));
  }

  String? _itemIdFor(Map<String, Object?> payload) => switch (payload['kind']) {
        'width' => 'width',
        'height' => 'height',
        'operation' => 'cell.${payload['cellId']}',
        _ => null,
      };

  /// Replaces the model, keeping model-level undo history.
  ///
  /// [recordHistory] is false while a boundary is being dragged, so the whole
  /// drag is a single undo step instead of one per pointer move.
  void updateModel(
    OpeningModel model, {
    String? resolvedItemId,
    bool recordHistory = true,
  }) {
    final document = state.document;
    if (document == null) return;
    if (recordHistory) {
      _modelUndo.add(document.model);
      if (_modelUndo.length > AppConstants.maxUndoSteps) _modelUndo.removeAt(0);
      _modelRedo.clear();
    }

    final interpretation = resolvedItemId == null
        ? state.interpretation
        : _markResolved(state.interpretation, resolvedItemId);

    state = state.copyWith(
      document: document.copyWith(model: model),
      interpretation: interpretation,
      isDirty: true,
    );
    _scheduleAutosave();
  }

  void undoModel() {
    final document = state.document;
    if (document == null || _modelUndo.isEmpty) return;
    _modelRedo.add(document.model);
    final previous = _modelUndo.removeLast();
    state = state.copyWith(document: document.copyWith(model: previous), isDirty: true);
    _scheduleAutosave();
  }

  void redoModel() {
    final document = state.document;
    if (document == null || _modelRedo.isEmpty) return;
    _modelUndo.add(document.model);
    final next = _modelRedo.removeLast();
    state = state.copyWith(document: document.copyWith(model: next), isDirty: true);
    _scheduleAutosave();
  }

  InterpretationResult? _markResolved(InterpretationResult? result, String itemId) {
    if (result == null) return null;
    final items = result.report.items
        .map((item) => item.id == itemId
            ? InterpretationItem(
                id: item.id,
                level: InterpretationLevel.recognised,
                title: item.title,
                detail: 'Confirmed by you.',
              )
            : item)
        .toList();
    return InterpretationResult(
      primitives: result.primitives,
      structure: result.structure,
      dimensions: result.dimensions,
      model: result.model,
      report: InterpretationReport(items: items, confidence: result.report.confidence),
    );
  }

  void selectRegion(String? id) =>
      state = id == null
          ? state.copyWith(clearSelection: true)
          : state.copyWith(selectedRegionId: id);

  /// Marks the start of a drag so everything that follows folds into one undo
  /// step, and the drag can be abandoned cleanly.
  void beginInteraction() => _dragging = true;

  void endInteraction() => _dragging = false;

  bool _dragging = false;
  bool get isDragging => _dragging;

  void setRenderStyle(RenderStyle style) => state = state.copyWith(renderStyle: style);

  void toggleDimensions() =>
      state = state.copyWith(showDimensions: !state.showDimensions);

  void toggleAutoRotate() => state = state.copyWith(autoRotate: !state.autoRotate);

  void clearError() => state = state.copyWith(clearError: true);

  // -- persistence ----------------------------------------------------------

  void _touch(DesignDocument document) {
    state = state.copyWith(document: document, isDirty: true);
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1200), saveDraft);
  }

  Future<void> saveDraft() async {
    final document = state.document;
    if (document == null) return;
    await ref.read(designRepositoryProvider).saveDraft(document);
  }

  /// Saves the design and records a restore point.
  Future<void> save({String versionLabel = 'Saved'}) async {
    final document = state.document;
    if (document == null) return;
    _autosaveTimer?.cancel();
    final snapshot = document.withVersionSnapshot(versionLabel);
    await ref.read(designLibraryProvider.notifier).save(snapshot);
    await ref.read(designRepositoryProvider).clearDraft();
    state = state.copyWith(document: snapshot, isDirty: false);
  }

  void restoreVersion(String versionId) {
    final document = state.document;
    if (document == null) return;
    final restored = document.restoreVersion(versionId);
    _modelUndo.clear();
    _modelRedo.clear();
    state = state.copyWith(document: restored, isDirty: true, clearInterpretation: true);
    _scheduleAutosave();
  }
}

final designSessionProvider =
    NotifierProvider<DesignSessionNotifier, DesignSession>(DesignSessionNotifier.new);

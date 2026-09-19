import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/scale.dart';
import '../../domain/editing/design_edits.dart';
import '../../domain/geometry/tolerances.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../../domain/model/materials.dart';
import '../../domain/model/question.dart';
import '../../domain/recognition/interpreter.dart';
import '../../domain/recognition/opening_symbol.dart';
import '../../domain/sections/section_builder.dart';
import '../../domain/sketch/stroke.dart';
import '../../domain/solid/camera.dart';
import '../../domain/solid/mesh.dart';
import '../../infrastructure/design_store.dart';
import '../canvas/cad_layers.dart';
import '../viewer/display_style.dart';
import 'tools.dart';

/// Everything on screen at once.
@immutable
class WorkspaceState {
  final Design design;
  final Tool tool;
  final WorkspaceView view;

  /// The id of the part the user has picked, if any.
  final String? selectedId;

  /// Questions the reading could not answer. Shown to the user; never
  /// answered by the application.
  final List<DesignQuestion> questions;

  /// Questions this design has already had put to it and settled — answered
  /// or waved away. They do not come back at the next reading: being asked
  /// the same thing twice is being asked to say twice what was said once.
  final Set<String> settledQuestions;

  /// True while the drawing has changes the geometry has not caught up with.
  final bool needsReading;

  /// Whether the user's own ink is shown over the geometry.
  final bool showSketch;

  final Camera camera;

  /// How far the openings are swung in the model view, 0 to 1.
  final double openFraction;

  /// The colour the pen draws in.
  final int penColour;

  /// What the technical drawing is showing. A way of looking at the design,
  /// never a change to it.
  final CadLayers layers;

  /// How the model is drawn. Also only a way of looking at it.
  final DisplayStyle displayStyle;
  final bool groundPlane;

  /// Strokes the user has said are lines to build rather than opening marks.
  /// Their answer is kept, so the same mark is never asked about twice.
  final Set<String> notSymbols;

  const WorkspaceState({
    required this.design,
    this.tool = Tool.pen,
    this.view = WorkspaceView.draw,
    this.selectedId,
    this.questions = const [],
    this.needsReading = false,
    this.showSketch = true,
    this.camera = const Camera(),
    this.openFraction = 0,
    this.penColour = 0xFF013E37,
    this.layers = const CadLayers(),
    this.displayStyle = DisplayStyle.shadedWithEdges,
    this.groundPlane = true,
    this.notSymbols = const {},
    this.settledQuestions = const {},
  });

  DesignElement? get selected =>
      selectedId == null ? null : design.elementById(selectedId!);

  WorkspaceState copyWith({
    Design? design,
    Tool? tool,
    WorkspaceView? view,
    String? selectedId,
    bool clearSelection = false,
    List<DesignQuestion>? questions,
    bool? needsReading,
    bool? showSketch,
    Camera? camera,
    double? openFraction,
    int? penColour,
    CadLayers? layers,
    DisplayStyle? displayStyle,
    bool? groundPlane,
    Set<String>? notSymbols,
    Set<String>? settledQuestions,
  }) =>
      WorkspaceState(
        design: design ?? this.design,
        tool: tool ?? this.tool,
        view: view ?? this.view,
        selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
        questions: questions ?? this.questions,
        needsReading: needsReading ?? this.needsReading,
        showSketch: showSketch ?? this.showSketch,
        camera: camera ?? this.camera,
        openFraction: openFraction ?? this.openFraction,
        penColour: penColour ?? this.penColour,
        layers: layers ?? this.layers,
        displayStyle: displayStyle ?? this.displayStyle,
        groundPlane: groundPlane ?? this.groundPlane,
        notSymbols: notSymbols ?? this.notSymbols,
        settledQuestions: settledQuestions ?? this.settledQuestions,
      );
}

/// The workspace: the design, what is being done to it, and the way back.
class WorkspaceController extends Notifier<WorkspaceState> {
  final _undo = <Design>[];
  final _redo = <Design>[];

  /// Set while a drag is in progress, so a hundred little moves become one
  /// step on the way back rather than a hundred.
  Object? _gesture;

  int _ids = 0;

  @override
  WorkspaceState build() => WorkspaceState(
        design: Design.empty(id: _newId('design'), kind: DesignKind.window),
      );

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_ids++}';

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void startDesign(DesignKind kind) {
    _undo.clear();
    _redo.clear();
    state = WorkspaceState(
      design: Design.empty(id: _newId('design'), kind: kind),
    );
  }

  void openDesign(Design design) {
    _undo.clear();
    _redo.clear();
    state = WorkspaceState(design: design, view: WorkspaceView.draw);
  }

  // ---------------------------------------------------------------- history

  void _remember({Object? coalesce}) {
    // Compared by value, not by identity: the keys are built by
    // interpolation, so two calls within one drag produce equal strings that
    // are not the same object, and comparing by identity would record every
    // step of the drag separately.
    if (coalesce != null && coalesce == _gesture) return;
    _gesture = coalesce;
    _undo.add(state.design);
    if (_undo.length > 120) _undo.removeAt(0);
    _redo.clear();
  }

  /// Call when a drag finishes, so the next one is a separate step.
  void endGesture() => _gesture = null;

  void undo() {
    if (_undo.isEmpty) return;
    _gesture = null;
    _redo.add(state.design);
    state = state.copyWith(design: _undo.removeLast(), clearSelection: true);
  }

  void redo() {
    if (_redo.isEmpty) return;
    _gesture = null;
    _undo.add(state.design);
    state = state.copyWith(design: _redo.removeLast(), clearSelection: true);
  }

  // ------------------------------------------------------------------ tools

  void useTool(Tool tool) => state = state.copyWith(
        tool: tool,
        clearSelection: tool != Tool.select,
      );

  void showView(WorkspaceView view) => state = state.copyWith(view: view);

  void toggleSketch() =>
      state = state.copyWith(showSketch: !state.showSketch);

  void setPenColour(int colour) => state = state.copyWith(penColour: colour);

  void setLayers(CadLayers layers) => state = state.copyWith(layers: layers);

  /// Swings the view round the model.
  void orbit(double byYaw, double byPitch) => state = state.copyWith(
        camera: state.camera.orbited(byYaw, byPitch),
      );

  /// Slides the view across the model, in millimetres of model.
  void panCamera(double acrossMm, double downMm) => state = state.copyWith(
        camera: state.camera.pannedBy(acrossMm, downMm),
      );

  void zoomCamera(double factor) => state = state.copyWith(
        camera: state.camera.zoomedBy(factor),
      );

  /// Looks at the model from one of the named views, keeping the zoom and
  /// the pan so it reads as walking round it rather than starting again.
  void lookFrom(Camera view, {double? zoom}) => state = state.copyWith(
        camera: state.camera.lookingFrom(view).copyWith(zoom: zoom),
      );

  /// Frames the whole model from where it is being looked at now.
  void zoomToFit(double zoom) => state = state.copyWith(
        camera: state.camera.copyWith(zoom: zoom, target: Vec3.zero),
      );

  void setProjection(Projection projection) => state = state.copyWith(
        camera: state.camera.copyWith(projection: projection),
      );

  /// Back to the whole model, centred.
  void zoomExtents() => state = state.copyWith(camera: state.camera.reset());

  void setDisplayStyle(DisplayStyle style) =>
      state = state.copyWith(displayStyle: style);

  void setGroundPlane(bool on) => state = state.copyWith(groundPlane: on);

  void setOpenFraction(double value) =>
      state = state.copyWith(openFraction: value.clamp(0.0, 1.0));

  // ----------------------------------------------------------------- ink

  /// Lays down a stroke exactly as it was made.
  void addStroke(List<StrokeSample> samples, {required Tool tool}) {
    if (samples.length < 2) return;
    _remember();
    _gesture = null;
    final stroke = Stroke(
      id: _newId('stroke'),
      samples: samples,
      tool: _toolKind(tool),
      colour: state.penColour,
    );
    state = state.copyWith(
      design: state.design.copyWith(
        sketch: state.design.sketch.add(stroke),
      ),
      needsReading: tool.structural,
    );

    // Annotation is not structure: it is added as itself, straight away.
    switch (tool) {
      case Tool.dimension:
        _addDimension(stroke);
      case Tool.arrow:
        _addArrow(stroke);
      default:
        break;
    }
  }

  StrokeTool _toolKind(Tool tool) => switch (tool) {
        Tool.line => StrokeTool.line,
        Tool.rectangle => StrokeTool.rectangle,
        Tool.polyline => StrokeTool.polyline,
        Tool.dimension => StrokeTool.dimension,
        Tool.arrow => StrokeTool.arrow,
        _ => StrokeTool.pen,
      };

  void _addDimension(Stroke stroke) {
    state = state.copyWith(
      design: state.design.copyWith(dimensions: [
        ...state.design.dimensions,
        DimensionElement(
          id: _newId('dim'),
          a: stroke.start,
          b: stroke.end,
          offsetMm: 0,
          fromStrokeId: stroke.id,
        ),
      ]),
    );
  }

  void _addArrow(Stroke stroke) {
    state = state.copyWith(
      design: state.design.copyWith(arrows: [
        ...state.design.arrows,
        ArrowElement(
          id: _newId('arrow'),
          from: stroke.start,
          to: stroke.end,
          colour: state.penColour,
          fromStrokeId: stroke.id,
        ),
      ]),
    );
  }

  /// A figure measuring two points the user dragged between.
  ///
  /// A dimension describes the design rather than building it, so it has no
  /// parent and is carried by nothing — the same as one drawn on the sheet.
  void addDimension(Vec2 a, Vec2 b) {
    if (a.distanceTo(b) < Tol.minLineMm) return;
    _remember();
    state = state.copyWith(
      design: state.design.copyWith(dimensions: [
        ...state.design.dimensions,
        DimensionElement(id: _newId('dimension'), a: a, b: b),
      ]),
    );
  }

  /// An arrow, from its tail to its point.
  void addArrow(Vec2 from, Vec2 to) {
    if (from.distanceTo(to) < Tol.minLineMm) return;
    _remember();
    state = state.copyWith(
      design: state.design.copyWith(arrows: [
        ...state.design.arrows,
        ArrowElement(
          id: _newId('arrow'),
          from: from,
          to: to,
          colour: state.penColour,
        ),
      ]),
    );
  }

  void addNote(String text, Vec2 at) {
    if (text.trim().isEmpty) return;
    _remember();
    final size = (state.design.heightMm * 0.045).clamp(40.0, 200.0);
    state = state.copyWith(
      design: state.design.copyWith(texts: [
        ...state.design.texts,
        TextElement(
          id: _newId('note'),
          text: text.trim(),
          at: at,
          sizeMm: size,
          colour: state.penColour,
        ),
      ]),
    );
  }

  /// Rubs out one of the user's own marks, and anything read from it.
  void eraseStroke(String strokeId) {
    _remember();
    var design = state.design.copyWith(
      sketch: state.design.sketch.erase(strokeId),
      dividers: [
        for (final d in state.design.dividers)
          if (d.fromStrokeId != strokeId) d,
      ],
      dimensions: [
        for (final d in state.design.dimensions)
          if (d.fromStrokeId != strokeId) d,
      ],
      arrows: [
        for (final a in state.design.arrows)
          if (a.fromStrokeId != strokeId) a,
      ],
    );
    if (design.frame?.fromStrokeId == strokeId) {
      design = design.copyWith(clearFrame: true, sections: const []);
    }
    design = SectionBuilder.rebuild(design);
    state = state.copyWith(design: design, needsReading: true);
  }

  // ----------------------------------------------------------- the reading

  /// Reads the drawing as geometry.
  ///
  /// This is where cleaning happens and where it stops. Anything the reading
  /// is unsure about comes back as a question for the user.
  void readDrawing() {
    _remember();
    final result = SketchInterpreter.interpret(
      state.design,
      notSymbols: state.notSymbols,
    );
    state = state.copyWith(
      design: result.design,
      questions: [
        for (final question in result.questions)
          if (!state.settledQuestions.contains(question.id)) question,
      ],
      needsReading: false,
      view: result.design.frame == null
          ? WorkspaceView.draw
          : WorkspaceView.plan,
    );
  }

  void answer(String questionId, String optionKey) {
    final question = state.questions.firstWhere(
      (q) => q.id == questionId,
      orElse: () => const DesignQuestion(id: '', prompt: '', options: []),
    );
    if (question.id.isEmpty) return;

    if (questionId.startsWith('symbol-')) {
      _answerSymbol(questionId.substring('symbol-'.length), optionKey);
    } else if (questionId.startsWith('opening-')) {
      final sectionId = questionId.substring('opening-'.length);
      if (optionKey != 'keep-line') {
        final mechanism = OpeningMechanism.values.firstWhere(
          (m) => m.name == optionKey,
          orElse: () => OpeningMechanism.fixed,
        );
        _remember();
        state = state.copyWith(
          design: DesignEdits.setOpening(
            state.design,
            sectionId,
            openingId: _newId('opening'),
            mechanism: mechanism,
          ),
        );
      }
    }

    state = state.copyWith(
      questions: [for (final q in state.questions) if (q.id != questionId) q],
      settledQuestions: {...state.settledQuestions, questionId},
    );
  }

  /// Which section the user says a `<` or `>` belongs to.
  ///
  /// The mark is theirs and so is the answer: the section they name opens,
  /// and no other. Saying it is not a mark puts the strokes back as lines,
  /// exactly where they were drawn, and the answer is remembered so the
  /// question is not asked again.
  void _answerSymbol(String strokeId, String optionKey) {
    if (optionKey == 'not-a-symbol') {
      _remember();
      final notSymbols = {...state.notSymbols, strokeId};
      final result = SketchInterpreter.interpret(
        state.design,
        notSymbols: notSymbols,
      );
      state = state.copyWith(
        design: result.design,
        notSymbols: notSymbols,
        questions: result.questions,
      );
      return;
    }

    final stroke = state.design.sketch.byId(strokeId);
    final symbol = stroke == null ? null : OpeningSymbolReader.read(stroke);
    if (symbol == null) return;
    if (state.design.sectionById(optionKey) == null) return;

    _remember();
    state = state.copyWith(
      design: DesignEdits.setOpening(
        state.design,
        optionKey,
        openingId: _newId('opening'),
        mechanism: symbol.mechanism,
        markAt: symbol.centre,
        markGlyph: symbol.glyph,
        fromStrokeId: strokeId,
      ),
    );
  }

  /// A diagonal the user says was an opening symbol, not a bar.
  ///
  /// The line comes out and the panel it was drawn across becomes one leaf.
  /// This is the one place a line the user drew is removed by an answer, and
  /// it only happens because they said the line was never meant to be built.
  /// Turns a line the user drew into the opening it was standing for.
  ///
  /// A diagonal across a pane is how an opening is marked on an elevation,
  /// but the same line is also a glazing bar somebody wants built. The
  /// reading builds it as a bar, because that is what a line is, and this is
  /// the one-tap way to say it meant the other thing. It is an edit, offered
  /// on the bar's own panel, rather than a question asked at reading time:
  /// the drawing is turned into geometry either way, and the user changes
  /// what they want changed.
  void openSectionOfBar(String dividerId, OpeningMechanism mechanism) {
    if (mechanism == OpeningMechanism.fixed) return;

    DividerElement? divider;
    for (final candidate in state.design.dividers) {
      if (candidate.id == dividerId) divider = candidate;
    }
    if (divider == null) return;

    _remember();
    final at = divider.segment.midpoint;
    var design = DesignEdits.delete(state.design, dividerId);
    final section = SectionBuilder.sectionAt(design, at);
    if (section != null) {
      design = DesignEdits.setOpening(
        design,
        section.id,
        openingId: _newId('opening'),
        mechanism: mechanism,
      );
    }
    state = state.copyWith(design: design, clearSelection: true);
  }

  void dismissQuestion(String questionId) => state = state.copyWith(
        questions: [
          for (final q in state.questions) if (q.id != questionId) q,
        ],
        settledQuestions: {...state.settledQuestions, questionId},
      );

  // -------------------------------------------------------------- editing

  void select(String? elementId) => state = elementId == null
      ? state.copyWith(clearSelection: true)
      : state.copyWith(selectedId: elementId);

  void selectAt(Vec2 point, {required double slopMm}) {
    final hit = DesignEdits.hitTest(state.design, point, slopMm: slopMm);
    select(hit?.id);
  }

  void dragSelected(Vec2 by) {
    final id = state.selectedId;
    if (id == null) return;
    _remember(coalesce: 'drag-$id');
    state = state.copyWith(design: DesignEdits.dragElement(state.design, id, by));
  }

  /// Moves a bar so that its middle lands on [to].
  void moveDividerTo(String dividerId, Vec2 to) {
    for (final divider in state.design.dividers) {
      if (divider.id != dividerId) continue;
      _remember(coalesce: 'grip-$dividerId');
      state = state.copyWith(
        design: DesignEdits.moveDivider(
          state.design,
          dividerId,
          to - divider.segment.midpoint,
        ),
      );
      return;
    }
  }

  void moveDividerEnd(
    String dividerId, {
    required bool startEnd,
    required Vec2 to,
  }) {
    _remember(coalesce: 'grip-end-$dividerId-$startEnd');
    state = state.copyWith(
      design: DesignEdits.moveDividerEnd(
        state.design,
        dividerId,
        startEnd: startEnd,
        to: to,
      ),
    );
  }

  /// Moves one side of the frame, leaving everything inside it where it is.
  void moveFrameEdge(FrameEdge edge, double toMm) {
    _remember(coalesce: 'frame-edge-$edge');
    state = state.copyWith(
      design: DesignEdits.moveFrameEdge(state.design, edge, toMm),
    );
  }

  /// Moves one side of the frame square to itself, by a distance.
  void moveFrameMember(int index, double byMm) {
    _remember(coalesce: 'frame-member-$index');
    state = state.copyWith(
      design: DesignEdits.moveFrameMember(state.design, index, byMm),
    );
  }

  /// Moves a bar square to itself, so its centre line lands on [to].
  void moveDividerAcross(String dividerId, Vec2 to) {
    _remember(coalesce: 'boundary-$dividerId');
    state = state.copyWith(
      design: DesignEdits.moveDividerAcross(state.design, dividerId, to),
    );
  }

  /// Drags any element by a distance, without needing it selected first.
  void dragElement(String elementId, Vec2 by) {
    _remember(coalesce: 'drag-$elementId');
    state = state.copyWith(
      design: DesignEdits.dragElement(state.design, elementId, by),
    );
  }

  void moveDimensionEnd(
    String dimensionId, {
    required Vec2 to,
    required bool startEnd,
  }) {
    _remember(coalesce: 'dim-end-$dimensionId-$startEnd');
    state = state.copyWith(
      design: DesignEdits.moveDimensionEnd(
        state.design,
        dimensionId,
        to,
        startEnd: startEnd,
      ),
    );
  }

  void setDimensionOffset(String dimensionId, Vec2 to) {
    _remember(coalesce: 'dim-offset-$dimensionId');
    state = state.copyWith(
      design: DesignEdits.setDimensionOffset(state.design, dimensionId, to),
    );
  }

  void moveArrowEnd(
    String arrowId, {
    required Vec2 to,
    required bool startEnd,
  }) {
    for (final arrow in state.design.arrows) {
      if (arrow.id != arrowId) continue;
      _remember(coalesce: 'arrow-end-$arrowId-$startEnd');
      state = state.copyWith(
        design: state.design.withElement(
          startEnd ? arrow.copyWith(from: to) : arrow.copyWith(to: to),
        ),
      );
      return;
    }
  }

  void deleteSelected() {
    final id = state.selectedId;
    if (id == null) return;
    _remember();
    state = state.copyWith(
      design: DesignEdits.delete(state.design, id),
      clearSelection: true,
    );
  }

  void setFinish(String elementId, Finish finish) {
    final element = state.design.elementById(elementId);
    if (element == null) return;
    _remember(coalesce: 'finish-$elementId');
    final updated = switch (element) {
      FrameElement() => element.copyWith(finish: finish),
      DividerElement() => element.copyWith(finish: finish),
      SectionElement() => element.copyWith(finish: finish),
      HardwareElement() => element.copyWith(finish: finish),
      _ => null,
    };
    if (updated == null) return;
    state = state.copyWith(design: state.design.withElement(updated));
  }

  void setSectionWidth(String sectionId, double widthMm) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setSectionWidth(state.design, sectionId, widthMm),
    );
  }

  void setSectionHeight(String sectionId, double heightMm) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setSectionHeight(state.design, sectionId, heightMm),
    );
  }

  void resizeFrame({double? widthMm, double? heightMm}) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.resizeFrame(
        state.design,
        widthMm: widthMm,
        heightMm: heightMm,
      ),
    );
  }

  void setProfile(double profileMm) {
    final frame = state.design.frame;
    if (frame == null || profileMm <= 0) return;
    _remember(coalesce: 'profile');
    state = state.copyWith(
      design: SectionBuilder.rebuild(
        state.design.withElement(frame.copyWith(profileMm: profileMm)),
      ),
    );
  }

  /// Makes a bar a given length, about its own middle.
  void setDividerLength(String dividerId, double lengthMm) {
    final design =
        DesignEdits.setDividerLength(state.design, dividerId, lengthMm);
    if (identical(design, state.design)) return;
    _remember(coalesce: 'length-$dividerId');
    state = state.copyWith(design: design);
  }

  /// Turns a bar to a given heading, about its own middle.
  void setDividerAngle(String dividerId, double degrees) {
    final design =
        DesignEdits.setDividerAngle(state.design, dividerId, degrees);
    if (identical(design, state.design)) return;
    _remember(coalesce: 'angle-$dividerId');
    state = state.copyWith(design: design);
  }

  void setBarWidth(String dividerId, double widthMm) {
    for (final divider in state.design.dividers) {
      if (divider.id != dividerId) continue;
      _remember(coalesce: 'bar-$dividerId');
      state = state.copyWith(
        design: SectionBuilder.rebuild(
          state.design.withElement(divider.copyWith(widthMm: widthMm)),
        ),
      );
      return;
    }
  }

  void setDepth(double depthMm) {
    if (depthMm <= 0) return;
    _remember(coalesce: 'depth');
    state = state.copyWith(design: state.design.copyWith(depthMm: depthMm));
  }

  /// Sets by hand what a section does.
  ///
  /// Where the section was opened by a `<` or `>`, turning it back to fixed
  /// is the user overruling their own mark. The mark is remembered as not
  /// being one, or reading the drawing again would put the opening straight
  /// back and their decision would not stick.
  void setOpening(String sectionId, OpeningMechanism mechanism,
      {OpeningDirection direction = OpeningDirection.inward}) {
    _remember();
    final existing = state.design.openingOf(sectionId);
    final markStroke = existing?.fromStrokeId;

    var next = state.copyWith(
      design: DesignEdits.setOpening(
        state.design,
        sectionId,
        openingId: _newId('opening'),
        mechanism: mechanism,
        direction: direction,
        markAt: mechanism == OpeningMechanism.fixed ? null : existing?.markAt,
        markGlyph:
            mechanism == OpeningMechanism.fixed ? null : existing?.markGlyph,
        fromStrokeId: mechanism == OpeningMechanism.fixed ? null : markStroke,
      ),
    );
    if (mechanism == OpeningMechanism.fixed && markStroke != null) {
      next = next.copyWith(notSymbols: {...state.notSymbols, markStroke});
    }
    state = next;
  }

  /// Puts a bar inside a section, or back among the main divisions.
  void setDividerParent(String dividerId, String? sectionId) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setDividerParent(
        state.design,
        dividerId,
        sectionId,
      ),
    );
  }

  /// Changes what a selected opening does.
  void setOpeningMechanism(String openingId, OpeningMechanism mechanism) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setOpeningMechanism(
        state.design,
        openingId,
        mechanism,
      ),
      clearSelection: mechanism == OpeningMechanism.fixed,
    );
  }

  void setOpeningSwing(String openingId, OpeningDirection direction) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setOpeningSwing(state.design, openingId, direction),
    );
  }

  /// Draws a line inside a section, as that section's own.
  ///
  /// This is what the line tools inside an opening do. The bar belongs to
  /// the opening from the moment it is made, so drawing in an opening
  /// divides the opening rather than ending it, and the new bar is selected
  /// so it can be moved or given a size straight away.
  void addLineInside(
    String sectionId,
    Vec2 at, {
    required bool horizontal,
  }) {
    final id = _newId('divider');
    _remember();
    final design = DesignEdits.addLineInside(
      state.design,
      sectionId,
      id: id,
      at: at,
      horizontal: horizontal,
    );
    if (identical(design, state.design)) return;
    state = state.copyWith(design: design, selectedId: id);
  }

  /// Draws a shape inside a section, as that section's own.
  ///
  /// A straight line at an angle, a rectangle or a polyline, all the same
  /// operation: the bars that enclose what the user drew, every one of them
  /// the section's from the moment it exists. Nothing is asked afterwards —
  /// the opening they are drawing in is what says where the geometry goes.
  void addShapeInside(
    String sectionId,
    List<Vec2> corners, {
    bool closed = false,
  }) {
    if (corners.length < 2) return;
    final prefix = _newId('shape');
    _remember();
    final design = DesignEdits.addShapeInside(
      state.design,
      sectionId,
      idPrefix: prefix,
      corners: corners,
      closed: closed,
    );
    if (identical(design, state.design)) return;
    final made = [
      for (final bar in design.dividers)
        if (bar.id.startsWith('\$prefix-')) bar.id,
    ];
    state = state.copyWith(
      design: design,
      selectedId: made.isEmpty ? state.selectedId : made.first,
    );
  }

  /// Moves a bar inside an opening to a place measured from the opening's
  /// own corner, rather than from the sheet's.
  void moveDividerWithin(String dividerId, double alongMm) {
    _remember(coalesce: 'within-$dividerId');
    state = state.copyWith(
      design: DesignEdits.moveDividerWithin(state.design, dividerId, alongMm),
    );
  }

  /// Changes an opening's ironmongery: how many hinges, where they sit, and
  /// where the handle is. Only what is named changes.
  void setOpeningHardware(
    String openingId, {
    int? hingeCount,
    double? hingeFromStartMm,
    double? hingeFromEndMm,
    double? handleAlongMm,
  }) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.setOpeningHardware(
        state.design,
        openingId,
        hingeCount: hingeCount,
        hingeFromStartMm: hingeFromStartMm,
        hingeFromEndMm: hingeFromEndMm,
        handleAlongMm: handleAlongMm,
      ),
    );
  }

  /// Puts the opening on a different section.
  void moveOpeningToSection(String openingId, String sectionId) {
    _remember();
    state = state.copyWith(
      design: DesignEdits.moveOpeningToSection(
        state.design,
        openingId,
        sectionId,
      ),
    );
  }

  void addHardware(HardwareKind kind, Vec2 at) {
    _remember();
    state = state.copyWith(
      design: state.design.copyWith(hardware: [
        ...state.design.hardware,
        HardwareElement(id: _newId('hw'), kind: kind, at: at),
      ]),
    );
  }

  void setDimensionValue(String dimensionId, double valueMm) {
    for (final dimension in state.design.dimensions) {
      if (dimension.id != dimensionId) continue;
      _remember();
      state = state.copyWith(
        design: DesignScale.toDimension(state.design, dimension, valueMm),
      );
      return;
    }
  }

  /// Puts the whole design into real millimetres from one overall width.
  void setRealWidth(double widthMm) {
    if (widthMm <= 0) return;
    _remember();
    state = state.copyWith(design: DesignScale.toWidth(state.design, widthMm));
  }

  void setRealHeight(double heightMm) {
    if (heightMm <= 0) return;
    _remember();
    state =
        state.copyWith(design: DesignScale.toHeight(state.design, heightMm));
  }

  void rename(String name) =>
      state = state.copyWith(design: state.design.copyWith(name: name));

  /// Keeps the design, sketch and all.
  Future<void> save() async {
    await ref.read(designStoreProvider).save(state.design);
    ref.invalidate(savedDesignsProvider);
  }
}

final designStoreProvider = Provider<DesignStore>((ref) => DesignStore());

final savedDesignsProvider = FutureProvider<List<Design>>(
  (ref) => ref.watch(designStoreProvider).all(),
);

final workspaceProvider =
    NotifierProvider<WorkspaceController, WorkspaceState>(
  WorkspaceController.new,
);

import '../../shared/models/geometry_structure.dart';
import '../../shared/models/interpretation.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../../shared/models/primitives.dart';
import '../../shared/models/scale_calibration.dart';
import '../../shared/models/sketch.dart';
import '../dimensions/dimension_resolver.dart';
import '../geometry/geometry_builder.dart';
import 'handwriting_recognizer.dart';
import 'stroke_recognizer.dart';
import 'structure_interpreter.dart';

/// Everything the app learned from one sketch.
class InterpretationResult {
  final List<SketchPrimitive> primitives;
  final GeometryStructure structure;
  final DimensionResolution dimensions;
  final OpeningModel model;
  final InterpretationReport report;

  const InterpretationResult({
    required this.primitives,
    required this.structure,
    required this.dimensions,
    required this.model,
    required this.report,
  });

  ScaleCalibration get calibration => dimensions.calibration;
}

/// Runs the whole understanding stage in one place:
/// ink → primitives → structure → dimensions → parametric model → read-back.
///
/// Nothing here touches pixels of the 3D model; it produces the structured
/// description that everything downstream is generated from (§51).
class InterpretationService {
  final StrokeRecognizer strokeRecognizer;
  final StructureInterpreter structureInterpreter;
  final DimensionResolver dimensionResolver;
  final GeometryBuilder geometryBuilder;
  final HandwritingRecognizer handwritingRecognizer;

  const InterpretationService({
    this.strokeRecognizer = const StrokeRecognizer(),
    this.structureInterpreter = const StructureInterpreter(),
    this.dimensionResolver = const DimensionResolver(),
    this.geometryBuilder = const GeometryBuilder(),
    this.handwritingRecognizer = const TypedValueRecognizer(),
  });

  Future<InterpretationResult> interpret({
    required Sketch sketch,
    required OpeningKind kind,
    ScaleCalibration? calibration,
    OpeningModel? carryOver,
    String modelId = 'model',
    bool useDrawingExtent = false,
  }) async {
    final primitives = strokeRecognizer.recognizeAll(sketch);

    // Ink annotations are read through the recogniser interface so a real OCR
    // implementation can be swapped in without changing this flow.
    final transcriptions = await handwritingRecognizer.transcribe(
      sketch.strokes.where((s) => s.tool == SketchTool.note).toList(),
    );

    final structure = structureInterpreter.interpret(
      primitives,
      kind: kind,
      useDrawingExtent: useDrawingExtent,
    );

    final dimensions = dimensionResolver.resolve(
      structure: structure,
      dimensions: primitives.whereType<DimensionPrimitive>().toList(),
      existing: calibration,
    );

    final model = geometryBuilder.build(
      structure: structure,
      dimensions: dimensions,
      kind: kind,
      id: modelId,
      material: carryOver?.material ?? FrameMaterial.aluminium,
      finish: carryOver?.finish ?? FrameFinish.naturalAnodised,
      glass: carryOver?.leafRegions.firstOrNull?.glass ?? GlassType.clearDouble,
    );

    final report = buildReport(
      structure: structure,
      dimensions: dimensions,
      model: model,
      primitives: primitives,
      transcriptions: transcriptions,
    );

    return InterpretationResult(
      primitives: primitives,
      structure: structure,
      dimensions: dimensions,
      model: model,
      report: report,
    );
  }

  /// Builds the "Understanding your design" read-back. Confident readings are
  /// listed as done; anything below the confidence bar becomes a question with
  /// concrete options (§16).
  InterpretationReport buildReport({
    required GeometryStructure structure,
    required DimensionResolution dimensions,
    required OpeningModel model,
    required List<SketchPrimitive> primitives,
    List<InkTranscription> transcriptions = const [],
  }) {
    final items = <InterpretationItem>[];
    final confidences = <double>[];

    items.add(InterpretationItem(
      id: 'outline',
      level: structure.outlineFromExtent
          ? InterpretationLevel.uncertain
          : InterpretationLevel.recognised,
      title: structure.outlineFromExtent
          ? 'Outline assumed from the extent of your drawing'
          : '${model.kind.label} outline found',
      detail: structure.outlineFromExtent
          ? 'You did not draw a closed outside shape, so the overall extent of '
              'what you drew was used as the frame. Check the size, or go back '
              'and draw the outline.'
          : '${structure.rows.length} horizontal '
          '${structure.rows.length == 1 ? 'band' : 'bands'}, '
          '${structure.cellCount} ${structure.cellCount == 1 ? 'section' : 'sections'}, '
          '${structure.mullionCount} vertical '
          '${structure.mullionCount == 1 ? 'division' : 'divisions'}.',
    ));
    confidences.add(structure.outlineFromExtent ? 0.4 : 1);

    // Size.
    for (final entry in <(String, String, ResolvedDimension, bool)>[
      ('width', 'Width', dimensions.width, true),
      ('height', 'Height', dimensions.height, false),
    ]) {
      final (id, label, resolved, isWidth) = entry;
      if (resolved.isMeasured) {
        items.add(InterpretationItem(
          id: id,
          level: InterpretationLevel.recognised,
          title: '$label ${resolved.millimetres.round()} mm',
          detail: 'Taken from the measurement you entered.',
        ));
        confidences.add(1);
      } else {
        final suggestion = resolved.suggestion;
        items.add(InterpretationItem(
          id: id,
          level: InterpretationLevel.uncertain,
          title: '$label is not measured',
          detail: suggestion != null
              ? 'Worked out as ${resolved.millimetres.round()} mm from the drawing '
                  'scale. Did you mean ${suggestion.round()} mm?'
              : 'Worked out as ${resolved.millimetres.round()} mm from the drawing '
                  'scale. Confirm or type the real size.',
          choices: [
            if (suggestion != null)
              InterpretationChoice(
                id: '$id.suggested',
                label: 'Use ${suggestion.round()} mm',
                isSuggested: true,
                payload: {'kind': isWidth ? 'width' : 'height', 'valueMm': suggestion},
              ),
            InterpretationChoice(
              id: '$id.keep',
              label: 'Keep ${resolved.millimetres.round()} mm',
              payload: {
                'kind': isWidth ? 'width' : 'height',
                'valueMm': resolved.millimetres,
              },
            ),
          ],
        ));
        confidences.add(0.4);
      }
    }

    // Sections and their opening direction.
    for (final row in structure.rows) {
      for (final cell in row.cells) {
        final cellId = 'r${cell.rowIndex}.c${cell.columnIndex}';
        final confident = cell.confidence >= RecognitionThresholds.confident;
        confidences.add(cell.confidence);
        items.add(InterpretationItem(
          id: 'cell.$cellId',
          level: confident ? InterpretationLevel.recognised : InterpretationLevel.uncertain,
          title: 'Section ${cell.rowIndex + 1}.${cell.columnIndex + 1}: '
              '${cell.operation.label}',
          detail: cell.evidence,
          choices: confident
              ? const []
              : _operationChoices(cellId, model.kind, cell.operation),
        ));
      }
    }

    // Dimension lines still waiting for a number.
    final blankDimensions =
        primitives.whereType<DimensionPrimitive>().where((d) => !d.hasValue).toList();
    for (final d in blankDimensions) {
      items.add(InterpretationItem(
        id: 'dim.${d.id}',
        level: InterpretationLevel.missing,
        title: 'A dimension line has no measurement',
        detail: 'Tap the dimension on the drawing and type the size in millimetres. '
            'The app will not guess it for you.',
      ));
      confidences.add(0.3);
    }

    if (!handwritingRecognizer.canReadInk && transcriptions.isEmpty) {
      final notes = primitives.whereType<NotePrimitive>().length;
      if (notes > 0) {
        items.add(InterpretationItem(
          id: 'handwriting',
          level: InterpretationLevel.recognised,
          title: '$notes ${notes == 1 ? 'note is' : 'notes are'} kept as annotation',
          detail: handwritingRecognizer.capabilityDescription,
        ));
        confidences.add(1);
      }
    }

    final mean = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length;

    return InterpretationReport(items: items, confidence: mean);
  }

  List<InterpretationChoice> _operationChoices(
    String cellId,
    OpeningKind kind,
    CellOperation current,
  ) {
    final options = kind == OpeningKind.door
        ? const [
            CellOperation.doorLeafLeft,
            CellOperation.doorLeafRight,
            CellOperation.slidingLeft,
            CellOperation.fixed,
          ]
        : const [
            CellOperation.casementLeft,
            CellOperation.casementRight,
            CellOperation.awning,
            CellOperation.fixed,
          ];
    return options
        .map((op) => InterpretationChoice(
              id: '$cellId.${op.name}',
              label: op.label,
              isSuggested: op == current,
              payload: {'kind': 'operation', 'cellId': cellId, 'operation': op.name},
            ))
        .toList();
  }
}

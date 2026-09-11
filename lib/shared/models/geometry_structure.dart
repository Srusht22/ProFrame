import '../../core/utilities/geometry_math.dart';
import 'opening_enums.dart';
import 'primitives.dart';

/// One section as it appears in the *drawing*, still in sketch coordinates.
///
/// Sections are free-form rectangles, not grid cells. A divider that only
/// crosses half the design produces exactly the sections that divider creates —
/// no more, no fewer.
class StructureSection {
  final String id;
  final Box2 box;
  final CellOperation operation;
  final double confidence;

  /// Plain-English reason for this reading, shown to the user rather than an
  /// opaque result.
  final String evidence;

  /// True when the user drew this section as a closed shape of its own, rather
  /// than it falling out of where the dividing lines happen to cross.
  final bool drawnExplicitly;

  const StructureSection({
    required this.id,
    required this.box,
    this.operation = CellOperation.fixed,
    this.confidence = 1.0,
    this.evidence = 'No opening marks found — read as a fixed section.',
    this.drawnExplicitly = false,
  });

  StructureSection copyWith({
    CellOperation? operation,
    double? confidence,
    String? evidence,
  }) =>
      StructureSection(
        id: id,
        box: box,
        operation: operation ?? this.operation,
        confidence: confidence ?? this.confidence,
        evidence: evidence ?? this.evidence,
        drawnExplicitly: drawnExplicitly,
      );
}

/// A dividing line the user actually drew, kept so the read-back can report
/// how many divisions were found and so nothing is silently dropped.
class StructureDivider {
  final Box2 span;
  final bool vertical;

  /// True when the divider runs the whole way across the design. A partial
  /// divider is just as valid — it simply makes fewer sections.
  final bool full;

  const StructureDivider({
    required this.span,
    required this.vertical,
    required this.full,
  });
}

/// The drawing understood as a set of sections — the last stage that still
/// lives in sketch coordinates. [GeometryBuilder] converts it to millimetres.
class GeometryStructure {
  final Box2 outline;
  final List<StructureSection> sections;
  final List<StructureDivider> dividers;
  final List<DimensionPrimitive> dimensions;
  final List<NotePrimitive> notes;

  /// True when no closed outline was drawn and the overall extent of the
  /// drawing was used instead. Always surfaced to the user — an assumed
  /// outline is never presented as if it had been drawn.
  final bool outlineFromExtent;

  const GeometryStructure({
    required this.outline,
    required this.sections,
    this.dividers = const [],
    this.dimensions = const [],
    this.notes = const [],
    this.outlineFromExtent = false,
  });

  static const GeometryStructure empty = GeometryStructure(
    outline: Box2(0, 0, 0, 0),
    sections: [],
  );

  bool get isEmpty => outline.width <= 0 || outline.height <= 0 || sections.isEmpty;

  int get sectionCount => sections.length;
  int get dividerCount => dividers.length;
  int get verticalDividerCount => dividers.where((d) => d.vertical).length;
  int get horizontalDividerCount => dividers.where((d) => !d.vertical).length;
  int get explicitSectionCount => sections.where((s) => s.drawnExplicitly).length;
  int get openingCount => sections.where((s) => s.operation.isOperable).length;

  /// Proportion of the drawn outline, used to keep the generated product
  /// faithful to what was drawn.
  double get aspectRatio => outline.height == 0 ? 1 : outline.width / outline.height;
}

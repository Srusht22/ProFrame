import '../core/errors/app_exception.dart';
import '../core/units/length_unit.dart';
import 'design_question.dart';
import 'geometry/polygon.dart';
import 'measurement.dart';
import 'panel.dart';
import 'panel_divider.dart';
import 'product/finish.dart';
import 'product/product_basics.dart';
import 'product/profile_system.dart';
import 'sketch.dart';

/// The one source of truth for a design (spec section 5).
///
/// The 2D editor, the 3D generator, validation and every export read this and
/// nothing else, which is what keeps them from disagreeing. It is structured
/// data throughout — never pixels, never a triangle mesh — so a saved project
/// reopens fully editable rather than as a picture of a decision.
class DesignDocument {
  /// Bumped whenever the stored shape changes.
  ///
  /// Older files are migrated forward on load, never rejected — see
  /// `Panel._notesFromJson`, which reads both the schema 1 single-note string
  /// and the schema 2 note list. A file from a *newer* build is refused,
  /// because this one cannot know what it would be dropping.
  ///
  /// | Version | Change |
  /// | --- | --- |
  /// | 1 | Phases 1 to 3. One note per panel, stored as a string. |
  /// | 2 | Notes become a list of [PanelNote] with positions and visibility. |
  static const int currentSchemaVersion = 2;

  final int schemaVersion;

  /// Stable project id. Survives renaming and duplication (duplicates get a
  /// new one).
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  final ProductCategory category;
  final FrameMaterial material;
  final ProfileSystemRef profile;
  final Finish finish;

  /// Which side of the product the elevation is drawn from. Every hinge side
  /// in [panels] is relative to this (spec section 3C).
  final ViewingSide viewedFrom;

  /// What the entered overall width and height refer to (spec section 3D).
  final DimensionReference dimensionReference;

  /// The gap allowed on each side between the frame and the wall opening.
  ///
  /// Only meaningful when [dimensionReference] is
  /// [DimensionReference.wallOpening]. It is a stored, visible value — the app
  /// never applies an installation allowance the user did not set.
  final double fittingGapMm;

  /// The unit the user types and reads. Storage is always millimetres.
  final LengthUnit displayUnit;

  /// The outer boundary in model space, or null before the drawing has been
  /// interpreted.
  final Polygon? outline;

  final List<PanelDivider> dividers;
  final List<Panel> panels;

  /// Overall size. Null means nobody has said yet, which is different from an
  /// estimate — see [Measurement].
  final Measurement? overallWidth;
  final Measurement? overallHeight;

  /// The original ink, kept for the life of the design.
  final Sketch sketch;

  /// Free text about the design as a whole — general remarks, customer
  /// requests (spec Phase 2, item 6).
  ///
  /// Separate from a panel's own note: this one belongs to the job, not to any
  /// one pane, and appears on the summary and in exports.
  final String designNote;

  DesignDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.material,
    required this.profile,
    required this.finish,
    this.schemaVersion = currentSchemaVersion,
    this.viewedFrom = ViewingSide.outside,
    this.dimensionReference = DimensionReference.outerFrame,
    this.fittingGapMm = 0,
    this.displayUnit = LengthUnit.millimetre,
    this.outline,
    this.dividers = const [],
    this.panels = const [],
    this.overallWidth,
    this.overallHeight,
    this.sketch = const Sketch(),
    this.designNote = '',
  });

  /// A new, empty design. The profile defaults to the factory default for the
  /// material so a beginner is never asked to pick one (spec section 3A).
  factory DesignDocument.blank({
    required String id,
    required ProductCategory category,
    required FrameMaterial material,
    String name = 'Untitled design',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return DesignDocument(
      id: id,
      name: name,
      createdAt: timestamp,
      updatedAt: timestamp,
      category: category,
      material: material,
      profile: GenericProfiles.defaultFor(material).ref,
      finish: StockFinishes.factoryDefault,
    );
  }

  // -- completeness ---------------------------------------------------------

  /// True once the drawing has been interpreted into a layout.
  bool get hasLayout => outline != null && panels.isNotEmpty;

  /// Dimensions the user has actually confirmed.
  bool get hasConfirmedSize =>
      (overallWidth?.isConfirmed ?? false) && (overallHeight?.isConfirmed ?? false);

  /// Panels still waiting for the user to say how they open.
  List<Panel> get panelsNeedingOpeningConfirmation =>
      panels.where((s) => s.needsOpeningConfirmation).toList();

  /// Everything still unconfirmed, in plain language. The 3D preview shows
  /// this list rather than implying the model is final (spec section 2).
  List<DesignQuestion> get outstandingQuestions => [
        if (outline == null)
          const DesignQuestion(DesignQuestionKind.notInterpreted),
        if (overallWidth == null)
          const DesignQuestion(DesignQuestionKind.overallWidthMissing)
        else if (!overallWidth!.isConfirmed)
          DesignQuestion(
            DesignQuestionKind.overallWidthUnconfirmed,
            source: overallWidth!.source,
          ),
        if (overallHeight == null)
          const DesignQuestion(DesignQuestionKind.overallHeightMissing)
        else if (!overallHeight!.isConfirmed)
          DesignQuestion(
            DesignQuestionKind.overallHeightUnconfirmed,
            source: overallHeight!.source,
          ),
        for (final panel in panelsNeedingOpeningConfirmation)
          DesignQuestion(
            DesignQuestionKind.hingeSideUnconfirmed,
            panelId: panel.id,
            panelLabel: panel.label.isEmpty ? null : panel.label,
          ),
      ];

  /// True when every dimension and assignment has been confirmed by a person.
  ///
  /// Even then this describes the *design*, not manufacturing readiness: the
  /// shipped profiles are generic previews, so no output from this build is
  /// production data (spec section 6).
  bool get isFullyConfirmed => hasLayout && outstandingQuestions.isEmpty;

  int get fixedPanelCount =>
      panels.where((s) => s.behaviour.isFixed).length;
  int get openingPanelCount =>
      panels.where((s) => s.behaviour.isOpening).length;

  Panel? panelById(String panelId) =>
      panels.where((s) => s.id == panelId).firstOrNull;

  // -- editing --------------------------------------------------------------

  DesignDocument copyWith({
    String? name,
    DateTime? updatedAt,
    ProductCategory? category,
    FrameMaterial? material,
    ProfileSystemRef? profile,
    Finish? finish,
    ViewingSide? viewedFrom,
    DimensionReference? dimensionReference,
    double? fittingGapMm,
    LengthUnit? displayUnit,
    Polygon? outline,
    List<PanelDivider>? dividers,
    List<Panel>? panels,
    Measurement? overallWidth,
    Measurement? overallHeight,
    Sketch? sketch,
    String? designNote,
  }) =>
      DesignDocument(
        id: id,
        schemaVersion: schemaVersion,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        category: category ?? this.category,
        material: material ?? this.material,
        profile: profile ?? this.profile,
        finish: finish ?? this.finish,
        viewedFrom: viewedFrom ?? this.viewedFrom,
        dimensionReference: dimensionReference ?? this.dimensionReference,
        fittingGapMm: fittingGapMm ?? this.fittingGapMm,
        displayUnit: displayUnit ?? this.displayUnit,
        outline: outline ?? this.outline,
        dividers: dividers ?? this.dividers,
        panels: panels ?? this.panels,
        overallWidth: overallWidth ?? this.overallWidth,
        overallHeight: overallHeight ?? this.overallHeight,
        sketch: sketch ?? this.sketch,
        designNote: designNote ?? this.designNote,
      );

  /// True when there is a design note worth showing an indicator for.
  bool get hasDesignNote => designNote.trim().isNotEmpty;

  /// Every note in the design, panel notes included, for the summary and for
  /// exports. Panels are named by label where they have one.
  List<({String source, String text})> get allNotes => [
        if (hasDesignNote) (source: 'Design', text: designNote.trim()),
        for (var i = 0; i < panels.length; i++)
          for (final note in panels[i].notes)
            if (!note.isEmpty)
              (
                source: panels[i].label.isEmpty
                    ? 'Panel ${i + 1}'
                    : panels[i].label,
                text: note.text.trim(),
              ),
      ];

  /// Replaces one panel, keeping its position in the list and every other
  /// panel untouched.
  DesignDocument withPanel(Panel replacement) => copyWith(
        panels: [
          for (final panel in panels)
            panel.id == replacement.id ? replacement : panel,
        ],
      );

  /// The profile system this design is built from.
  ///
  /// Resolved from the stored reference; falls back to the material's default
  /// when the reference names a system this build does not have, so a project
  /// from a factory with its own catalogue still opens and can still be shown.
  ProfileSystem get profileSystem =>
      GenericProfiles.byId(profile.id) ??
      GenericProfiles.defaultFor(material);

  /// The frame size this design manufactures to.
  ///
  /// When the user entered a wall opening, the fitting gap is subtracted here
  /// — in one place, visibly, from a value they set — rather than being folded
  /// into the stored dimension (spec section 3D).
  double? get frameWidthMm => switch (dimensionReference) {
        DimensionReference.outerFrame => overallWidth?.millimetres,
        DimensionReference.wallOpening =>
          overallWidth == null ? null : overallWidth!.millimetres - 2 * fittingGapMm,
      };

  double? get frameHeightMm => switch (dimensionReference) {
        DimensionReference.outerFrame => overallHeight?.millimetres,
        DimensionReference.wallOpening =>
          overallHeight == null ? null : overallHeight!.millimetres - 2 * fittingGapMm,
      };

  // -- serialisation --------------------------------------------------------

  Map<String, dynamic> toJson() => {
        // Always the current version: a document that was migrated on load is
        // saved forward, so an old file is upgraded the first time it is
        // touched rather than staying old forever.
        'schema': currentSchemaVersion,
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'category': category.name,
        'material': material.name,
        'profile': profile.toJson(),
        'finish': finish.toJson(),
        'viewedFrom': viewedFrom.name,
        'dimensionReference': dimensionReference.name,
        'fittingGapMm': fittingGapMm,
        'displayUnit': displayUnit.name,
        if (outline != null) 'outline': outline!.toJson(),
        'dividers': [for (final d in dividers) d.toJson()],
        'panels': [for (final s in panels) s.toJson()],
        if (overallWidth != null) 'overallWidth': overallWidth!.toJson(),
        if (overallHeight != null) 'overallHeight': overallHeight!.toJson(),
        'sketch': sketch.toJson(),
        if (designNote.isNotEmpty) 'designNote': designNote,
      };

  /// Reads a saved project.
  ///
  /// Throws [DesignDataException] with the path of the offending field rather
  /// than returning a partially-populated document: a design that loads with a
  /// silently dropped CH/Z assignment is worse than one that refuses to load
  /// (spec section 10).
  static DesignDocument fromJson(Object? json) {
    if (json is! Map) {
      throw const DesignDataException('This file is not a ProFrame project.');
    }

    final schema = json['schema'];
    if (schema is! int) {
      throw const DesignDataException(
        'This file has no version number, so it cannot be opened safely.',
        path: 'schema',
      );
    }
    if (schema > currentSchemaVersion) {
      throw DesignDataException(
        'This project was saved by a newer version of ProFrame '
        '(format $schema; this build reads up to $currentSchemaVersion). '
        'Update the app to open it.',
        path: 'schema',
      );
    }

    try {
      final id = json['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('id must be a non-empty string');
      }
      final name = json['name'];
      final category = ProductCategory.values
          .where((c) => c.name == json['category'])
          .firstOrNull;
      if (category == null) {
        throw FormatException('category is not door or window: ${json['category']}');
      }
      final material = FrameMaterial.values
          .where((m) => m.name == json['material'])
          .firstOrNull;
      if (material == null) {
        throw FormatException('material is not a known material: ${json['material']}');
      }
      final viewedFrom = ViewingSide.values
          .where((v) => v.name == json['viewedFrom'])
          .firstOrNull;
      if (viewedFrom == null) {
        throw FormatException(
          'viewedFrom is not a known viewing side: ${json['viewedFrom']}',
        );
      }
      final reference = DimensionReference.values
          .where((r) => r.name == json['dimensionReference'])
          .firstOrNull;
      if (reference == null) {
        throw FormatException(
          'dimensionReference is not known: ${json['dimensionReference']}',
        );
      }
      final unit = LengthUnit.values
          .where((u) => u.name == json['displayUnit'])
          .firstOrNull;
      if (unit == null) {
        throw FormatException('displayUnit is not known: ${json['displayUnit']}');
      }

      final rawDividers = json['dividers'];
      final rawPanels = json['panels'];
      if (rawDividers is! List) {
        throw FormatException('dividers must be a list, got $rawDividers');
      }
      if (rawPanels is! List) {
        throw FormatException('panels must be a list, got $rawPanels');
      }

      final gap = json['fittingGapMm'];
      final designNote = json['designNote'];
      final outlineJson = json['outline'];
      final widthJson = json['overallWidth'];
      final heightJson = json['overallHeight'];

      return DesignDocument(
        schemaVersion: schema,
        id: id,
        name: name is String ? name : 'Untitled design',
        createdAt: _parseTime(json['createdAt'], 'createdAt'),
        updatedAt: _parseTime(json['updatedAt'], 'updatedAt'),
        category: category,
        material: material,
        profile: ProfileSystemRef.fromJson(json['profile']),
        finish: Finish.fromJson(json['finish']),
        viewedFrom: viewedFrom,
        dimensionReference: reference,
        fittingGapMm: gap is num && gap.isFinite ? gap.toDouble() : 0,
        displayUnit: unit,
        outline: outlineJson == null
            ? null
            : Polygon.fromJson(outlineJson, path: 'outline'),
        dividers: [
          for (var i = 0; i < rawDividers.length; i++)
            PanelDivider.fromJson(rawDividers[i], path: 'dividers[$i]'),
        ],
        panels: [
          for (var i = 0; i < rawPanels.length; i++)
            Panel.fromJson(rawPanels[i], path: 'panels[$i]'),
        ],
        overallWidth: widthJson == null
            ? null
            : Measurement.fromJson(
                (widthJson as Map).cast<String, dynamic>(),
                path: 'overallWidth',
              ),
        overallHeight: heightJson == null
            ? null
            : Measurement.fromJson(
                (heightJson as Map).cast<String, dynamic>(),
                path: 'overallHeight',
              ),
        sketch: Sketch.fromJson(json['sketch'] ?? const {'strokes': <Object?>[]}),
        designNote: designNote is String ? designNote : '',
      );
    } on FormatException catch (error) {
      throw DesignDataException(
        'This project file is damaged: ${error.message}',
      );
    } on GeometryException catch (error) {
      throw DesignDataException(
        'This project contains geometry that cannot be rebuilt: '
        '${error.message}',
      );
    } on ArgumentError catch (error) {
      throw DesignDataException(
        'This project contains an inconsistent panel: ${error.message}',
      );
    }
  }

  static DateTime _parseTime(Object? value, String field) {
    if (value is! String) {
      throw FormatException('$field must be an ISO-8601 string, got $value');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field is not a valid date: $value');
    }
    return parsed.toUtc();
  }

  @override
  String toString() => 'DesignDocument($id, "$name", ${category.name}, '
      '${panels.length} panels)';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

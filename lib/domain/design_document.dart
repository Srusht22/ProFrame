import '../core/errors/app_exception.dart';
import '../core/units/length_unit.dart';
import 'divider.dart';
import 'geometry/polygon.dart';
import 'measurement.dart';
import 'product/finish.dart';
import 'product/product_basics.dart';
import 'product/profile_system.dart';
import 'section.dart';
import 'sketch.dart';

/// The one source of truth for a design (spec section 5).
///
/// The 2D editor, the 3D generator, validation and every export read this and
/// nothing else, which is what keeps them from disagreeing. It is structured
/// data throughout — never pixels, never a triangle mesh — so a saved project
/// reopens fully editable rather than as a picture of a decision.
class DesignDocument {
  /// Bumped whenever the stored shape changes in a way older builds cannot
  /// read. [fromJson] refuses anything newer rather than guessing.
  static const int currentSchemaVersion = 1;

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
  /// in [sections] is relative to this (spec section 3C).
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

  final List<Divider> dividers;
  final List<Section> sections;

  /// Overall size. Null means nobody has said yet, which is different from an
  /// estimate — see [Measurement].
  final Measurement? overallWidth;
  final Measurement? overallHeight;

  /// The original ink, kept for the life of the design.
  final Sketch sketch;

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
    this.sections = const [],
    this.overallWidth,
    this.overallHeight,
    this.sketch = const Sketch(),
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
  bool get hasLayout => outline != null && sections.isNotEmpty;

  /// Dimensions the user has actually confirmed.
  bool get hasConfirmedSize =>
      (overallWidth?.isConfirmed ?? false) && (overallHeight?.isConfirmed ?? false);

  /// Sections still waiting for the user to say how they open.
  List<Section> get sectionsNeedingOpeningConfirmation =>
      sections.where((s) => s.needsOpeningConfirmation).toList();

  /// Everything still unconfirmed, in plain language. The 3D preview shows
  /// this list rather than implying the model is final (spec section 2).
  List<String> get outstandingQuestions => [
        if (outline == null) 'The drawing has not been interpreted yet.',
        if (overallWidth == null)
          'The overall width has not been entered.'
        else if (!overallWidth!.isConfirmed)
          'The overall width is ${overallWidth!.source.name}, not confirmed.',
        if (overallHeight == null)
          'The overall height has not been entered.'
        else if (!overallHeight!.isConfirmed)
          'The overall height is ${overallHeight!.source.name}, not confirmed.',
        for (final section in sectionsNeedingOpeningConfirmation)
          'Section ${section.label.isEmpty ? section.id : section.label} '
              'opens, but the hinge side has not been confirmed.',
      ];

  /// True when every dimension and assignment has been confirmed by a person.
  ///
  /// Even then this describes the *design*, not manufacturing readiness: the
  /// shipped profiles are generic previews, so no output from this build is
  /// production data (spec section 6).
  bool get isFullyConfirmed => hasLayout && outstandingQuestions.isEmpty;

  int get fixedSectionCount =>
      sections.where((s) => s.behaviour.isFixed).length;
  int get openingSectionCount =>
      sections.where((s) => s.behaviour.isOpening).length;

  Section? sectionById(String sectionId) =>
      sections.where((s) => s.id == sectionId).firstOrNull;

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
    List<Divider>? dividers,
    List<Section>? sections,
    Measurement? overallWidth,
    Measurement? overallHeight,
    Sketch? sketch,
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
        sections: sections ?? this.sections,
        overallWidth: overallWidth ?? this.overallWidth,
        overallHeight: overallHeight ?? this.overallHeight,
        sketch: sketch ?? this.sketch,
      );

  /// Replaces one section, keeping its position in the list and every other
  /// section untouched.
  DesignDocument withSection(Section replacement) => copyWith(
        sections: [
          for (final section in sections)
            section.id == replacement.id ? replacement : section,
        ],
      );

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
        'schema': schemaVersion,
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
        'sections': [for (final s in sections) s.toJson()],
        if (overallWidth != null) 'overallWidth': overallWidth!.toJson(),
        if (overallHeight != null) 'overallHeight': overallHeight!.toJson(),
        'sketch': sketch.toJson(),
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
      final rawSections = json['sections'];
      if (rawDividers is! List) {
        throw FormatException('dividers must be a list, got $rawDividers');
      }
      if (rawSections is! List) {
        throw FormatException('sections must be a list, got $rawSections');
      }

      final gap = json['fittingGapMm'];
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
            Divider.fromJson(rawDividers[i], path: 'dividers[$i]'),
        ],
        sections: [
          for (var i = 0; i < rawSections.length; i++)
            Section.fromJson(rawSections[i], path: 'sections[$i]'),
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
        'This project contains an inconsistent section: ${error.message}',
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
      '${sections.length} sections)';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

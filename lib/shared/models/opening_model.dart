import '../../core/utilities/geometry_math.dart';
import 'design_region.dart';
import 'materials.dart';
import 'opening_enums.dart';
import 'profile_spec.dart';

export 'opening_enums.dart';
export 'profile_spec.dart';

/// The single parametric description of the product.
///
/// The design is a set of free-form sections at exact millimetre positions —
/// **not** a grid of rows and columns. That distinction is the whole point: a
/// 400 x 400 opening in one corner is just a rectangle there, and it does not
/// impose a division on the rest of the product. Asymmetry, unequal sections
/// and deliberately odd arrangements survive untouched all the way to the 3D
/// model and the price.
///
/// Nothing downstream is allowed to round these numbers, equalise sections,
/// centre anything or otherwise tidy the design up.
class OpeningModel {
  final String id;
  final OpeningKind kind;
  final double widthMm;
  final double heightMm;
  final FrameMaterial material;
  final FrameFinish finish;

  /// Profile sizes. Anything not pinned here follows [material].
  final ProfileSpec profile;

  /// Top-level sections, positioned in the product's own coordinate space:
  /// origin at the top-left of the outer frame, millimetres, y downwards.
  final List<DesignRegion> regions;

  /// Depth of the wall reveal the frame sits in.
  final double wallDepthMm;

  final bool hasThreshold;
  final bool hasSill;
  final double sillProjectionMm;

  const OpeningModel({
    required this.id,
    required this.kind,
    required this.widthMm,
    required this.heightMm,
    required this.regions,
    this.material = FrameMaterial.aluminium,
    this.finish = FrameFinish.naturalAnodised,
    this.profile = ProfileSpec.fromMaterial,
    this.wallDepthMm = 200,
    this.hasThreshold = false,
    this.hasSill = false,
    this.sillProjectionMm = 40,
  });

  /// A starting point when a type is chosen before anything is drawn: one
  /// section filling the whole product, which the user then divides however
  /// they like.
  ///
  /// Pass [widthMm]/[heightMm] to start at a known size. Do not reach for
  /// [copyWith] to resize a model — that changes the overall dimensions and
  /// leaves the sections where they were. [RegionEditor.setOverallSize] is the
  /// operation that keeps the two in step.
  factory OpeningModel.blank(
    OpeningKind kind, {
    String id = 'model',
    double? widthMm,
    double? heightMm,
  }) {
    final isDoor = kind == OpeningKind.door;
    final width = widthMm ?? (isDoor ? 900.0 : 1200.0);
    final height = heightMm ?? (isDoor ? 2100.0 : 1400.0);
    return OpeningModel(
      id: id,
      kind: kind,
      widthMm: width,
      heightMm: height,
      hasThreshold: isDoor,
      hasSill: !isDoor,
      regions: [
        DesignRegion(
          id: 's1',
          rect: Box2.fromLTWH(0, 0, width, height),
          operation: isDoor ? CellOperation.doorLeafRight : CellOperation.fixed,
          swing: isDoor ? SwingDirection.inward : SwingDirection.none,
          handle: isDoor ? HandleStyle.lever : HandleStyle.none,
          hasLock: isDoor,
        ),
      ],
    );
  }

  Box2 get outerRect => Box2.fromLTWH(0, 0, widthMm, heightMm);

  // Resolved profile sizes. Everything downstream reads these rather than the
  // material directly, so an overridden dimension reaches the drawing, the 3D
  // model and the price alike.
  double get frameFaceMm => profile.frameFace(material);
  double get frameDepthMm => profile.frameDepth(material);
  double get sashFaceMm => profile.sashFace(material);
  double get sashDepthMm => profile.sashDepth(material);
  double get mullionFaceMm => profile.mullionFace(material);
  double get glazingBeadMm => profile.glazingBead(material);

  double get areaM2 => (widthMm * heightMm) / 1e6;

  List<DesignRegion> get allRegions => RegionTree.all(regions).toList();

  List<DesignRegion> get leafRegions => RegionTree.leaves(regions).toList();

  DesignRegion? region(String id) => RegionTree.findById(regions, id);

  int get operableCount => allRegions.where((r) => r.isOperable).length;

  /// Total area of the sections, which equals the product area only when the
  /// sections cover it exactly. The difference is reported by the validator
  /// rather than being corrected.
  double get coveredAreaM2 =>
      regions.fold<double>(0, (sum, r) => sum + (r.rect.width * r.rect.height)) / 1e6;

  OpeningModel copyWith({
    OpeningKind? kind,
    double? widthMm,
    double? heightMm,
    FrameMaterial? material,
    FrameFinish? finish,
    ProfileSpec? profile,
    List<DesignRegion>? regions,
    double? wallDepthMm,
    bool? hasThreshold,
    bool? hasSill,
    double? sillProjectionMm,
  }) =>
      OpeningModel(
        id: id,
        kind: kind ?? this.kind,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        material: material ?? this.material,
        finish: finish ?? this.finish,
        profile: profile ?? this.profile,
        regions: regions ?? this.regions,
        wallDepthMm: wallDepthMm ?? this.wallDepthMm,
        hasThreshold: hasThreshold ?? this.hasThreshold,
        hasSill: hasSill ?? this.hasSill,
        sillProjectionMm: sillProjectionMm ?? this.sillProjectionMm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'material': material.name,
        'finish': finish.name,
        if (!profile.isAllDefault) 'profile': profile.toJson(),
        'wallDepthMm': wallDepthMm,
        'hasThreshold': hasThreshold,
        'hasSill': hasSill,
        'sillProjectionMm': sillProjectionMm,
        'regions': regions.map((r) => r.toJson()).toList(),
      };

  factory OpeningModel.fromJson(Map<String, dynamic> json) => OpeningModel(
        id: json['id'] as String,
        kind: enumByName(OpeningKind.values, json['kind'], OpeningKind.window),
        widthMm: (json['widthMm'] as num).toDouble(),
        heightMm: (json['heightMm'] as num).toDouble(),
        material: enumByName(FrameMaterial.values, json['material'], FrameMaterial.aluminium),
        finish: enumByName(FrameFinish.values, json['finish'], FrameFinish.naturalAnodised),
        profile: json['profile'] == null
            ? ProfileSpec.fromMaterial
            : ProfileSpec.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
        wallDepthMm: (json['wallDepthMm'] as num?)?.toDouble() ?? 200,
        hasThreshold: json['hasThreshold'] as bool? ?? false,
        hasSill: json['hasSill'] as bool? ?? false,
        sillProjectionMm: (json['sillProjectionMm'] as num?)?.toDouble() ?? 40,
        regions: ((json['regions'] as List?) ?? const [])
            .map((e) => DesignRegion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

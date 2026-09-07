import '../../core/utils/id_generator.dart';
import '../../core/utils/unit_converter.dart';
import 'config_enums.dart';
import 'configuration_value_objects.dart';

/// The single source of truth for one configured door/window.
///
/// Every other subsystem — the validation engine, the 2D designer, the 3D
/// generator, the pricing engine, the BOM/cutting-list generator, the
/// quotation PDF and the manufacturing order — reads from this same object.
/// Nothing downstream is allowed to keep its own copy of width/height/etc;
/// they all take a [ProductConfiguration] as input. This is what keeps a
/// width change from ever going out of sync between the drawing, the price
/// and the production paperwork.
class ProductConfiguration {
  final String id;
  final String? projectId;
  final String name;

  final ProductCategory category;
  final DoorType? doorType;
  final WindowType? windowType;

  /// Overall finished-unit dimensions, always in millimeters.
  final double widthMm;
  final double heightMm;

  /// The rough wall opening the unit will be installed into (may be larger
  /// than the unit to allow for packing/render/plaster).
  final double wallOpeningWidthMm;
  final double wallOpeningHeightMm;

  final int quantity;

  final FrameSpec frame;
  final LeafSpec leaf;
  final PanelSpec panel;
  final GlassSpec glass;
  final HardwareSpec hardware;
  final FinishSpec finish;
  final AccessoryOptions accessories;

  /// Number of glazed/paneled compartments across the width — used by
  /// windows (and fixed-panel doors) to place vertical mullions.
  final int sections;

  /// Optional horizontal transom positions, expressed as a fraction (0-1)
  /// of the total height, measured from the top. Empty = no transom.
  final List<double> transomFractions;

  final ProductConfigState state;
  final String? notes;
  final String? thumbnailBase64;

  final int version;
  final String? createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductConfiguration({
    required this.id,
    this.projectId,
    required this.name,
    this.category = ProductCategory.window,
    this.doorType,
    this.windowType = WindowType.sliding,
    this.widthMm = 1200,
    this.heightMm = 1500,
    this.wallOpeningWidthMm = 1220,
    this.wallOpeningHeightMm = 1520,
    this.quantity = 1,
    this.frame = const FrameSpec(),
    this.leaf = const LeafSpec(),
    this.panel = const PanelSpec(),
    this.glass = const GlassSpec(),
    this.hardware = const HardwareSpec(),
    this.finish = const FinishSpec(),
    this.accessories = const AccessoryOptions(),
    this.sections = 2,
    this.transomFractions = const [],
    this.state = ProductConfigState.draft,
    this.notes,
    this.thumbnailBase64,
    this.version = 1,
    this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductConfiguration.newDraft({
    required String name,
    ProductCategory category = ProductCategory.window,
    String? projectId,
    String? createdByUserId,
  }) {
    final now = DateTime.now();
    return ProductConfiguration(
      id: IdGenerator.generate(),
      projectId: projectId,
      name: name,
      category: category,
      doorType: category == ProductCategory.door ? DoorType.exterior : null,
      windowType: category == ProductCategory.window ? WindowType.sliding : null,
      widthMm: category == ProductCategory.door ? 950 : 1200,
      heightMm: category == ProductCategory.door ? 2150 : 1500,
      wallOpeningWidthMm: category == ProductCategory.door ? 970 : 1220,
      wallOpeningHeightMm: category == ProductCategory.door ? 2170 : 1520,
      frame: FrameSpec(
        hasDoorJamb: category == ProductCategory.door,
        hasThreshold: category == ProductCategory.door,
      ),
      leaf: LeafSpec(
        arrangement: category == ProductCategory.door
            ? LeafArrangement.single
            : LeafArrangement.custom,
        leafCount: category == ProductCategory.door ? 1 : 0,
        openingDirection: category == ProductCategory.door
            ? OpeningDirection.leftHinge
            : OpeningDirection.slideLeft,
      ),
      panel: PanelSpec(type: category == ProductCategory.door ? PanelType.glass : PanelType.glass),
      hardware: HardwareSpec(
        hingeCount: category == ProductCategory.door ? 3 : 0,
        handleModel: category == ProductCategory.door
            ? HandleModel.standardLever
            : HandleModel.flushLatch,
        lockType: category == ProductCategory.door ? LockType.standardCylinder : LockType.none,
      ),
      sections: category == ProductCategory.door ? 1 : 2,
      createdByUserId: createdByUserId,
      createdAt: now,
      updatedAt: now,
    );
  }

  double get widthM => AreaConverter.metersFromMm(widthMm);
  double get heightM => AreaConverter.metersFromMm(heightMm);
  double get areaM2 => AreaConverter.squareMetersFromMm(widthMm, heightMm);

  String get productTypeLabel {
    if (category == ProductCategory.door) return doorType?.label ?? 'Door';
    return windowType?.label ?? 'Window';
  }

  String formattedDimensions([LengthUnit unit = LengthUnit.mm]) {
    return '${unit.format(widthMm)} × ${unit.format(heightMm)}';
  }

  ProductConfiguration copyWith({
    String? id,
    String? projectId,
    String? name,
    ProductCategory? category,
    DoorType? doorType,
    WindowType? windowType,
    double? widthMm,
    double? heightMm,
    double? wallOpeningWidthMm,
    double? wallOpeningHeightMm,
    int? quantity,
    FrameSpec? frame,
    LeafSpec? leaf,
    PanelSpec? panel,
    GlassSpec? glass,
    HardwareSpec? hardware,
    FinishSpec? finish,
    AccessoryOptions? accessories,
    int? sections,
    List<double>? transomFractions,
    ProductConfigState? state,
    String? notes,
    String? thumbnailBase64,
    int? version,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDoorType = false,
    bool clearWindowType = false,
  }) {
    return ProductConfiguration(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      category: category ?? this.category,
      doorType: clearDoorType ? null : (doorType ?? this.doorType),
      windowType: clearWindowType ? null : (windowType ?? this.windowType),
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      wallOpeningWidthMm: wallOpeningWidthMm ?? this.wallOpeningWidthMm,
      wallOpeningHeightMm: wallOpeningHeightMm ?? this.wallOpeningHeightMm,
      quantity: quantity ?? this.quantity,
      frame: frame ?? this.frame,
      leaf: leaf ?? this.leaf,
      panel: panel ?? this.panel,
      glass: glass ?? this.glass,
      hardware: hardware ?? this.hardware,
      finish: finish ?? this.finish,
      accessories: accessories ?? this.accessories,
      sections: sections ?? this.sections,
      transomFractions: transomFractions ?? this.transomFractions,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      version: version ?? this.version,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'name': name,
        'category': category.name,
        'doorType': doorType?.name,
        'windowType': windowType?.name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'wallOpeningWidthMm': wallOpeningWidthMm,
        'wallOpeningHeightMm': wallOpeningHeightMm,
        'quantity': quantity,
        'frame': frame.toJson(),
        'leaf': leaf.toJson(),
        'panel': panel.toJson(),
        'glass': glass.toJson(),
        'hardware': hardware.toJson(),
        'finish': finish.toJson(),
        'accessories': accessories.toJson(),
        'sections': sections,
        'transomFractions': transomFractions,
        'state': state.name,
        'notes': notes,
        'thumbnailBase64': thumbnailBase64,
        'version': version,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProductConfiguration.fromJson(Map<String, dynamic> json) {
    return ProductConfiguration(
      id: json['id'] as String,
      projectId: json['projectId'] as String?,
      name: json['name'] as String? ?? 'Untitled',
      category: ProductCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ProductCategory.window,
      ),
      doorType: json['doorType'] != null
          ? DoorType.values.firstWhere(
              (e) => e.name == json['doorType'],
              orElse: () => DoorType.exterior,
            )
          : null,
      windowType: json['windowType'] != null
          ? WindowType.values.firstWhere(
              (e) => e.name == json['windowType'],
              orElse: () => WindowType.sliding,
            )
          : null,
      widthMm: (json['widthMm'] as num?)?.toDouble() ?? 1200,
      heightMm: (json['heightMm'] as num?)?.toDouble() ?? 1500,
      wallOpeningWidthMm: (json['wallOpeningWidthMm'] as num?)?.toDouble() ?? 1220,
      wallOpeningHeightMm: (json['wallOpeningHeightMm'] as num?)?.toDouble() ?? 1520,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      frame: json['frame'] != null
          ? FrameSpec.fromJson(Map<String, dynamic>.from(json['frame'] as Map))
          : const FrameSpec(),
      leaf: json['leaf'] != null
          ? LeafSpec.fromJson(Map<String, dynamic>.from(json['leaf'] as Map))
          : const LeafSpec(),
      panel: json['panel'] != null
          ? PanelSpec.fromJson(Map<String, dynamic>.from(json['panel'] as Map))
          : const PanelSpec(),
      glass: json['glass'] != null
          ? GlassSpec.fromJson(Map<String, dynamic>.from(json['glass'] as Map))
          : const GlassSpec(),
      hardware: json['hardware'] != null
          ? HardwareSpec.fromJson(Map<String, dynamic>.from(json['hardware'] as Map))
          : const HardwareSpec(),
      finish: json['finish'] != null
          ? FinishSpec.fromJson(Map<String, dynamic>.from(json['finish'] as Map))
          : const FinishSpec(),
      accessories: json['accessories'] != null
          ? AccessoryOptions.fromJson(Map<String, dynamic>.from(json['accessories'] as Map))
          : const AccessoryOptions(),
      sections: (json['sections'] as num?)?.toInt() ?? 2,
      transomFractions: (json['transomFractions'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [],
      state: ProductConfigState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => ProductConfigState.draft,
      ),
      notes: json['notes'] as String?,
      thumbnailBase64: json['thumbnailBase64'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdByUserId: json['createdByUserId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Flat payload sent across the JS bridge to the three.js parametric
  /// engine. Kept intentionally flat/primitive (no enums) because it
  /// crosses a JSON boundary into JavaScript.
  Map<String, dynamic> to3DParams() {
    return {
      'category': category.name,
      'productType': category == ProductCategory.door ? doorType?.name : windowType?.name,
      'width': widthMm,
      'height': heightMm,
      'frameDepth': frame.frameDepthMm,
      'frameThickness': frame.frameThicknessMm,
      'frameMaterial': frame.material.name,
      'hasDoorJamb': frame.hasDoorJamb,
      'hasThreshold': frame.hasThreshold,
      'leafArrangement': leaf.arrangement.name,
      'leafCount': leaf.leafCount,
      'primaryLeafRatio': leaf.primaryLeafRatio,
      'openingDirection': leaf.openingDirection.name,
      'panelType': panel.type.name,
      'glassType': glass.type.name,
      'glassThickness': glass.thicknessMm,
      'glassPanes': glass.panesCount,
      'hingeCount': hardware.hingeCount,
      'handleModel': hardware.handleModel.name,
      'handleColor': hardware.handleColor.name,
      'lockType': hardware.lockType.name,
      'hasPullHandle': hardware.hasPullHandle,
      'frameColor': finish.frameColor.name,
      'customHexColor': finish.customHexColor,
      'sections': sections,
      'transomFractions': transomFractions,
      'hasMosquitoNet': accessories.mosquitoNet,
    };
  }
}

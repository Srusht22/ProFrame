import 'config_enums.dart';

/// Immutable value objects that compose [ProductConfiguration]. Each one
/// maps to a real manufacturing sub-system (frame, leaf, glazing, hardware,
/// finish, extra options) so the 2D designer, 3D generator, pricing engine
/// and BOM generator can each read only the slice they need without the
/// aggregate turning into an unreadable flat bag of fields.
class FrameSpec {
  final FrameMaterial material;
  final String profileSystem;
  final double frameDepthMm;
  final double frameThicknessMm;
  final bool hasInnerFrame;
  final bool hasOuterFrame;
  final bool hasBorder;
  final bool hasDoorJamb;
  final bool hasThreshold;

  const FrameSpec({
    this.material = FrameMaterial.aluminum,
    this.profileSystem = 'Standard 55',
    this.frameDepthMm = 55,
    this.frameThicknessMm = 45,
    this.hasInnerFrame = true,
    this.hasOuterFrame = true,
    this.hasBorder = true,
    this.hasDoorJamb = false,
    this.hasThreshold = false,
  });

  FrameSpec copyWith({
    FrameMaterial? material,
    String? profileSystem,
    double? frameDepthMm,
    double? frameThicknessMm,
    bool? hasInnerFrame,
    bool? hasOuterFrame,
    bool? hasBorder,
    bool? hasDoorJamb,
    bool? hasThreshold,
  }) {
    return FrameSpec(
      material: material ?? this.material,
      profileSystem: profileSystem ?? this.profileSystem,
      frameDepthMm: frameDepthMm ?? this.frameDepthMm,
      frameThicknessMm: frameThicknessMm ?? this.frameThicknessMm,
      hasInnerFrame: hasInnerFrame ?? this.hasInnerFrame,
      hasOuterFrame: hasOuterFrame ?? this.hasOuterFrame,
      hasBorder: hasBorder ?? this.hasBorder,
      hasDoorJamb: hasDoorJamb ?? this.hasDoorJamb,
      hasThreshold: hasThreshold ?? this.hasThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'material': material.name,
        'profileSystem': profileSystem,
        'frameDepthMm': frameDepthMm,
        'frameThicknessMm': frameThicknessMm,
        'hasInnerFrame': hasInnerFrame,
        'hasOuterFrame': hasOuterFrame,
        'hasBorder': hasBorder,
        'hasDoorJamb': hasDoorJamb,
        'hasThreshold': hasThreshold,
      };

  factory FrameSpec.fromJson(Map<String, dynamic> json) => FrameSpec(
        material: FrameMaterial.values.firstWhere(
          (e) => e.name == json['material'],
          orElse: () => FrameMaterial.aluminum,
        ),
        profileSystem: json['profileSystem'] as String? ?? 'Standard 55',
        frameDepthMm: (json['frameDepthMm'] as num?)?.toDouble() ?? 55,
        frameThicknessMm: (json['frameThicknessMm'] as num?)?.toDouble() ?? 45,
        hasInnerFrame: json['hasInnerFrame'] as bool? ?? true,
        hasOuterFrame: json['hasOuterFrame'] as bool? ?? true,
        hasBorder: json['hasBorder'] as bool? ?? true,
        hasDoorJamb: json['hasDoorJamb'] as bool? ?? false,
        hasThreshold: json['hasThreshold'] as bool? ?? false,
      );
}

class LeafSpec {
  final LeafArrangement arrangement;
  final int leafCount;

  /// Fraction (0-1) of the total width given to the primary leaf when
  /// [arrangement] is [LeafArrangement.unequalDouble].
  final double primaryLeafRatio;
  final OpeningDirection openingDirection;

  const LeafSpec({
    this.arrangement = LeafArrangement.single,
    this.leafCount = 1,
    this.primaryLeafRatio = 0.5,
    this.openingDirection = OpeningDirection.leftHinge,
  });

  LeafSpec copyWith({
    LeafArrangement? arrangement,
    int? leafCount,
    double? primaryLeafRatio,
    OpeningDirection? openingDirection,
  }) {
    return LeafSpec(
      arrangement: arrangement ?? this.arrangement,
      leafCount: leafCount ?? this.leafCount,
      primaryLeafRatio: primaryLeafRatio ?? this.primaryLeafRatio,
      openingDirection: openingDirection ?? this.openingDirection,
    );
  }

  Map<String, dynamic> toJson() => {
        'arrangement': arrangement.name,
        'leafCount': leafCount,
        'primaryLeafRatio': primaryLeafRatio,
        'openingDirection': openingDirection.name,
      };

  factory LeafSpec.fromJson(Map<String, dynamic> json) => LeafSpec(
        arrangement: LeafArrangement.values.firstWhere(
          (e) => e.name == json['arrangement'],
          orElse: () => LeafArrangement.single,
        ),
        leafCount: (json['leafCount'] as num?)?.toInt() ?? 1,
        primaryLeafRatio: (json['primaryLeafRatio'] as num?)?.toDouble() ?? 0.5,
        openingDirection: OpeningDirection.values.firstWhere(
          (e) => e.name == json['openingDirection'],
          orElse: () => OpeningDirection.leftHinge,
        ),
      );
}

class PanelSpec {
  final PanelType type;

  /// Panel grid used for multi-panel layouts (e.g. a 2x1 door panel split).
  final int rows;
  final int columns;

  const PanelSpec({
    this.type = PanelType.glass,
    this.rows = 1,
    this.columns = 1,
  });

  PanelSpec copyWith({PanelType? type, int? rows, int? columns}) {
    return PanelSpec(
      type: type ?? this.type,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'rows': rows,
        'columns': columns,
      };

  factory PanelSpec.fromJson(Map<String, dynamic> json) => PanelSpec(
        type: PanelType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PanelType.glass,
        ),
        rows: (json['rows'] as num?)?.toInt() ?? 1,
        columns: (json['columns'] as num?)?.toInt() ?? 1,
      );
}

class GlassSpec {
  final GlassType type;
  final double thicknessMm;
  final int panesCount;
  final String? customHexColor;

  const GlassSpec({
    this.type = GlassType.clear,
    this.thicknessMm = 6,
    this.panesCount = 1,
    this.customHexColor,
  });

  GlassSpec copyWith({
    GlassType? type,
    double? thicknessMm,
    int? panesCount,
    String? customHexColor,
  }) {
    return GlassSpec(
      type: type ?? this.type,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      panesCount: panesCount ?? this.panesCount,
      customHexColor: customHexColor ?? this.customHexColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'thicknessMm': thicknessMm,
        'panesCount': panesCount,
        'customHexColor': customHexColor,
      };

  factory GlassSpec.fromJson(Map<String, dynamic> json) => GlassSpec(
        type: GlassType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => GlassType.clear,
        ),
        thicknessMm: (json['thicknessMm'] as num?)?.toDouble() ?? 6,
        panesCount: (json['panesCount'] as num?)?.toInt() ?? 1,
        customHexColor: json['customHexColor'] as String?,
      );
}

class HardwareSpec {
  final int hingeCount;
  final HandleModel handleModel;
  final FrameColor handleColor;
  final LockType lockType;
  final DoorCloserType doorCloser;
  final bool hasPullHandle;
  final int extraAccessoryCount;

  const HardwareSpec({
    this.hingeCount = 3,
    this.handleModel = HandleModel.standardLever,
    this.handleColor = FrameColor.black,
    this.lockType = LockType.standardCylinder,
    this.doorCloser = DoorCloserType.none,
    this.hasPullHandle = false,
    this.extraAccessoryCount = 0,
  });

  HardwareSpec copyWith({
    int? hingeCount,
    HandleModel? handleModel,
    FrameColor? handleColor,
    LockType? lockType,
    DoorCloserType? doorCloser,
    bool? hasPullHandle,
    int? extraAccessoryCount,
  }) {
    return HardwareSpec(
      hingeCount: hingeCount ?? this.hingeCount,
      handleModel: handleModel ?? this.handleModel,
      handleColor: handleColor ?? this.handleColor,
      lockType: lockType ?? this.lockType,
      doorCloser: doorCloser ?? this.doorCloser,
      hasPullHandle: hasPullHandle ?? this.hasPullHandle,
      extraAccessoryCount: extraAccessoryCount ?? this.extraAccessoryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'hingeCount': hingeCount,
        'handleModel': handleModel.name,
        'handleColor': handleColor.name,
        'lockType': lockType.name,
        'doorCloser': doorCloser.name,
        'hasPullHandle': hasPullHandle,
        'extraAccessoryCount': extraAccessoryCount,
      };

  factory HardwareSpec.fromJson(Map<String, dynamic> json) => HardwareSpec(
        hingeCount: (json['hingeCount'] as num?)?.toInt() ?? 3,
        handleModel: HandleModel.values.firstWhere(
          (e) => e.name == json['handleModel'],
          orElse: () => HandleModel.standardLever,
        ),
        handleColor: FrameColor.values.firstWhere(
          (e) => e.name == json['handleColor'],
          orElse: () => FrameColor.black,
        ),
        lockType: LockType.values.firstWhere(
          (e) => e.name == json['lockType'],
          orElse: () => LockType.standardCylinder,
        ),
        doorCloser: DoorCloserType.values.firstWhere(
          (e) => e.name == json['doorCloser'],
          orElse: () => DoorCloserType.none,
        ),
        hasPullHandle: json['hasPullHandle'] as bool? ?? false,
        extraAccessoryCount: (json['extraAccessoryCount'] as num?)?.toInt() ?? 0,
      );
}

class FinishSpec {
  final FrameColor frameColor;
  final String? customHexColor;
  final String finishName;

  const FinishSpec({
    this.frameColor = FrameColor.black,
    this.customHexColor,
    this.finishName = 'Powder Coated Matte',
  });

  FinishSpec copyWith({
    FrameColor? frameColor,
    String? customHexColor,
    String? finishName,
  }) {
    return FinishSpec(
      frameColor: frameColor ?? this.frameColor,
      customHexColor: customHexColor ?? this.customHexColor,
      finishName: finishName ?? this.finishName,
    );
  }

  Map<String, dynamic> toJson() => {
        'frameColor': frameColor.name,
        'customHexColor': customHexColor,
        'finishName': finishName,
      };

  factory FinishSpec.fromJson(Map<String, dynamic> json) => FinishSpec(
        frameColor: FrameColor.values.firstWhere(
          (e) => e.name == json['frameColor'],
          orElse: () => FrameColor.black,
        ),
        customHexColor: json['customHexColor'] as String?,
        finishName: json['finishName'] as String? ?? 'Powder Coated Matte',
      );
}

class AccessoryOptions {
  final bool mosquitoNet;
  final bool safetyLock;
  final bool soundInsulation;
  final bool thermalInsulation;
  final bool decorativeStrips;
  final bool weatherSealing;
  final String? customEngraving;

  const AccessoryOptions({
    this.mosquitoNet = false,
    this.safetyLock = false,
    this.soundInsulation = false,
    this.thermalInsulation = false,
    this.decorativeStrips = false,
    this.weatherSealing = true,
    this.customEngraving,
  });

  AccessoryOptions copyWith({
    bool? mosquitoNet,
    bool? safetyLock,
    bool? soundInsulation,
    bool? thermalInsulation,
    bool? decorativeStrips,
    bool? weatherSealing,
    String? customEngraving,
  }) {
    return AccessoryOptions(
      mosquitoNet: mosquitoNet ?? this.mosquitoNet,
      safetyLock: safetyLock ?? this.safetyLock,
      soundInsulation: soundInsulation ?? this.soundInsulation,
      thermalInsulation: thermalInsulation ?? this.thermalInsulation,
      decorativeStrips: decorativeStrips ?? this.decorativeStrips,
      weatherSealing: weatherSealing ?? this.weatherSealing,
      customEngraving: customEngraving ?? this.customEngraving,
    );
  }

  /// Count of active boolean add-ons — used by pricing to charge a flat fee
  /// per selected accessory.
  int get activeCount => [
        mosquitoNet,
        safetyLock,
        soundInsulation,
        thermalInsulation,
        decorativeStrips,
      ].where((e) => e).length;

  Map<String, dynamic> toJson() => {
        'mosquitoNet': mosquitoNet,
        'safetyLock': safetyLock,
        'soundInsulation': soundInsulation,
        'thermalInsulation': thermalInsulation,
        'decorativeStrips': decorativeStrips,
        'weatherSealing': weatherSealing,
        'customEngraving': customEngraving,
      };

  factory AccessoryOptions.fromJson(Map<String, dynamic> json) => AccessoryOptions(
        mosquitoNet: json['mosquitoNet'] as bool? ?? false,
        safetyLock: json['safetyLock'] as bool? ?? false,
        soundInsulation: json['soundInsulation'] as bool? ?? false,
        thermalInsulation: json['thermalInsulation'] as bool? ?? false,
        decorativeStrips: json['decorativeStrips'] as bool? ?? false,
        weatherSealing: json['weatherSealing'] as bool? ?? true,
        customEngraving: json['customEngraving'] as String?,
      );
}

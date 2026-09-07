import '../configuration/config_enums.dart';
import 'currency.dart';

enum LaborMode { percentageOfMaterials, fixedPerUnit }

/// Administrator-editable pricing configuration (spec: "Administrators
/// should be able to change prices without changing source code"). Every
/// number here is a placeholder default — factories are expected to tune
/// these from Settings → Pricing Rules.
class PricingRules {
  final AppCurrency currency;

  final Map<FrameMaterial, double> framePricePerMeter;
  final Map<GlassType, double> glassPricePerSqm;
  final Map<PanelType, double> panelPricePerSqm;

  final double hingePriceEach;
  final double handleBasePrice;
  final Map<LockType, double> lockPrice;
  final Map<DoorCloserType, double> doorCloserPrice;
  final double accessoryFlatPrice;
  final double mosquitoNetPricePerSqm;
  final double sealPricePerMeter;

  final LaborMode laborMode;
  final double laborPercent; // used when laborMode == percentageOfMaterials
  final double laborFixedPerUnit; // used when laborMode == fixedPerUnit

  final Map<FrameColor, double> finishMultiplier;

  final double wastePercent;
  final double overheadPercent;
  final double profitPercent;

  final double installationPricePerUnit;
  final double deliveryFlatPrice;

  const PricingRules({
    this.currency = AppCurrency.usd,
    this.framePricePerMeter = const {
      FrameMaterial.aluminum: 14.5,
      FrameMaterial.upvc: 11.0,
      FrameMaterial.wood: 22.0,
      FrameMaterial.steel: 28.0,
    },
    this.glassPricePerSqm = const {
      GlassType.clear: 32.0,
      GlassType.frosted: 38.0,
      GlassType.tinted: 40.0,
      GlassType.tempered: 48.0,
      GlassType.laminated: 58.0,
      GlassType.doubleGlazed: 72.0,
      GlassType.tripleGlazed: 96.0,
      GlassType.custom: 60.0,
    },
    this.panelPricePerSqm = const {
      PanelType.solid: 45.0,
      PanelType.glass: 32.0,
      PanelType.decorative: 60.0,
    },
    this.hingePriceEach = 4.5,
    this.handleBasePrice = 18.0,
    this.lockPrice = const {
      LockType.none: 0,
      LockType.standardCylinder: 15.0,
      LockType.multiPointLock: 55.0,
      LockType.mortiseKeyLock: 35.0,
      LockType.smartLock: 140.0,
    },
    this.doorCloserPrice = const {
      DoorCloserType.none: 0,
      DoorCloserType.standard: 40.0,
      DoorCloserType.concealed: 85.0,
      DoorCloserType.floorSpring: 120.0,
    },
    this.accessoryFlatPrice = 12.0,
    this.mosquitoNetPricePerSqm = 18.0,
    this.sealPricePerMeter = 1.2,
    this.laborMode = LaborMode.percentageOfMaterials,
    this.laborPercent = 0.10,
    this.laborFixedPerUnit = 45.0,
    this.finishMultiplier = const {
      FrameColor.white: 1.0,
      FrameColor.black: 1.03,
      FrameColor.darkGreen: 1.05,
      FrameColor.woodFinish: 1.18,
      FrameColor.anthracite: 1.05,
      FrameColor.silver: 1.0,
      FrameColor.bronze: 1.12,
      FrameColor.custom: 1.25,
    },
    this.wastePercent = 0.05,
    this.overheadPercent = 0.08,
    this.profitPercent = 0.20,
    this.installationPricePerUnit = 40.0,
    this.deliveryFlatPrice = 100.0,
  });

  PricingRules copyWith({
    AppCurrency? currency,
    Map<FrameMaterial, double>? framePricePerMeter,
    Map<GlassType, double>? glassPricePerSqm,
    Map<PanelType, double>? panelPricePerSqm,
    double? hingePriceEach,
    double? handleBasePrice,
    Map<LockType, double>? lockPrice,
    Map<DoorCloserType, double>? doorCloserPrice,
    double? accessoryFlatPrice,
    double? mosquitoNetPricePerSqm,
    double? sealPricePerMeter,
    LaborMode? laborMode,
    double? laborPercent,
    double? laborFixedPerUnit,
    Map<FrameColor, double>? finishMultiplier,
    double? wastePercent,
    double? overheadPercent,
    double? profitPercent,
    double? installationPricePerUnit,
    double? deliveryFlatPrice,
  }) {
    return PricingRules(
      currency: currency ?? this.currency,
      framePricePerMeter: framePricePerMeter ?? this.framePricePerMeter,
      glassPricePerSqm: glassPricePerSqm ?? this.glassPricePerSqm,
      panelPricePerSqm: panelPricePerSqm ?? this.panelPricePerSqm,
      hingePriceEach: hingePriceEach ?? this.hingePriceEach,
      handleBasePrice: handleBasePrice ?? this.handleBasePrice,
      lockPrice: lockPrice ?? this.lockPrice,
      doorCloserPrice: doorCloserPrice ?? this.doorCloserPrice,
      accessoryFlatPrice: accessoryFlatPrice ?? this.accessoryFlatPrice,
      mosquitoNetPricePerSqm: mosquitoNetPricePerSqm ?? this.mosquitoNetPricePerSqm,
      sealPricePerMeter: sealPricePerMeter ?? this.sealPricePerMeter,
      laborMode: laborMode ?? this.laborMode,
      laborPercent: laborPercent ?? this.laborPercent,
      laborFixedPerUnit: laborFixedPerUnit ?? this.laborFixedPerUnit,
      finishMultiplier: finishMultiplier ?? this.finishMultiplier,
      wastePercent: wastePercent ?? this.wastePercent,
      overheadPercent: overheadPercent ?? this.overheadPercent,
      profitPercent: profitPercent ?? this.profitPercent,
      installationPricePerUnit: installationPricePerUnit ?? this.installationPricePerUnit,
      deliveryFlatPrice: deliveryFlatPrice ?? this.deliveryFlatPrice,
    );
  }

  static Map<String, double> _enumMapToJson<T extends Enum>(Map<T, double> map) =>
      map.map((k, v) => MapEntry(k.name, v));

  static Map<T, double> _enumMapFromJson<T extends Enum>(
    Map<String, dynamic>? json,
    List<T> values,
    Map<T, double> fallback,
  ) {
    if (json == null) return fallback;
    final result = <T, double>{};
    for (final v in values) {
      final raw = json[v.name];
      result[v] = raw is num ? raw.toDouble() : (fallback[v] ?? 0);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'currency': currency.toJson(),
        'framePricePerMeter': _enumMapToJson(framePricePerMeter),
        'glassPricePerSqm': _enumMapToJson(glassPricePerSqm),
        'panelPricePerSqm': _enumMapToJson(panelPricePerSqm),
        'hingePriceEach': hingePriceEach,
        'handleBasePrice': handleBasePrice,
        'lockPrice': _enumMapToJson(lockPrice),
        'doorCloserPrice': _enumMapToJson(doorCloserPrice),
        'accessoryFlatPrice': accessoryFlatPrice,
        'mosquitoNetPricePerSqm': mosquitoNetPricePerSqm,
        'sealPricePerMeter': sealPricePerMeter,
        'laborMode': laborMode.name,
        'laborPercent': laborPercent,
        'laborFixedPerUnit': laborFixedPerUnit,
        'finishMultiplier': _enumMapToJson(finishMultiplier),
        'wastePercent': wastePercent,
        'overheadPercent': overheadPercent,
        'profitPercent': profitPercent,
        'installationPricePerUnit': installationPricePerUnit,
        'deliveryFlatPrice': deliveryFlatPrice,
      };

  factory PricingRules.fromJson(Map<String, dynamic> json) {
    const defaults = PricingRules();
    return PricingRules(
      currency: json['currency'] != null
          ? AppCurrency.fromJson(Map<String, dynamic>.from(json['currency'] as Map))
          : AppCurrency.usd,
      framePricePerMeter: _enumMapFromJson(
        json['framePricePerMeter'] as Map<String, dynamic>?,
        FrameMaterial.values,
        defaults.framePricePerMeter,
      ),
      glassPricePerSqm: _enumMapFromJson(
        json['glassPricePerSqm'] as Map<String, dynamic>?,
        GlassType.values,
        defaults.glassPricePerSqm,
      ),
      panelPricePerSqm: _enumMapFromJson(
        json['panelPricePerSqm'] as Map<String, dynamic>?,
        PanelType.values,
        defaults.panelPricePerSqm,
      ),
      hingePriceEach: (json['hingePriceEach'] as num?)?.toDouble() ?? defaults.hingePriceEach,
      handleBasePrice: (json['handleBasePrice'] as num?)?.toDouble() ?? defaults.handleBasePrice,
      lockPrice: _enumMapFromJson(
        json['lockPrice'] as Map<String, dynamic>?,
        LockType.values,
        defaults.lockPrice,
      ),
      doorCloserPrice: _enumMapFromJson(
        json['doorCloserPrice'] as Map<String, dynamic>?,
        DoorCloserType.values,
        defaults.doorCloserPrice,
      ),
      accessoryFlatPrice: (json['accessoryFlatPrice'] as num?)?.toDouble() ?? defaults.accessoryFlatPrice,
      mosquitoNetPricePerSqm:
          (json['mosquitoNetPricePerSqm'] as num?)?.toDouble() ?? defaults.mosquitoNetPricePerSqm,
      sealPricePerMeter: (json['sealPricePerMeter'] as num?)?.toDouble() ?? defaults.sealPricePerMeter,
      laborMode: LaborMode.values.firstWhere(
        (e) => e.name == json['laborMode'],
        orElse: () => LaborMode.percentageOfMaterials,
      ),
      laborPercent: (json['laborPercent'] as num?)?.toDouble() ?? defaults.laborPercent,
      laborFixedPerUnit: (json['laborFixedPerUnit'] as num?)?.toDouble() ?? defaults.laborFixedPerUnit,
      finishMultiplier: _enumMapFromJson(
        json['finishMultiplier'] as Map<String, dynamic>?,
        FrameColor.values,
        defaults.finishMultiplier,
      ),
      wastePercent: (json['wastePercent'] as num?)?.toDouble() ?? defaults.wastePercent,
      overheadPercent: (json['overheadPercent'] as num?)?.toDouble() ?? defaults.overheadPercent,
      profitPercent: (json['profitPercent'] as num?)?.toDouble() ?? defaults.profitPercent,
      installationPricePerUnit:
          (json['installationPricePerUnit'] as num?)?.toDouble() ?? defaults.installationPricePerUnit,
      deliveryFlatPrice: (json['deliveryFlatPrice'] as num?)?.toDouble() ?? defaults.deliveryFlatPrice,
    );
  }
}

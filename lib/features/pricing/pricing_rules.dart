import '../../shared/models/materials.dart';

/// Rates a factory can edit. Nothing here is baked into the UI (§66) — the
/// engine reads these numbers and the settings screen writes them.
class PricingRules {
  final String currencySymbol;

  /// Cost per linear metre of outer frame profile, by material.
  final Map<FrameMaterial, double> framePerMetre;

  /// Cost per linear metre of sash / leaf profile.
  final Map<FrameMaterial, double> sashPerMetre;

  /// Cost per linear metre of mullion / transom.
  final Map<FrameMaterial, double> barPerMetre;

  /// Cost per square metre of glazing, by glass type.
  final Map<GlassType, double> glassPerSquareMetre;

  /// Cost per square metre of solid infill, by panel material.
  final Map<PanelMaterial, double> panelPerSquareMetre;

  final double hingeEach;
  final double handleEach;
  final double lockEach;
  final double slidingTrackPerMetre;
  final double sealPerMetre;
  final double thresholdPerMetre;
  final double sillPerMetre;

  /// Labour is charged on the finished area.
  final double labourPerSquareMetre;
  final double installationPerSquareMetre;

  /// Fractions, 0..1.
  final double wasteRate;
  final double overheadRate;
  final double profitRate;

  const PricingRules({
    this.currencySymbol = '\$',
    this.framePerMetre = const {
      FrameMaterial.aluminium: 14.5,
      FrameMaterial.upvc: 11.0,
      FrameMaterial.steel: 18.0,
      FrameMaterial.wood: 22.0,
    },
    this.sashPerMetre = const {
      FrameMaterial.aluminium: 12.0,
      FrameMaterial.upvc: 9.5,
      FrameMaterial.steel: 15.5,
      FrameMaterial.wood: 19.0,
    },
    this.barPerMetre = const {
      FrameMaterial.aluminium: 13.0,
      FrameMaterial.upvc: 10.0,
      FrameMaterial.steel: 16.5,
      FrameMaterial.wood: 20.0,
    },
    this.glassPerSquareMetre = const {
      GlassType.clearSingle: 22.0,
      GlassType.clearDouble: 46.0,
      GlassType.tinted: 34.0,
      GlassType.frosted: 30.0,
      GlassType.reflective: 42.0,
      GlassType.laminated: 58.0,
      GlassType.lowE: 64.0,
    },
    this.panelPerSquareMetre = const {
      PanelMaterial.sandwichPanel: 52.0,
      PanelMaterial.aluminiumSheet: 38.0,
      PanelMaterial.mdf: 26.0,
      PanelMaterial.solidWood: 74.0,
      PanelMaterial.louvre: 44.0,
    },
    this.hingeEach = 4.2,
    this.handleEach = 16.0,
    this.lockEach = 24.0,
    this.slidingTrackPerMetre = 9.5,
    this.sealPerMetre = 1.6,
    this.thresholdPerMetre = 12.0,
    this.sillPerMetre = 15.0,
    this.labourPerSquareMetre = 28.0,
    this.installationPerSquareMetre = 18.0,
    this.wasteRate = 0.07,
    this.overheadRate = 0.10,
    this.profitRate = 0.15,
  });

  PricingRules copyWith({
    String? currencySymbol,
    double? labourPerSquareMetre,
    double? installationPerSquareMetre,
    double? wasteRate,
    double? overheadRate,
    double? profitRate,
  }) =>
      PricingRules(
        currencySymbol: currencySymbol ?? this.currencySymbol,
        framePerMetre: framePerMetre,
        sashPerMetre: sashPerMetre,
        barPerMetre: barPerMetre,
        glassPerSquareMetre: glassPerSquareMetre,
        panelPerSquareMetre: panelPerSquareMetre,
        hingeEach: hingeEach,
        handleEach: handleEach,
        lockEach: lockEach,
        slidingTrackPerMetre: slidingTrackPerMetre,
        sealPerMetre: sealPerMetre,
        thresholdPerMetre: thresholdPerMetre,
        sillPerMetre: sillPerMetre,
        labourPerSquareMetre: labourPerSquareMetre ?? this.labourPerSquareMetre,
        installationPerSquareMetre:
            installationPerSquareMetre ?? this.installationPerSquareMetre,
        wasteRate: wasteRate ?? this.wasteRate,
        overheadRate: overheadRate ?? this.overheadRate,
        profitRate: profitRate ?? this.profitRate,
      );

  Map<String, dynamic> toJson() => {
        'currencySymbol': currencySymbol,
        'labourPerSquareMetre': labourPerSquareMetre,
        'installationPerSquareMetre': installationPerSquareMetre,
        'wasteRate': wasteRate,
        'overheadRate': overheadRate,
        'profitRate': profitRate,
      };

  factory PricingRules.fromJson(Map<String, dynamic> json) => const PricingRules().copyWith(
        currencySymbol: json['currencySymbol'] as String?,
        labourPerSquareMetre: (json['labourPerSquareMetre'] as num?)?.toDouble(),
        installationPerSquareMetre: (json['installationPerSquareMetre'] as num?)?.toDouble(),
        wasteRate: (json['wasteRate'] as num?)?.toDouble(),
        overheadRate: (json['overheadRate'] as num?)?.toDouble(),
        profitRate: (json['profitRate'] as num?)?.toDouble(),
      );
}

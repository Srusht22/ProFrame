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
    Map<FrameMaterial, double>? framePerMetre,
    Map<FrameMaterial, double>? sashPerMetre,
    Map<FrameMaterial, double>? barPerMetre,
    Map<GlassType, double>? glassPerSquareMetre,
    Map<PanelMaterial, double>? panelPerSquareMetre,
    double? hingeEach,
    double? handleEach,
    double? lockEach,
    double? slidingTrackPerMetre,
    double? sealPerMetre,
    double? thresholdPerMetre,
    double? sillPerMetre,
    double? labourPerSquareMetre,
    double? installationPerSquareMetre,
    double? wasteRate,
    double? overheadRate,
    double? profitRate,
  }) =>
      PricingRules(
        currencySymbol: currencySymbol ?? this.currencySymbol,
        framePerMetre: framePerMetre ?? this.framePerMetre,
        sashPerMetre: sashPerMetre ?? this.sashPerMetre,
        barPerMetre: barPerMetre ?? this.barPerMetre,
        glassPerSquareMetre: glassPerSquareMetre ?? this.glassPerSquareMetre,
        panelPerSquareMetre: panelPerSquareMetre ?? this.panelPerSquareMetre,
        hingeEach: hingeEach ?? this.hingeEach,
        handleEach: handleEach ?? this.handleEach,
        lockEach: lockEach ?? this.lockEach,
        slidingTrackPerMetre: slidingTrackPerMetre ?? this.slidingTrackPerMetre,
        sealPerMetre: sealPerMetre ?? this.sealPerMetre,
        thresholdPerMetre: thresholdPerMetre ?? this.thresholdPerMetre,
        sillPerMetre: sillPerMetre ?? this.sillPerMetre,
        labourPerSquareMetre: labourPerSquareMetre ?? this.labourPerSquareMetre,
        installationPerSquareMetre:
            installationPerSquareMetre ?? this.installationPerSquareMetre,
        wasteRate: wasteRate ?? this.wasteRate,
        overheadRate: overheadRate ?? this.overheadRate,
        profitRate: profitRate ?? this.profitRate,
      );

  /// Replaces one entry of a rate map without disturbing the others.
  PricingRules withFrameRate(FrameMaterial material, double value) =>
      copyWith(framePerMetre: {...framePerMetre, material: value});

  PricingRules withSashRate(FrameMaterial material, double value) =>
      copyWith(sashPerMetre: {...sashPerMetre, material: value});

  PricingRules withBarRate(FrameMaterial material, double value) =>
      copyWith(barPerMetre: {...barPerMetre, material: value});

  PricingRules withGlassRate(GlassType type, double value) =>
      copyWith(glassPerSquareMetre: {...glassPerSquareMetre, type: value});

  PricingRules withPanelRate(PanelMaterial type, double value) =>
      copyWith(panelPerSquareMetre: {...panelPerSquareMetre, type: value});

  static Map<String, dynamic> _mapToJson<T extends Enum>(Map<T, double> map) =>
      {for (final entry in map.entries) entry.key.name: entry.value};

  static Map<T, double> _mapFromJson<T extends Enum>(
    Object? raw,
    List<T> values,
    Map<T, double> fallback,
  ) {
    if (raw is! Map) return fallback;
    final result = Map<T, double>.from(fallback);
    raw.forEach((key, value) {
      final match = values.where((v) => v.name == key);
      final number = value is num ? value.toDouble() : null;
      if (match.isNotEmpty && number != null && number >= 0) {
        result[match.first] = number;
      }
    });
    return result;
  }

  Map<String, dynamic> toJson() => {
        'currencySymbol': currencySymbol,
        'framePerMetre': _mapToJson(framePerMetre),
        'sashPerMetre': _mapToJson(sashPerMetre),
        'barPerMetre': _mapToJson(barPerMetre),
        'glassPerSquareMetre': _mapToJson(glassPerSquareMetre),
        'panelPerSquareMetre': _mapToJson(panelPerSquareMetre),
        'hingeEach': hingeEach,
        'handleEach': handleEach,
        'lockEach': lockEach,
        'slidingTrackPerMetre': slidingTrackPerMetre,
        'sealPerMetre': sealPerMetre,
        'thresholdPerMetre': thresholdPerMetre,
        'sillPerMetre': sillPerMetre,
        'labourPerSquareMetre': labourPerSquareMetre,
        'installationPerSquareMetre': installationPerSquareMetre,
        'wasteRate': wasteRate,
        'overheadRate': overheadRate,
        'profitRate': profitRate,
      };

  /// Anything missing or malformed falls back to the shipped default, so a
  /// partially-written settings file can never leave the app unable to price.
  factory PricingRules.fromJson(Map<String, dynamic> json) {
    const defaults = PricingRules();
    double number(String key, double fallback) {
      final value = json[key];
      return value is num && value >= 0 ? value.toDouble() : fallback;
    }

    return PricingRules(
      currencySymbol: (json['currencySymbol'] as String?)?.trim().isNotEmpty == true
          ? json['currencySymbol'] as String
          : defaults.currencySymbol,
      framePerMetre: _mapFromJson(
          json['framePerMetre'], FrameMaterial.values, defaults.framePerMetre),
      sashPerMetre: _mapFromJson(
          json['sashPerMetre'], FrameMaterial.values, defaults.sashPerMetre),
      barPerMetre:
          _mapFromJson(json['barPerMetre'], FrameMaterial.values, defaults.barPerMetre),
      glassPerSquareMetre: _mapFromJson(
          json['glassPerSquareMetre'], GlassType.values, defaults.glassPerSquareMetre),
      panelPerSquareMetre: _mapFromJson(json['panelPerSquareMetre'],
          PanelMaterial.values, defaults.panelPerSquareMetre),
      hingeEach: number('hingeEach', defaults.hingeEach),
      handleEach: number('handleEach', defaults.handleEach),
      lockEach: number('lockEach', defaults.lockEach),
      slidingTrackPerMetre:
          number('slidingTrackPerMetre', defaults.slidingTrackPerMetre),
      sealPerMetre: number('sealPerMetre', defaults.sealPerMetre),
      thresholdPerMetre: number('thresholdPerMetre', defaults.thresholdPerMetre),
      sillPerMetre: number('sillPerMetre', defaults.sillPerMetre),
      labourPerSquareMetre:
          number('labourPerSquareMetre', defaults.labourPerSquareMetre),
      installationPerSquareMetre:
          number('installationPerSquareMetre', defaults.installationPerSquareMetre),
      wasteRate: number('wasteRate', defaults.wasteRate),
      overheadRate: number('overheadRate', defaults.overheadRate),
      profitRate: number('profitRate', defaults.profitRate),
    );
  }
}

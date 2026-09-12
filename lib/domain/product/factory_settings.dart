import 'dart:convert';

import '../../core/units/length_unit.dart';
import 'finish.dart';
import 'product_basics.dart';

/// The defaults a factory sets once, so ordinary users never have to
/// (spec section 9).
///
/// These are *starting points for a new design*, not constraints on it: a
/// salesperson can still change any of them per project. What they remove is
/// the need to re-enter the same technical answers on every job.
class FactorySettings {
  static const int currentVersion = 1;

  final FrameMaterial defaultMaterial;
  final String defaultFinishId;

  /// Which side drawings are read from in this factory.
  final ViewingSide defaultViewingSide;

  /// What dimensions mean here by default.
  final DimensionReference defaultDimensionReference;

  /// The gap left each side when fitting into a wall opening.
  ///
  /// Only ever applied when the reference is
  /// [DimensionReference.wallOpening], and always shown — never hidden
  /// (spec section 6).
  final double fittingGapMm;

  /// What the staff type and read.
  final LengthUnit displayUnit;

  const FactorySettings({
    this.defaultMaterial = FrameMaterial.pvc,
    this.defaultFinishId = 'white',
    this.defaultViewingSide = ViewingSide.outside,
    this.defaultDimensionReference = DimensionReference.outerFrame,
    this.fittingGapMm = 10,
    this.displayUnit = LengthUnit.centimetre,
  });

  static const FactorySettings standard = FactorySettings();

  Finish get defaultFinish =>
      StockFinishes.all.where((f) => f.id == defaultFinishId).firstOrNull ??
      StockFinishes.factoryDefault;

  FactorySettings copyWith({
    FrameMaterial? defaultMaterial,
    String? defaultFinishId,
    ViewingSide? defaultViewingSide,
    DimensionReference? defaultDimensionReference,
    double? fittingGapMm,
    LengthUnit? displayUnit,
  }) =>
      FactorySettings(
        defaultMaterial: defaultMaterial ?? this.defaultMaterial,
        defaultFinishId: defaultFinishId ?? this.defaultFinishId,
        defaultViewingSide: defaultViewingSide ?? this.defaultViewingSide,
        defaultDimensionReference:
            defaultDimensionReference ?? this.defaultDimensionReference,
        fittingGapMm: fittingGapMm ?? this.fittingGapMm,
        displayUnit: displayUnit ?? this.displayUnit,
      );

  String encode() => jsonEncode({
        'version': currentVersion,
        'material': defaultMaterial.name,
        'finish': defaultFinishId,
        'viewingSide': defaultViewingSide.name,
        'dimensionReference': defaultDimensionReference.name,
        'fittingGapMm': fittingGapMm,
        'displayUnit': displayUnit.name,
      });

  /// Reads stored settings.
  ///
  /// Anything unreadable falls back to [standard] rather than throwing: these
  /// are preferences, and refusing to start the app over a damaged preference
  /// file would be out of all proportion.
  static FactorySettings decode(String? raw) {
    if (raw == null) return standard;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return standard;
      return FactorySettings(
        defaultMaterial: FrameMaterial.values
                .where((m) => m.name == json['material'])
                .firstOrNull ??
            standard.defaultMaterial,
        defaultFinishId: json['finish'] is String
            ? json['finish'] as String
            : standard.defaultFinishId,
        defaultViewingSide: ViewingSide.values
                .where((v) => v.name == json['viewingSide'])
                .firstOrNull ??
            standard.defaultViewingSide,
        defaultDimensionReference: DimensionReference.values
                .where((r) => r.name == json['dimensionReference'])
                .firstOrNull ??
            standard.defaultDimensionReference,
        fittingGapMm: json['fittingGapMm'] is num
            ? (json['fittingGapMm'] as num).toDouble()
            : standard.fittingGapMm,
        displayUnit: LengthUnit.values
                .where((u) => u.name == json['displayUnit'])
                .firstOrNull ??
            standard.displayUnit,
      );
    } on Object {
      return standard;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FactorySettings &&
      other.defaultMaterial == defaultMaterial &&
      other.defaultFinishId == defaultFinishId &&
      other.defaultViewingSide == defaultViewingSide &&
      other.defaultDimensionReference == defaultDimensionReference &&
      other.fittingGapMm == fittingGapMm &&
      other.displayUnit == displayUnit;

  @override
  int get hashCode => Object.hash(
        defaultMaterial,
        defaultFinishId,
        defaultViewingSide,
        defaultDimensionReference,
        fittingGapMm,
        displayUnit,
      );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

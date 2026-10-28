import '../model/materials.dart';
import '../text/numerals.dart';

/// The factory's usual sizes for one kind of profile: the frame's border,
/// the thickness of the lines inside it, and how deep it is — each in
/// millimetres, and each null until the factory says.
///
/// **A default is the factory's own figure, never a size read off a
/// sketch.** It is what the workshop builds a uPVC or an aluminium frame
/// with unless a design says otherwise, set once by whoever keeps the
/// factory's figures so nobody types the same border into every design. It
/// fills nothing by itself: the sizes form offers it, the user sees it in
/// the fields and can type over it for that one design, and only **Apply**
/// puts it into the design — where it is that design's from then on, and a
/// later change to the default leaves it alone.
class ProfileDefaults {
  /// The frame's border, as the sizes form's *Frame border*.
  final double? borderMm;

  /// Every bar's thickness, as the sizes form's *Bar thickness*.
  final double? barMm;

  /// How deep the frame is, front to back.
  final double? depthMm;

  const ProfileDefaults({this.borderMm, this.barMm, this.depthMm});

  static const none = ProfileDefaults();

  /// Whether the factory has said none of them.
  bool get isEmpty => borderMm == null && barMm == null && depthMm == null;

  Map<String, Object?> toJson() => {
    if (borderMm != null) 'borderMm': borderMm,
    if (barMm != null) 'barMm': barMm,
    if (depthMm != null) 'depthMm': depthMm,
  };

  /// What [raw] says, a figure that is not a size — not a number, nothing
  /// or less — being no figure at all.
  static ProfileDefaults fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return none;
    double? size(Object? v) =>
        v is num && v.isFinite && v > 0 ? v.toDouble() : null;
    return ProfileDefaults(
      borderMm: size(raw['borderMm']),
      barMm: size(raw['barMm']),
      depthMm: size(raw['depthMm']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileDefaults &&
      other.borderMm == borderMm &&
      other.barMm == barMm &&
      other.depthMm == depthMm;

  @override
  int get hashCode => Object.hash(borderMm, barMm, depthMm);
}

/// The factory's usual sizes, one set for each kind of profile it sells —
/// uPVC, aluminium — kept apart from its prices.
class MeasurementDefaults {
  final Map<MaterialKind, ProfileDefaults> byMaterial;

  const MeasurementDefaults([this.byMaterial = const {}]);

  static const none = MeasurementDefaults();

  /// What the factory said for [material], or nothing.
  ProfileDefaults of(MaterialKind material) =>
      byMaterial[material] ?? ProfileDefaults.none;

  /// The materials with anything said, in [order].
  List<MaterialKind> said(Iterable<MaterialKind> order) => [
    for (final m in order)
      if (!of(m).isEmpty) m,
  ];

  MeasurementDefaults withMaterial(MaterialKind m, ProfileDefaults d) =>
      MeasurementDefaults({...byMaterial, m: d});

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'materials': {
      for (final e in byMaterial.entries)
        if (!e.value.isEmpty) e.key.name: e.value.toJson(),
    },
  };

  /// What [raw] says; a material this version does not know is passed
  /// over, and anything that cannot be read is nothing said.
  static MeasurementDefaults fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return none;
    final materials = raw['materials'];
    if (materials is! Map<String, Object?>) return none;
    return MeasurementDefaults({
      for (final e in materials.entries)
        if (MaterialKind.values.where((m) => m.name == e.key).firstOrNull
            case final m?)
          if (ProfileDefaults.fromJson(e.value) case final d when !d.isEmpty)
            m: d,
    });
  }

  /// A figure typed in centimetres, as millimetres: null for an empty field
  /// (nothing said), and [invalid] for one that is not a size.
  static double? readCm(String text) {
    final t = Numerals.latin(text).trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || !v.isFinite || v <= 0) return invalid;
    return v * 10;
  }

  /// What [readCm] gives for a figure that is not a size.
  static const invalid = -1.0;
}

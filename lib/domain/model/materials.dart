/// What a part is made of. Affects how it is drawn, how it is rendered in 3D,
/// and what the maker reads off the summary.
enum MaterialKind {
  upvc('uPVC'),
  aluminium('Aluminium'),
  wood('Wood'),
  steel('Steel'),
  clearGlass('Clear glass'),
  frostedGlass('Frosted glass'),
  tintedGlass('Tinted glass'),
  panel('Solid panel'),
  louvre('Louvre'),
  mesh('Insect mesh');

  const MaterialKind(this.label);
  final String label;

  /// True when you can see through it, which is what decides whether a
  /// section is drawn as a pane or as a solid face.
  bool get isGlazing =>
      this == clearGlass || this == frostedGlass || this == tintedGlass;

  /// How much light passes, 0 opaque to 1 clear. Used by the renderer only.
  double get transparency => switch (this) {
        clearGlass => 0.82,
        tintedGlass => 0.55,
        frostedGlass => 0.35,
        mesh => 0.25,
        _ => 0,
      };

  /// How shiny, 0 matt to 1 mirror.
  double get gloss => switch (this) {
        aluminium => 0.55,
        steel => 0.6,
        upvc => 0.32,
        wood => 0.18,
        clearGlass || tintedGlass => 0.9,
        frostedGlass => 0.4,
        _ => 0.2,
      };
}

/// The colour and material of one part, as the user set it.
///
/// Nothing here has a default the application invents for the user beyond the
/// neutral starting point: whatever the user picks is what is built.
class Finish {
  /// 0xAARRGGBB.
  final int colour;
  final MaterialKind material;

  const Finish({this.colour = 0xFFFFFFFF, this.material = MaterialKind.upvc});

  static const Finish frameDefault =
      Finish(colour: 0xFFF3F4F2, material: MaterialKind.upvc);
  static const Finish glazingDefault =
      Finish(colour: 0xFFD8E6EA, material: MaterialKind.clearGlass);

  Finish copyWith({int? colour, MaterialKind? material}) =>
      Finish(colour: colour ?? this.colour, material: material ?? this.material);

  Map<String, Object?> toJson() => {'colour': colour, 'material': material.name};

  static Finish fromJson(Object? json, {Finish fallback = frameDefault}) {
    if (json == null) return fallback;
    final map = json as Map<String, Object?>;
    return Finish(
      colour: (map['colour'] as num?)?.toInt() ?? fallback.colour,
      material: MaterialKind.values.firstWhere(
        (m) => m.name == map['material'],
        orElse: () => fallback.material,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Finish && other.colour == colour && other.material == material;

  @override
  int get hashCode => Object.hash(colour, material);
}

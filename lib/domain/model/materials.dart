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
/// The finishes ironmongery is actually sold in.
///
/// A handle is bought in a finish, not mixed to a colour, so these are the
/// ones a joiner orders by name. They are here rather than in the inspector
/// because the solid has to build the piece in the chosen one and a test has
/// to be able to ask what "silver" is — one list, read by both, rather than a
/// row of swatches in a widget and a number written out again somewhere else.
///
/// Anything outside the list is the user's own: `Finish.colour` takes any
/// value and **Custom** opens the full picker. Nothing here limits what can
/// be built; it is the short way to the usual answer.
enum HardwareColour {
  black('Black', 0xFF1C1C1C),
  white('White', 0xFFF2F2F0),
  silver('Silver', 0xFFC3C7C9),
  grey('Grey', 0xFF7C8285),
  bronze('Bronze', 0xFF8C6A3F),
  brown('Brown', 0xFF4E3524);

  const HardwareColour(this.label, this.colour);

  final String label;

  /// 0xAARRGGBB, the value the facets are built with.
  final int colour;

  /// The one of these [colour] is, or null when it is the user's own.
  static HardwareColour? of(int colour) {
    for (final option in values) {
      if (option.colour == colour) return option;
    }
    return null;
  }
}

/// The glass a joiner orders by name, for a part the user says is glass.
///
/// Each is a real glazing material in a real colour, and both go on the
/// pane's own geometry — the solid builds it in that colour and lets that
/// much light through. There is no picture of glass anywhere; a frosted
/// pane is a pane that lets less through. **Custom** keeps the glass and
/// takes any colour.
enum GlassLook {
  clear('Clear', MaterialKind.clearGlass, 0xFFD8E6EA),
  tinted('Tinted', MaterialKind.tintedGlass, 0xFF8E9E98),
  frosted('Frosted', MaterialKind.frostedGlass, 0xFFE4EAEC),
  dark('Dark', MaterialKind.tintedGlass, 0xFF3B4347),
  blueGrey('Blue-grey', MaterialKind.tintedGlass, 0xFF7D93A6);

  const GlassLook(this.label, this.material, this.colour);

  final String label;
  final MaterialKind material;

  /// 0xAARRGGBB.
  final int colour;

  Finish get finish => Finish(colour: colour, material: material);

  /// The one of these [finish] is, or null when it is the user's own.
  static GlassLook? of(Finish finish) {
    for (final look in values) {
      if (look.material == finish.material && look.colour == finish.colour) {
        return look;
      }
    }
    return null;
  }
}

/// The colours a door panel is ordered in, for a part the user says is
/// panel. **Custom** opens the full picker for anything else.
///
/// Nothing here is picked for the user: a part is made a panel in the
/// colour they tap, and the colour goes on the panel's own geometry.
enum PanelColour {
  white('White', 0xFFF4F4F1),
  black('Black', 0xFF1E1F1F),
  grey('Grey', 0xFF8C9094),
  brown('Brown', 0xFF5A3D2B);

  const PanelColour(this.label, this.colour);

  final String label;

  /// 0xAARRGGBB.
  final int colour;

  Finish get finish => Finish(colour: colour, material: MaterialKind.panel);

  /// The one of these [finish] is, or null when it is not a panel or its
  /// colour is the user's own.
  static PanelColour? of(Finish finish) {
    if (finish.material != MaterialKind.panel) return null;
    for (final option in values) {
      if (option.colour == finish.colour) return option;
    }
    return null;
  }
}

/// The materials a piece of ironmongery is made of.
///
/// The glazing kinds are not among them: a handle is not made of clear
/// glass, and offering it would be the panel asking a question that has no
/// sensible answer.
const List<MaterialKind> hardwareMaterials = [
  MaterialKind.aluminium,
  MaterialKind.steel,
  MaterialKind.upvc,
  MaterialKind.wood,
];

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

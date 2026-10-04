import '../model/elements.dart';
import '../model/materials.dart';

/// The workshop's prices: every figure the pricing engine multiplies by,
/// and nothing else.
///
/// **Prices live here and only here.** No widget, no geometry and no
/// strategy holds a figure of its own: a strategy says *what* is charged —
/// a metre of frame, a square metre of glass, a hinge — and reads *how
/// much* from the list. So the owner changes a price by changing the list,
/// and nothing that draws or builds a design is touched.
///
/// Every amount is in [currency], per the unit it names: a metre of
/// profile, a square metre of glass or panel, one piece of ironmongery.
/// Sizes come in from the design in millimetres and are turned into metres
/// and square metres once, by the takeoff, so a centimetre is never
/// multiplied by a price per metre.
class PriceList {
  /// Bumped every time the list is changed and kept, so a price worked out
  /// from it can say which list it came from.
  final int version;

  /// True for the example list the application starts with, until the
  /// owner keeps one of their own. Its figures are examples, and the screen
  /// says so.
  final bool isStarter;

  final String currency;

  /// What each frame material's profile costs, and its colours. A design
  /// framed in a material with no entry here is not priced.
  final Map<MaterialKind, ProfileRate> profiles;

  /// Glass, by the look the user chose, a square metre of what is cut.
  final Map<GlassLook, double> glassPerM2;

  /// Glass the user gave a colour of their own, which matches no look — or
  /// null where the list does not price it.
  final double? customGlassPerM2;

  /// Panel, by colour, a square metre of what is cut.
  final Map<PanelColour, double> panelPerM2;

  /// A panel in a colour of the user's own, or null where the list does not
  /// price it.
  final double? customPanelPerM2;

  /// One piece of each kind of ironmongery.
  final Map<HardwareKind, double> hardwareEach;

  /// Making one leaf, by what it is: [LeafRate].
  final Map<LeafRate, double> leafEach;

  /// A sliding design's track, a metre of the frame's width.
  final double trackPerMetre;

  /// One roller, and how many a sliding panel runs on.
  final double rollerEach;
  final int rollersPerSlidingPanel;

  /// One joint of the frame that is not square, which an angled design is
  /// cut with.
  final double angledJointEach;

  /// How each category is made — its labour — by category name. A
  /// category with no entry is not priced.
  final Map<String, CategoryRate> categories;

  final InstallationRate installation;

  const PriceList({
    required this.currency,
    required this.profiles,
    required this.glassPerM2,
    required this.panelPerM2,
    required this.hardwareEach,
    required this.leafEach,
    required this.categories,
    required this.installation,
    this.version = 1,
    this.isStarter = false,
    this.customGlassPerM2,
    this.customPanelPerM2,
    this.trackPerMetre = 0,
    this.rollerEach = 0,
    this.rollersPerSlidingPanel = 2,
    this.angledJointEach = 0,
  });

  /// The example list the application starts with. Its figures are
  /// examples in Iraqi dinars, there to show how a price is made up until
  /// the owner keeps the workshop's own; the screen says so while it is in
  /// use ([isStarter]).
  static final PriceList starter = PriceList(
    isStarter: true,
    currency: 'IQD',
    profiles: {
      MaterialKind.upvc: const ProfileRate(
        framePerMetre: 20000,
        sashPerMetre: 18000,
        barPerMetre: 14000,
        colours: [
          ColourRate('White', 0xFFFFFFFF, ColourGrade.standard, 0),
          ColourRate('Off white', 0xFFF3F4F2, ColourGrade.standard, 0),
          ColourRate('Cream', 0xFFD8D5CC, ColourGrade.nonStandard, 10),
          ColourRate('Grey', 0xFF6E7472, ColourGrade.nonStandard, 12),
          ColourRate('Graphite', 0xFF3A3A38, ColourGrade.nonStandard, 12),
          ColourRate('Black', 0xFF1C1C1C, ColourGrade.nonStandard, 12),
          ColourRate('Oak effect', 0xFF7B4A2B, ColourGrade.nonStandard, 20),
          ColourRate('Walnut effect', 0xFF4A2F1E, ColourGrade.nonStandard, 20),
        ],
        specialColourPercent: 30,
      ),
      MaterialKind.aluminium: const ProfileRate(
        framePerMetre: 35000,
        sashPerMetre: 30000,
        barPerMetre: 24000,
        colours: [
          ColourRate('Silver', 0xFF9C9C9C, ColourGrade.standard, 0),
          ColourRate('White', 0xFFFFFFFF, ColourGrade.standard, 0),
          ColourRate('Off white', 0xFFF3F4F2, ColourGrade.standard, 0),
          ColourRate('Black', 0xFF1C1C1C, ColourGrade.nonStandard, 8),
          ColourRate('Anthracite', 0xFF383E42, ColourGrade.nonStandard, 8),
          ColourRate('Graphite', 0xFF3A3A38, ColourGrade.nonStandard, 8),
          ColourRate('Oak effect', 0xFF7B4A2B, ColourGrade.nonStandard, 18),
        ],
        specialColourPercent: 25,
      ),
    },
    glassPerM2: const {
      GlassLook.clear: 30000,
      GlassLook.frosted: 38000,
      GlassLook.tinted: 40000,
      GlassLook.dark: 42000,
      GlassLook.blueGrey: 42000,
    },
    customGlassPerM2: 45000,
    panelPerM2: const {
      PanelColour.white: 35000,
      PanelColour.grey: 40000,
      PanelColour.black: 40000,
      PanelColour.brown: 42000,
    },
    customPanelPerM2: 48000,
    hardwareEach: const {
      HardwareKind.handle: 15000,
      HardwareKind.lever: 20000,
      HardwareKind.knob: 12000,
      HardwareKind.lock: 30000,
      HardwareKind.hinge: 4000,
      HardwareKind.letterplate: 15000,
      HardwareKind.peephole: 8000,
      HardwareKind.closer: 35000,
      HardwareKind.pull: 18000,
      HardwareKind.screen: 60000,
      HardwareKind.sensor: 150000,
    },
    leafEach: const {
      LeafRate.door: 40000,
      LeafRate.window: 20000,
      LeafRate.sliding: 30000,
      LeafRate.unnamed: 20000,
    },
    trackPerMetre: 22000,
    rollerEach: 6000,
    angledJointEach: 7000,
    categories: const {
      'door': CategoryRate(
        'Door',
        LabourRate(fixed: 25000, perSquareMetre: 10000, percent: 5),
      ),
      'window': CategoryRate(
        'Window',
        LabourRate(fixed: 15000, perSquareMetre: 8000),
      ),
      'sliding': CategoryRate(
        'Sliding',
        LabourRate(fixed: 30000, perSquareMetre: 10000, percent: 5),
      ),
      'both': CategoryRate(
        'Door & window',
        LabourRate(fixed: 30000, perSquareMetre: 10000, percent: 5),
      ),
      'angled': CategoryRate(
        'Angled / Asymmetrical',
        LabourRate(fixed: 25000, perSquareMetre: 12000, percent: 10),
      ),
    },
    installation: const InstallationRate(fixed: 25000, perSquareMetre: 10000),
  );

  PriceList copyWith({
    int? version,
    bool? isStarter,
    String? currency,
    Map<MaterialKind, ProfileRate>? profiles,
    Map<GlassLook, double>? glassPerM2,
    double? customGlassPerM2,
    Map<PanelColour, double>? panelPerM2,
    double? customPanelPerM2,
    Map<HardwareKind, double>? hardwareEach,
    Map<LeafRate, double>? leafEach,
    double? trackPerMetre,
    double? rollerEach,
    int? rollersPerSlidingPanel,
    double? angledJointEach,
    Map<String, CategoryRate>? categories,
    InstallationRate? installation,
  }) => PriceList(
    version: version ?? this.version,
    isStarter: isStarter ?? this.isStarter,
    currency: currency ?? this.currency,
    profiles: profiles ?? this.profiles,
    glassPerM2: glassPerM2 ?? this.glassPerM2,
    customGlassPerM2: customGlassPerM2 ?? this.customGlassPerM2,
    panelPerM2: panelPerM2 ?? this.panelPerM2,
    customPanelPerM2: customPanelPerM2 ?? this.customPanelPerM2,
    hardwareEach: hardwareEach ?? this.hardwareEach,
    leafEach: leafEach ?? this.leafEach,
    trackPerMetre: trackPerMetre ?? this.trackPerMetre,
    rollerEach: rollerEach ?? this.rollerEach,
    rollersPerSlidingPanel:
        rollersPerSlidingPanel ?? this.rollersPerSlidingPanel,
    angledJointEach: angledJointEach ?? this.angledJointEach,
    categories: categories ?? this.categories,
    installation: installation ?? this.installation,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    if (isStarter) 'isStarter': true,
    'currency': currency,
    'profiles': {
      for (final e in profiles.entries) e.key.name: e.value.toJson(),
    },
    'glassPerM2': {for (final e in glassPerM2.entries) e.key.name: e.value},
    'customGlassPerM2': customGlassPerM2,
    'panelPerM2': {for (final e in panelPerM2.entries) e.key.name: e.value},
    'customPanelPerM2': customPanelPerM2,
    'hardwareEach': {for (final e in hardwareEach.entries) e.key.name: e.value},
    'leafEach': {for (final e in leafEach.entries) e.key.name: e.value},
    'trackPerMetre': trackPerMetre,
    'rollerEach': rollerEach,
    'rollersPerSlidingPanel': rollersPerSlidingPanel,
    'angledJointEach': angledJointEach,
    'categories': {for (final e in categories.entries) e.key: e.value.toJson()},
    'installation': installation.toJson(),
  };

  /// The list kept as [json]. **A figure that is not a price is left out
  /// rather than read as one** — not a number, below nothing, infinite —
  /// so a damaged entry leaves that thing unpriced, which the engine says,
  /// rather than priced at nonsense. Keys this version does not know — a
  /// material, a glass, a category from a later version — are passed over
  /// in the same way. Returns null where [json] is not a price list at all.
  static PriceList? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final currency = json['currency'];
    if (currency is! String || currency.isEmpty) return null;
    Map<K, double> rates<K>(Object? raw, K? Function(String) key) => {
      if (raw is Map<String, Object?>)
        for (final e in raw.entries)
          if (key(e.key) case final k? when price(e.value) != null)
            k: price(e.value)!,
    };
    return PriceList(
      version: (json['version'] as num?)?.toInt() ?? 1,
      isStarter: json['isStarter'] == true,
      currency: currency,
      profiles: {
        if (json['profiles'] case final Map<String, Object?> raw)
          for (final e in raw.entries)
            if ((
                  _byName(MaterialKind.values, e.key),
                  ProfileRate.fromJson(e.value),
                )
                case (final m?, final p?))
              m: p,
      },
      glassPerM2: rates(
        json['glassPerM2'],
        (k) => _byName(GlassLook.values, k),
      ),
      customGlassPerM2: price(json['customGlassPerM2']),
      panelPerM2: rates(
        json['panelPerM2'],
        (k) => _byName(PanelColour.values, k),
      ),
      customPanelPerM2: price(json['customPanelPerM2']),
      hardwareEach: rates(
        json['hardwareEach'],
        (k) => _byName(HardwareKind.values, k),
      ),
      leafEach: rates(json['leafEach'], (k) => _byName(LeafRate.values, k)),
      trackPerMetre: price(json['trackPerMetre']) ?? 0,
      rollerEach: price(json['rollerEach']) ?? 0,
      rollersPerSlidingPanel: (price(json['rollersPerSlidingPanel']) ?? 2)
          .round(),
      angledJointEach: price(json['angledJointEach']) ?? 0,
      categories: {
        if (json['categories'] case final Map<String, Object?> raw)
          for (final e in raw.entries) e.key: ?CategoryRate.fromJson(e.value),
      },
      installation: InstallationRate.fromJson(json['installation']),
    );
  }

  /// [raw] as a price: a finite number no less than nothing, or null.
  static double? price(Object? raw) =>
      raw is num && raw.isFinite && raw >= 0 ? raw.toDouble() : null;

  static T? _byName<T extends Enum>(List<T> values, String name) =>
      values.where((v) => v.name == name).firstOrNull;
}

/// What making one leaf is charged as. The leaf's own kind decides it — a
/// door leaf as a door, a window sash as a window — never the category of
/// the design round it.
enum LeafRate {
  door('Door leaf'),
  window('Window sash'),
  sliding('Sliding panel'),

  /// A leaf nobody has said is a door or a window yet — in a door & window
  /// set or an angled design, before the question is answered.
  unnamed('Opening leaf');

  const LeafRate(this.label);
  final String label;
}

/// How dear a colour is, against the material's own standard colours.
enum ColourGrade {
  standard('Standard colour'),
  nonStandard('Non-standard colour'),

  /// Any colour the price list does not name — a custom or special colour.
  special('Special colour');

  const ColourGrade(this.label);
  final String label;
}

/// One colour a profile is sold in, and what it adds.
///
/// [colour] is the finish value it is matched against — the colour the user
/// gave the part. It is a material's colour, never the application's own:
/// the house green and cream of the bars and buttons are not on any list,
/// so a frame painted in one is priced as a special colour.
class ColourRate {
  final String name;
  final int colour;
  final ColourGrade grade;

  /// What it adds to the profile's price, as a percentage.
  final double surchargePercent;

  const ColourRate(this.name, this.colour, this.grade, this.surchargePercent);

  Map<String, Object?> toJson() => {
    'name': name,
    'colour': colour,
    'grade': grade.name,
    'surchargePercent': surchargePercent,
  };

  static ColourRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final name = json['name'];
    final colour = json['colour'];
    final grade = PriceList._byName(
      ColourGrade.values,
      json['grade'] as String? ?? '',
    );
    final percent = PriceList.price(json['surchargePercent']);
    if (name is! String || colour is! int || grade == null || percent == null) {
      return null;
    }
    return ColourRate(name, colour, grade, percent);
  }
}

/// What a frame material's profile costs — the frame, a sash and a bar,
/// each a metre of it — and the colours it comes in.
class ProfileRate {
  final double framePerMetre;
  final double sashPerMetre;
  final double barPerMetre;
  final List<ColourRate> colours;

  /// What a colour not on [colours] adds, as a percentage.
  final double specialColourPercent;

  const ProfileRate({
    required this.framePerMetre,
    required this.sashPerMetre,
    required this.barPerMetre,
    this.colours = const [],
    this.specialColourPercent = 0,
  });

  /// The colour [colour] is sold as: the one on the list with that value,
  /// or a special colour.
  ColourRate colourOf(int colour) =>
      colours.where((c) => c.colour == colour).firstOrNull ??
      ColourRate(
        ColourGrade.special.label,
        colour,
        ColourGrade.special,
        specialColourPercent,
      );

  Map<String, Object?> toJson() => {
    'framePerMetre': framePerMetre,
    'sashPerMetre': sashPerMetre,
    'barPerMetre': barPerMetre,
    'colours': [for (final c in colours) c.toJson()],
    'specialColourPercent': specialColourPercent,
  };

  static ProfileRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final frame = PriceList.price(json['framePerMetre']);
    final sash = PriceList.price(json['sashPerMetre']);
    final bar = PriceList.price(json['barPerMetre']);
    if (frame == null || sash == null || bar == null) return null;
    return ProfileRate(
      framePerMetre: frame,
      sashPerMetre: sash,
      barPerMetre: bar,
      colours: [
        if (json['colours'] case final List<Object?> raw)
          for (final c in raw) ?ColourRate.fromJson(c),
      ],
      specialColourPercent: PriceList.price(json['specialColourPercent']) ?? 0,
    );
  }
}

/// Labour, any mix of three ways of charging it: a fixed amount, so much a
/// square metre of the design, and a percentage of its materials and
/// ironmongery.
class LabourRate {
  final double fixed;
  final double perSquareMetre;
  final double percent;

  const LabourRate({this.fixed = 0, this.perSquareMetre = 0, this.percent = 0});

  Map<String, Object?> toJson() => {
    'fixed': fixed,
    'perSquareMetre': perSquareMetre,
    'percent': percent,
  };

  static LabourRate fromJson(Object? json) => json is Map<String, Object?>
      ? LabourRate(
          fixed: PriceList.price(json['fixed']) ?? 0,
          perSquareMetre: PriceList.price(json['perSquareMetre']) ?? 0,
          percent: PriceList.price(json['percent']) ?? 0,
        )
      : const LabourRate();
}

/// How a category is made: what it is called and what its labour is.
class CategoryRate {
  final String label;
  final LabourRate labour;

  const CategoryRate(this.label, this.labour);

  Map<String, Object?> toJson() => {'label': label, 'labour': labour.toJson()};

  static CategoryRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final label = json['label'];
    if (label is! String) return null;
    return CategoryRate(label, LabourRate.fromJson(json['labour']));
  }
}

/// Fitting on site: a fixed amount and so much a square metre. Only ever
/// added where the user has asked for it.
class InstallationRate {
  final double fixed;
  final double perSquareMetre;

  const InstallationRate({this.fixed = 0, this.perSquareMetre = 0});

  Map<String, Object?> toJson() => {
    'fixed': fixed,
    'perSquareMetre': perSquareMetre,
  };

  static InstallationRate fromJson(Object? json) => json is Map<String, Object?>
      ? InstallationRate(
          fixed: PriceList.price(json['fixed']) ?? 0,
          perSquareMetre: PriceList.price(json['perSquareMetre']) ?? 0,
        )
      : const InstallationRate();
}

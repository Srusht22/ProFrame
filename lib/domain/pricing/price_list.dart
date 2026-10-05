import '../model/elements.dart';
import '../model/materials.dart';
import 'default_factory_pricing.dart';
import 'price_list_migration.dart';

/// The workshop's prices: every figure the pricing engine multiplies by,
/// and nothing else.
///
/// **Prices live here and only here.** No widget, no geometry and no
/// strategy holds a figure of its own: a strategy says *what* is charged —
/// a metre of normal profile, a metre of opening profile, a square metre of
/// glass, a hinge — and reads *how much* from the list. The owner changes a
/// price by changing the list, and nothing that draws or builds a design is
/// touched. The measurement is never stored with the rate: a design is
/// measured afresh (`PricingTakeoff`) and multiplied by the list as it is.
///
/// Every amount is in [currency], per the unit it names: a metre of
/// profile, a square metre of glass or panel, one piece of ironmongery.
class PriceList {
  /// Bumped every time the list is changed and kept, so a price worked out
  /// from it can say which list it came from.
  final int version;

  /// True for the example list the application starts with, until the
  /// owner keeps a list of their own. Its figures are examples, and the
  /// screen says so.
  final bool isStarter;

  final String currency;

  /// What each frame material's profile costs — the normal profile and the
  /// opening profile, each by the metre — and its colours. A design framed
  /// in a material with no entry here is not priced.
  final Map<MaterialKind, ProfileRate> profiles;

  /// Glass, by the look the user chose, a square metre of what is cut.
  final Map<GlassLook, double> glassPerM2;

  /// Glass the user gave a colour of their own, which matches no look — or
  /// null where the list does not price it.
  final double? customGlassPerM2;

  /// A sealed glazing unit — two sheets and a sealed cavity, which is how
  /// the solid builds every pane deep enough for one — by the look of its
  /// glass, a square metre of what is cut. Its own rate: a sealed unit is
  /// never priced at the single-sheet rate above, and a look with no entry
  /// here is not priced as a sealed unit at all.
  final Map<GlassLook, double> sealedGlassPerM2;

  /// A sealed unit in a glass of the user's own colour, or null where the
  /// list does not price it.
  final double? customSealedGlassPerM2;

  /// Panel, by colour, a square metre of what is cut.
  final Map<PanelColour, double> panelPerM2;

  /// A panel in a colour of the user's own, or null where the list does not
  /// price it.
  final double? customPanelPerM2;

  /// One piece of each kind of ironmongery.
  final Map<HardwareKind, double> hardwareEach;

  /// A sliding design's track, a metre of the frame's width.
  final double trackPerMetre;

  /// One roller, and how many a sliding panel runs on.
  final double rollerEach;
  final int rollersPerSlidingPanel;

  /// How each category is made — its labour — by category name. A
  /// category with no entry is not priced.
  final Map<String, CategoryRate> categories;

  final InstallationRate installation;

  /// The schema an older list was kept in, where this one was migrated
  /// from it as it was read — null for a list kept in the current schema.
  /// Never written: a migrated list kept again is kept in the current one.
  final int? migratedFrom;

  /// What an older list held that the current schema has no place for, said
  /// in words, where it was migrated. Nothing is invented in its stead.
  final List<String> migrationNotes;

  /// The schema this version writes. 1 was the first engine's — a metre of
  /// frame, of sash and of bar, a leaf by its kind, an angled joint; 2 the
  /// factory's normal and opening profile; 3 adds the sealed unit's own
  /// rate. See [fromJson].
  static const schemaVersion = 3;

  const PriceList({
    required this.currency,
    required this.profiles,
    required this.glassPerM2,
    required this.panelPerM2,
    required this.hardwareEach,
    required this.categories,
    required this.installation,
    this.version = 1,
    this.isStarter = false,
    this.customGlassPerM2,
    this.customPanelPerM2,
    this.trackPerMetre = 0,
    this.rollerEach = 0,
    this.rollersPerSlidingPanel = 2,
    this.sealedGlassPerM2 = const {},
    this.customSealedGlassPerM2,
    this.migratedFrom,
    this.migrationNotes = const [],
  });

  /// The example list the application starts with, until the owner keeps
  /// the workshop's own. Its figures live in one place,
  /// [DefaultFactoryPricing], and nowhere else.
  static PriceList get starter => DefaultFactoryPricing.list;

  PriceList copyWith({
    int? version,
    bool? isStarter,
    String? currency,
    Map<MaterialKind, ProfileRate>? profiles,
    Map<GlassLook, double>? glassPerM2,
    double? customGlassPerM2,
    Map<GlassLook, double>? sealedGlassPerM2,
    double? customSealedGlassPerM2,
    Map<PanelColour, double>? panelPerM2,
    double? customPanelPerM2,
    Map<HardwareKind, double>? hardwareEach,
    double? trackPerMetre,
    double? rollerEach,
    int? rollersPerSlidingPanel,
    Map<String, CategoryRate>? categories,
    InstallationRate? installation,
    int? migratedFrom,
    List<String>? migrationNotes,
  }) => PriceList(
    version: version ?? this.version,
    isStarter: isStarter ?? this.isStarter,
    currency: currency ?? this.currency,
    profiles: profiles ?? this.profiles,
    glassPerM2: glassPerM2 ?? this.glassPerM2,
    customGlassPerM2: customGlassPerM2 ?? this.customGlassPerM2,
    sealedGlassPerM2: sealedGlassPerM2 ?? this.sealedGlassPerM2,
    customSealedGlassPerM2:
        customSealedGlassPerM2 ?? this.customSealedGlassPerM2,
    panelPerM2: panelPerM2 ?? this.panelPerM2,
    customPanelPerM2: customPanelPerM2 ?? this.customPanelPerM2,
    hardwareEach: hardwareEach ?? this.hardwareEach,
    trackPerMetre: trackPerMetre ?? this.trackPerMetre,
    rollerEach: rollerEach ?? this.rollerEach,
    rollersPerSlidingPanel:
        rollersPerSlidingPanel ?? this.rollersPerSlidingPanel,
    categories: categories ?? this.categories,
    installation: installation ?? this.installation,
    migratedFrom: migratedFrom ?? this.migratedFrom,
    migrationNotes: migrationNotes ?? this.migrationNotes,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'version': version,
    if (isStarter) 'isStarter': true,
    'currency': currency,
    'profiles': {
      for (final e in profiles.entries) e.key.name: e.value.toJson(),
    },
    'glassPerM2': {for (final e in glassPerM2.entries) e.key.name: e.value},
    if (customGlassPerM2 != null) 'customGlassPerM2': customGlassPerM2,
    'sealedGlassPerM2': {
      for (final e in sealedGlassPerM2.entries) e.key.name: e.value,
    },
    if (customSealedGlassPerM2 != null)
      'customSealedGlassPerM2': customSealedGlassPerM2,
    'panelPerM2': {for (final e in panelPerM2.entries) e.key.name: e.value},
    if (customPanelPerM2 != null) 'customPanelPerM2': customPanelPerM2,
    'hardwareEach': {for (final e in hardwareEach.entries) e.key.name: e.value},
    'trackPerMetre': trackPerMetre,
    'rollerEach': rollerEach,
    'rollersPerSlidingPanel': rollersPerSlidingPanel,
    'categories': {for (final e in categories.entries) e.key: e.value.toJson()},
    'installation': installation.toJson(),
  };

  /// The list kept as [json]. **A figure that is not a price is left out
  /// rather than read as one** — not a number, below nothing, infinite —
  /// so a damaged entry leaves that thing unpriced, which the engine says,
  /// rather than priced at nonsense. Keys this version does not know — a
  /// material, a glass, a category from a later version — are passed over
  /// in the same way. Returns null where [json] is not a price list at all.
  ///
  /// **A list kept in an older schema is migrated as it is read**
  /// ([PriceListMigration]): what has a place in the current schema is
  /// carried over at the same figure, what has none is named in
  /// [migrationNotes], and nothing is made up. The list kept on the device
  /// is not written by reading it.
  static PriceList? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final migration = PriceListMigration.toCurrent(raw);
    final read = _fromCurrent(migration.json);
    if (read == null || migration.from == schemaVersion) return read;
    return read.copyWith(
      migratedFrom: migration.from,
      migrationNotes: migration.notes,
    );
  }

  /// [json] in the current schema, read.
  static PriceList? _fromCurrent(Map<String, Object?> json) {
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
      sealedGlassPerM2: rates(
        json['sealedGlassPerM2'],
        (k) => _byName(GlassLook.values, k),
      ),
      customSealedGlassPerM2: price(json['customSealedGlassPerM2']),
      panelPerM2: rates(
        json['panelPerM2'],
        (k) => _byName(PanelColour.values, k),
      ),
      customPanelPerM2: price(json['customPanelPerM2']),
      hardwareEach: rates(
        json['hardwareEach'],
        (k) => _byName(HardwareKind.values, k),
      ),
      trackPerMetre: price(json['trackPerMetre']) ?? 0,
      rollerEach: price(json['rollerEach']) ?? 0,
      rollersPerSlidingPanel: (price(json['rollersPerSlidingPanel']) ?? 2)
          .round(),
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

/// How dear a colour is, against the material's own standard colours.
enum ColourGrade {
  standard('Standard colour'),
  nonStandard('Non-standard colour'),

  /// Any colour the price list does not name — a custom or special colour.
  special('Special colour');

  const ColourGrade(this.label);
  final String label;
}

/// What a colour adds to a profile: so much a metre, and so much in a
/// hundred on the profile's own price. Either, both or neither — the
/// factory's own formula.
class ColourSurcharge {
  final double perMetre;
  final double percent;

  const ColourSurcharge({this.perMetre = 0, this.percent = 0});

  bool get isNone => perMetre <= 0 && percent <= 0;

  Map<String, Object?> toJson() => {
    if (perMetre != 0) 'perMetre': perMetre,
    if (percent != 0) 'percent': percent,
  };

  static ColourSurcharge fromJson(Object? json) => json is Map<String, Object?>
      ? ColourSurcharge(
          perMetre: PriceList.price(json['perMetre']) ?? 0,
          percent: PriceList.price(json['percent']) ?? 0,
        )
      : const ColourSurcharge();
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

  /// What it adds a metre of profile, and as a share of the profile's own
  /// price.
  final double perMetre;
  final double percent;

  const ColourRate(
    this.name,
    this.colour,
    this.grade, {
    this.perMetre = 0,
    this.percent = 0,
  });

  ColourRate._(this.name, this.colour, this.grade, ColourSurcharge surcharge)
    : perMetre = surcharge.perMetre,
      percent = surcharge.percent;

  ColourSurcharge get surcharge =>
      ColourSurcharge(perMetre: perMetre, percent: percent);

  Map<String, Object?> toJson() => {
    'name': name,
    'colour': colour,
    'grade': grade.name,
    'surcharge': surcharge.toJson(),
  };

  static ColourRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final name = json['name'];
    final colour = json['colour'];
    final grade = PriceList._byName(
      ColourGrade.values,
      json['grade'] as String? ?? '',
    );
    if (name is! String || colour is! int || grade == null) return null;
    return ColourRate._(
      name,
      colour,
      grade,
      ColourSurcharge.fromJson(json['surcharge']),
    );
  }
}

/// What a frame material's profile costs — the normal profile (the border
/// and every line cut from it) and the opening profile, each a metre — and
/// the colours it comes in.
class ProfileRate {
  final double normalPerMetre;
  final double openingPerMetre;
  final List<ColourRate> colours;

  /// What a colour not on [colours] adds.
  final ColourSurcharge special;

  const ProfileRate({
    required this.normalPerMetre,
    required this.openingPerMetre,
    this.colours = const [],
    this.special = const ColourSurcharge(),
  });

  /// The colour [colour] is sold as: the one on the list with that value,
  /// or a special colour.
  ColourRate colourOf(int colour) =>
      colours.where((c) => c.colour == colour).firstOrNull ??
      ColourRate._(
        ColourGrade.special.label,
        colour,
        ColourGrade.special,
        special,
      );

  Map<String, Object?> toJson() => {
    'normalPerMetre': normalPerMetre,
    'openingPerMetre': openingPerMetre,
    'colours': [for (final c in colours) c.toJson()],
    'special': special.toJson(),
  };

  static ProfileRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final normal = PriceList.price(json['normalPerMetre']);
    final opening = PriceList.price(json['openingPerMetre']);
    if (normal == null || opening == null) return null;
    return ProfileRate(
      normalPerMetre: normal,
      openingPerMetre: opening,
      colours: [
        if (json['colours'] case final List<Object?> raw)
          for (final c in raw) ?ColourRate.fromJson(c),
      ],
      special: ColourSurcharge.fromJson(json['special']),
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

import '../model/elements.dart';
import '../model/materials.dart';
import 'default_factory_pricing.dart';
import 'price_list_migration.dart';
import 'profile_category.dart';

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
  /// opening profile, each by the metre — and what a colour the catalog
  /// does not name adds. A design framed in a material with no entry here
  /// is not priced.
  final Map<MaterialKind, ProfileRate> profiles;

  /// The factory's colour catalog: every colour the profile is sold in,
  /// each with an id of its own, the materials it is sold in and what it
  /// adds on each, in the order the factory lists them. A colour is never
  /// removed, only retired ([FactoryColour.active]), so a design chosen in
  /// it still says what it is. See [colourFor].
  final List<FactoryColour> colours;

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
  /// rate; 4 keeps the colours as one catalog, each colour with an id,
  /// its materials and a rate for each; 5 prices aluminium's border and
  /// lines by profile category — System and Bend Shoulder, each its own
  /// rate ([ProfileRate.categories]). See [fromJson].
  static const schemaVersion = 5;

  const PriceList({
    required this.currency,
    required this.profiles,
    required this.glassPerM2,
    required this.panelPerM2,
    required this.hardwareEach,
    required this.categories,
    required this.installation,
    this.colours = const [],
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
    List<FactoryColour>? colours,
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
    bool clearCustomGlass = false,
    bool clearCustomSealedGlass = false,
    bool clearCustomPanel = false,
  }) => PriceList(
    version: version ?? this.version,
    isStarter: isStarter ?? this.isStarter,
    currency: currency ?? this.currency,
    profiles: profiles ?? this.profiles,
    colours: colours ?? this.colours,
    glassPerM2: glassPerM2 ?? this.glassPerM2,
    customGlassPerM2: clearCustomGlass
        ? null
        : customGlassPerM2 ?? this.customGlassPerM2,
    sealedGlassPerM2: sealedGlassPerM2 ?? this.sealedGlassPerM2,
    customSealedGlassPerM2: clearCustomSealedGlass
        ? null
        : customSealedGlassPerM2 ?? this.customSealedGlassPerM2,
    panelPerM2: panelPerM2 ?? this.panelPerM2,
    customPanelPerM2: clearCustomPanel
        ? null
        : customPanelPerM2 ?? this.customPanelPerM2,
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
    'colours': [for (final c in colours) c.toJson()],
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
      colours: _catalogOf(json['colours']),
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

  /// The catalog kept as [raw]: every entry that can be read, in the order
  /// the factory lists them. An entry whose id another entry already has is
  /// passed over — an id names one colour — and an entry that cannot be
  /// read is passed over too, so a damaged catalog leaves that colour
  /// unpriced rather than priced as another.
  static List<FactoryColour> _catalogOf(Object? raw) {
    final out = <FactoryColour>[];
    if (raw is List<Object?>) {
      for (final c in raw) {
        final colour = FactoryColour.fromJson(c);
        if (colour != null && out.every((o) => o.id != colour.id)) {
          out.add(colour);
        }
      }
    }
    out.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(out);
  }

  /// The catalog entry with [id], retired or not, or null.
  FactoryColour? colourById(String id) =>
      colours.where((c) => c.id == id).firstOrNull;

  /// The colours offered for a new choice on [material]: the active ones
  /// sold in it, in the factory's order.
  List<FactoryColour> offeredFor(MaterialKind material) => [
    for (final c in colours)
      if (c.active && c.appliesTo(material)) c,
  ];

  /// What a profile in [material] and [colour] adds, and whether it can be
  /// priced — **always by material and colour together**.
  ///
  /// Where [id] is given — a colour chosen from the catalog — it is that
  /// colour and no other: one sold in [material] with a rate for it is
  /// priced at that rate; one not sold in it needs choosing again; one
  /// sold in it with no rate is not configured; one retired and no longer
  /// priced on [material], or an id the catalog does not have, needs an
  /// active colour. **Nothing falls back** — not to another material's
  /// rate, not to the rate for any other colour, not to nothing.
  ///
  /// Without an id — a frame painted in the inspector, a design kept before
  /// the catalog — the colour is matched by its value among the colours
  /// sold in [material], an active one first: matched, it is that colour
  /// as above; matched by none, it is a colour the catalog does not name,
  /// and [ProfileRate.special] — *any other colour* — is what it adds.
  ColourPricing colourFor(MaterialKind material, int colour, {String? id}) {
    FactoryColour? entry;
    if (id != null) {
      entry = colourById(id);
      if (entry == null) {
        return ColourPricing._(ColourPricingState.unknown, material, colour);
      }
    } else {
      final matches = [
        for (final c in colours)
          if (c.swatch == colour && c.appliesTo(material)) c,
      ];
      entry = matches.where((c) => c.active).firstOrNull ?? matches.firstOrNull;
      if (entry == null) {
        final special = profiles[material]?.special;
        return special == null
            ? ColourPricing._(ColourPricingState.noProfile, material, colour)
            : ColourPricing._(
                ColourPricingState.other,
                material,
                colour,
                surcharge: special,
              );
      }
    }
    final rate = entry.rateFor(material);
    final state = switch ((entry.active, entry.appliesTo(material), rate)) {
      (true, false, _) => ColourPricingState.notForMaterial,
      (true, true, null) => ColourPricingState.notConfigured,
      (false, _, null) => ColourPricingState.retiredUnpriced,
      _ => ColourPricingState.named,
    };
    return ColourPricing._(
      state,
      material,
      colour,
      entry: entry,
      surcharge: rate ?? const ColourSurcharge(),
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

  /// A catalog colour's rate on one material, as kept: null where none is
  /// kept, or where a figure kept is not a price — that colour is then not
  /// priced on that material, never priced at nothing.
  static ColourSurcharge? read(Object? json) {
    if (json is! Map<String, Object?>) return null;
    for (final key in ['perMetre', 'percent']) {
      if (json.containsKey(key) && PriceList.price(json[key]) == null) {
        return null;
      }
    }
    return fromJson(json);
  }

  @override
  bool operator ==(Object other) =>
      other is ColourSurcharge &&
      other.perMetre == perMetre &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(perMetre, percent);
}

/// One colour of the factory's colour catalog: what it is called, its
/// swatch, the materials it is sold in and what it adds on each.
///
/// **Its [id] is what it is**, never its name: a design chosen in it keeps
/// the id (`Design.profileColourId`), so renaming it renames it everywhere
/// and a price kept before says the name it had then. Nothing ever removes
/// one: a colour the factory stops selling is retired ([active] false) —
/// no longer offered for a new choice, and still what every design chosen
/// in it is.
///
/// [rates] is keyed by every material it is sold in. A material with a
/// null rate is one it is sold in that has no price yet: a design in it is
/// not priced, and says *colour pricing is not configured* — it never
/// borrows another material's rate or the rate for any other colour. The
/// editor never keeps one so; a list from elsewhere might hold one.
///
/// [swatch] is the finish value a design chosen in it is drawn in — a
/// material's colour, never the application's own: the house green and
/// cream of the bars and buttons are on no list.
class FactoryColour {
  final String id;
  final String name;
  final int swatch;
  final ColourGrade grade;
  final Map<MaterialKind, ColourSurcharge?> rates;

  /// Offered for a new choice. A retired colour is still read, shown and
  /// — where it is still priced — priced for the designs already in it.
  final bool active;

  /// Where it is listed, lowest first.
  final int order;

  const FactoryColour({
    required this.id,
    required this.name,
    required this.swatch,
    required this.rates,
    this.grade = ColourGrade.nonStandard,
    this.active = true,
    this.order = 0,
  });

  /// The materials it is sold in, in the order a joiner reads them.
  List<MaterialKind> get materials => [
    for (final m in MaterialKind.values)
      if (rates.containsKey(m)) m,
  ];

  bool appliesTo(MaterialKind material) => rates.containsKey(material);

  /// What it adds on [material], or null where it is not sold in it or has
  /// no price on it.
  ColourSurcharge? rateFor(MaterialKind material) => rates[material];

  FactoryColour copyWith({
    String? name,
    int? swatch,
    ColourGrade? grade,
    Map<MaterialKind, ColourSurcharge?>? rates,
    bool? active,
    int? order,
  }) => FactoryColour(
    id: id,
    name: name ?? this.name,
    swatch: swatch ?? this.swatch,
    grade: grade ?? this.grade,
    rates: rates ?? this.rates,
    active: active ?? this.active,
    order: order ?? this.order,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'swatch': swatch,
    'grade': grade.name,
    'rates': {
      for (final m in materials) m.name: rates[m]?.toJson(),
    },
    if (!active) 'active': false,
    'order': order,
  };

  /// The colour kept as [json], or null where it is not one: an id, a name
  /// and a swatch are required. A material this version does not know is
  /// passed over; a rate that is not a price is read as no rate, so that
  /// colour on that material is not priced rather than priced at nonsense.
  static FactoryColour? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final swatch = json['swatch'];
    if (id is! String || id.isEmpty || name is! String || swatch is! int) {
      return null;
    }
    return FactoryColour(
      id: id,
      name: name,
      swatch: swatch,
      grade:
          PriceList._byName(ColourGrade.values, json['grade'] as String? ?? '') ??
          ColourGrade.nonStandard,
      rates: {
        if (json['rates'] case final Map<String, Object?> raw)
          for (final e in raw.entries)
            ?PriceList._byName(MaterialKind.values, e.key):
                ColourSurcharge.read(e.value),
      },
      active: json['active'] != false,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Where a profile's colour stands against the catalog.
enum ColourPricingState {
  /// A colour of the catalog, sold in the material, with its rate.
  named,

  /// A colour the catalog does not name: *any other colour*.
  other,

  /// A colour of the catalog that is not sold in the material.
  notForMaterial,

  /// A colour of the catalog sold in the material, with no rate on it.
  notConfigured,

  /// A retired colour no longer priced on the material.
  retiredUnpriced,

  /// An id the catalog does not have.
  unknown,

  /// The material has no profile rate at all — said by the profile line.
  noProfile,
}

/// What a profile's colour adds, or why it cannot be priced — the one
/// answer [PriceList.colourFor] gives the engine, the price's state, the
/// selector and the card alike.
class ColourPricing {
  final ColourPricingState state;
  final MaterialKind material;

  /// The finish value the design is in.
  final int colour;

  /// The catalog's colour, where it is one.
  final FactoryColour? entry;

  /// What it adds, where it is priced.
  final ColourSurcharge surcharge;

  const ColourPricing._(
    this.state,
    this.material,
    this.colour, {
    this.entry,
    this.surcharge = const ColourSurcharge(),
  });

  bool get isPriced =>
      state == ColourPricingState.named || state == ColourPricingState.other;

  /// Whether the answer is for the user to choose another colour — as
  /// opposed to the owner to price this one.
  bool get needsSelection =>
      state == ColourPricingState.notForMaterial ||
      state == ColourPricingState.retiredUnpriced ||
      state == ColourPricingState.unknown;

  /// What it is called on a price line: the catalog's name, or *Special
  /// colour* for one it does not name.
  String get name => entry?.name ?? ColourGrade.special.label;

  ColourGrade get grade => entry?.grade ?? ColourGrade.special;

  /// Why it cannot be priced, in words — null where it can.
  String? get problem => switch (state) {
    ColourPricingState.named || ColourPricingState.other => null,
    ColourPricingState.notForMaterial =>
      'Please select a colour available for ${material.label}.',
    ColourPricingState.notConfigured =>
      'Colour pricing is not configured for ${material.label}.',
    ColourPricingState.retiredUnpriced || ColourPricingState.unknown =>
      'Colour pricing unavailable — please select an active colour.',
    ColourPricingState.noProfile =>
      'The price list has no price for ${material.label} profile.',
  };
}

/// What a frame material's profile costs — the normal profile (the border
/// and every line cut from it) and the opening profile, each a metre — and
/// what a colour the catalog does not name adds on it. The named colours
/// are the list's catalog ([PriceList.colours]).
class ProfileRate {
  /// A metre of the material's normal profile — the border and the lines,
  /// which share it. **Not read for a material sold by profile category**
  /// (aluminium): its border and lines are priced at [categories] instead,
  /// and this is null. Null for any other material is no price.
  final double? normalPerMetre;
  final double openingPerMetre;

  /// A metre of the border and the lines in each profile category of the
  /// material — System Aluminium, Bend Shoulder Aluminium — each its own
  /// figure and never another's. A category with no entry is not priced.
  final Map<ProfileCategory, double> categories;

  /// What a colour the catalog does not name adds — *any other colour*.
  /// Only ever for such a colour: a catalog colour with no rate on this
  /// material is not priced at this.
  final ColourSurcharge special;

  const ProfileRate({
    this.normalPerMetre,
    required this.openingPerMetre,
    this.categories = const {},
    this.special = const ColourSurcharge(),
  });

  /// What a metre of the border and the lines costs as [category], or —
  /// for a material with no categories — at its normal rate. Null where
  /// the list has no figure for it: it is then not priced.
  double? normalRateFor(ProfileCategory? category) =>
      category == null ? normalPerMetre : categories[category];

  ProfileRate copyWith({
    double? normalPerMetre,
    bool clearNormal = false,
    double? openingPerMetre,
    Map<ProfileCategory, double>? categories,
    ColourSurcharge? special,
  }) => ProfileRate(
    normalPerMetre: clearNormal ? null : normalPerMetre ?? this.normalPerMetre,
    openingPerMetre: openingPerMetre ?? this.openingPerMetre,
    categories: categories ?? this.categories,
    special: special ?? this.special,
  );

  Map<String, Object?> toJson() => {
    if (normalPerMetre != null) 'normalPerMetre': normalPerMetre,
    'openingPerMetre': openingPerMetre,
    if (categories.isNotEmpty)
      'categories': {for (final e in categories.entries) e.key.name: e.value},
    'special': special.toJson(),
  };

  static ProfileRate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final opening = PriceList.price(json['openingPerMetre']);
    if (opening == null) return null;
    return ProfileRate(
      normalPerMetre: PriceList.price(json['normalPerMetre']),
      openingPerMetre: opening,
      categories: {
        if (json['categories'] case final Map<String, Object?> raw)
          for (final e in raw.entries)
            if ((ProfileCategory.byName(e.key), PriceList.price(e.value))
                case (final c?, final rate?))
              c: rate,
      },
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

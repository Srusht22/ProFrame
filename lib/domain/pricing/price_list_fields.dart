import '../model/elements.dart';
import '../model/materials.dart';
import 'price_list.dart';

/// One figure of the price list, as the owner edits it: what it is, in
/// what unit, how it is read from a list and how a list is written with a
/// new figure in it.
///
/// The price editor shows these and nothing else, so every figure the
/// engine reads can be set — a profile's metre by material, what a colour
/// the catalog does not name adds on it, glass, sealed units, panels, ironmongery, the
/// sliding track and its rollers, labour and installation — and nothing is
/// dropped from the list by being edited: each figure is written into the
/// list it came from, with every other figure as it was. The catalog's
/// named colours are the one part of the list edited as a whole colour at
/// a time (`ColourCatalog`), so they are not here.
class RateField {
  /// Stable across lists: `profile.upvc.normal`, `glass.sealed.clear`.
  final String id;

  /// The heading it is listed under: *Normal profile*, *Any other colour — uPVC*.
  final String section;

  /// What it is, under its heading: *uPVC*, *A metre*.
  final String label;

  /// What one of it is: `/ m`, `/ m²`, `each`, `%`.
  final String unit;

  /// Whether it may be left empty — that thing then has no price, and a
  /// design using it says so rather than being priced at nothing.
  final bool optional;

  /// Whether it is a count, not an amount.
  final bool whole;

  final double? Function(PriceList list) read;
  final PriceList Function(PriceList list, double? value) write;

  const RateField({
    required this.id,
    required this.section,
    required this.label,
    required this.unit,
    required this.read,
    required this.write,
    this.optional = false,
    this.whole = false,
  });

  /// Why [value] cannot be this figure, or null where it can.
  String? problemWith(double? value) {
    if (value == null) return optional ? null : 'A price is needed here.';
    if (!value.isFinite || value < 0) return 'Enter a figure of 0 or more.';
    if (whole && value != value.roundToDouble()) return 'Enter a whole number.';
    return null;
  }

  /// Every figure of [list], in the order the editor lists them.
  static List<RateField> of(PriceList list) => [
    // Every material's normal profile together, then every opening profile:
    // the two are read as a pair of columns, not one material at a time.
    for (final m in list.profiles.keys) _profile(m).first,
    for (final m in list.profiles.keys) _profile(m).last,
    for (final m in list.profiles.keys) ..._colours(list, m),
    ..._looks(
      'Glass (single sheet)',
      'glass.single',
      (l) => l.glassPerM2,
      (l, map) => l.copyWith(glassPerM2: map),
      read: (l) => l.customGlassPerM2,
      write: (l, v) => v == null
          ? l.copyWith(clearCustomGlass: true)
          : l.copyWith(customGlassPerM2: v),
    ),
    ..._looks(
      'Sealed glass unit',
      'glass.sealed',
      (l) => l.sealedGlassPerM2,
      (l, map) => l.copyWith(sealedGlassPerM2: map),
      read: (l) => l.customSealedGlassPerM2,
      write: (l, v) => v == null
          ? l.copyWith(clearCustomSealedGlass: true)
          : l.copyWith(customSealedGlassPerM2: v),
    ),
    for (final c in PanelColour.values)
      RateField(
        id: 'panel.${c.name}',
        section: 'Panel',
        label: c.label,
        unit: '/ m²',
        optional: true,
        read: (l) => l.panelPerM2[c],
        write: (l, v) => l.copyWith(panelPerM2: _put(l.panelPerM2, c, v)),
      ),
    RateField(
      id: 'panel.custom',
      section: 'Panel',
      label: 'Any other colour',
      unit: '/ m²',
      optional: true,
      read: (l) => l.customPanelPerM2,
      write: (l, v) => v == null
          ? l.copyWith(clearCustomPanel: true)
          : l.copyWith(customPanelPerM2: v),
    ),
    for (final k in HardwareKind.values)
      RateField(
        id: 'hardware.${k.name}',
        section: 'Hardware',
        label: k.label,
        unit: 'each',
        optional: true,
        read: (l) => l.hardwareEach[k],
        write: (l, v) => l.copyWith(hardwareEach: _put(l.hardwareEach, k, v)),
      ),
    RateField(
      id: 'sliding.track',
      section: 'Sliding',
      label: 'Track',
      unit: '/ m',
      read: (l) => l.trackPerMetre,
      write: (l, v) => l.copyWith(trackPerMetre: v),
    ),
    RateField(
      id: 'sliding.roller',
      section: 'Sliding',
      label: 'Roller',
      unit: 'each',
      read: (l) => l.rollerEach,
      write: (l, v) => l.copyWith(rollerEach: v),
    ),
    RateField(
      id: 'sliding.rollersPerPanel',
      section: 'Sliding',
      label: 'Rollers on each sliding panel',
      unit: 'rollers',
      whole: true,
      read: (l) => l.rollersPerSlidingPanel.toDouble(),
      write: (l, v) => l.copyWith(rollersPerSlidingPanel: v?.round()),
    ),
    RateField(
      id: 'installation.fixed',
      section: 'Installation',
      label: 'Each design',
      unit: 'fixed',
      read: (l) => l.installation.fixed,
      write: (l, v) => l.copyWith(
        installation: InstallationRate(
          fixed: v ?? 0,
          perSquareMetre: l.installation.perSquareMetre,
        ),
      ),
    ),
    RateField(
      id: 'installation.area',
      section: 'Installation',
      label: 'By area',
      unit: '/ m²',
      read: (l) => l.installation.perSquareMetre,
      write: (l, v) => l.copyWith(
        installation: InstallationRate(
          fixed: l.installation.fixed,
          perSquareMetre: v ?? 0,
        ),
      ),
    ),
    for (final MapEntry(key: name, value: rate) in list.categories.entries)
      ..._labour(name, rate.label),
  ];

  static List<RateField> _profile(MaterialKind m) => [
    RateField(
      id: 'profile.${m.name}.normal',
      section: 'Normal profile',
      label: m.label,
      unit: '/ m',
      read: (l) => l.profiles[m]?.normalPerMetre,
      write: (l, v) => _withProfile(l, m, normal: v),
    ),
    RateField(
      id: 'profile.${m.name}.opening',
      section: 'Opening profile',
      label: m.label,
      unit: '/ m',
      read: (l) => l.profiles[m]?.openingPerMetre,
      write: (l, v) => _withProfile(l, m, opening: v),
    ),
  ];

  /// What a colour the catalog does not name adds on [m]'s profile — a
  /// metre, and a share of the profile's price. The catalog's own colours
  /// are edited as colours (`ColourCatalog`), each change a version of the
  /// list, so their rates are not fields here.
  static List<RateField> _colours(PriceList list, MaterialKind m) {
    final section = 'Any other colour — ${m.label}';
    return [
      RateField(
        id: 'colour.${m.name}.special.metre',
        section: section,
        label: 'A metre',
        unit: '/ m',
        read: (l) => l.profiles[m]?.special.perMetre,
        write: (l, v) => _withSpecial(l, m, perMetre: v ?? 0),
      ),
      RateField(
        id: 'colour.${m.name}.special.percent',
        section: section,
        label: 'On the profile',
        unit: '%',
        read: (l) => l.profiles[m]?.special.percent,
        write: (l, v) => _withSpecial(l, m, percent: v ?? 0),
      ),
    ];
  }

  static List<RateField> _looks(
    String section,
    String id,
    Map<GlassLook, double> Function(PriceList) map,
    PriceList Function(PriceList, Map<GlassLook, double>) put, {
    required double? Function(PriceList) read,
    required PriceList Function(PriceList, double?) write,
  }) => [
    for (final look in GlassLook.values)
      RateField(
        id: '$id.${look.name}',
        section: section,
        label: look.label,
        unit: '/ m²',
        optional: true,
        read: (l) => map(l)[look],
        write: (l, v) => put(l, _put(map(l), look, v)),
      ),
    RateField(
      id: '$id.custom',
      section: section,
      label: 'Any other colour',
      unit: '/ m²',
      optional: true,
      read: read,
      write: write,
    ),
  ];

  static List<RateField> _labour(String category, String label) {
    LabourRate of(PriceList l) =>
        l.categories[category]?.labour ?? const LabourRate();
    PriceList put(PriceList l, LabourRate labour) => l.copyWith(
      categories: {
        ...l.categories,
        category: CategoryRate(l.categories[category]?.label ?? label, labour),
      },
    );
    final section = 'Labour — $label';
    return [
      RateField(
        id: 'labour.$category.fixed',
        section: section,
        label: 'Each design',
        unit: 'fixed',
        read: (l) => of(l).fixed,
        write: (l, v) => put(
          l,
          LabourRate(
            fixed: v ?? 0,
            perSquareMetre: of(l).perSquareMetre,
            percent: of(l).percent,
          ),
        ),
      ),
      RateField(
        id: 'labour.$category.area',
        section: section,
        label: 'By area',
        unit: '/ m²',
        read: (l) => of(l).perSquareMetre,
        write: (l, v) => put(
          l,
          LabourRate(
            fixed: of(l).fixed,
            perSquareMetre: v ?? 0,
            percent: of(l).percent,
          ),
        ),
      ),
      RateField(
        id: 'labour.$category.percent',
        section: section,
        label: 'On the materials',
        unit: '%',
        read: (l) => of(l).percent,
        write: (l, v) => put(
          l,
          LabourRate(
            fixed: of(l).fixed,
            perSquareMetre: of(l).perSquareMetre,
            percent: v ?? 0,
          ),
        ),
      ),
    ];
  }

  /// [map] with [key] at [value], or without it where [value] is null.
  static Map<K, double> _put<K>(Map<K, double> map, K key, double? value) {
    final out = Map<K, double>.of(map);
    if (value == null) {
      out.remove(key);
    } else {
      out[key] = value;
    }
    return out;
  }

  static PriceList _withProfile(
    PriceList l,
    MaterialKind m, {
    double? normal,
    double? opening,
  }) {
    final was = l.profiles[m];
    if (was == null) return l;
    return l.copyWith(
      profiles: {
        ...l.profiles,
        m: ProfileRate(
          normalPerMetre: normal ?? was.normalPerMetre,
          openingPerMetre: opening ?? was.openingPerMetre,
          special: was.special,
        ),
      },
    );
  }

  static PriceList _withSpecial(
    PriceList l,
    MaterialKind m, {
    double? perMetre,
    double? percent,
  }) {
    final was = l.profiles[m];
    if (was == null) return l;
    return l.copyWith(
      profiles: {
        ...l.profiles,
        m: ProfileRate(
          normalPerMetre: was.normalPerMetre,
          openingPerMetre: was.openingPerMetre,
          special: ColourSurcharge(
            perMetre: perMetre ?? was.special.perMetre,
            percent: percent ?? was.special.percent,
          ),
        ),
      },
    );
  }
}

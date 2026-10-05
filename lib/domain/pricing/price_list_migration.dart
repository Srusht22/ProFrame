/// A price list kept in an older schema, brought to the current one.
///
/// ```
/// stored list ─ schema? ─ 1 ─ v1 → v2 ─┐
///                       ─ 2 ───────────┴─ v2 → v3 ─┐
///                       ─ 3 ───────────────────────┴─ v3 → v4 ─┐
///                       ─ 4 ───────────────────────────────────┴─ current
/// ```
///
/// | Schema | What it held |
/// | --- | --- |
/// | 1 | the first engine: a metre of frame, of sash and of bar for each material, a colour's surcharge as a percentage, a price per leaf and per angled joint (`proframe.pricelist.v1`) |
/// | 2 | the factory model: a metre of normal and of opening profile, a colour's surcharge by the metre and the percentage — kept without a schema number |
/// | 3 | schema 2 and a sealed glazing unit's own rate by look, kept with `schemaVersion: 3` |
/// | 4 | schema 3 with the colours as one catalog: each colour an id, a name, a swatch, the materials it is sold in and a rate on each, active or retired, in order |
///
/// **Only what has a place is carried, at the same figure.** What has none
/// is named in the notes and left out; nothing is made up in its stead.
/// Each step is stated where it is written, so a later schema is one more
/// step and none of these change.
abstract final class PriceListMigration {
  /// The schema [json] was kept in: its own number where it has one;
  /// otherwise the first engine's where its profiles are priced by frame,
  /// sash and bar; otherwise the factory model's.
  static int schemaOf(Map<String, Object?> json) {
    if (json['schemaVersion'] case final num v) return v.toInt();
    final profiles = json['profiles'];
    final firstEngine =
        json.containsKey('leafEach') ||
        json.containsKey('angledJointEach') ||
        (profiles is Map<String, Object?> &&
            profiles.values.any(
              (p) =>
                  p is Map<String, Object?> && p.containsKey('framePerMetre'),
            ));
    return firstEngine ? 1 : 2;
  }

  /// [json] in the current schema, the schema it came from, and what it
  /// held that the current schema has no place for.
  static ({Map<String, Object?> json, int from, List<String> notes}) toCurrent(
    Map<String, Object?> json,
  ) {
    final from = schemaOf(json);
    final notes = <String>[];
    var now = Map<String, Object?>.of(json);
    if (from <= 1) now = _v1ToV2(now, notes);
    if (from <= 2) now = _v2ToV3(now, notes);
    if (from <= 3) now = _v3ToV4(now, notes);
    now['schemaVersion'] = 4;
    return (json: now, from: from, notes: List.unmodifiable(notes));
  }

  /// The first engine's list as the factory model's.
  ///
  /// - A metre of **frame** is a metre of **normal profile**: the border is
  ///   normal profile. A bar is normal profile too and is priced at the
  ///   same rate, so a bar rate that differed from the frame's has no
  ///   place, and is named.
  /// - A metre of **sash** is a metre of **opening profile**: both are the
  ///   profile round an opening.
  /// - A colour's **percentage** stays a percentage; it adds nothing by the
  ///   metre, as before.
  /// - A price **per leaf** and **per angled joint** have no place — a leaf
  ///   is priced by its opening profile and its ironmongery — and are
  ///   named.
  /// - Everything else — currency, glass, panel, ironmongery, track,
  ///   rollers, labour, installation — has the same name and meaning, and
  ///   is carried as it is.
  static Map<String, Object?> _v1ToV2(
    Map<String, Object?> json,
    List<String> notes,
  ) {
    final out = Map<String, Object?>.of(json)
      ..remove('leafEach')
      ..remove('angledJointEach');
    final profiles = <String, Object?>{};
    if (json['profiles'] case final Map<String, Object?> raw) {
      for (final MapEntry(key: material, value: p) in raw.entries) {
        if (p is! Map<String, Object?>) continue;
        final frame = p['framePerMetre'];
        final bar = p['barPerMetre'];
        if (bar is num && frame is num && bar != frame) {
          notes.add(
            'The $material bar rate ($bar a metre): bars are now normal '
            'profile, priced at the frame rate ($frame).',
          );
        }
        profiles[material] = {
          'normalPerMetre': frame,
          'openingPerMetre': p['sashPerMetre'],
          'colours': [
            if (p['colours'] case final List<Object?> colours)
              for (final c in colours)
                if (c is Map<String, Object?>)
                  {
                    'name': c['name'],
                    'colour': c['colour'],
                    'grade': c['grade'],
                    'surcharge': {'percent': c['surchargePercent'] ?? 0},
                  },
          ],
          'special': {'percent': p['specialColourPercent'] ?? 0},
        };
      }
    }
    out['profiles'] = profiles;
    if (json['leafEach'] case final Map<String, Object?> leaves
        when leaves.values.any((v) => v is num && v > 0)) {
      final each = [
        for (final MapEntry(:key, :value) in leaves.entries)
          if (value is num && value > 0) '$key $value',
      ].join(', ');
      notes.add(
        'A price per leaf ($each): a leaf is now priced by its opening '
        'profile and its ironmongery.',
      );
    }
    if (json['angledJointEach'] case final num joint when joint > 0) {
      notes.add(
        'A price per angled joint ($joint): an angled design is now priced '
        'by its own measurements.',
      );
    }
    return out;
  }

  /// The factory model's list with sealed units priced.
  ///
  /// Before sealed units had a rate of their own, the glass rate priced
  /// every pane — and every pane deep enough is built as a sealed unit — so
  /// what a sealed unit cost was the glass rate. That is carried over as
  /// the sealed unit's rate, look for look; the single-sheet rate stays
  /// what it was.
  static Map<String, Object?> _v2ToV3(
    Map<String, Object?> json,
    List<String> notes,
  ) {
    final out = Map<String, Object?>.of(json);
    if (!out.containsKey('sealedGlassPerM2')) {
      out['sealedGlassPerM2'] = json['glassPerM2'];
      if (json['customGlassPerM2'] != null) {
        out['customSealedGlassPerM2'] = json['customGlassPerM2'];
      }
      notes.add(
        'Sealed glazing units are priced at the glass rates the list '
        'already had, which priced every pane before sealed units had a '
        'rate of their own.',
      );
    }
    return out;
  }

  /// Schema 3's colours — a list under each material, matched by value —
  /// as one catalog.
  ///
  /// A colour is the same colour on two materials where it has the same
  /// value, the same name and the same grade, and is then one entry with a
  /// rate on each, at the figures each material had. Colours that differ
  /// in any of the three stay apart. Every entry is active, in the order
  /// the materials and their colours were listed, and its id is made from
  /// its name — `colour-black` — with a number after where two would share
  /// one, so the same list always gives the same ids. Nothing is added: a
  /// colour sold in one material is not made available in another, and
  /// what a colour the list does not name adds stays each material's own.
  static Map<String, Object?> _v3ToV4(
    Map<String, Object?> json,
    List<String> notes,
  ) {
    final out = Map<String, Object?>.of(json);
    final profiles = <String, Object?>{};
    final catalog = <Map<String, Object?>>[];
    final byKey = <(Object?, Object?, Object?), Map<String, Object?>>{};
    if (json['profiles'] case final Map<String, Object?> raw) {
      for (final MapEntry(key: material, value: p) in raw.entries) {
        if (p is! Map<String, Object?>) {
          profiles[material] = p;
          continue;
        }
        profiles[material] = Map<String, Object?>.of(p)..remove('colours');
        if (p['colours'] case final List<Object?> colours) {
          for (final c in colours) {
            if (c is! Map<String, Object?>) continue;
            final key = (c['colour'], c['name'], c['grade']);
            final entry = byKey.putIfAbsent(key, () {
              final made = <String, Object?>{
                'id': null,
                'name': c['name'],
                'swatch': c['colour'],
                'grade': c['grade'],
                'rates': <String, Object?>{},
                'order': catalog.length,
              };
              catalog.add(made);
              return made;
            });
            (entry['rates']! as Map<String, Object?>)[material] =
                c['surcharge'] ?? const <String, Object?>{};
          }
        }
      }
    }
    final taken = <String>{};
    for (final entry in catalog) {
      entry['id'] = idFor(
        entry['name'] is String ? entry['name']! as String : '',
        taken,
      );
    }
    out['profiles'] = profiles;
    // A catalog already there — written by a later list that only lost its
    // schema number — is kept as it is.
    if (catalog.isNotEmpty || out['colours'] is! List<Object?>) {
      out['colours'] = catalog;
    }
    if (catalog.isNotEmpty) {
      notes.add(
        'Colours are now one catalog: a colour sold in more than one '
        'material is one colour with a rate on each, at the figures it had.',
      );
    }
    return out;
  }

  /// An id for a colour called [name], none of [taken], added to them:
  /// `colour-` and the name in lower case, a number after it where needed.
  static String idFor(String name, Set<String> taken) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = 'colour-${slug.isEmpty ? 'unnamed' : slug}';
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }
    taken.add(id);
    return id;
  }
}

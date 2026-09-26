import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dimensions/measurements.dart';
import '../domain/model/design.dart';

/// A short number for the design with [id] that a person can read out and
/// type back in: the moment it was made, to the millisecond, written in
/// letters and figures — eight characters, and different for every design
/// made a millisecond apart. An id that carries no such moment is known by
/// its end.
String shortIdOf(String id) {
  final runs = RegExp(r'\d+').allMatches(id).map((m) => m[0]!);
  final longest = runs.fold('', (a, b) => b.length > a.length ? b : a);
  final moment = longest.length >= 13 ? int.tryParse(longest) : null;
  if (moment == null) {
    return id.substring(id.length > 6 ? id.length - 6 : 0).toUpperCase();
  }
  // Microseconds where the platform has them, milliseconds where it does
  // not — the web's clock stops at the millisecond.
  final millis = longest.length >= 16 ? moment ~/ 1000 : moment;
  return millis.toRadixString(36).toUpperCase();
}

/// What the list of designs needs to know about one design, and nothing
/// more: who it is for, what kind it is, how big, and when it was made and
/// last edited.
///
/// **The list is read from these, never from the designs.** A design
/// carries every stroke the user drew; a summary is a line. Listing,
/// counting and searching thousands of designs reads thousands of lines,
/// and a design itself is read only when its card is on the screen or it
/// is opened.
class DesignSummary {
  final String id;
  final String? customer;
  final String name;
  final DesignKind kind;

  /// The overall size, where the drawing has been read into a frame.
  final double? widthMm;
  final double? heightMm;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DesignSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.widthMm,
    this.heightMm,
  });

  factory DesignSummary.of(Design design) => DesignSummary(
    id: design.id,
    customer: design.customer,
    name: design.name,
    kind: design.kind,
    // Only a size the user has given: one read off the sketch is a guess,
    // and the list does not write guesses down.
    widthMm: design.frame == null ||
            !Measurements.knowsOverall(design, MeasureAxis.across)
        ? null
        : design.widthMm,
    heightMm: design.frame == null ||
            !Measurements.knowsOverall(design, MeasureAxis.down)
        ? null
        : design.heightMm,
    createdAt: design.createdAt,
    updatedAt: design.updatedAt,
  );

  /// What the design is called in the list: who it is for, or — for a
  /// design kept before there was a customer — its own name.
  String get title {
    final who = customer?.trim();
    return who == null || who.isEmpty ? name : who;
  }

  /// Its [shortIdOf].
  String get number => shortIdOf(id);

  /// Whether a search for [query] finds it: its customer, its name, its id
  /// or its number holding what was typed, whatever the case.
  bool matches(String query) {
    final wanted = query.trim().toLowerCase();
    if (wanted.isEmpty) return true;
    return [
      customer ?? '',
      name,
      id,
      number,
    ].any((field) => field.toLowerCase().contains(wanted));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    if (customer != null) 'customer': customer,
    if (widthMm != null) 'w': widthMm,
    if (heightMm != null) 'h': heightMm,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DesignSummary fromJson(Map<String, Object?> map) => DesignSummary(
    id: map['id']! as String,
    name: map['name']! as String,
    kind: DesignKind.values.firstWhere(
      (k) => k.name == map['kind'],
      orElse: () => DesignKind.window,
    ),
    customer: map['customer'] as String?,
    widthMm: (map['w'] as num?)?.toDouble(),
    heightMm: (map['h'] as num?)?.toDouble(),
    createdAt: DateTime.parse(map['createdAt']! as String),
    updatedAt: DateTime.parse(map['updatedAt']! as String),
  );
}

/// One page of the designs a search found, most recently edited first, and
/// how many it found in all.
class DesignPage {
  final List<DesignSummary> items;
  final int total;

  const DesignPage(this.items, this.total);
}

/// Keeps designs between sessions.
///
/// The whole design is stored, sketch and all. The user's own marks are part
/// of the document, not a step on the way to it, so losing them on save
/// would lose the record of what they actually drew.
///
/// **Each design is kept on its own, and the list is kept apart from
/// them.** A workshop keeps a design for every person it draws for, so the
/// list has to stay quick however long it grows: [page] reads the index —
/// one [DesignSummary] a design — and hands back a page of it, and a design
/// itself is read by [load] only when it is shown or opened. The screens
/// ask only for pages and for single designs, so a store kept on a server
/// can stand in for this one without the screens changing.
///
/// This one keeps its designs on the device, in the browser's own storage
/// on the web. That has a size limit of its own — a few megabytes in most
/// browsers — which a server does not.
class DesignStore {
  /// Where the index is kept, and where each design is.
  static const indexKey = 'proframe.index.v2';
  static const designKeyPrefix = 'proframe.design.v2.';

  /// Where designs were kept before, every one in a single list; moved
  /// over, and removed, the first time the store is read.
  static const legacyKey = 'proframe.designs.v1';

  /// The index as last read, and the text it was read from — reused while
  /// that text is unchanged, so paging through it does not parse it again
  /// for every page.
  String? _indexText;
  List<DesignSummary> _index = const [];
  Map<String, DesignSummary> _byId = const {};

  /// Designs read recently, so a card that scrolls away and back is not
  /// read from storage again. Held by id and edit time, so an edited
  /// design is never shown as it was.
  final _recent = <String, Design>{};
  static const _recentLimit = 120;

  static String _designKey(String id) => '$designKeyPrefix$id';

  Future<List<DesignSummary>> _read(SharedPreferences prefs) async {
    await _moveLegacy(prefs);
    final text = prefs.getString(indexKey);
    if (text == null) {
      _byId = const {};
      return _index = const [];
    }
    if (identical(text, _indexText) || text == _indexText) return _index;
    final list = <DesignSummary>[];
    try {
      for (final entry in jsonDecode(text) as List<Object?>) {
        try {
          list.add(DesignSummary.fromJson(entry! as Map<String, Object?>));
        } on Object {
          // One unreadable line must not take the rest down with it.
          continue;
        }
      }
    } on Object {
      list.clear();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _indexText = text;
    _byId = {for (final s in list) s.id: s};
    return _index = list;
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<DesignSummary> index,
  ) async {
    final text = jsonEncode([for (final s in index) s.toJson()]);
    await prefs.setString(indexKey, text);
    _indexText = text;
    _index = index;
    _byId = {for (final s in index) s.id: s};
  }

  /// Designs kept by an earlier version of the app, in one list, moved to
  /// one key each with an index beside them.
  Future<void> _moveLegacy(SharedPreferences prefs) async {
    final legacy = prefs.getStringList(legacyKey);
    if (legacy == null) return;
    final existing = prefs.getString(indexKey);
    final index = <DesignSummary>[
      if (existing != null)
        for (final entry in jsonDecode(existing) as List<Object?>)
          DesignSummary.fromJson(entry! as Map<String, Object?>),
    ];
    final known = {for (final s in index) s.id};
    for (final entry in legacy) {
      try {
        final design = Design.fromJson(jsonDecode(entry));
        if (known.contains(design.id)) continue;
        await prefs.setString(_designKey(design.id), entry);
        index.add(DesignSummary.of(design));
      } on Object {
        continue;
      }
    }
    index.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _write(prefs, index);
    await prefs.remove(legacyKey);
  }

  /// The designs a search for [query] finds, most recently edited first:
  /// [limit] of them from [offset], and how many it found in all.
  Future<DesignPage> page({
    String query = '',
    int offset = 0,
    int limit = 40,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _read(prefs);
    final found = query.trim().isEmpty
        ? index
        : [
            for (final s in index)
              if (s.matches(query)) s,
          ];
    final start = offset.clamp(0, found.length);
    final end = (start + limit).clamp(start, found.length);
    return DesignPage(found.sublist(start, end), found.length);
  }

  /// How many designs are kept.
  Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _read(prefs)).length;
  }

  /// The design kept as [id], exactly as it was kept, or null where there is
  /// none.
  Future<Design?> load(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _read(prefs);
    // Read before, and not edited since: the same design.
    final kept = _recent[id];
    if (kept != null && kept.updatedAt == _byId[id]?.updatedAt) return kept;
    final text = prefs.getString(_designKey(id));
    if (text == null) return null;
    final Design design;
    try {
      design = Design.fromJson(jsonDecode(text));
    } on Object {
      return null;
    }
    _remember(design);
    return design;
  }

  void _remember(Design design) {
    _recent.remove(design.id);
    _recent[design.id] = design;
    if (_recent.length > _recentLimit) _recent.remove(_recent.keys.first);
  }

  Future<void> save(Design design) async {
    final prefs = await SharedPreferences.getInstance();
    final index = [
      for (final s in await _read(prefs))
        if (s.id != design.id) s,
    ];
    await prefs.setString(_designKey(design.id), jsonEncode(design.toJson()));
    final summary = DesignSummary.of(design);
    // In its place by when it was last edited, which for a design just
    // edited is the top.
    var at = 0;
    while (at < index.length &&
        !index[at].updatedAt.isBefore(summary.updatedAt)) {
      at++;
    }
    index.insert(at, summary);
    await _write(prefs, index);
    _remember(design);
  }

  Future<void> remove(String designId) async {
    final prefs = await SharedPreferences.getInstance();
    final index = [
      for (final s in await _read(prefs))
        if (s.id != designId) s,
    ];
    await prefs.remove(_designKey(designId));
    await _write(prefs, index);
    _recent.remove(designId);
  }

  /// A copy of the design kept as [id], made now under an id and a number
  /// of its own — the same drawing, geometry and everything said about it —
  /// kept beside the original, which is not touched. Null where nothing is
  /// kept as [id].
  ///
  /// So a workshop can start a customer's second door from their first
  /// without changing the first.
  Future<Design?> duplicate(String id, {DateTime? now}) async {
    final original = await load(id);
    if (original == null) return null;
    final at = now ?? DateTime.now();
    final json = original.toJson()
      ..['id'] = 'design-${at.microsecondsSinceEpoch}'
      ..['createdAt'] = at.toIso8601String()
      ..['updatedAt'] = at.toIso8601String();
    if (original.customer != null) {
      json['customer'] = '${original.customer} (copy)';
    } else {
      json['name'] = '${original.name} (copy)';
    }
    final copy = Design.fromJson(json);
    await save(copy);
    return copy;
  }

  /// The design kept as [id], now said to be for [customer]. Nothing else
  /// about it changes. Null where nothing is kept as [id].
  Future<Design?> rename(String id, String customer) async {
    final design = await load(id);
    final who = customer.trim();
    if (design == null || who.isEmpty) return null;
    final renamed = design.copyWith(customer: who);
    await save(renamed);
    return renamed;
  }

  /// Every design kept, whole, most recently edited first. For a handful —
  /// a test, an export — never for the list, which reads [page].
  Future<List<Design>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _read(prefs);
    return [for (final s in index) ?await load(s.id)];
  }
}

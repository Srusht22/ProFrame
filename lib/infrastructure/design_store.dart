import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dimensions/measurements.dart';
import '../domain/model/design.dart';
import 'customer_store.dart';

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

  /// The customer the design belongs to — see `Design.customerId`.
  final String? customerId;
  final String name;
  final DesignKind kind;

  /// What to call it on the screen — its name, or where it has none,
  /// `shownNameOf` says so.
  String get shownName => shownNameOf(name, kind);

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
    this.customerId,
    this.widthMm,
    this.heightMm,
  });

  factory DesignSummary.of(Design design) => DesignSummary(
    id: design.id,
    customer: design.customer,
    customerId: design.customerId,
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

  /// The same design, listed under [customerName] — the name its customer
  /// is kept under now — where there is one.
  DesignSummary under(String? customerName) =>
      customerName == null || customerName == customer
      ? this
      : DesignSummary(
          id: id,
          name: name,
          kind: kind,
          createdAt: createdAt,
          updatedAt: updatedAt,
          customer: customerName,
          customerId: customerId,
          widthMm: widthMm,
          heightMm: heightMm,
        );

  /// Its [shortIdOf].
  String get number => shortIdOf(id);

  /// Whether a search for [query] finds it: its customer, its name, its id
  /// or its number holding what was typed, whatever the case.
  ///
  /// Without [byCustomer] the customer's name is not searched — among one
  /// customer's own designs it is in every one of them, so it would find
  /// them all and tell none apart.
  bool matches(String query, {bool byCustomer = true}) {
    final wanted = query.trim().toLowerCase();
    if (wanted.isEmpty) return true;
    return [
      if (byCustomer) customer ?? '',
      name,
      id,
      number,
    ].any((field) => field.toLowerCase().contains(wanted));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': kind.name,
    if (customer != null) 'customer': customer,
    if (customerId != null) 'customerId': customerId,
    if (widthMm != null) 'w': widthMm,
    if (heightMm != null) 'h': heightMm,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DesignSummary fromJson(Map<String, Object?> map) => DesignSummary(
    id: map['id']! as String,
    name: map['name']! as String,
    // Kept as `category`; an index written before that said `kind`.
    kind: DesignKind.values.firstWhere(
      (k) => k.name == (map['category'] ?? map['kind']),
      orElse: () => DesignKind.window,
    ),
    customer: map['customer'] as String?,
    customerId: map['customerId'] as String?,
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
///
/// **Every design kept belongs to a customer.** One kept without a
/// `customerId` is given the customer it was typed as being for — the one
/// already called that in [customers], or a new one — and so is every
/// design kept before customers existed, the first time the store is read.
/// Nothing else about a design changes on the way in. A customer's designs
/// are then the designs naming it: [page] with a `customerId`.
class DesignStore {
  /// Where the people the designs belong to are kept.
  final CustomerStore customers;

  DesignStore({CustomerStore? customers})
    : customers = customers ?? CustomerStore();

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

  /// The index, with anything kept by an older version brought over first.
  Future<List<DesignSummary>> _read(SharedPreferences prefs) async {
    await _moveLegacy(prefs);
    return _withCustomers(prefs, _indexNow(prefs));
  }

  /// The index as the device holds it at this moment, read without
  /// waiting for anything.
  ///
  /// **Changing the index is a read and a write with nothing waited on in
  /// between**, and that is what keeps two changes made at once from losing
  /// one another. Storage takes a value the moment it is set, so an index
  /// read here and written back before anything is awaited cannot have been
  /// changed in between — by this store or any other instance of it, which
  /// all keep designs in the same place. Reading, then waiting, then
  /// writing is how four designs saved at once came back as one in the
  /// list, the other three kept on the device with nothing pointing at
  /// them.
  List<DesignSummary> _indexNow(SharedPreferences prefs) {
    final text = prefs.getString(indexKey);
    if (text == null) {
      _indexText = null;
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

  /// [index], with every design in it that has no customer yet given one.
  Future<List<DesignSummary>> _withCustomers(
    SharedPreferences prefs,
    List<DesignSummary> index,
  ) async {
    final waiting = index.any(
      (s) => s.customerId == null && !_unadoptable.contains(s.id),
    );
    return waiting ? _adoptAll(prefs, index) : index;
  }

  /// Designs whose file could not be read, and so could not be given a
  /// customer — tried once a session rather than on every read.
  final _unadoptable = <String>{};

  /// [design] as it is kept: belonging to a customer. One that already
  /// names its customer is returned as it is; one that does not is given
  /// the customer it was typed as being for, or — kept before anybody was
  /// asked — the one its own name stands for, as the list already showed
  /// it. Nothing else about it changes, not even when it was last edited.
  Future<Design> _owned(Design design) async {
    if (design.customerId != null) return design;
    final who = design.customer?.trim();
    final customer = await customers.obtain(
      who == null || who.isEmpty ? design.name : who,
      at: design.createdAt,
    );
    return design.copyWith(
      customerId: customer.id,
      updatedAt: design.updatedAt,
    );
  }

  /// Every design in [index] kept before customers existed, given its
  /// customer and kept again — the file and its line in the index — with
  /// nothing else about it changed.
  Future<List<DesignSummary>> _adoptAll(
    SharedPreferences prefs,
    List<DesignSummary> index,
  ) async {
    final adopted = <DesignSummary>[];
    for (final s in index) {
      if (s.customerId != null || _unadoptable.contains(s.id)) {
        adopted.add(s);
        continue;
      }
      final text = prefs.getString(_designKey(s.id));
      final Design design;
      try {
        design = Design.fromJson(jsonDecode(text!));
      } on Object {
        _unadoptable.add(s.id);
        adopted.add(s);
        continue;
      }
      final owned = await _owned(design);
      await prefs.setString(_designKey(s.id), jsonEncode(owned.toJson()));
      _recent.remove(s.id);
      adopted.add(DesignSummary.of(owned));
    }
    // Into the index as it is now, not as it was read before the waiting
    // above: anything kept meanwhile stays.
    final given = {for (final s in adopted) s.id: s};
    final merged = [for (final s in _indexNow(prefs)) given[s.id] ?? s];
    await _write(prefs, merged);
    return merged;
  }

  /// Sets the index to [index] now, and answers when the device has it.
  Future<bool> _write(SharedPreferences prefs, List<DesignSummary> index) {
    final text = jsonEncode([for (final s in index) s.toJson()]);
    final done = prefs.setString(indexKey, text);
    _indexText = text;
    _index = index;
    _byId = {for (final s in index) s.id: s};
    return done;
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
    // Nothing is waited on until all of it is written, so a second read
    // arriving meanwhile finds the move done rather than doing it again.
    final writes = <Future<bool>>[];
    for (final entry in legacy) {
      try {
        final design = Design.fromJson(jsonDecode(entry));
        if (known.contains(design.id)) continue;
        writes.add(prefs.setString(_designKey(design.id), entry));
        index.add(DesignSummary.of(design));
      } on Object {
        continue;
      }
    }
    index.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    writes
      ..add(_write(prefs, index))
      ..add(prefs.remove(legacyKey));
    await Future.wait(writes);
  }

  /// The designs a search for [query] finds, most recently edited first:
  /// [limit] of them from [offset], and how many it found in all. With
  /// [customerId], only that customer's designs, searched by what they are
  /// called rather than by whose they are; with [kind], only those of that
  /// category. Reading a page changes nothing that is kept.
  Future<DesignPage> page({
    String query = '',
    String? customerId,
    DesignKind? kind,
    int offset = 0,
    int limit = 40,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final names = customers.namesNow(prefs);
    // Each design under the name its customer has now: the name typed when
    // it was begun is kept in the design and not rewritten, so a customer
    // renamed is listed — and found — by the new name without any design
    // being touched.
    final index = [
      for (final s in await _read(prefs)) s.under(names[s.customerId]),
    ];
    final found = query.trim().isEmpty && customerId == null && kind == null
        ? index
        : [
            for (final s in index)
              if ((customerId == null || s.customerId == customerId) &&
                  (kind == null || s.kind == kind) &&
                  s.matches(query, byCustomer: customerId == null))
                s,
          ];
    final start = offset.clamp(0, found.length);
    final end = (start + limit).clamp(start, found.length);
    return DesignPage(found.sublist(start, end), found.length);
  }

  /// How many designs each customer has, by customer id, read from the
  /// index in one pass — a line a design, never the designs themselves. A
  /// customer with none is not in it.
  Future<Map<String, int>> countsByCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final counts = <String, int>{};
    for (final s in await _read(prefs)) {
      final owner = s.customerId;
      if (owner != null) counts[owner] = (counts[owner] ?? 0) + 1;
    }
    return counts;
  }

  /// How many of customer [customerId]'s designs there are of each
  /// category, read from the index in one pass. A category they have none
  /// of is not in it.
  Future<Map<DesignKind, int>> kindsOf(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = <DesignKind, int>{};
    for (final s in await _read(prefs)) {
      if (s.customerId != customerId) continue;
      counts[s.kind] = (counts[s.kind] ?? 0) + 1;
    }
    return counts;
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

  /// Keeps [design], and returns it as kept — belonging to a customer.
  Future<Design> save(Design unowned) async {
    final prefs = await SharedPreferences.getInstance();
    final design = await _owned(unowned);
    await _read(prefs);
    // From here to the writes nothing is waited on: see [_indexNow].
    final index = [
      for (final s in _indexNow(prefs))
        if (s.id != design.id) s,
    ];
    final file = prefs.setString(
      _designKey(design.id),
      jsonEncode(design.toJson()),
    );
    final summary = DesignSummary.of(design);
    // In its place by when it was last edited, which for a design just
    // edited is the top.
    var at = 0;
    while (at < index.length &&
        !index[at].updatedAt.isBefore(summary.updatedAt)) {
      at++;
    }
    index.insert(at, summary);
    final written = _write(prefs, index);
    _remember(design);
    await Future.wait([file, written]);
    return design;
  }

  Future<void> remove(String designId) async {
    final prefs = await SharedPreferences.getInstance();
    await _read(prefs);
    // From here to the writes nothing is waited on: see [_indexNow].
    final index = [
      for (final s in _indexNow(prefs))
        if (s.id != designId) s,
    ];
    final file = prefs.remove(_designKey(designId));
    final written = _write(prefs, index);
    _recent.remove(designId);
    await Future.wait([file, written]);
  }

  /// A copy of the design kept as [id], made now under an id and a number
  /// of its own — the same drawing, geometry and everything said about it —
  /// kept beside the original, which is not touched. Null where nothing is
  /// kept as [id].
  ///
  /// So a workshop can start a customer's second door from their first
  /// without changing the first. The copy is the same customer's — another
  /// of their designs, not another person — and it is the design's own
  /// name that says it is the copy.
  Future<Design?> duplicate(String id, {DateTime? now}) async {
    final original = await load(id);
    if (original == null) return null;
    final at = now ?? DateTime.now();
    final json = original.toJson()
      ..['id'] = 'design-${at.microsecondsSinceEpoch}'
      ..['name'] = '${original.name} (copy)'
      ..['createdAt'] = at.toIso8601String()
      ..['updatedAt'] = at.toIso8601String();
    return save(Design.fromJson(json));
  }

  /// The design kept as [id], now said to be for [customer] — and so
  /// belonging to the customer of that name, who is made if there is none.
  /// Nothing else about it changes. Null where nothing is kept as [id].
  Future<Design?> rename(String id, String customer) async {
    final design = await load(id);
    final who = customer.trim();
    if (design == null || who.isEmpty) return null;
    final owner = await customers.obtain(who);
    return save(design.copyWith(customer: who, customerId: owner.id));
  }

  /// The design kept as [id], now called [name] — trimmed — and nothing
  /// else about it changed: the same id, the same customer, the same
  /// category, and its drawing, geometry, sizes, openings, lines and
  /// materials exactly as kept. Null where nothing is kept as [id] or the
  /// name is empty.
  Future<Design?> retitle(String id, String name) async {
    final design = await load(id);
    final called = name.trim();
    if (design == null || called.isEmpty) return null;
    return save(design.copyWith(name: called));
  }

  /// Every design kept, whole, most recently edited first. For a handful —
  /// a test, an export — never for the list, which reads [page].
  Future<List<Design>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _read(prefs);
    return [for (final s in index) ?await load(s.id)];
  }
}

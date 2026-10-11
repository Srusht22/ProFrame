import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing/pricing_access.dart';
import '../domain/pricing/quotation.dart';
import '../domain/text/words.dart';

/// One page of a customer's quotations, newest first, and how many there
/// are.
class QuotationPage {
  final List<Quotation> items;
  final int total;

  const QuotationPage(this.items, this.total);
}

/// Keeps the workshop's quotations.
///
/// One key a quotation, and beside them one list a customer of their
/// quotations' ids, newest first — so a customer's page reads one page of
/// quotations and never all of them, and a quotation, which carries every
/// design's whole price, is read only when it is shown. A quotation is
/// written whole when it is made and again only when its status changes;
/// nothing here removes one.
class QuotationStore {
  /// Who is reading, for a store the application hands out: asked before
  /// anything is read through it, so seeing what is kept needs its `.view`
  /// capability in the store itself and not only on the screen. Null for a
  /// store with nobody to ask — the device's own housekeeping, or a test —
  /// which reads as the device always could.
  final Future<Authority> Function()? readsAs;

  QuotationStore({this.readsAs});

  /// Nothing where whoever is reading may see quotations; [AccessDenied]
  /// otherwise, before anything is read.
  Future<void> _mayRead() async {
    final who = readsAs;
    if (who != null) (await who()).require(Capability.quotationsView);
  }

  static const keyPrefix = 'proframe.quotation.v1.';
  static const indexPrefix = 'proframe.quotations.v1.';

  /// The last number given to a quotation.
  static const sequenceKey = 'proframe.quotation-sequence.v1';

  static String _key(String id) => '$keyPrefix$id';
  static String _indexKey(String customerId) => '$indexPrefix$customerId';

  /// Makes a quotation: [build] is handed the next number and gives the
  /// quotation, or why it cannot be made — in which case nothing is
  /// written and no number is used. Needs `quotations.create`, asked [by];
  /// without it nothing is written and [AccessDenied] is thrown.
  ///
  /// The number is the sequence kept on the device, plus one, taken and
  /// written with nothing waited on in between, so two quotations made at
  /// once are two numbers. Where the sequence has been lost it starts after
  /// the highest number kept.
  Future<({Quotation? quotation, String? problem})> create(
    ({Quotation? quotation, String? problem}) Function(int number) build, {
    required Authority by,
  }) async {
    by.require(Capability.quotationsCreate);
    final prefs = await SharedPreferences.getInstance();
    final made = build(_last(prefs) + 1);
    final q = made.quotation;
    if (q == null) return made;
    final index = [q.id, ..._ids(prefs, q.customerId)];
    await Future.wait([
      prefs.setInt(sequenceKey, q.number),
      prefs.setString(_key(q.id), jsonEncode(q.toJson())),
      prefs.setString(_indexKey(q.customerId), jsonEncode(index)),
    ]);
    return made;
  }

  /// Quotation [id] made [next] at [now], asked [by] whoever holds
  /// `quotations.edit` — or why it cannot. Only its status changes.
  Future<({Quotation? quotation, String? problem})> setStatus(
    String id,
    QuotationStatus next, {
    required Authority by,
    DateTime? now,
    Words words = const EnglishWords(),
  }) async {
    by.require(Capability.quotationsEdit);
    final prefs = await SharedPreferences.getInstance();
    final kept = _loadNow(prefs, id);
    if (kept == null) {
      return (quotation: null, problem: words.quotationGone);
    }
    final changed = kept.become(
      next,
      at: now ?? DateTime.now(),
      by: by.label,
      words: words,
    );
    if (changed.quotation case final q?) {
      await prefs.setString(_key(q.id), jsonEncode(q.toJson()));
    }
    return changed;
  }

  /// The quotation kept as [id], or null where there is none or it cannot
  /// be read.
  Future<Quotation?> load(String id) async {
    await _mayRead();
    return _loadNow(await SharedPreferences.getInstance(), id);
  }

  /// [limit] of customer [customerId]'s quotations from [offset], newest
  /// first, and how many they have.
  Future<QuotationPage> page(
    String customerId, {
    int offset = 0,
    int limit = 5,
  }) async {
    await _mayRead();
    final prefs = await SharedPreferences.getInstance();
    final ids = _ids(prefs, customerId);
    final start = offset.clamp(0, ids.length);
    final end = (start + limit).clamp(start, ids.length);
    return QuotationPage([
      for (final id in ids.sublist(start, end)) ?_loadNow(prefs, id),
    ], ids.length);
  }

  List<String> _ids(SharedPreferences prefs, String customerId) {
    final text = prefs.getString(_indexKey(customerId));
    if (text == null) return const [];
    try {
      return [
        for (final id in jsonDecode(text) as List<Object?>)
          if (id is String) id,
      ];
    } on Object {
      return const [];
    }
  }

  Quotation? _loadNow(SharedPreferences prefs, String id) {
    final text = prefs.getString(_key(id));
    if (text == null) return null;
    try {
      return Quotation.fromJson(jsonDecode(text));
    } on Object {
      return null;
    }
  }

  int _last(SharedPreferences prefs) {
    final kept = prefs.getInt(sequenceKey);
    if (kept != null) return kept;
    var highest = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(keyPrefix)) continue;
      final q = _loadNow(prefs, key.substring(keyPrefix.length));
      if (q != null && q.number > highest) highest = q.number;
    }
    return highest;
  }
}

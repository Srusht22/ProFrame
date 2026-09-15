import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/design.dart';

/// Keeps designs between sessions.
///
/// The whole design is stored, sketch and all. The user's own marks are part
/// of the document, not a step on the way to it, so losing them on save
/// would lose the record of what they actually drew.
class DesignStore {
  static const _key = 'proframe.designs.v1';

  Future<List<Design>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final designs = <Design>[];
    for (final entry in raw) {
      try {
        designs.add(Design.fromJson(jsonDecode(entry)));
      } on Object {
        // One unreadable design must not take the rest down with it.
        continue;
      }
    }
    designs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return designs;
  }

  Future<void> save(Design design) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? const [];
    final kept = <String>[];
    for (final entry in existing) {
      try {
        final map = jsonDecode(entry) as Map<String, Object?>;
        if (map['id'] != design.id) kept.add(entry);
      } on Object {
        continue;
      }
    }
    kept.insert(0, jsonEncode(design.toJson()));
    await prefs.setStringList(_key, kept);
  }

  Future<void> remove(String designId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? const [];
    final kept = <String>[];
    for (final entry in existing) {
      try {
        final map = jsonDecode(entry) as Map<String, Object?>;
        if (map['id'] != designId) kept.add(entry);
      } on Object {
        continue;
      }
    }
    await prefs.setStringList(_key, kept);
  }
}

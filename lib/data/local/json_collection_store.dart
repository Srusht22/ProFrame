import 'dart:convert';
import 'key_value_store.dart';

/// Persists a `List<T>` as a single JSON blob under [collectionKey].
/// Every "local" repository is a thin CRUD wrapper around one of these —
/// this is the only class that touches `jsonEncode`/`jsonDecode`.
class JsonCollectionStore<T> {
  final IKeyValueStore keyValueStore;
  final String collectionKey;
  final Map<String, dynamic> Function(T item) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  JsonCollectionStore({
    required this.keyValueStore,
    required this.collectionKey,
    required this.toJson,
    required this.fromJson,
  });

  Future<List<T>> readAll() async {
    final raw = await keyValueStore.read(collectionKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeAll(List<T> items) async {
    final encoded = jsonEncode(items.map(toJson).toList());
    await keyValueStore.write(collectionKey, encoded);
  }

  Future<bool> isSeeded() async => (await keyValueStore.read('${collectionKey}__seeded')) == '1';

  Future<void> markSeeded() async => keyValueStore.write('${collectionKey}__seeded', '1');
}

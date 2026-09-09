import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/key_value_store.dart';
import '../../shared/models/design_document.dart';

/// Saved designs, stored locally so the whole app works offline (§57).
class DesignRepository {
  final KeyValueStore store;

  const DesignRepository(this.store);

  Future<List<DesignDocument>> loadAll() async {
    final raw = await store.read(AppConstants.designsKey);
    if (raw == null || raw.isEmpty) return <DesignDocument>[];
    try {
      final list = jsonDecode(raw) as List;
      final designs = list
          .map((e) => DesignDocument.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      designs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return designs;
    } catch (error) {
      throw StorageException('Saved designs could not be read.', cause: error);
    }
  }

  Future<void> saveAll(List<DesignDocument> designs) async {
    try {
      await store.write(
        AppConstants.designsKey,
        jsonEncode(designs.map((d) => d.toJson()).toList()),
      );
    } catch (error) {
      throw StorageException('The design could not be saved.', cause: error);
    }
  }

  Future<DesignDocument?> findById(String id) async {
    final all = await loadAll();
    for (final design in all) {
      if (design.id == id) return design;
    }
    return null;
  }

  Future<List<DesignDocument>> save(DesignDocument design) async {
    final all = await loadAll();
    final index = all.indexWhere((d) => d.id == design.id);
    if (index >= 0) {
      all[index] = design;
    } else {
      all.insert(0, design);
    }
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await saveAll(all);
    return all;
  }

  Future<List<DesignDocument>> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((d) => d.id == id);
    await saveAll(all);
    return all;
  }

  // -- unfinished work recovery (§56) --------------------------------------

  Future<void> saveDraft(DesignDocument design) async {
    await store.write(AppConstants.draftKey, jsonEncode(design.toJson()));
  }

  Future<DesignDocument?> loadDraft() async {
    final raw = await store.read(AppConstants.draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DesignDocument.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // A corrupt draft must never block the app from starting.
      await clearDraft();
      return null;
    }
  }

  Future<void> clearDraft() => store.delete(AppConstants.draftKey);
}

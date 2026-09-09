import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/utilities/id_generator.dart';
import '../../shared/models/design_document.dart';
import '../../shared/models/opening_model.dart';
import 'design_templates.dart';

/// The list of saved designs.
class DesignLibrary extends AsyncNotifier<List<DesignDocument>> {
  @override
  Future<List<DesignDocument>> build() =>
      ref.watch(designRepositoryProvider).loadAll();

  Future<DesignDocument> create(OpeningKind kind, {String? name}) async {
    final design = DesignDocument.blank(id: IdGenerator.generate(), kind: kind, name: name);
    final all = await ref.read(designRepositoryProvider).save(design);
    state = AsyncData(all);
    return design;
  }

  /// Starts from a ready-made configuration. The result is an ordinary design
  /// with an empty sketch — it can be edited freely, or drawn over.
  Future<DesignDocument> createFromTemplate(DesignTemplate template) async {
    final id = IdGenerator.generate();
    final design = DesignDocument.blank(id: id, kind: template.kind, name: template.name)
        .copyWith(model: template.build(id));
    final all = await ref.read(designRepositoryProvider).save(design);
    state = AsyncData(all);
    return design;
  }

  /// Copies a saved design, history excluded — a copy starts its own history.
  Future<DesignDocument> duplicate(DesignDocument source) async {
    final copy = DesignDocument(
      id: IdGenerator.generate(),
      name: '${source.name} copy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sketch: source.sketch,
      model: source.model,
      calibration: source.calibration,
      notes: source.notes,
    );
    final all = await ref.read(designRepositoryProvider).save(copy);
    state = AsyncData(all);
    return copy;
  }

  Future<void> save(DesignDocument design) async {
    final all = await ref.read(designRepositoryProvider).save(design);
    state = AsyncData(all);
  }

  Future<void> remove(String id) async {
    final all = await ref.read(designRepositoryProvider).delete(id);
    state = AsyncData(all);
  }

  Future<void> rename(DesignDocument design, String name) =>
      save(design.copyWith(name: name));
}

final designLibraryProvider =
    AsyncNotifierProvider<DesignLibrary, List<DesignDocument>>(DesignLibrary.new);

/// The unfinished design found on start-up, if any (§56).
final recoverableDraftProvider = FutureProvider<DesignDocument?>(
  (ref) => ref.watch(designRepositoryProvider).loadDraft(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/utilities/id_generator.dart';
import '../../shared/models/design_document.dart';
import '../../shared/models/opening_model.dart';

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

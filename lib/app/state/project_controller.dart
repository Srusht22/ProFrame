import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/design_document.dart';
import '../../infrastructure/key_value_store.dart';
import '../../infrastructure/project_repository.dart';

/// The store the app saves into.
///
/// Overridden in `main` with the real device store, and in tests with an
/// in-memory one — which is what lets saving and recovery be tested without a
/// platform channel.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError(
    'Override keyValueStoreProvider with a real store in main().',
  ),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(keyValueStoreProvider)),
);

/// Saved projects, newest first.
final projectListProvider = FutureProvider<List<ProjectSummary>>(
  (ref) => ref.watch(projectRepositoryProvider).list(),
);

/// Whether the design on screen has unsaved changes.
class SaveState {
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSavedAt;

  /// Set when a save failed, so the user is told rather than left believing
  /// their work is safe (spec section 10).
  final String? error;

  const SaveState({
    this.isDirty = false,
    this.isSaving = false,
    this.lastSavedAt,
    this.error,
  });

  SaveState copyWith({
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSavedAt,
    String? error,
    bool clearError = false,
  }) =>
      SaveState(
        isDirty: isDirty ?? this.isDirty,
        isSaving: isSaving ?? this.isSaving,
        lastSavedAt: lastSavedAt ?? this.lastSavedAt,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Saves the design being edited.
///
/// Two mechanisms, on purpose:
///
/// * **Autosave to a draft** runs a moment after every change. It is a safety
///   net for a closed tab or a flat battery, and a failure there is silent
///   because interrupting a drawing gesture to report it would be worse than
///   the risk.
/// * **Save** writes the real project and *does* report a failure, because a
///   user who thinks their work is saved when it is not will lose it.
class SaveController extends Notifier<SaveState> {
  Timer? _autosaveTimer;

  /// How long after the last change the draft is written. Long enough that a
  /// continuous drawing gesture writes once, not once per stroke.
  static const Duration autosaveDelay = Duration(milliseconds: 900);

  @override
  SaveState build() {
    ref.onDispose(() => _autosaveTimer?.cancel());
    return const SaveState();
  }

  /// Records that the design changed and schedules a draft write.
  void markChanged(DesignDocument design) {
    state = state.copyWith(isDirty: true, clearError: true);
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () {
      unawaited(ref.read(projectRepositoryProvider).saveDraft(design));
    });
  }

  /// Writes the project properly.
  Future<bool> save(DesignDocument design) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(projectRepositoryProvider).save(design);
      // The draft has served its purpose once the real save lands.
      await ref.read(projectRepositoryProvider).clearDraft();
      state = SaveState(lastSavedAt: DateTime.now());
      ref.invalidate(projectListProvider);
      return true;
    } on DesignDataException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: 'This project could not be saved: $error',
      );
      return false;
    }
  }

  /// Called when a different project is opened.
  void reset() {
    _autosaveTimer?.cancel();
    state = const SaveState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final saveControllerProvider =
    NotifierProvider<SaveController, SaveState>(SaveController.new);

/// The unfinished design from a previous run, if there is one.
final recoverableDraftProvider = FutureProvider<DesignDocument?>(
  (ref) => ref.watch(projectRepositoryProvider).loadDraft(),
);

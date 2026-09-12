import 'dart:convert';

import '../core/errors/app_exception.dart';
import '../domain/design_document.dart';
import 'key_value_store.dart';

/// A saved project, as it appears in the list, without loading the whole
/// design.
class ProjectSummary {
  final String id;
  final String name;
  final DateTime updatedAt;

  /// What it is, in a few words, for the card.
  final String description;

  /// True when the file could not be read. It is listed anyway, so a damaged
  /// project is visible rather than silently absent (spec section 10).
  final bool isDamaged;

  const ProjectSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.description,
    this.isDamaged = false,
  });
}

/// Saves and reopens projects.
///
/// Every project is stored as the full structured design — never a picture, so
/// reopening gives back something editable rather than a preview
/// (spec section 10).
///
/// **Writes are atomic.** A project is written to a scratch key first and only
/// then moved to its real one, so a save interrupted halfway leaves the
/// previous version intact instead of a half-written file.
class ProjectRepository {
  static const String _projectPrefix = 'proframe.project.';
  static const String _scratchPrefix = 'proframe.writing.';
  static const String _draftKey = 'proframe.draft';

  final KeyValueStore _store;

  const ProjectRepository(this._store);

  String _keyFor(String id) => '$_projectPrefix$id';

  // -- saving ---------------------------------------------------------------

  /// Saves [design], replacing any previous version of the same project.
  ///
  /// Throws [DesignDataException] if the store refuses the write, so the UI
  /// can tell the user their work is not saved rather than letting them close
  /// the app believing it is.
  Future<void> save(DesignDocument design) async {
    final encoded = jsonEncode(design.toJson());
    final scratch = '$_scratchPrefix${design.id}';

    try {
      // Written aside first: if this is interrupted, the real key is untouched
      // and the previous save survives.
      await _store.write(scratch, encoded);
      await _store.write(_keyFor(design.id), encoded);
      await _store.delete(scratch);
    } on Object catch (error) {
      throw DesignDataException(
        'This project could not be saved: $error',
        path: design.id,
      );
    }
  }

  /// Loads one project, or null when there is no such project.
  ///
  /// Throws [DesignDataException] when the project exists but cannot be read —
  /// a damaged file is reported, never quietly replaced with a blank design.
  Future<DesignDocument?> load(String id) async {
    final raw = await _store.read(_keyFor(id));
    if (raw == null) return null;
    return _decode(raw, id);
  }

  Future<void> delete(String id) async {
    await _store.delete(_keyFor(id));
    await _store.delete('$_scratchPrefix$id');
  }

  /// Every saved project, newest first.
  ///
  /// A project that will not parse is listed as damaged rather than skipped:
  /// the user needs to know it is there and broken, not wonder where it went.
  Future<List<ProjectSummary>> list() async {
    final keys = await _store.keys();
    final summaries = <ProjectSummary>[];

    for (final key in keys.where((k) => k.startsWith(_projectPrefix))) {
      final id = key.substring(_projectPrefix.length);
      final raw = await _store.read(key);
      if (raw == null) continue;
      try {
        final design = _decode(raw, id);
        summaries.add(
          ProjectSummary(
            id: design.id,
            name: design.name,
            updatedAt: design.updatedAt,
            description: _describe(design),
          ),
        );
      } on Object {
        summaries.add(
          ProjectSummary(
            id: id,
            name: 'Damaged project',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            description: 'This project cannot be opened.',
            isDamaged: true,
          ),
        );
      }
    }

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  /// Copies a project under a new id and name.
  ///
  /// A duplicate is a new project: it gets its own id so editing it cannot
  /// touch the original (spec section 3).
  Future<DesignDocument> duplicate(
    DesignDocument design, {
    required String newId,
    String? newName,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final copy = DesignDocument.fromJson({
      ...design.toJson(),
      'id': newId,
      'name': newName ?? '${design.name} (copy)',
      'createdAt': timestamp.toUtc().toIso8601String(),
      'updatedAt': timestamp.toUtc().toIso8601String(),
    });
    await save(copy);
    return copy;
  }

  // -- drafts ---------------------------------------------------------------

  /// Keeps the design being worked on, so a crash or a closed tab does not
  /// lose it (spec section 10).
  ///
  /// A draft failing to write is not worth interrupting the user over — it is
  /// a safety net, not the save — so this swallows a failure rather than
  /// throwing into the middle of a drawing gesture.
  Future<void> saveDraft(DesignDocument design) async {
    try {
      await _store.write(_draftKey, jsonEncode(design.toJson()));
    } on Object {
      // Deliberately ignored; `save` is the one that reports.
    }
  }

  /// The unfinished design, if there is one.
  ///
  /// A draft that will not parse returns null rather than throwing: it is
  /// offered as a recovery, and a broken recovery must not block start-up.
  Future<DesignDocument?> loadDraft() async {
    final raw = await _store.read(_draftKey);
    if (raw == null) return null;
    try {
      return _decode(raw, 'draft');
    } on Object {
      return null;
    }
  }

  Future<void> clearDraft() async => _store.delete(_draftKey);

  // -- helpers --------------------------------------------------------------

  static DesignDocument _decode(String raw, String id) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw DesignDataException(
        'This project file is not readable.',
        path: id,
      );
    }
    return DesignDocument.fromJson(decoded);
  }

  static String _describe(DesignDocument design) {
    final size = design.overallWidth == null || design.overallHeight == null
        ? 'not measured'
        : '${design.overallWidth!.millimetres.round()} × '
            '${design.overallHeight!.millimetres.round()} mm';
    return '${design.category.label} · ${design.material.label} · $size · '
        '${design.panels.length} '
        '${design.panels.length == 1 ? 'panel' : 'panels'}';
  }
}

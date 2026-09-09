import 'opening_model.dart';
import 'scale_calibration.dart';
import 'sketch.dart';

/// A point in a design's history that the user can go back to (§47).
class DesignVersion {
  final String id;
  final DateTime createdAt;
  final String label;
  final Sketch sketch;
  final OpeningModel model;
  final ScaleCalibration calibration;

  const DesignVersion({
    required this.id,
    required this.createdAt,
    required this.label,
    required this.sketch,
    required this.model,
    required this.calibration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'label': label,
        'sketch': sketch.toJson(),
        'model': model.toJson(),
        'calibration': calibration.toJson(),
      };

  factory DesignVersion.fromJson(Map<String, dynamic> json) => DesignVersion(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        label: (json['label'] as String?) ?? 'Version',
        sketch: Sketch.fromJson(Map<String, dynamic>.from(json['sketch'] as Map)),
        model: OpeningModel.fromJson(Map<String, dynamic>.from(json['model'] as Map)),
        calibration:
            ScaleCalibration.fromJson(Map<String, dynamic>.from(json['calibration'] as Map)),
      );
}

/// Everything that makes up a saved design: the original ink, the scale, the
/// parametric model, and the history behind it (§46).
///
/// The 2D drawing, the 3D scene and the price are *not* stored — they are
/// derived from [model] every time, so a saved design can never disagree with
/// itself.
class DesignDocument {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Sketch sketch;
  final OpeningModel model;
  final ScaleCalibration calibration;
  final List<DesignVersion> versions;
  final String? notes;

  const DesignDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.sketch,
    required this.model,
    required this.calibration,
    this.versions = const [],
    this.notes,
  });

  factory DesignDocument.blank({
    required String id,
    required OpeningKind kind,
    String? name,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return DesignDocument(
      id: id,
      name: name ?? 'Untitled ${kind.label.toLowerCase()}',
      createdAt: timestamp,
      updatedAt: timestamp,
      sketch: const Sketch(),
      model: OpeningModel.blank(kind, id: id),
      calibration: ScaleCalibration.assumed,
    );
  }

  OpeningKind get kind => model.kind;

  String get sizeLabel =>
      '${model.widthMm.round()} × ${model.heightMm.round()} mm';

  DesignDocument copyWith({
    String? name,
    DateTime? updatedAt,
    Sketch? sketch,
    OpeningModel? model,
    ScaleCalibration? calibration,
    List<DesignVersion>? versions,
    String? notes,
  }) =>
      DesignDocument(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        sketch: sketch ?? this.sketch,
        model: model ?? this.model,
        calibration: calibration ?? this.calibration,
        versions: versions ?? this.versions,
        notes: notes ?? this.notes,
      );

  /// Snapshots the current state into the history. The most recent 20 entries
  /// are kept so a long editing session cannot grow unbounded on device.
  DesignDocument withVersionSnapshot(String label, {DateTime? now, String? versionId}) {
    final timestamp = now ?? DateTime.now();
    final snapshot = DesignVersion(
      id: versionId ?? 'v${timestamp.microsecondsSinceEpoch}',
      createdAt: timestamp,
      label: label,
      sketch: sketch,
      model: model,
      calibration: calibration,
    );
    final next = [snapshot, ...versions];
    return copyWith(
      versions: next.length > 20 ? next.sublist(0, 20) : next,
      updatedAt: timestamp,
    );
  }

  /// Restores a previous version, keeping the history intact and recording
  /// the state being replaced so a restore is itself undoable.
  DesignDocument restoreVersion(String versionId, {DateTime? now}) {
    final target = versions.where((v) => v.id == versionId).firstOrNull;
    if (target == null) return this;
    final withBackup = withVersionSnapshot('Before restore', now: now);
    return withBackup.copyWith(
      sketch: target.sketch,
      model: target.model,
      calibration: target.calibration,
      updatedAt: now ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sketch': sketch.toJson(),
        'model': model.toJson(),
        'calibration': calibration.toJson(),
        'versions': versions.map((v) => v.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };

  factory DesignDocument.fromJson(Map<String, dynamic> json) => DesignDocument(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Untitled design',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        sketch: Sketch.fromJson(Map<String, dynamic>.from(json['sketch'] as Map)),
        model: OpeningModel.fromJson(Map<String, dynamic>.from(json['model'] as Map)),
        calibration:
            ScaleCalibration.fromJson(Map<String, dynamic>.from(json['calibration'] as Map)),
        versions: ((json['versions'] as List?) ?? const [])
            .map((e) => DesignVersion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: json['notes'] as String?,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Production workflow stages (spec §26), in factory-floor order.
enum ManufacturingStage {
  productionOrder('Production Order'),
  materialPreparation('Material Preparation'),
  cutting('Cutting'),
  assembly('Assembly'),
  glassInstallation('Glass Installation'),
  hardwareInstallation('Hardware Installation'),
  qualityControl('Quality Control'),
  packaging('Packaging'),
  delivery('Delivery'),
  installation('Installation'),
  completed('Completed');

  final String label;
  const ManufacturingStage(this.label);

  static const List<ManufacturingStage> ordered = ManufacturingStage.values;

  ManufacturingStage? get next {
    final i = ordered.indexOf(this);
    if (i < 0 || i == ordered.length - 1) return null;
    return ordered[i + 1];
  }

  double get progressFraction => (ordered.indexOf(this) + 1) / ordered.length;
}

enum QcResult { pending, pass, fail, notApplicable }

class QcCheckItem {
  final String id;
  final String label;
  final QcResult result;
  final String? note;

  const QcCheckItem({
    required this.id,
    required this.label,
    this.result = QcResult.pending,
    this.note,
  });

  QcCheckItem copyWith({QcResult? result, String? note}) => QcCheckItem(
        id: id,
        label: label,
        result: result ?? this.result,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'result': result.name,
        'note': note,
      };

  factory QcCheckItem.fromJson(Map<String, dynamic> json) => QcCheckItem(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        result: QcResult.values.firstWhere(
          (e) => e.name == json['result'],
          orElse: () => QcResult.pending,
        ),
        note: json['note'] as String?,
      );

  static List<QcCheckItem> standardChecklist() => const [
        QcCheckItem(id: 'dimensions', label: 'Dimensions verified against configuration'),
        QcCheckItem(id: 'frame', label: 'Frame inspected — square, no distortion'),
        QcCheckItem(id: 'glass', label: 'Glass inspected — no chips or scratches'),
        QcCheckItem(id: 'handle', label: 'Handle operation inspected'),
        QcCheckItem(id: 'hinges', label: 'Hinges inspected and torque-checked'),
        QcCheckItem(id: 'lock', label: 'Lock tested'),
        QcCheckItem(id: 'finish', label: 'Surface finish inspected'),
        QcCheckItem(id: 'seals', label: 'Weather seals inspected'),
        QcCheckItem(id: 'finalMeasure', label: 'Final measurements verified'),
      ];
}

class ManufacturingOrder {
  final String id;
  final String moNumber;
  final String orderId;
  final String projectId;
  final ManufacturingStage stage;
  final List<QcCheckItem> qcChecklist;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManufacturingOrder({
    required this.id,
    required this.moNumber,
    required this.orderId,
    required this.projectId,
    this.stage = ManufacturingStage.productionOrder,
    this.qcChecklist = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get qcPassed =>
      qcChecklist.isNotEmpty && qcChecklist.every((c) => c.result == QcResult.pass || c.result == QcResult.notApplicable);

  bool get qcHasFailure => qcChecklist.any((c) => c.result == QcResult.fail);

  ManufacturingOrder copyWith({
    ManufacturingStage? stage,
    List<QcCheckItem>? qcChecklist,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ManufacturingOrder(
      id: id,
      moNumber: moNumber,
      orderId: orderId,
      projectId: projectId,
      stage: stage ?? this.stage,
      qcChecklist: qcChecklist ?? this.qcChecklist,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'moNumber': moNumber,
        'orderId': orderId,
        'projectId': projectId,
        'stage': stage.name,
        'qcChecklist': qcChecklist.map((e) => e.toJson()).toList(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ManufacturingOrder.fromJson(Map<String, dynamic> json) => ManufacturingOrder(
        id: json['id'] as String,
        moNumber: json['moNumber'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        stage: ManufacturingStage.values.firstWhere(
          (e) => e.name == json['stage'],
          orElse: () => ManufacturingStage.productionOrder,
        ),
        qcChecklist: (json['qcChecklist'] as List?)
                ?.map((e) => QcCheckItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        notes: json['notes'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

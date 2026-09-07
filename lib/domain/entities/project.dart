enum ProjectStatus {
  draft('Draft'),
  design('Design'),
  quotation('Quotation'),
  approved('Approved'),
  manufacturing('Manufacturing'),
  installation('Installation'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const ProjectStatus(this.label);
}

enum ProjectType {
  residential('Residential'),
  commercial('Commercial'),
  industrial('Industrial'),
  renovation('Renovation');

  final String label;
  const ProjectType(this.label);
}

class Project {
  final String id;
  final String projectNumber;
  final String name;
  final String customerId;
  final String? location;
  final ProjectType type;
  final ProjectStatus status;
  final String? description;
  final DateTime? startDate;
  final DateTime? expectedCompletionDate;
  final String? notes;

  /// Ids of [ProductConfiguration] items belonging to this project.
  final List<String> configurationIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.projectNumber,
    required this.name,
    required this.customerId,
    this.location,
    this.type = ProjectType.residential,
    this.status = ProjectStatus.draft,
    this.description,
    this.startDate,
    this.expectedCompletionDate,
    this.notes,
    this.configurationIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({
    String? name,
    String? customerId,
    String? location,
    ProjectType? type,
    ProjectStatus? status,
    String? description,
    DateTime? startDate,
    DateTime? expectedCompletionDate,
    String? notes,
    List<String>? configurationIds,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      projectNumber: projectNumber,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      location: location ?? this.location,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      notes: notes ?? this.notes,
      configurationIds: configurationIds ?? this.configurationIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectNumber': projectNumber,
        'name': name,
        'customerId': customerId,
        'location': location,
        'type': type.name,
        'status': status.name,
        'description': description,
        'startDate': startDate?.toIso8601String(),
        'expectedCompletionDate': expectedCompletionDate?.toIso8601String(),
        'notes': notes,
        'configurationIds': configurationIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        projectNumber: json['projectNumber'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled project',
        customerId: json['customerId'] as String? ?? '',
        location: json['location'] as String?,
        type: ProjectType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ProjectType.residential,
        ),
        status: ProjectStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ProjectStatus.draft,
        ),
        description: json['description'] as String?,
        startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
        expectedCompletionDate: json['expectedCompletionDate'] != null
            ? DateTime.tryParse(json['expectedCompletionDate'] as String)
            : null,
        notes: json['notes'] as String?,
        configurationIds:
            (json['configurationIds'] as List?)?.map((e) => e as String).toList() ?? const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

enum NotificationType {
  quotationAccepted,
  quotationRejected,
  lowInventory,
  newOrder,
  manufacturingCompleted,
  qualityControlFailed,
  projectDeadline,
  general,
}

/// In-app notification. The [type] doubles as a routing hint for future
/// push-notification integration (spec §29): a push provider can key its
/// payload off the same enum without the domain model changing.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedEntityId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.relatedEntityId,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        relatedEntityId: relatedEntityId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'relatedEntityId': relatedEntityId,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: NotificationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NotificationType.general,
        ),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        relatedEntityId: json['relatedEntityId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

import 'permission.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? avatarInitial;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarInitial,
    this.isActive = true,
    required this.createdAt,
  });

  bool can(Permission permission) => RolePermissions.can(role, permission);

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'avatarInitial': avatarInitial,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Unknown User',
        email: json['email'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.viewer,
        ),
        avatarInitial: json['avatarInitial'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

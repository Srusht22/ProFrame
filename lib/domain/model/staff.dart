import '../pricing/pricing_access.dart';

/// A member of the workshop's staff, and what the owner allows them.
///
/// The owner adds them (`users.manage`) and gives or takes away their
/// capabilities (`permissions.manage`); whoever does it may only give what
/// they hold themselves, so nobody can hand themselves more than they were
/// given. A member is never deleted — what they recorded names them — but
/// can be made inactive, and an inactive member cannot sign in and may do
/// nothing.
class StaffMember implements Authority {
  final String id;
  final String name;
  final Set<Capability> capabilities;
  final bool active;

  /// A salted SHA-256 of their PIN, never the PIN (`StaffStore`).
  final String pinSalt;
  final String pinHash;

  final DateTime createdAt;

  const StaffMember({
    required this.id,
    required this.name,
    required this.capabilities,
    required this.pinSalt,
    required this.pinHash,
    required this.createdAt,
    this.active = true,
  });

  @override
  String get label => name;

  @override
  bool can(Capability capability) =>
      active && capabilities.contains(capability);

  StaffMember copyWith({
    String? name,
    Set<Capability>? capabilities,
    bool? active,
    String? pinSalt,
    String? pinHash,
  }) => StaffMember(
    id: id,
    name: name ?? this.name,
    capabilities: capabilities ?? this.capabilities,
    active: active ?? this.active,
    pinSalt: pinSalt ?? this.pinSalt,
    pinHash: pinHash ?? this.pinHash,
    createdAt: createdAt,
  );

  /// Why [by] may not give [wanted] to this member, or null where they may:
  /// they need `permissions.manage`, and may only give what they hold.
  String? problemGiving(Set<Capability> wanted, Authority by) {
    if (!by.can(Capability.permissionsManage)) {
      return '${by.label} does not have permission to change permissions.';
    }
    final beyond = wanted.difference(capabilities).where((c) => !by.can(c));
    if (beyond.isNotEmpty) {
      return '${by.label} cannot give a permission they do not have: '
          '${beyond.map((c) => c.key).join(', ')}.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'capabilities': [
      for (final c in Capability.values)
        if (capabilities.contains(c)) c.key,
    ],
    if (!active) 'active': false,
    'pinSalt': pinSalt,
    'pinHash': pinHash,
    'createdAt': createdAt.toIso8601String(),
  };

  /// A member as kept, or null where the entry is not one. A capability this
  /// version does not know is passed over — never turned into another.
  static StaffMember? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final salt = json['pinSalt'];
    final hash = json['pinHash'];
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id is! String || name is! String || salt is! String) return null;
    if (hash is! String || created == null) return null;
    final caps = json['capabilities'];
    return StaffMember(
      id: id,
      name: name,
      capabilities: {
        if (caps is List)
          for (final k in caps) ?Capability.byKey(k),
      },
      active: json['active'] != false,
      pinSalt: salt,
      pinHash: hash,
      createdAt: created,
    );
  }
}

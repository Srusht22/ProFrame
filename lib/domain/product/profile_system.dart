import 'product_basics.dart';

/// A profile system: the extrusion family a product is built from.
///
/// Every dimension here is a real input to the generated geometry — frame
/// face decides how wide the border reads in the elevation, frame depth
/// decides how far the model stands off the wall, and the glazing rebate
/// decides how much glass is hidden behind the bead.
///
/// No manufacturer data is bundled with this application. The systems in
/// [GenericProfiles] are clearly labelled generic preview profiles with their
/// assumptions written down, exactly as required when real catalogues are not
/// available (spec section 6). Nothing built on them may be described as
/// production-ready.
class ProfileSystem {
  /// Stable identifier, referenced by saved projects.
  final String id;

  /// Version of this system's data. A saved project records both, so a project
  /// drawn against older numbers can be recognised rather than silently
  /// re-dimensioned.
  final int version;

  final String name;
  final FrameMaterial material;

  /// Visible width of the outer frame in the elevation, in millimetres.
  final double frameFaceMm;

  /// Depth of the outer frame through the wall, in millimetres.
  final double frameDepthMm;

  /// Visible width of a sash or door leaf profile.
  final double sashFaceMm;

  /// Depth of a sash or door leaf profile.
  final double sashDepthMm;

  /// Visible width of a mullion or transom.
  final double dividerFaceMm;

  /// How far the frame or bead overlaps the glass edge on each side.
  final double glazingRebateMm;

  /// Gap between a sash and the frame it closes into.
  final double sashClearanceMm;

  /// True when this is a generic preview profile rather than a manufacturer's
  /// system. The UI must show this, and it must never be hidden.
  final bool isGeneric;

  /// What the numbers above are based on. Shown to the user in full.
  final String assumptions;

  /// The largest opening leaf this system is offered for. Beyond this the app
  /// warns; it does not silently resize anything.
  final double maxSashWidthMm;
  final double maxSashHeightMm;

  const ProfileSystem({
    required this.id,
    required this.version,
    required this.name,
    required this.material,
    required this.frameFaceMm,
    required this.frameDepthMm,
    required this.sashFaceMm,
    required this.sashDepthMm,
    required this.dividerFaceMm,
    required this.glazingRebateMm,
    required this.sashClearanceMm,
    required this.maxSashWidthMm,
    required this.maxSashHeightMm,
    required this.assumptions,
    this.isGeneric = true,
  });

  /// How this system is referred to from a saved project.
  ProfileSystemRef get ref => ProfileSystemRef(id: id, version: version);

  @override
  String toString() => '$name (v$version${isGeneric ? ', generic' : ''})';
}

/// A saved project's pointer to a profile system.
///
/// Projects store the reference, not a copy of the numbers, so that correcting
/// a profile updates every design that uses it. The version is recorded so a
/// mismatch can be reported rather than applied silently.
class ProfileSystemRef {
  final String id;
  final int version;

  const ProfileSystemRef({required this.id, required this.version});

  @override
  bool operator ==(Object other) =>
      other is ProfileSystemRef && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() => '$id@v$version';

  Map<String, dynamic> toJson() => {'id': id, 'version': version};

  static ProfileSystemRef fromJson(Object? json, {String path = 'profile'}) {
    if (json is! Map) {
      throw FormatException('$path must be an object, got $json');
    }
    final id = json['id'];
    final version = json['version'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    if (version is! int) {
      throw FormatException('$path.version must be an integer, got $version');
    }
    return ProfileSystemRef(id: id, version: version);
  }
}

/// The generic preview profiles this build ships with.
///
/// These are plausible mid-range dimensions for each material, used so the app
/// can generate an honest-looking preview before a factory supplies its own
/// catalogue. They are not any manufacturer's product and must not be
/// presented as one.
abstract final class GenericProfiles {
  static const ProfileSystem pvcCasement = ProfileSystem(
    id: 'generic.pvc.casement',
    version: 1,
    name: 'Generic PVC casement',
    material: FrameMaterial.pvc,
    frameFaceMm: 62,
    frameDepthMm: 70,
    sashFaceMm: 76,
    sashDepthMm: 70,
    dividerFaceMm: 82,
    glazingRebateMm: 18,
    sashClearanceMm: 4,
    maxSashWidthMm: 900,
    maxSashHeightMm: 1600,
    assumptions: 'Preview profile only. Based on a typical 70 mm five-chamber '
        'PVC casement system. Not a manufacturer specification: face widths, '
        'depths, rebates and size limits must be replaced with your supplier\'s '
        'data before any of this is used for fabrication.',
  );

  static const ProfileSystem aluminiumCasement = ProfileSystem(
    id: 'generic.aluminium.casement',
    version: 1,
    name: 'Generic aluminium casement',
    material: FrameMaterial.aluminium,
    frameFaceMm: 52,
    frameDepthMm: 65,
    sashFaceMm: 64,
    sashDepthMm: 65,
    dividerFaceMm: 68,
    glazingRebateMm: 16,
    sashClearanceMm: 3,
    maxSashWidthMm: 1000,
    maxSashHeightMm: 2100,
    assumptions: 'Preview profile only. Based on a typical 65 mm thermally '
        'broken aluminium casement system. Not a manufacturer specification: '
        'face widths, depths, rebates and size limits must be replaced with '
        'your supplier\'s data before any of this is used for fabrication.',
  );

  static const List<ProfileSystem> all = [pvcCasement, aluminiumCasement];

  /// The factory default for [material], used so a beginner never has to open
  /// the profile picker (spec section 3A).
  static ProfileSystem defaultFor(FrameMaterial material) => switch (material) {
        FrameMaterial.pvc => pvcCasement,
        FrameMaterial.aluminium => aluminiumCasement,
      };

  static ProfileSystem? byId(String id) =>
      all.where((p) => p.id == id).firstOrNull;

  const GenericProfiles._();
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

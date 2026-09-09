import 'materials.dart';

/// The profile sizes the product is built from.
///
/// Every value defaults to the chosen material's own system, and every value
/// can be overridden. A factory running a specific extrusion is not obliged to
/// accept the app's idea of how wide a frame is (§1: frame, border, jamb,
/// mullion, transom, thickness are all editable).
///
/// A null field means "whatever the material says", so switching material still
/// moves anything the user has not pinned.
class ProfileSpec {
  /// Visible face width of the outer frame, in elevation.
  final double? frameFaceMm;

  /// Front-to-back depth of the outer frame.
  final double? frameDepthMm;

  /// Visible face width of a sash or leaf profile.
  final double? sashFaceMm;

  /// Front-to-back depth of a sash or leaf profile.
  final double? sashDepthMm;

  /// Face width of a mullion or transom bar.
  final double? mullionFaceMm;

  /// How much of the aperture the glazing bead covers on each edge.
  final double? glazingBeadMm;

  const ProfileSpec({
    this.frameFaceMm,
    this.frameDepthMm,
    this.sashFaceMm,
    this.sashDepthMm,
    this.mullionFaceMm,
    this.glazingBeadMm,
  });

  /// Everything left to the material.
  static const ProfileSpec fromMaterial = ProfileSpec();

  bool get isAllDefault =>
      frameFaceMm == null &&
      frameDepthMm == null &&
      sashFaceMm == null &&
      sashDepthMm == null &&
      mullionFaceMm == null &&
      glazingBeadMm == null;

  double frameFace(FrameMaterial material) => frameFaceMm ?? material.frameFaceMm;
  double frameDepth(FrameMaterial material) => frameDepthMm ?? material.frameDepthMm;
  double sashFace(FrameMaterial material) => sashFaceMm ?? material.sashFaceMm;
  double sashDepth(FrameMaterial material) => sashDepthMm ?? material.sashDepthMm;
  double mullionFace(FrameMaterial material) =>
      mullionFaceMm ?? material.mullionFaceMm;
  double glazingBead(FrameMaterial material) => glazingBeadMm ?? defaultGlazingBeadMm;

  /// The bead is a fitting, not a property of the frame system, so it has one
  /// default rather than one per material.
  static const double defaultGlazingBeadMm = 14;

  ProfileSpec copyWith({
    double? frameFaceMm,
    double? frameDepthMm,
    double? sashFaceMm,
    double? sashDepthMm,
    double? mullionFaceMm,
    double? glazingBeadMm,
  }) =>
      ProfileSpec(
        frameFaceMm: frameFaceMm ?? this.frameFaceMm,
        frameDepthMm: frameDepthMm ?? this.frameDepthMm,
        sashFaceMm: sashFaceMm ?? this.sashFaceMm,
        sashDepthMm: sashDepthMm ?? this.sashDepthMm,
        mullionFaceMm: mullionFaceMm ?? this.mullionFaceMm,
        glazingBeadMm: glazingBeadMm ?? this.glazingBeadMm,
      );

  /// Clears one override so it follows the material again.
  ProfileSpec clearing(ProfileDimension dimension) => ProfileSpec(
        frameFaceMm: dimension == ProfileDimension.frameFace ? null : frameFaceMm,
        frameDepthMm: dimension == ProfileDimension.frameDepth ? null : frameDepthMm,
        sashFaceMm: dimension == ProfileDimension.sashFace ? null : sashFaceMm,
        sashDepthMm: dimension == ProfileDimension.sashDepth ? null : sashDepthMm,
        mullionFaceMm:
            dimension == ProfileDimension.mullionFace ? null : mullionFaceMm,
        glazingBeadMm:
            dimension == ProfileDimension.glazingBead ? null : glazingBeadMm,
      );

  Map<String, dynamic> toJson() => {
        if (frameFaceMm != null) 'frameFaceMm': frameFaceMm,
        if (frameDepthMm != null) 'frameDepthMm': frameDepthMm,
        if (sashFaceMm != null) 'sashFaceMm': sashFaceMm,
        if (sashDepthMm != null) 'sashDepthMm': sashDepthMm,
        if (mullionFaceMm != null) 'mullionFaceMm': mullionFaceMm,
        if (glazingBeadMm != null) 'glazingBeadMm': glazingBeadMm,
      };

  factory ProfileSpec.fromJson(Map<String, dynamic> json) {
    double? read(String key) {
      final value = json[key];
      return value is num && value > 0 ? value.toDouble() : null;
    }

    return ProfileSpec(
      frameFaceMm: read('frameFaceMm'),
      frameDepthMm: read('frameDepthMm'),
      sashFaceMm: read('sashFaceMm'),
      sashDepthMm: read('sashDepthMm'),
      mullionFaceMm: read('mullionFaceMm'),
      glazingBeadMm: read('glazingBeadMm'),
    );
  }
}

enum ProfileDimension {
  frameFace,
  frameDepth,
  sashFace,
  sashDepth,
  mullionFace,
  glazingBead,
}

extension ProfileDimensionInfo on ProfileDimension {
  String get label => switch (this) {
        ProfileDimension.frameFace => 'Frame face',
        ProfileDimension.frameDepth => 'Frame depth',
        ProfileDimension.sashFace => 'Sash / leaf face',
        ProfileDimension.sashDepth => 'Sash / leaf depth',
        ProfileDimension.mullionFace => 'Mullion & transom face',
        ProfileDimension.glazingBead => 'Glazing bead',
      };

  String get help => switch (this) {
        ProfileDimension.frameFace => 'How much frame you see around the outside',
        ProfileDimension.frameDepth => 'Front to back, into the wall',
        ProfileDimension.sashFace => 'How much leaf you see around a moving section',
        ProfileDimension.sashDepth => 'Front to back of a moving section',
        ProfileDimension.mullionFace => 'The bar between two sections',
        ProfileDimension.glazingBead => 'The lip that holds the glass in',
      };
}

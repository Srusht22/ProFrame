import 'dart:math' as math;

import 'materials.dart';
import 'surface.dart';

/// A point of a profile's cross-section: how far in from the member's
/// outer edge, and how far back from its front face, in millimetres.
class ProfilePoint {
  /// From the outer edge (0) towards the daylight edge (the profile's
  /// width).
  final double across;

  /// From the front face (0) back towards the rear (the profile's depth).
  final double back;

  const ProfilePoint(this.across, this.back);

  @override
  String toString() => 'ProfilePoint($across, $back)';
}

/// How a family of profiles is shaped, by what it is made of.
enum ProfileStyle {
  /// A uPVC chamber profile: softly rounded arrises and a sculptured
  /// sightline — the curved slope a PVC frame falls away to its glass by.
  sculptured,

  /// An aluminium or steel extrusion: arrises all but square, and a shadow
  /// step along the sightline where the face drops to the glazing lip.
  extruded,

  /// A timber section: generously rounded arrises and an ovolo — a quarter
  /// round — on the sightline.
  moulded;

  /// The style of a member made of [material].
  static ProfileStyle of(MaterialKind material) =>
      switch (material.surface.kind) {
        MaterialClass.aluminium ||
        MaterialClass.metal ||
        MaterialClass.handleMetal ||
        MaterialClass.hingeMetal => extruded,
        MaterialClass.wood => moulded,
        _ => sculptured,
      };
}

/// The cross-section of a frame member or a sash — what a joiner would see
/// cutting through it — and the lines it shows from the front.
///
/// **It lives entirely inside the member it shapes.** Its width is the
/// member's profile, from the outline to the daylight, and its depth the
/// design's depth, and it reaches all four: the outer edge and the daylight
/// edge, the front face and the back. So a frame shaped by it has exactly
/// the outline, the daylight and the depth it had as a plain ring — a
/// 100 × 200 cm design stays 100 × 200 cm — and what changes is only what
/// happens inside the ring: rounded or square arrises, the slope or step
/// at the sightline.
///
/// Every figure is a share of the member's own width or depth, clamped to
/// what the material is made to, and nothing comes from the size of the
/// design: the same profile on a garden gate and a shop front is the same
/// section.
class FrameProfile {
  /// From the outer edge to the daylight edge.
  final double width;

  /// From the front face to the back.
  final double depth;

  final ProfileStyle style;

  /// The section, going round: along the front face from the outer edge to
  /// the daylight, back down the reveal, along the back face and up the
  /// outside.
  final List<ProfilePoint> section;

  /// How far in from the outer edge each line seen from the front stands —
  /// where the front face turns into the sightline. An elevation draws
  /// these, between the outline and the daylight.
  final List<double> sightlines;

  const FrameProfile._(
    this.width,
    this.depth,
    this.style,
    this.section,
    this.sightlines,
  );

  /// The profile of a member [width] wide and [depth] deep, in [material].
  factory FrameProfile.of(
    MaterialKind material, {
    required double width,
    required double depth,
  }) {
    final style = ProfileStyle.of(material);
    if (width <= 0 || depth <= 0) {
      return FrameProfile._(width, depth, style, const [], const []);
    }
    return switch (style) {
      ProfileStyle.sculptured => _sculptured(width, depth),
      ProfileStyle.extruded => _extruded(width, depth),
      ProfileStyle.moulded => _moulded(width, depth),
    };
  }

  /// A quarter round from [from] to [to], bulging away from [centre].
  static List<ProfilePoint> _round(
    ProfilePoint centre,
    ProfilePoint from,
    ProfilePoint to,
    int pieces,
  ) {
    final a0 = math.atan2(from.back - centre.back, from.across - centre.across);
    var a1 = math.atan2(to.back - centre.back, to.across - centre.across);
    if ((a1 - a0).abs() > math.pi) a1 += a1 < a0 ? 2 * math.pi : -2 * math.pi;
    final rx =
        (from.across - centre.across).abs() + (to.across - centre.across).abs();
    final ry = (from.back - centre.back).abs() + (to.back - centre.back).abs();
    return [
      for (var i = 0; i <= pieces; i++)
        () {
          final a = a0 + (a1 - a0) * i / pieces;
          return ProfilePoint(
            centre.across + math.cos(a) * rx,
            centre.back + math.sin(a) * ry,
          );
        }(),
    ];
  }

  /// A plain box section with its four arrises rounded or cut — [across]
  /// on the face, [back] down the sides — and [sightline], the shaped run
  /// from the front face to the daylight edge, in place of the front inner
  /// arris.
  ///
  /// Everything across the section is a share of its width alone, so what
  /// an elevation sees of a profile does not change with its depth; the
  /// depth only limits how far back a curve can run.
  static List<ProfilePoint> _box(
    double w,
    double d,
    double across,
    double back,
    int arrisPieces,
    List<ProfilePoint> sightline,
  ) => [
    // The outer front arris.
    ..._round(
      ProfilePoint(across, back),
      ProfilePoint(0, back),
      ProfilePoint(across, 0),
      arrisPieces,
    ),
    // The front face runs into the sightline, which ends on the daylight.
    ...sightline,
    // The reveal, to the inner back arris.
    ..._round(
      ProfilePoint(w - across, d - back),
      ProfilePoint(w, d - back),
      ProfilePoint(w - across, d),
      arrisPieces,
    ),
    // The back face, to the outer back arris.
    ..._round(
      ProfilePoint(across, d - back),
      ProfilePoint(across, d),
      ProfilePoint(0, d - back),
      arrisPieces,
    ),
  ];

  /// uPVC: soft 3 mm arrises and a sculptured sightline a fifth of the face
  /// wide, falling away in a curve to the daylight.
  static FrameProfile _sculptured(double w, double d) {
    final arris = math.min(3.0, 0.06 * w);
    final across = 0.22 * w;
    final back = math.min(0.12 * d, across * 0.7);
    final sightline = _round(
      ProfilePoint(w - across, back),
      ProfilePoint(w - across, 0),
      ProfilePoint(w, back),
      4,
    );
    return FrameProfile._(
      w,
      d,
      ProfileStyle.sculptured,
      _box(w, d, arris, math.min(arris, 0.06 * d), 3, sightline),
      [w - across],
    );
  }

  /// Aluminium: arrises cut at a millimetre, and a shadow step a seventh of
  /// the face in from the daylight, down to the glazing lip.
  static FrameProfile _extruded(double w, double d) {
    final arris = math.min(1.0, 0.03 * w);
    final lip = 0.14 * w;
    final step = math.min(0.07 * d, lip);
    final sightline = [
      ProfilePoint(w - lip, 0),
      ProfilePoint(w - lip, step),
      ProfilePoint(w, step),
    ];
    return FrameProfile._(
      w,
      d,
      ProfileStyle.extruded,
      _box(w, d, arris, math.min(arris, 0.03 * d), 1, sightline),
      [w - lip],
    );
  }

  /// Timber: arrises rounded to a tenth of the section, and an ovolo a fifth
  /// of the face wide on the sightline.
  static FrameProfile _moulded(double w, double d) {
    final arris = 0.1 * w;
    final ovolo = 0.2 * w;
    final ovoloBack = math.min(ovolo, 0.4 * d);
    final sightline = _round(
      ProfilePoint(w - ovolo, ovoloBack),
      ProfilePoint(w - ovolo, 0),
      ProfilePoint(w, ovoloBack),
      4,
    );
    return FrameProfile._(
      w,
      d,
      ProfileStyle.moulded,
      _box(w, d, arris, math.min(arris, 0.1 * d), 4, sightline),
      [arris, w - ovolo],
    );
  }

  bool get isEmpty => section.length < 3;
}

/// How the long edges of a bar are eased, by what it is made of: the
/// arris a mullion or a transom has along its front, so it reads as a
/// member and not as a strip. A share of the bar's own width.
double barArrisOf(MaterialKind material, double barWidth) =>
    switch (ProfileStyle.of(material)) {
      ProfileStyle.sculptured => math.min(6.0, 0.12 * barWidth),
      ProfileStyle.extruded => math.min(1.0, 0.03 * barWidth),
      ProfileStyle.moulded => math.min(8.0, 0.15 * barWidth),
    };

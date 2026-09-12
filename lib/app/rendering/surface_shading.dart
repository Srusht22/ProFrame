import 'package:flutter/painting.dart';

import '../../core/design/contrast.dart';
import '../../domain/rendering/scene.dart';

/// Derives the tones a solid surface needs from one chosen colour.
///
/// The user picks a finish — white, anthracite, golden oak — and every face of
/// every profile has to be shaded from it. Nothing here invents a colour: the
/// front, the top and the side are the same hue at different lightness, which
/// is what makes the drawing read as one solid object lit from one direction
/// (spec Phase 3, item 2).
///
/// Working in HSL rather than by multiplying RGB matters for the dark
/// finishes: anthracite multiplied towards black loses its shape entirely,
/// while lifting its lightness keeps the edge visible.
class SurfaceShading {
  /// The finish the user chose.
  final Color base;

  const SurfaceShading(this.base);

  /// Faces angled away from the light read darker; the front reads as the
  /// finish itself.
  static const double _sideShift = -0.10;
  static const double _topShift = 0.09;

  Color get front => base;

  /// The face running back along the left or right of a profile.
  Color get verticalSide => _shifted(_sideShift);

  /// The face running back along the top or bottom.
  Color get horizontalSide => _shifted(_topShift);

  /// The edge line drawn around a surface, so the shape survives when two
  /// faces shade to nearly the same tone — a white frame on a pale background
  /// would otherwise dissolve.
  Color get edge => _shifted(-0.28);

  /// Whichever of black or white can actually be read on [base].
  Color get label => Contrast.mostReadableOn(
        base,
        const [Color(0xFF000000), Color(0xFFFFFFFF)],
      );

  Color forFace(FaceKind kind) => switch (kind) {
        FaceKind.front => front,
        FaceKind.verticalSide => verticalSide,
        FaceKind.horizontalSide => horizontalSide,
      };

  /// Moves lightness by [amount], clamped.
  ///
  /// A near-black finish has no room to go darker, so the shift is flipped
  /// when it would clip — the faces stay distinguishable instead of all
  /// collapsing to the same black.
  Color _shifted(double amount) {
    final hsl = HSLColor.fromColor(base);
    var lightness = hsl.lightness + amount;
    if (lightness <= 0.04 || lightness >= 0.98) {
      lightness = hsl.lightness - amount;
    }
    return hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
  }
}

import 'dart:math' as math;

import '../geometry/vec2.dart';
import 'mesh.dart';

/// A face ready to be painted: where it lands on the screen, how far away it
/// is, and how much light falls on it.
class ProjectedFacet {
  /// The corners on screen, in the same units the caller works in.
  final List<Vec2> corners;

  /// How far the face is from the eye. Bigger is further away.
  final double depth;

  /// 0 to 1. How square-on the face is to the light.
  final double light;

  final Facet source;

  const ProjectedFacet({
    required this.corners,
    required this.depth,
    required this.light,
    required this.source,
  });

  String get elementId => source.elementId;
}

/// Looks at the model from somewhere.
///
/// A real perspective camera, not a flattened projection: turning the model
/// actually brings one jamb towards the viewer and takes the other away, and
/// the near end of a long reveal is genuinely wider than the far end. That is
/// the difference between a picture of a window and a diagram of one.
class Camera {
  /// Turn about the upright axis, in degrees. 0 looks straight on.
  final double turnDegrees;

  /// Tilt up or down, in degrees. Positive looks down on it.
  final double tiltDegrees;

  /// How strong the perspective is: how many model-widths back the eye sits.
  /// Smaller is a wider lens and a stronger effect.
  final double distanceInSpans;

  const Camera({
    this.turnDegrees = 26,
    this.tiltDegrees = 12,
    this.distanceInSpans = 2.6,
  });

  static const Camera straightOn =
      Camera(turnDegrees: 0, tiltDegrees: 0, distanceInSpans: 6);

  Camera copyWith({
    double? turnDegrees,
    double? tiltDegrees,
    double? distanceInSpans,
  }) =>
      Camera(
        turnDegrees: turnDegrees ?? this.turnDegrees,
        tiltDegrees: tiltDegrees ?? this.tiltDegrees,
        distanceInSpans: distanceInSpans ?? this.distanceInSpans,
      );

  /// Every face of [mesh], projected, and sorted so the far ones are painted
  /// first.
  ///
  /// The sort is on the projected depth, not on the depth the face has in the
  /// model, because turning the model changes which jamb is the near one.
  /// Sorting on the wrong one is what makes a turned frame look inside out.
  List<ProjectedFacet> project(Mesh mesh, {Vec3? lightFrom}) {
    if (mesh.isEmpty) return const [];

    final centre = mesh.centre;
    final span = math.max(mesh.span, 1);
    final eyeDistance = span * distanceInSpans;

    final turn = turnDegrees * math.pi / 180;
    final tilt = tiltDegrees * math.pi / 180;
    final cosTurn = math.cos(turn), sinTurn = math.sin(turn);
    final cosTilt = math.cos(tilt), sinTilt = math.sin(tilt);

    // Light from over the viewer's left shoulder, which is where a window is
    // usually photographed from.
    final light = (lightFrom ?? const Vec3(-0.45, -0.7, 1)).normalised;

    Vec3 toEye(Vec3 point) {
      final p = point - centre;
      // Turn about the upright axis.
      final x = p.x * cosTurn + p.z * sinTurn;
      final z = -p.x * sinTurn + p.z * cosTurn;
      // Then tilt.
      final y = p.y * cosTilt - z * sinTilt;
      final zz = p.y * sinTilt + z * cosTilt;
      return Vec3(x, y, zz);
    }

    final projected = <ProjectedFacet>[];
    for (final facet in mesh.facets) {
      if (facet.corners.length < 3) continue;

      final corners = <Vec2>[];
      var depthSum = 0.0;
      var behind = false;
      for (final corner in facet.corners) {
        final eye = toEye(corner);
        final away = eyeDistance - eye.z;
        if (away <= span * 0.02) {
          behind = true;
          break;
        }
        final scale = eyeDistance / away;
        corners.add(Vec2(eye.x * scale, eye.y * scale));
        depthSum += away;
      }
      if (behind || corners.length < 3) continue;

      // The normal has to be turned too, or the shading stays put while the
      // model moves.
      final normal = facet.normal;
      final turned = toEye(normal + centre) - toEye(centre);
      final facing = turned.normalised;

      // Light either side: a face turned away from the viewer is the inside
      // of the reveal, and it is lit, not black.
      final lambert = facing.dot(light).abs();
      final shade = (0.32 + 0.68 * lambert).clamp(0.0, 1.0);

      projected.add(ProjectedFacet(
        corners: corners,
        depth: depthSum / corners.length,
        light: shade,
        source: facet,
      ));
    }

    projected.sort((a, b) => b.depth.compareTo(a.depth));
    return projected;
  }
}

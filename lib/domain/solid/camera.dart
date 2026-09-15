import 'dart:math' as math;

import '../geometry/vec2.dart';
import 'mesh.dart';

/// How the model is flattened onto the screen.
enum Projection {
  /// What an eye sees: the near side of a reveal is wider than the far side.
  perspective('Perspective'),

  /// What a drawing uses: parallel edges stay parallel, so sizes can be
  /// compared across the model.
  parallel('Parallel');

  const Projection(this.label);
  final String label;
}

/// A face ready to be painted: where it lands, how far away it is, and how
/// much light falls on it.
class ProjectedFacet {
  /// The corners in view units — millimetres at the model's own scale,
  /// before the viewport decides how many pixels a millimetre is.
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

/// Where the model is being looked at from.
///
/// Yaw swings round it, pitch rises over it, the target is what the view is
/// centred on, and the zoom is how close it looks. The target is kept in the
/// model's own space rather than on the screen, so panning and then orbiting
/// leaves the view centred on the same part of the model — which is what a
/// modelling program does and what makes a model feel solid rather than like
/// a picture being dragged about.
class Camera {
  /// Degrees round the upright axis. 0 faces the front of the design.
  final double yawDegrees;

  /// Degrees above the horizon. Positive looks down on the model.
  final double pitchDegrees;

  /// How far back the eye sits, in model-widths. Only perspective uses it:
  /// smaller is a wider lens and a stronger effect.
  final double distanceInSpans;

  /// How close the view is. 1 fits the model.
  final double zoom;

  /// What the view is centred on, as an offset in millimetres from the
  /// middle of the model.
  final Vec3 target;

  final Projection projection;

  const Camera({
    this.yawDegrees = 30,
    this.pitchDegrees = 17,
    this.distanceInSpans = 4.2,
    this.zoom = 1,
    this.target = Vec3.zero,
    this.projection = Projection.perspective,
  });

  // The views a modelling program puts on its toolbar. Each keeps whatever
  // zoom and pan the user already had, so switching between them is a look
  // from a different side rather than a reset.
  static const Camera front = Camera(yawDegrees: 0, pitchDegrees: 0);
  static const Camera back = Camera(yawDegrees: 180, pitchDegrees: 0);
  static const Camera left = Camera(yawDegrees: -90, pitchDegrees: 0);
  static const Camera right = Camera(yawDegrees: 90, pitchDegrees: 0);
  static const Camera top = Camera(yawDegrees: 0, pitchDegrees: 89);
  static const Camera bottom = Camera(yawDegrees: 0, pitchDegrees: -89);

  /// The three-quarter view a model is usually shown in.
  static const Camera isometric = Camera(yawDegrees: 35, pitchDegrees: 25);

  Camera copyWith({
    double? yawDegrees,
    double? pitchDegrees,
    double? distanceInSpans,
    double? zoom,
    Vec3? target,
    Projection? projection,
  }) =>
      Camera(
        yawDegrees: yawDegrees ?? this.yawDegrees,
        pitchDegrees: pitchDegrees ?? this.pitchDegrees,
        distanceInSpans: distanceInSpans ?? this.distanceInSpans,
        zoom: zoom ?? this.zoom,
        target: target ?? this.target,
        projection: projection ?? this.projection,
      );

  /// Swings the view, keeping everything else.
  ///
  /// Pitch stops just short of straight up and straight down, where the
  /// horizon would flip over and the model would appear to spin.
  Camera orbited(double byYaw, double byPitch) => copyWith(
        yawDegrees: _wrap(yawDegrees + byYaw),
        pitchDegrees: (pitchDegrees + byPitch).clamp(-89.0, 89.0),
      );

  /// Moves what the view is centred on, by a distance in millimetres across
  /// and down the screen.
  ///
  /// The move is worked out in the model's own space, so the view stays on
  /// the same part of the model when it is next orbited.
  Camera pannedBy(double acrossMm, double downMm) =>
      copyWith(target: target - screenRight * acrossMm - screenDown * downMm);

  Camera zoomedBy(double factor) =>
      copyWith(zoom: (zoom * factor).clamp(0.05, 60.0));

  /// Takes a named view and keeps the zoom, the pan and the projection.
  Camera lookingFrom(Camera view) => view.copyWith(
        zoom: zoom,
        target: target,
        projection: projection,
        distanceInSpans: distanceInSpans,
      );

  Camera reset() => copyWith(zoom: 1, target: Vec3.zero);

  /// The direction that is to the right on screen, in the model's space.
  Vec3 get screenRight {
    final yaw = yawDegrees * math.pi / 180;
    return Vec3(math.cos(yaw), 0, math.sin(yaw));
  }

  /// The direction that is down the screen, in the model's space.
  Vec3 get screenDown {
    final yaw = yawDegrees * math.pi / 180;
    final pitch = pitchDegrees * math.pi / 180;
    return Vec3(
      math.sin(yaw) * math.sin(pitch),
      math.cos(pitch),
      -math.cos(yaw) * math.sin(pitch),
    );
  }

  /// Every face of [mesh], projected, and sorted so the far ones are painted
  /// first.
  ///
  /// The sort is on the projected depth, not on the depth a face has in the
  /// model, because turning the model changes which jamb is the near one.
  /// Sorting on the wrong one is what makes a turned frame look inside out.
  List<ProjectedFacet> project(Mesh mesh, {Vec3? lightFrom}) {
    if (mesh.isEmpty) return const [];

    final centre = mesh.centre + target;
    final span = math.max(mesh.span, 1);
    final eyeDistance = span * distanceInSpans;

    final yaw = yawDegrees * math.pi / 180;
    final pitch = pitchDegrees * math.pi / 180;
    final cosYaw = math.cos(yaw), sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch), sinPitch = math.sin(pitch);

    // Light from over the viewer's left shoulder, which is where a window is
    // usually photographed from.
    final light = (lightFrom ?? const Vec3(-0.45, -0.7, 1)).normalised;

    Vec3 toEye(Vec3 point) {
      final p = point - centre;
      final x = p.x * cosYaw + p.z * sinYaw;
      final z = -p.x * sinYaw + p.z * cosYaw;
      final y = p.y * cosPitch - z * sinPitch;
      final zz = p.y * sinPitch + z * cosPitch;
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
        if (projection == Projection.perspective && away <= span * 0.02) {
          behind = true;
          break;
        }
        final scale = projection == Projection.perspective
            ? eyeDistance / away
            : 1.0;
        corners.add(Vec2(eye.x * scale * zoom, eye.y * scale * zoom));
        depthSum += away;
      }
      if (behind || corners.length < 3) continue;

      // The normal has to be turned too, or the shading stays put while the
      // model moves.
      final turned = toEye(facet.normal + centre) - toEye(centre);
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

  /// How many view units across the model is, looked at from any angle.
  ///
  /// Taken from the model's own diagonal rather than from what happens to be
  /// on screen, so the view does not quietly rescale itself every time it is
  /// orbited — which would make zooming and panning impossible.
  ///
  /// Deliberately independent of [zoom]. The zoom is already in the
  /// projected coordinates; putting it here too would divide it straight
  /// back out again and the zoom would do nothing at all.
  static double viewSpan(Mesh mesh) => math.max(mesh.span, 1);

  /// The zoom that makes the model fill [fraction] of the view from where it
  /// is being looked at now.
  ///
  /// Worked out from this view in particular, because a window seen from the
  /// side is seventy millimetres deep and would otherwise be a sliver.
  double zoomToFit(Mesh mesh, {double fraction = 0.9}) {
    final faces = copyWith(zoom: 1).project(mesh);
    if (faces.isEmpty) return zoom;
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (final face in faces) {
      for (final c in face.corners) {
        left = math.min(left, c.x);
        right = math.max(right, c.x);
        top = math.min(top, c.y);
        bottom = math.max(bottom, c.y);
      }
    }
    final extent = math.max(right - left, bottom - top);
    if (extent <= 0) return zoom;
    return (viewSpan(mesh) / extent * fraction / 0.92).clamp(0.05, 60.0);
  }

  static double _wrap(double degrees) {
    var value = degrees % 360;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }
}

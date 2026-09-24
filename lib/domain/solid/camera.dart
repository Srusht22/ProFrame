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

    final projected = <_Seen>[];
    for (final facet in mesh.facets) {
      if (facet.corners.length < 3) continue;

      final corners = <Vec2>[];
      final inEye = <Vec3>[];
      var depthSum = 0.0;
      var behind = false;
      for (final corner in facet.corners) {
        final eye = toEye(corner);
        inEye.add(eye);
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

      projected.add(_Seen(
        ProjectedFacet(
          corners: corners,
          depth: depthSum / corners.length,
          light: shade,
          source: facet,
        ),
        inEye,
      ));
    }

    projected.sort((a, b) => b.facet.depth.compareTo(a.facet.depth));
    _ironmongeryWhereItIs(
      projected,
      projection == Projection.perspective ? Vec3(0, 0, eyeDistance) : null,
    );
    return [for (final seen in projected) seen.facet];
  }

  /// Puts each piece of ironmongery where it actually is in the painting
  /// order: behind every face it is behind, in front of every face it is in
  /// front of.
  ///
  /// Sorting on each face's average distance is the painter's algorithm,
  /// and it is wrong exactly where a small thing sits against a long one. A
  /// door's hinges are round the back of the leaf, and a stile's face runs
  /// the height of the door, so its average distance is that of its middle:
  /// a hinge near the foot came out nearer than the stile it was behind and
  /// was painted over it, and hinges the drawing says cannot be seen from
  /// outside were on the front of the model.
  ///
  /// A plane settles it rather than an average. A piece lying wholly on the
  /// far side of a face's plane, from where the eye is, cannot be in front
  /// of that face, so it is painted first; wholly on the near side, it is
  /// painted after. Only faces that overlap the piece on the screen are
  /// asked, because nothing else can hide it or be hidden by it. Where the
  /// two cannot both be met the order is left as the sort had it.
  ///
  /// [eye] is the eye in eye space for a perspective view, and null for a
  /// parallel one, whose eye is infinitely far along +z.
  static void _ironmongeryWhereItIs(List<_Seen> order, Vec3? eye) {
    // A piece built on both faces of the leaf is two pieces here: taken
    // together they are neither in front of nor behind anything.
    String pieceOf(_Seen seen) =>
        '${seen.facet.elementId}|${seen.facet.source.part ?? ''}';
    final pieces = <String>{
      for (final seen in order)
        if (seen.facet.source.role == FacetRole.hardware) pieceOf(seen),
    };

    for (final id in pieces) {
      final members = [
        for (final seen in order)
          if (pieceOf(seen) == id) seen,
      ];
      final others = [
        for (final seen in order)
          if (pieceOf(seen) != id) seen,
      ];
      // Where the piece sits among the rest, before anything is decided.
      final at = order.indexOf(members.first);
      var place = 0;
      for (var i = 0; i < at; i++) {
        if (pieceOf(order[i]) != id) place++;
      }

      final bounds = _Box.around(members);
      final corners = [for (final m in members) ...m.eye];
      var before = others.length; // the earliest face it must precede
      var after = -1; // the latest face it must follow
      for (var i = 0; i < others.length; i++) {
        final face = others[i];
        if (!bounds.overlaps(face.box)) continue;
        switch (face.sideOf(corners, eye)) {
          case _Side.behind:
            if (i < before) before = i;
          case _Side.inFront:
            after = i;
          case _Side.across:
            break;
        }
      }
      if (after < before) {
        if (place > before) place = before;
        if (place <= after) place = after + 1;
      }

      order
        ..clear()
        ..addAll(others)
        ..insertAll(place, members);
    }
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

/// A projected face with its corners still in eye space, for the one
/// question an average depth cannot answer: which side of it something is.
class _Seen {
  final ProjectedFacet facet;
  final List<Vec3> eye;
  final _Box box;

  _Seen(this.facet, this.eye) : box = _Box.of(facet.corners);

  /// Where [points] lie against this face's plane, as seen [from] the eye —
  /// null for a parallel view, looking along -z.
  _Side sideOf(List<Vec3> points, Vec3? from) {
    if (eye.length < 3) return _Side.across;
    final normal = (eye[1] - eye[0]).cross(eye[2] - eye[0]);
    final size = normal.length;
    if (size == 0) return _Side.across;
    final n = normal * (1 / size);
    // Which way the eye is from the plane. Edge on, the plane hides
    // nothing and nothing hides it.
    final toEye = from == null ? n.z : n.dot(from - eye[0]);
    if (toEye.abs() < _onIt) return _Side.across;
    final facing = toEye > 0 ? 1.0 : -1.0;

    var allBehind = true;
    var allInFront = true;
    for (final p in points) {
      final d = n.dot(p - eye[0]) * facing;
      if (d > -_onIt) allBehind = false;
      if (d < _onIt) allInFront = false;
      if (!allBehind && !allInFront) return _Side.across;
    }
    return allBehind ? _Side.behind : _Side.inFront;
  }

  /// A hundredth of a millimetre: a point closer than this to a plane is on
  /// it, not either side of it.
  static const _onIt = 0.01;
}

enum _Side { behind, inFront, across }

/// A face's extent on the screen.
class _Box {
  final double left, top, right, bottom;
  const _Box(this.left, this.top, this.right, this.bottom);

  factory _Box.of(List<Vec2> corners) {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final c in corners) {
      l = math.min(l, c.x);
      r = math.max(r, c.x);
      t = math.min(t, c.y);
      b = math.max(b, c.y);
    }
    return _Box(l, t, r, b);
  }

  factory _Box.around(List<_Seen> faces) {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final f in faces) {
      l = math.min(l, f.box.left);
      r = math.max(r, f.box.right);
      t = math.min(t, f.box.top);
      b = math.max(b, f.box.bottom);
    }
    return _Box(l, t, r, b);
  }

  bool overlaps(_Box o) =>
      left < o.right && o.left < right && top < o.bottom && o.top < bottom;
}

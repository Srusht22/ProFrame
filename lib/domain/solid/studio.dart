import 'dart:math' as math;

import '../geometry/vec2.dart';
import 'camera.dart';
import 'mesh.dart';
import 'shading.dart';

/// What the model is shown in: a photographer's studio, and nothing else.
///
/// **This is not the application's palette.** The house green and cream are
/// the application — its bars, its buttons, what is chosen — and they stay
/// there. What stands behind the model and what it stands on are the
/// studio's, and a studio is neutral: every colour here has its red, green
/// and blue equal, so nothing in the model borrows a tint from the screen
/// round it. Glass shows what is behind it, and what is behind it is grey,
/// not green. The design's own finishes are the customer's and come from
/// the design alone.
///
/// The appearance chooses between the light studio and the dark one, as it
/// chooses the page a drawing is read on; it never supplies a colour.
class Studio {
  /// The backdrop, top to bottom: a seamless sweep with no horizon drawn on
  /// it, lighter above as a studio's paper is under its lights.
  final int backdropTop;
  final int backdropBottom;

  /// What the floor's grid and a wireframe are drawn in, against the
  /// backdrop.
  final int lines;

  /// How strongly the floor's metre lines and its ten-centimetre lines show,
  /// where the floor is seen square on and near the model. Faint: they give
  /// the model a size and a place to stand, and must never compete with it.
  final double majorLines;
  final double minorLines;

  const Studio({
    required this.backdropTop,
    required this.backdropBottom,
    required this.lines,
    required this.majorLines,
    required this.minorLines,
  });

  static const light = Studio(
    backdropTop: 0xFFF6F6F6,
    backdropBottom: 0xFFE2E2E2,
    lines: 0xFF000000,
    majorLines: 0.13,
    minorLines: 0.05,
  );

  static const dark = Studio(
    backdropTop: 0xFF2C2C2C,
    backdropBottom: 0xFF171717,
    lines: 0xFFFFFFFF,
    majorLines: 0.14,
    minorLines: 0.05,
  );

  static Studio of({required bool dark}) => dark ? Studio.dark : Studio.light;

  /// The line between two faces of the model: dark in either studio,
  /// because the faces either side are the design's own colours, and
  /// neutral, because it is the model's.
  static const int edgeInk = 0xFF0A0A0A;

  /// The one colour a monochrome view is in: a grey, not the application's.
  static const int clay = 0xFFDEDEDE;
}

/// The floor a design stands on in the 3D view.
///
/// It is at the model's lowest point, level, and it is there to say four
/// things: **where** the model is (it stands on something), **how big** it
/// is (a grid of ten-centimetre squares, a stronger line every metre, laid
/// from the model's own left side and drawn face), **that it touches** the
/// floor, and **how deep** the space is (the grid runs away from the eye).
///
/// Its shadows are worked out, not painted on: at each point of the floor,
/// how much of the room's light from above the model shuts out
/// ([occlusionAt]) and how much of the key light ([keyShutAt]), both by
/// rays against the model's own envelope. The floor is then lit by the same
/// `Environment.lightOn` every face of the model is, so a shadow on the
/// floor is exactly as dark as the light it takes away. It is dark at the
/// foot, where the model shuts out half the sky, and falls away from it —
/// sharp at the contact and soft further out, as a large light's shadow is.
///
/// Everything on the floor is drawn before the model, so no shadow and no
/// line can ever lie over a part of the design.
class Floor {
  /// The floor's height: the model's lowest point, in millimetres down.
  final double level;

  /// How tall the model stands on it.
  final double height;

  /// The plan of what stands on the floor — across and in depth.
  final double minX, maxX, minZ, maxZ;

  /// The model's envelope: what shuts light out.
  final List<Block> blocks;

  Floor._({
    required this.level,
    required this.height,
    required this.minX,
    required this.maxX,
    required this.minZ,
    required this.maxZ,
    required this.blocks,
  });

  /// The grid's squares, in millimetres, and how many make a metre line.
  static const double gridStep = 100;
  static const int majorEvery = 10;

  /// How far out from the model the floor is shown, in shares of the
  /// model's own size: far enough for its shadow and a metre or two of
  /// grid, fading to nothing so it has no edge.
  static const double reachShare = 1.2;

  /// A face this close to the floor, in shares of the model's height,
  /// stands on it.
  static const double standingShare = 0.02;

  /// The floor under [mesh]; null for a model with nothing in it.
  ///
  /// The envelope is the design's opaque members, each as the box it
  /// fills: the frame's head, sill and two sides, a sash's the same —
  /// wherever the leaf has swung to — each panel and each bar, with one
  /// inside another left out, since it shuts out nothing the other does
  /// not. A ring is taken side by side rather than as one box, because the
  /// light comes through the middle of it. **Glass lets the light
  /// through**, so it shuts none out: the floor behind a pane is lit, and
  /// the shadow on the floor is the shape of what the design is made of.
  /// Ironmongery is left out: a handle a metre up shuts out nothing the
  /// floor would show.
  static Floor? under(Mesh mesh) {
    if (mesh.isEmpty) return null;
    final whole = <String, Block>{};
    var top = double.infinity, level = -double.infinity;
    var plan = Block.around(mesh.facets.first.corners);
    for (final facet in mesh.facets) {
      for (final c in facet.corners) {
        top = math.min(top, c.y);
        level = math.max(level, c.y);
      }
      plan = plan.join(Block.around(facet.corners));
      if (_shutsOutNothing(facet)) continue;
      final box = Block.around(facet.corners);
      whole[facet.elementId] = whole[facet.elementId]?.join(box) ?? box;
    }
    if (!level.isFinite) return null;
    // Each part's faces, taken by the side of the part they are nearest.
    final byMember = <String, Block>{};
    for (final facet in mesh.facets) {
      if (_shutsOutNothing(facet)) continue;
      final part = whole[facet.elementId]!;
      final c = facet.centre;
      final sides = [
        c.x - part.minX,
        part.maxX - c.x,
        c.y - part.minY,
        part.maxY - c.y,
      ];
      var side = 0;
      for (var k = 1; k < 4; k++) {
        if (sides[k] < sides[side]) side = k;
      }
      final key = '${facet.elementId}|$side';
      final box = Block.around(facet.corners);
      byMember[key] = byMember[key]?.join(box) ?? box;
    }
    final all = byMember.values.toList();
    final blocks = [
      for (var i = 0; i < all.length; i++)
        if (!_heldByAnother(all, i)) all[i],
    ];
    final height = math.max(level - top, 1.0);
    final standing = height * standingShare;
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final b in blocks) {
      if (level - b.maxY > standing) continue;
      minX = math.min(minX, b.minX);
      maxX = math.max(maxX, b.maxX);
      minZ = math.min(minZ, b.minZ);
      maxZ = math.max(maxZ, b.maxZ);
    }
    if (!minX.isFinite) {
      // Nothing opaque reaches the floor: the plan of the whole.
      minX = plan.minX;
      maxX = plan.maxX;
      minZ = plan.minZ;
      maxZ = plan.maxZ;
    }
    return Floor._(
      level: level,
      height: height,
      minX: minX,
      maxX: maxX,
      minZ: minZ,
      maxZ: maxZ,
      blocks: blocks,
    );
  }

  static bool _shutsOutNothing(Facet facet) =>
      facet.role == FacetRole.hardware || facet.surface.isTransparent;

  static bool _heldByAnother(List<Block> all, int i) {
    for (var j = 0; j < all.length; j++) {
      if (j == i) continue;
      if (all[j].holds(all[i]) && (!all[i].holds(all[j]) || j < i)) {
        return true;
      }
    }
    return false;
  }

  /// Every block at once: a ray that misses this misses them all, which is
  /// most rays from most of the floor.
  late final Block? _all = blocks.isEmpty
      ? null
      : blocks.reduce((a, b) => a.join(b));

  /// How far the floor is shown beyond the model's plan.
  double get reach =>
      reachShare * math.max(height, math.max(maxX - minX, maxZ - minZ));

  /// Where the grid's lines across the floor stand, running away from the
  /// eye — each at a whole number of squares from the model's own left
  /// side, and whether it is a metre line.
  List<(double, bool)> get linesAcross =>
      _lines(minX, minX - reach, maxX + reach);

  /// Where its lines along the floor stand — each at a whole number of
  /// squares from the model's drawn face.
  List<(double, bool)> get linesDeep =>
      _lines(maxZ, minZ - reach, maxZ + reach);

  static List<(double, bool)> _lines(double from, double low, double high) => [
    for (
      var k = ((low - from) / gridStep).ceil();
      from + k * gridStep <= high;
      k++
    )
      (from + k * gridStep, k % majorEvery == 0),
  ];

  /// How far [x], [z] is from the plan of what stands on the floor; 0 on it.
  double fromPlan(double x, double z) {
    final dx = math.max(0.0, math.max(minX - x, x - maxX));
    final dz = math.max(0.0, math.max(minZ - z, z - maxZ));
    return math.sqrt(dx * dx + dz * dz);
  }

  /// How much of the floor is shown at [x], [z], 1 near the model and 0 at
  /// [reach], smoothly, so the floor never has an edge.
  double fadeAt(double x, double z) {
    final t = (fromPlan(x, z) / reach).clamp(0.0, 1.0);
    final u = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    return 1 - u * u * (3 - 2 * u);
  }

  /// The share of the room's light from above that the model shuts out at
  /// [x], [z] on the floor, 0 to 1: the light from every direction of the
  /// sky, as much from each as it falls on a level floor, asked whether the
  /// model is in the way.
  double occlusionAt(double x, double z) {
    var shut = 0;
    for (final d in _sky) {
      if (_blockedAt(x, z, d)) shut++;
    }
    return shut / _sky.length;
  }

  /// The share of the key light, of [angularSize] across and coming from
  /// [towardsKey] in the model's space, that the model shuts out at [x],
  /// [z] on the floor. Sharp where the model touches the floor, softer the
  /// further its shadow falls, as the shadow of a large light is.
  double keyShutAt(
    double x,
    double z, {
    required Vec3 towardsKey,
    required double angularSize,
  }) {
    final rays = _keyRays(towardsKey, angularSize);
    if (rays.isEmpty) return 0;
    var shut = 0;
    for (final d in rays) {
      if (_blockedAt(x, z, d)) shut++;
    }
    return shut / rays.length;
  }

  /// Directions spread across the key light — its middle and two rings —
  /// worked out once for a light and kept while it stays where it is.
  /// None where the light is below the floor's horizon: it lights nothing.
  static List<_Ray> _keyRays(Vec3 towardsKey, double angularSize) {
    final last = _lastKey;
    if (last != null &&
        last.$1 == towardsKey.x &&
        last.$2 == towardsKey.y &&
        last.$3 == towardsKey.z &&
        last.$4 == angularSize) {
      return last.$5;
    }
    final k = towardsKey.normalised;
    final rays = <_Ray>[];
    if (k.y < 0) {
      // Two directions square to the light, to spread samples across it.
      final side = k.cross(const Vec3(0, 1, 0)).normalised;
      final other = k.cross(side).normalised;
      final radius = math.tan(angularSize / 2);
      for (final (r, n) in const [(0.0, 1), (0.5, 6), (1.0, 12)]) {
        for (var i = 0; i < n; i++) {
          final a = 2 * math.pi * (i + 0.5 * r) / n;
          final d =
              k +
              side * (radius * r * math.cos(a)) +
              other * (radius * r * math.sin(a));
          rays.add(_Ray(d.normalised));
        }
      }
    }
    _lastKey = (towardsKey.x, towardsKey.y, towardsKey.z, angularSize, rays);
    return rays;
  }

  static (double, double, double, double, List<_Ray>)? _lastKey;

  /// How far above the floor a ray starts, in millimetres: clear of the
  /// floor's own plane, so the underside of what stands on it is not taken
  /// for something in the way.
  static const double _lift = 0.5;

  /// [_blocked] for a ray from the floor at [x], [z], without making
  /// anything on the way: it is asked tens of thousands of times a view.
  bool _blockedAt(double x, double z, _Ray d) {
    final all = _all;
    final y = level - _lift;
    if (all == null || !all._hit(x, y, z, d)) return false;
    for (final b in blocks) {
      if (b._hit(x, y, z, d)) return true;
    }
    return false;
  }

  /// Directions over the sky, as many towards each part of it as it lights
  /// a level floor by — more overhead than along the horizon — spread
  /// evenly so the answer is the same every time. Up is −y.
  static final List<_Ray> _sky = [
    for (var i = 0; i < 8; i++)
      for (var j = 0; j < 12; j++)
        () {
          final u = (i + 0.5) / 8;
          final a = 2 * math.pi * (j + 0.5 * (i % 2)) / 12;
          final r = math.sqrt(u);
          return _Ray(
            Vec3(r * math.cos(a), -math.sqrt(1 - u), r * math.sin(a)),
          );
        }(),
  ];

  /// Where the floor is sampled across, in millimetres: close together at
  /// the edges of the plan, where the shadow changes fastest, further apart
  /// out towards [reach] — and never further apart than a share of it, so a
  /// shadow cast some way out is still sampled closely enough to keep its
  /// shape.
  List<double> _samplesAcross(double low, double high) {
    final spread = _spreadAcross(low, high);
    final widest = reach / 20;
    final out = <double>[spread.first];
    for (final next in spread.skip(1)) {
      final gap = next - out.last;
      final pieces = (gap / widest).ceil();
      for (var k = 1; k < pieces; k++) {
        out.add(out.last + gap / pieces);
      }
      out.add(next);
    }
    return out;
  }

  List<double> _spreadAcross(double low, double high) {
    final out = <double>{low, high};
    const n = 12;
    for (var k = 1; k <= n; k++) {
      final d = reach * (k / n) * (k / n);
      out
        ..add(low - d)
        ..add(high + d);
      if (d < (high - low) / 2) {
        out
          ..add(low + d)
          ..add(high - d);
      }
    }
    return out.toList()..sort();
  }

  /// The floor as it is seen by [camera], lit by [environment]; null where
  /// the eye is level with the floor or below it, where there is no floor to
  /// show — a floor seen from beneath would stand in front of the model.
  ProjectedFloor? seenBy(Camera camera, Mesh mesh, {Environment? environment}) {
    final env = environment ?? Environment.daylight;
    final space = camera.eyeSpaceFor(mesh);
    final foot = Vec3((minX + maxX) / 2, level, (minZ + maxZ) / 2);
    final looking = space.lookingAt(foot);
    // Looking down onto the floor is looking along +y.
    final facing = looking.y;
    if (facing <= 0) return null;
    if (space.eye case final eye? when eye.y >= level) return null;

    final skyward = space.turn(const Vec3(0, -1, 0)).normalised;
    final full = env.lightOn(skyward, up: skyward);
    final towardsKey = space.turnBack(env.light);

    final xs = _samplesAcross(minX, maxX);
    final zs = _samplesAcross(minZ, maxZ);
    final occlusion = _occlusionGrid(xs, zs);
    final points = <Vec2?>[];
    final darkness = <double>[];
    var i = 0;
    for (final z in zs) {
      for (final x in xs) {
        points.add(space.place(Vec3(x, level, z)));
        final shut = keyShutAt(
          x,
          z,
          towardsKey: towardsKey,
          angularSize: env.keySize,
        );
        final lit = env.lightOn(
          skyward,
          up: skyward,
          occlusion: occlusion[i++],
          shadowed: shut,
        );
        final dark = full <= 0 ? 0.0 : (1 - lit / full).clamp(0.0, 1.0);
        darkness.add(dark * fadeAt(x, z));
      }
    }

    final lines = <FloorLine>[];
    final r = reach;
    void line(Vec3 a, Vec3 b, bool major) {
      final length = (b - a).length;
      final pieces = math.max(1, (length / gridStep).ceil());
      for (var k = 0; k < pieces; k++) {
        final p = a + (b - a) * (k / pieces);
        final q = a + (b - a) * ((k + 1) / pieces);
        final mid = (p + q) * 0.5;
        final weight = fadeAt(mid.x, mid.z);
        if (weight <= 0.004) continue;
        final from = space.place(p), to = space.place(q);
        if (from == null || to == null) continue;
        lines.add(FloorLine(from, to, weight: weight, major: major));
      }
    }

    final x0 = minX - r, x1 = maxX + r, z0 = minZ - r, z1 = maxZ + r;
    for (final (x, major) in linesAcross) {
      line(Vec3(x, level, z0), Vec3(x, level, z1), major);
    }
    for (final (z, major) in linesDeep) {
      line(Vec3(x0, level, z), Vec3(x1, level, z), major);
    }

    // How big one square of the grid is seen at the model's foot, the
    // narrower way — what decides whether its ten-centimetre lines are far
    // enough apart to draw.
    final at = space.place(foot);
    final across = space.place(foot + const Vec3(gridStep, 0, 0));
    final deep = space.place(foot + const Vec3(0, 0, gridStep));
    var stepSeen = 0.0;
    if (at != null && across != null && deep != null) {
      stepSeen = math.min((across - at).length, (deep - at).length);
    }

    return ProjectedFloor(
      columns: xs.length,
      points: points,
      darkness: darkness,
      lines: lines,
      facing: facing,
      stepSeen: stepSeen,
    );
  }

  /// [occlusionAt] at every point of the sampling grid — the same for every
  /// view, since the room's light comes from all round, so it is kept for
  /// the envelope it was worked out for and not asked again while only the
  /// view changes.
  List<double> _occlusionGrid(List<double> xs, List<double> zs) {
    final key = [
      level,
      height,
      minX,
      maxX,
      minZ,
      maxZ,
      for (final b in blocks) ...[
        b.minX,
        b.minY,
        b.minZ,
        b.maxX,
        b.maxY,
        b.maxZ,
      ],
    ];
    final last = _lastOcclusion;
    if (last != null && _same(last.$1, key)) return last.$2;
    final grid = [
      for (final z in zs)
        for (final x in xs) occlusionAt(x, z),
    ];
    _lastOcclusion = (key, grid);
    return grid;
  }

  static (List<double>, List<double>)? _lastOcclusion;

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A box in the model's space, square to its axes.
class Block {
  final double minX, minY, minZ, maxX, maxY, maxZ;

  const Block(this.minX, this.minY, this.minZ, this.maxX, this.maxY, this.maxZ);

  factory Block.around(List<Vec3> points) {
    var a = points.first, b = points.first;
    for (final p in points) {
      a = Vec3(math.min(a.x, p.x), math.min(a.y, p.y), math.min(a.z, p.z));
      b = Vec3(math.max(b.x, p.x), math.max(b.y, p.y), math.max(b.z, p.z));
    }
    return Block(a.x, a.y, a.z, b.x, b.y, b.z);
  }

  Block join(Block o) => Block(
    math.min(minX, o.minX),
    math.min(minY, o.minY),
    math.min(minZ, o.minZ),
    math.max(maxX, o.maxX),
    math.max(maxY, o.maxY),
    math.max(maxZ, o.maxZ),
  );

  bool holds(Block o) =>
      o.minX >= minX &&
      o.maxX <= maxX &&
      o.minY >= minY &&
      o.maxY <= maxY &&
      o.minZ >= minZ &&
      o.maxZ <= maxZ;

  /// [hitBy] for a ray from [x], [y], [z] along [d], with nothing made on
  /// the way — the same slab test, three axes written out.
  bool _hit(double x, double y, double z, _Ray d) {
    var near = 0.0, far = double.infinity;
    if (d.x == 0) {
      if (x < minX || x > maxX) return false;
    } else {
      var t0 = (minX - x) * d.ix, t1 = (maxX - x) * d.ix;
      if (t0 > t1) (t0, t1) = (t1, t0);
      if (t0 > near) near = t0;
      if (t1 < far) far = t1;
      if (near > far) return false;
    }
    if (d.y == 0) {
      if (y < minY || y > maxY) return false;
    } else {
      var t0 = (minY - y) * d.iy, t1 = (maxY - y) * d.iy;
      if (t0 > t1) (t0, t1) = (t1, t0);
      if (t0 > near) near = t0;
      if (t1 < far) far = t1;
      if (near > far) return false;
    }
    if (d.z == 0) {
      if (z < minZ || z > maxZ) return false;
    } else {
      var t0 = (minZ - z) * d.iz, t1 = (maxZ - z) * d.iz;
      if (t0 > t1) (t0, t1) = (t1, t0);
      if (t0 > near) near = t0;
      if (t1 < far) far = t1;
      if (near > far) return false;
    }
    return true;
  }

  /// Whether a ray from [from] along [d] passes through the box.
  bool hitBy(Vec3 from, Vec3 d) => _hit(from.x, from.y, from.z, _Ray(d));
}

/// A direction a ray is cast in, with its reciprocals kept beside it.
class _Ray {
  final double x, y, z, ix, iy, iz;

  _Ray(Vec3 d)
    : x = d.x,
      y = d.y,
      z = d.z,
      ix = d.x == 0 ? 0 : 1 / d.x,
      iy = d.y == 0 ? 0 : 1 / d.y,
      iz = d.z == 0 ? 0 : 1 / d.z;
}

/// The floor as the eye sees it, in view units as the model's faces are.
class ProjectedFloor {
  /// How many sampling points there are across; the rest of [points] are
  /// the rows behind and in front of them.
  final int columns;

  /// Each sampling point on the screen; null for one too near the eye.
  final List<Vec2?> points;

  /// How much darker the floor is at each point than where nothing stands
  /// in the light, 0 to 1 — its shadow, faded out towards the floor's edge.
  final List<double> darkness;

  final List<FloorLine> lines;

  /// How square on the floor is seen at the model's foot, 0 edge on to 1
  /// looking straight down.
  final double facing;

  /// How big one square of the grid is seen at the model's foot, in view
  /// units, the narrower way.
  final double stepSeen;

  const ProjectedFloor({
    required this.columns,
    required this.points,
    required this.darkness,
    required this.lines,
    required this.facing,
    required this.stepSeen,
  });

  int get rows => columns == 0 ? 0 : points.length ~/ columns;
}

/// A piece of one of the floor's grid lines, and how strongly it shows.
class FloorLine {
  final Vec2 from, to;

  /// 1 near the model, falling to 0 where the floor fades out.
  final double weight;

  /// A metre line rather than a ten-centimetre one.
  final bool major;

  const FloorLine(
    this.from,
    this.to, {
    required this.weight,
    required this.major,
  });
}

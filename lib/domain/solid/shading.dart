import 'dart:math' as math;

import '../model/surface.dart';
import 'mesh.dart';

// How a face looks under the light, from what it is made of.
//
// One function, [Shading.of], for every face of the model: the user's colour,
// the face's material ([Surface]) and which way the face points go in, and a
// colour and an opacity come out. The renderer only paints what comes back,
// so how glass, panel, frame, metal and rubber look is decided here, once,
// from each material's physical figures — never by a colour or a gradient
// chosen to make one part stand out.
//
// The model is one key light and what it stands in: sky above, ground below.
// Everything is in the eye's own space: x across, y down the screen, z out
// towards the viewer.

/// A colour as three channels, 0 to 1.
class Rgb {
  final double r;
  final double g;
  final double b;

  const Rgb(this.r, this.g, this.b);

  factory Rgb.of(int argb) => Rgb(
    ((argb >> 16) & 0xFF) / 255,
    ((argb >> 8) & 0xFF) / 255,
    (argb & 0xFF) / 255,
  );

  static const white = Rgb(1, 1, 1);

  Rgb operator +(Rgb o) => Rgb(r + o.r, g + o.g, b + o.b);
  Rgb operator *(double f) => Rgb(r * f, g * f, b * f);

  /// Channel by channel: light of this colour falling on [o].
  Rgb tinting(Rgb o) => Rgb(r * o.r, g * o.g, b * o.b);

  Rgb mixedWith(Rgb o, double t) =>
      Rgb(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t);

  /// How bright, the way an eye weighs the three.
  double get luminance => 0.2126 * r + 0.7152 * g + 0.0722 * b;

  /// 0xAARRGGBB, fully opaque; each channel clamped.
  int get argb {
    int c(double v) => (v.clamp(0.0, 1.0) * 255).round();
    return 0xFF000000 | (c(r) << 16) | (c(g) << 8) | c(b);
  }
}

/// What the model stands in: one key light, and the sky and ground a
/// surface reflects.
class Environment {
  /// Towards the light, in eye space.
  final Vec3 light;

  final Rgb sky;
  final Rgb horizon;
  final Rgb ground;

  /// How much light reaches a face turned away from the key: what the sky
  /// fills in.
  final double ambient;

  /// How strong the key light is. With [ambient], a white face square to
  /// the viewer comes out white — the exposure a photograph of the thing
  /// would be taken at — and a reveal turned from the light about half
  /// that.
  final double key;

  /// The studio's strip lights: a tall, narrow soft light either side of
  /// the camera, as glass is photographed — travelling with the camera, as
  /// a photographer's lights do. [stripsAt] is how far round from the
  /// camera each stands, in degrees either side; [stripHalfWidth] how wide
  /// each is, and [stripEdge] how soft its edges, in degrees; [stripRadiance]
  /// how much brighter than a surface it lights. A strip seen in a pane is
  /// the sheen across it — the one thing that says glass at a glance, as it
  /// does in every photograph of a window — and it moves as the view turns.
  final double stripsAt;
  final double stripHalfWidth;
  final double stripEdge;
  final double stripRadiance;

  const Environment({
    required this.light,
    required this.sky,
    required this.horizon,
    required this.ground,
    this.ambient = 0.45,
    this.key = 0.75,
    this.skyRadiance = 1.6,
    this.stripsAt = 67.5,
    this.stripHalfWidth = 1.2,
    this.stripEdge = 1.0,
    this.stripRadiance = 2.6,
  });

  /// Over the viewer's left shoulder, where a window is usually
  /// photographed from — the same light `Camera.project` has always used.
  static const keyLight = Vec3(-0.45, -0.7, 1);

  /// A bright day: the light the model is shown in by default. A clear
  /// sky, bluer overhead than at the hazy horizon, over paving — so what a
  /// surface reflects depends on which way it faces and from where it is
  /// seen, as it does outdoors, and glass shows the sky moving across it.
  static final daylight = Environment(
    light: keyLight.normalised,
    sky: Rgb.of(0xFF94B4CF),
    horizon: Rgb.of(0xFFF1F4F4),
    ground: Rgb.of(0xFF77746D),
  );

  /// What is seen looking along [direction]: sky above the horizon, ground
  /// below it. y runs down the screen, so up is negative y.
  Rgb seen(Vec3 direction) => seenAt(-direction.normalised.y);

  /// What is seen looking [up] — the sine of how far above the horizon —
  /// from -1 straight down to 1 straight up. The horizon is an edge: the
  /// ground is darker than the sky even where the two meet, which is the
  /// line a pane of glass shows the day by.
  Rgb seenAt(double up) {
    if (up >= 0) return horizon.mixedWith(sky, math.min(1, up * 1.4));
    return horizon.mixedWith(ground, 0.6 + 0.4 * math.min(1, -up * 2.2));
  }

  /// How much brighter the sky is than a surface it lights: it is the
  /// light, so what reflects it shows it brighter than anything lit by it.
  final double skyRadiance;

  /// The light arriving from [up]: the sky at its own brightness, the
  /// ground at what it gives back. What a mirror-smooth surface reflects,
  /// before Fresnel says how much of it.
  Rgb radianceAt(double up) =>
      up >= 0 ? seenAt(up) * skyRadiance : seenAt(up);

  /// The light arriving along [direction], in the eye's space, with
  /// [skyward] the way up in the world: the sky or the ground there, and a
  /// strip light where the direction meets one — fading over its edge, as a
  /// diffused light does.
  ///
  /// [blur], in degrees, is how far a rough surface spreads what it
  /// reflects: a strip light seen in brushed metal is a broad soft band, not
  /// a line. The light it spreads is the same light, so the band is fainter
  /// the wider it is — never brighter than the strip itself.
  ///
  /// [studio] asks for the room on the camera's side as well: looking back
  /// towards the viewer, what is seen is the studio the photograph is taken
  /// in, dimmer than the open sky the design faces — see [studioColour].
  Rgb radianceToward(
    Vec3 direction,
    Vec3 skyward, {
    double blur = 0,
    bool studio = false,
  }) {
    final d = direction.normalised;
    final up = d.dot(skyward);
    final spread = (stripHalfWidth + stripEdge) /
        (stripHalfWidth + stripEdge + blur);
    var around = radianceAt(up);
    if (studio) {
      final t = ((d.z - 0.3) / 0.5).clamp(0.0, 1.0);
      around = around.mixedWith(studioColour, t * t * (3 - 2 * t));
    }
    return around +
        Rgb.white * (stripRadiance * spread * stripAt(d, up, blur: blur));
  }

  /// How much of a strip light is seen looking along [d] — 1 inside one, 0
  /// clear of both — [up] being how far above the horizon it points. The
  /// strips stand from a little below eye level to well above it.
  double stripAt(Vec3 d, double up, {double blur = 0}) {
    if (up < -0.25 || up > 0.85) return 0;
    final round = (math.atan2(d.x, d.z) * 180 / math.pi).abs();
    final off = (round - stripsAt).abs() - stripHalfWidth;
    final edge = stripEdge + blur;
    if (off <= 0) return 1;
    if (off >= edge) return 0;
    final t = 1 - off / edge;
    return t * t * (3 - 2 * t);
  }

  /// The average of all of it: what a rough surface reflects, since it
  /// blurs every direction together.
  Rgb get diffuse => sky * 0.4 + horizon * 0.35 + ground * 0.25;

  /// The studio on the camera's side, as a metal sees it mirrored.
  ///
  /// Metal is photographed with the room behind the camera kept dim — so
  /// that a polished plate facing the lens shows its own colour darkened,
  /// with the lights along its edges, and not a flat white mirror of an open
  /// sky. Glass reflects a few per cent of whatever is there, so it is the
  /// metals, which mirror most of it, that this is for.
  static const studioColour = Rgb(0.62, 0.63, 0.64);
}

/// How a point of a face set [depth] below what stands beside it, [away]
/// from that step, sees the sky and the light.
///
/// The step hides part of the sky: for a point on a flat face beside a wall,
/// the share of the (cosine-weighted) sky the wall hides is half of one less
/// the sine of the angle up to its top — half at its foot, a sixth a wall's
/// height away, next to nothing three away. And where the light comes over
/// the step, the step throws a shadow as wide as it is tall times how low
/// the light comes in. [out] is the way across the step from the face,
/// [normal] the way the face looks, [light] the way to the light.
({double occlusion, double shadowed}) recess({
  required double depth,
  required double away,
  required Vec3 out,
  required Vec3 normal,
  required Vec3 light,
}) {
  if (depth <= 0) return (occlusion: 0.0, shadowed: 0.0);
  final d = math.max(0.0, away);
  final occlusion = 0.5 * (1 - d / math.sqrt(d * d + depth * depth));
  final down = light.dot(normal);
  final across = light.dot(out);
  var shadowed = 0.0;
  if (down > 1e-6 && across > 0) {
    final width = depth * across / down;
    // A soft edge a millimetre either side: the light is not a point.
    const soft = 1.0;
    final t = ((width + soft - d) / (2 * soft)).clamp(0.0, 1.0);
    shadowed = t * t * (3 - 2 * t);
  }
  return (occlusion: occlusion, shadowed: shadowed);
}

/// A face's colour under the light, and how much it hides what is behind
/// it.
///
/// Three layers, because glass is three things at once:
///
/// - [filter]: what the material does to the light passing through it —
///   what is behind is *multiplied* by it, as a tinted pane darkens and
///   tints the view through it. Null for anything that lets nothing
///   through.
/// - [colour] at [opacity]: what the surface shows of itself, laid *over*
///   what is behind — everything, for a solid; the glow of scattered light,
///   for frosted glass; nothing, for clear.
/// - [reflection]: the light the surface reflects, *added* to whatever is
///   there. Null where there is none worth adding.
class Shaded {
  /// 0xAARRGGBB, opaque; [opacity] is laid on separately.
  final int colour;

  /// 0 shows everything behind, 1 hides it.
  final double opacity;

  /// 0xAARRGGBB, multiplied into what is behind; null when nothing passes.
  final int? filter;

  /// 0xAARRGGBB, added over the top; null when nothing is reflected.
  ///
  final int? reflection;

  const Shaded(this.colour, this.opacity, {this.filter, this.reflection});
}

abstract final class Shading {
  /// How [surface] in [colour], facing along [normal], looks in
  /// [environment]. [occlusion] and [shadowed], 0 to 1, are how much of the
  /// sky and of the key light what stands round the point hides from it.
  /// [side] is the thin side of a sheet; [view] is the way
  /// to the eye from the point being shaded — straight out of the screen
  /// for a parallel view, and different at every point of a perspective
  /// one, which is what makes a reflection move across a pane.
  ///
  /// Four things are worked out, each from the material's own figures:
  ///
  /// - **diffuse**: the colour itself, lit by how square the face is to the
  ///   light — most of what a panel or a frame is, almost none of what a
  ///   metal is ([Surface.metallic]);
  /// - **reflection**: the sky and ground, sharp on a smooth surface and
  ///   blurred to their average on a rough one ([Surface.roughness]), more
  ///   of it at a glancing angle than square on (Fresnel, from
  ///   [Surface.reflectivity]), white off a dielectric and in its own
  ///   colour off a metal;
  /// - **highlight**: the key light seen in the surface, tight and bright
  ///   when polished, broad and faint when rough;
  /// - **transmission**: what glass lets through, tinted by its colour and,
  ///   frosted, scattered — which is what makes it see-through where the
  ///   rest is not ([Surface.transmission], [Surface.scatter]).
  static Shaded of({
    required Surface surface,
    required int colour,
    required Vec3 normal,
    required Environment environment,
    bool side = false,
    Vec3 view = const Vec3(0, 0, 1),
    Vec3 skyward = const Vec3(0, -1, 0),
    double occlusion = 0,
    double shadowed = 0,
    int glassFaces = 2,
  }) {
    final base = Rgb.of(colour);
    var n = normal.normalised;
    // The side of the face the viewer is on.
    if (n.dot(view) < 0) n = n * -1;
    final light = environment.light;

    final facingView = n.dot(view).clamp(0.0, 1.0);
    // Lit on either side, as `Camera.project` has it: a face turned from
    // the key is the inside of a reveal, which is lit by the room, not black.
    final facingLight = n.dot(light).abs();
    // [occlusion] is how much of the sky the surroundings hide from this
    // point, [shadowed] whether the key light is blocked on its way here:
    // both are what a recess does to a face set in it.
    final open = 1 - occlusion.clamp(0.0, 1.0);
    final lit =
        environment.ambient * open +
        environment.key * facingLight * (1 - shadowed.clamp(0.0, 1.0));

    final rough = surface.roughness.clamp(0.04, 1.0);
    // Schlick's Fresnel, with the glancing reflection a rough surface can
    // reach held down by its roughness: a polished surface mirrors at a
    // glancing angle, a rubber one does not.
    final f0 = surface.reflectivity;
    final fresnel =
        f0 + (math.max(1 - rough, f0) - f0) * math.pow(1 - facingView, 5);

    // What the surface reflects: the environment in the mirror direction —
    // the sky at its own brightness, as glass and metal see it — blurred
    // towards its average as the surface roughens.
    final mirror = n * (2 * facingView) - view;
    final mirrorUp = mirror.normalised.dot(skyward);
    final reflected = environment
        .radianceAt(mirrorUp)
        .mixedWith(environment.diffuse, math.min(1, rough * 1.25));

    // The key light, seen in the surface.
    final half = (light + view).normalised;
    final shininess = (2 / math.pow(rough, 4) - 2).clamp(2.0, 4000.0);
    final highlight =
        math.pow(math.max(0.0, n.dot(half)), shininess) * (1 - rough);

    // A metal reflects in its own colour; anything else in white.
    final metal = surface.metallic;
    final tint = Rgb.white.mixedWith(base, metal);

    if (surface.isTransparent) {
      return _glass(
        surface,
        base,
        lit,
        fresnel.toDouble(),
        environment.radianceToward(mirror, skyward),
        environment.diffuse,
        highlight.toDouble(),
        side,
        glassFaces,
      );
    }

    // **A metal mirrors the studio it stands in**: the sky at its own
    // brightness and the strip lights either side of the camera, spread by
    // its roughness — a polished lever carries a bright streak along it,
    // a satin hinge a soft band. That is what says *metal* at a glance, and
    // the same studio glass reflects. Anything that is not a metal keeps
    // the blurred sky and ground it always reflected.
    final mirrored = metal <= 0
        ? reflected
        : reflected.mixedWith(
            environment
                .radianceToward(
                  mirror,
                  skyward,
                  blur: rough * 30,
                  studio: true,
                )
                .mixedWith(environment.diffuse, math.min(1, rough * 2.2)),
            metal,
          );

    // **A metal's colour is what it reflects.** Paint and plastic reflect a
    // few per cent, in white, over their own colour; a metal has no colour
    // underneath — its colour is the share of each light it gives back. So
    // the more metallic a surface is, the more of its look is what it
    // reflects, tinted by its colour, and its reflectivity figure only says
    // how polished it is — the same share its highlight is taken at.
    // Multiplying the colour by the whole figure again, as it once did,
    // counted the colour twice and turned a grey handle near black.
    final polish = 0.35 + 0.65 * surface.reflectivity;
    final reflects = fresnel.toDouble() * (1 - metal) + metal * polish;
    final diffuse = base * (lit * (1 - metal * 0.85));
    final reflection = mirrored.tinting(tint) * (reflects * open);
    final shine = tint * (highlight * polish);
    final result = diffuse * (1 - reflects) + reflection + shine;
    return Shaded(result.argb, 1);
  }

  /// Glass: what it lets through, what it scatters, and what it reflects.
  ///
  /// A pane is built as a slab, so a line of sight through it crosses two
  /// of its faces, and each filters by its share of the glass — the square
  /// root of what the whole lets through — so the two together let through
  /// exactly [Surface.transmission], less what each surface reflects away.
  /// The filter takes half its colour from the glass: a clear pane greys
  /// and cools what is behind it a little, a tinted one a lot.
  ///
  /// What frosting scatters shows as the pane's own light, laid over; what
  /// the surface reflects — the sky, and the key light in it — is added.
  ///
  /// The thin side is not seen through: it is the glass's body end on, in
  /// the green of the iron in it.
  static Shaded _glass(
    Surface surface,
    Rgb base,
    double lit,
    double fresnel,
    Rgb arriving,
    Rgb average,
    double highlight,
    bool side,
    int faces,
  ) {
    if (side) {
      final edge = surface.edge.sideTint == null
          ? base
          : Rgb.of(surface.edge.sideTint!);
      return Shaded((edge * lit).argb, 0.9);
    }

    // Each of the [faces] faces a line of sight crosses takes its share of
    // what the glass lets through and of its colour: the square root of
    // each for a single sheet's two faces, the fourth root for a sealed
    // unit's four.
    final each = math.max(1, faces);
    final share = math.pow(
      surface.transmission.clamp(0.0, 1.0),
      1 / each,
    ).toDouble();
    // What the faces reflect away is taken from what passes — shared among
    // them as the reflection itself is (below), so a sealed unit of four
    // faces is the same glass as a sheet of two, letting through and
    // reflecting what it does.
    final passes = (1 - fresnel * (2 / each)).clamp(0.0, 1.0);
    final filter = Rgb.white.mixedWith(base, 1 / each) * (share * passes);

    // Frosting catches the light that passes and spreads it, so a frosted
    // pane glows with the light rather than showing what is behind it.
    final scattered = surface.scatter * (1 - share);
    final glow =
        base.mixedWith(Rgb.white, surface.scatter * 0.4) *
        (0.82 + 0.18 * lit);

    // What the surface reflects: the light arriving from the mirror
    // direction — the sky, the ground, the studio's softbox — at its own
    // brightness, blurred towards the average as the surface roughens, and
    // as much of it as Fresnel says.
    final rough = surface.roughness.clamp(0.04, 1.0);
    final reflected = arriving.mixedWith(
      average,
      math.min(1, rough * 1.25),
    );
    // What the glass reflects is shared among its faces as what it lets
    // through is: [Surface.reflectivity] is the glass as glazed, so a sealed
    // unit is the same glass whether a line of sight meets two faces of it
    // or four, and does not wash out white for having more of them.
    final reflection =
        (reflected * fresnel + Rgb.white * (highlight * 0.9)) * (2 / each);
    return Shaded(
      glow.argb,
      scattered.clamp(0.0, 1.0),
      filter: filter.argb,
      reflection: reflection.argb,
    );
  }

  /// A material with its colour taken away: the form alone, for a view
  /// that shows the shape without the finishes. Glass stays see-through,
  /// though less so, because the parts behind it are part of the form.
  static Surface clay(Surface surface) => Surface(
    id: 'clay',
    kind: surface.kind,
    transmission: surface.transmission * 0.6,
    roughness: 0.8,
    reflectivity: 0.03,
    edge: surface.edge,
    cad: surface.cad,
  );
}

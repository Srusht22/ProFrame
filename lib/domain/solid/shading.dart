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

  const Environment({
    required this.light,
    required this.sky,
    required this.horizon,
    required this.ground,
    this.ambient = 0.45,
    this.key = 0.75,
  });

  /// Over the viewer's left shoulder, where a window is usually
  /// photographed from — the same light `Camera.project` has always used.
  static const keyLight = Vec3(-0.45, -0.7, 1);

  /// A bright overcast day: the light the model is shown in by default.
  static final daylight = Environment(
    light: keyLight.normalised,
    sky: Rgb.of(0xFFE9EEF0),
    horizon: Rgb.of(0xFFF7F8F6),
    ground: Rgb.of(0xFF8F8D86),
  );

  /// What is seen looking along [direction]: sky above the horizon, ground
  /// below it. y runs down the screen, so up is negative y.
  Rgb seen(Vec3 direction) {
    final up = -direction.normalised.y;
    if (up >= 0) return horizon.mixedWith(sky, math.min(1, up * 1.4));
    return horizon.mixedWith(ground, math.min(1, -up * 2.2));
  }

  /// The average of all of it: what a rough surface reflects, since it
  /// blurs every direction together.
  Rgb get diffuse => sky * 0.4 + horizon * 0.35 + ground * 0.25;
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
  final int? reflection;

  const Shaded(this.colour, this.opacity, {this.filter, this.reflection});
}

abstract final class Shading {
  /// How [surface] in [colour], facing along [normal], looks in
  /// [environment]. [side] is the thin side of a sheet.
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
  }) {
    final base = Rgb.of(colour);
    var n = normal.normalised;
    // The side of the face the viewer is on.
    if (n.z < 0) n = n * -1;
    const view = Vec3(0, 0, 1);
    final light = environment.light;

    final facingView = n.z.clamp(0.0, 1.0);
    // Lit on either side, as `Camera.project` has it: a face turned from
    // the key is the inside of a reveal, which is lit by the room, not black.
    final facingLight = n.dot(light).abs();
    final lit = environment.ambient + environment.key * facingLight;

    final rough = surface.roughness.clamp(0.04, 1.0);
    // Schlick's Fresnel, with the glancing reflection a rough surface can
    // reach held down by its roughness: a polished surface mirrors at a
    // glancing angle, a rubber one does not.
    final f0 = surface.reflectivity;
    final fresnel =
        f0 + (math.max(1 - rough, f0) - f0) * math.pow(1 - facingView, 5);

    // What the surface reflects: the environment in the mirror direction,
    // blurred towards its average as the surface roughens.
    final mirror = n * (2 * facingView) - view;
    final reflected = environment
        .seen(mirror)
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
        reflected,
        highlight.toDouble(),
        side,
      );
    }

    final diffuse = base * (lit * (1 - metal * 0.85));
    final reflection = reflected.tinting(tint) * fresnel.toDouble();
    final shine = tint * (highlight * (0.35 + 0.65 * surface.reflectivity));
    final result = diffuse * (1 - fresnel.toDouble()) + reflection + shine;
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
    Rgb reflected,
    double highlight,
    bool side,
  ) {
    if (side) {
      final edge = surface.edge.sideTint == null
          ? base
          : Rgb.of(surface.edge.sideTint!);
      return Shaded((edge * lit).argb, 0.9);
    }

    final share = math.sqrt(surface.transmission.clamp(0.0, 1.0));
    final filter = Rgb.white.mixedWith(base, 0.5) * (share * (1 - fresnel));

    // Frosting catches the light that passes and spreads it, so a frosted
    // pane glows with the light rather than showing what is behind it.
    final scattered = surface.scatter * (1 - share);
    final glow =
        base.mixedWith(Rgb.white, surface.scatter * 0.4) *
        (0.82 + 0.18 * lit);

    final reflection = reflected * fresnel + Rgb.white * (highlight * 0.9);
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

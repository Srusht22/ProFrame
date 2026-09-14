# ProFrame

Draw a door or a window by hand. The drawing becomes editable geometry, and
the geometry becomes the 2D design and the 3D model — exactly as drawn.

## The rule the whole thing is built on

**The user draws the design. The application reproduces that design.**

It does not redesign, tidy up, balance, symmetrise, or fill anything in. It
does not have a stock door it stretches to fit, and it has no opinion about
what a window usually looks like. An off-centre mullion stays off-centre, a
48/52 split stays 48/52, and a five-sided opening is built with five sides.

The one thing it is allowed to do unasked is take the shake out of a hand:

| Cleaning — allowed | Redesigning — never |
| --- | --- |
| Smoothing the wobble along a line | Straightening a line drawn at a slope |
| Squaring a line drawn two degrees off vertical | Moving a bar to the middle |
| Welding two ends drawn a few millimetres apart | Making two sections equal |
| Trimming a line drawn past the corner | Adding a panel that was not drawn |

Where the drawing is genuinely ambiguous — a diagonal that might be an
opening symbol or might be a glazing bar — the application asks. It never
decides quietly.

## How it works

```
you draw  →  strokes kept exactly  →  read as geometry  →  you confirm or edit
                                                                   ↓
                            3D model  ←  sections  ←  clean 2D design
```

1. **The sketch** is every mark you made, with pressure and timing, kept for
   the life of the design. Recognition reads from it and writes elsewhere;
   the only thing that removes a mark is your own eraser.
2. **Reading** fits each stroke to straight runs, with the corner tolerance
   scaled to the stroke rather than to the sheet. Ends drawn near each other
   are welded, so a box drawn as four separate strokes closes. Lines drawn
   past their corner are trimmed.
3. **Sections** come from planar subdivision: your lines are cut at their
   crossings, joined into a graph, and the faces of that graph are the
   sections. A diagonal makes triangles. A line stopping short of another
   still divides. Nothing is laid out to a template.
4. **Real size** comes from a dimension you type. Everything scales by one
   number about one origin, so every proportion you drew survives it.
5. **The model** is built from that geometry — the frame along your outline,
   bars along your bars, panes filling what they enclose, hardware only where
   you put it. Every face knows which part it came from, so tapping a pane in
   the model selects the same pane as tapping it in the drawing.

## Layout

```
lib/
  domain/          pure Dart, no Flutter
    geometry/      points, segments, polygons, and every tolerance in one place
    sketch/        the user's own marks, kept forever
    model/         the design document and its editable elements
    recognition/   strokes → geometry, and questions where it is unsure
    sections/      planar subdivision
    dimensions/    real sizes, in proportion
    editing/       moving, resizing, deleting, colouring
    solid/         mesh generation and the perspective camera
  app/             theme, state, canvas, inspector, 3D view, screens
  infrastructure/  saving designs
test/
  domain/          the geometry and the promises, on deliberately awkward drawings
  app/             the workspace, and the screens
```

## Running it

```sh
flutter pub get
flutter run                 # a device, a tablet, or a desktop
flutter test                # 81 tests
flutter analyze             # strict: casts, inference, raw types
```

The web build runs offline: `web/flutter_bootstrap.js` points Flutter at the
copy of its renderer inside the bundle rather than at a CDN, so it opens in a
workshop with no internet.

## Tolerances

Every one lives in `lib/domain/geometry/tolerances.dart`, with the reason it
is the size it is. They are mostly relative rather than absolute, because a
three-pixel wobble is twenty-three millimetres on a three-metre sheet: a
fixed figure is either blind to real corners on a small drawing or sees a
corner in every tremor on a large one.

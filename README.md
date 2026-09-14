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
   still divides. Nothing is laid out to a template. Every bar is cut in as
   its two faces, not its centre line, so a section is the real daylight
   opening rather than half a bar too wide.
4. **Real size** comes from a dimension you type. Everything scales by one
   number about one origin, so every proportion you drew survives it.
5. **The CAD drawing** is that same geometry drawn to drafting conventions —
   line weights that mean something, hatching through the frame profile,
   the glazing mark on each pane, dashed swing symbols, and dimension
   chains measured off the sections themselves. It is editable by taking
   hold of it: grips on the selected bar or frame edge, snapping only to
   positions where something already is. Layers turn parts of the drawing
   on and off; none of them changes the design.
6. **The model** is built from that geometry — the frame along your outline,
   bars along your bars, panes filling what they enclose, hardware only where
   you put it. Every face knows which part it came from, so tapping a pane in
   the model selects the same pane as tapping it in the drawing. Orbit, pan
   and zoom it; look at it from the front, back, either side, above, below or
   three-quarters; switch between perspective and parallel; draw it shaded,
   shaded with edges, as a wireframe, or in one colour. Wireframe is the
   proof it is a solid: every edge is there, including the ones behind.

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
  app/
    theme/         the one place colours and type live
    state/         the workspace, its tools, its history
    canvas/        the sheet, the CAD drawing, and what they are drawn with
    inspector/     what is selected, the component tree, the questions
    viewer/        the 3D view
    screens/       the way in, the workspace, the tool rail
  infrastructure/  saving designs
test/
  domain/          the geometry and the promises, on deliberately awkward drawings
  app/             the workspace, and the screens
```

## Running it

```sh
flutter pub get
flutter run                 # a device, a tablet, or a desktop
flutter test                # 175 tests
flutter analyze             # strict: casts, inference, raw types
```

The web build runs offline: `web/flutter_bootstrap.js` points Flutter at the
copy of its renderer inside the bundle rather than at a CDN, so it opens in a
workshop with no internet.

## Openings

**Only the user decides which section opens.** There is no rule anywhere
that picks a door leaf, nothing that decides the lower section is probably
the door, and no template. A design with nothing marked comes back with no
openings, however door-shaped it is.

You mark a section by drawing one of four marks inside it:

| Mark | Meaning |
| --- | --- |
| `>` | hinged on the left, opening from the right |
| `<` | hinged on the right, opening from the left |
| `^` | hinged at the bottom, opening at the top |
| `v` | hinged at the top, opening at the bottom |

One rule covers all four: **the point is at the edge that moves**, and the
hinge is opposite it. That is how they are read on an elevation.

```
┌────────────────────────┐        ┌──────────┬─────────────┐
│                        │        │          │             │
│         GLASS          │        │    <     │             │
│                        │        │          │    GLASS    │
├────────────────────────┤        │          │             │
│           >            │        └──────────┴─────────────┘
│                        │
│       DOOR PART        │        The section holding the < opens.
│                        │        The other one does not.
└────────────────────────┘
```

The mark never becomes a bar; it is an instruction, not something to build.
It stays in your sketch like every other stroke, and the drawing shows the
glyph where you made it, so the design can always be checked against the
instruction it came from.

If the mark is not clearly inside one section — it crosses a bar, or sits
outside the frame — **nothing is opened** and you are asked which section
you meant, with every candidate offered and none chosen. An opening made
from a mark lasts exactly as long as the mark does: rub it out, or say it
was not one, and the opening goes with it.

### Editing an opening

The marked section becomes an object you can select — from its mark on the
drawing, from the component tree, or from the section's own panel. Selected,
it shows what it is and lets you change it:

```
Hinged left  >

Direction      <   >   ^   v
               You marked this section with a >.
Opening type   Hinged left · Hinges on the left, opens from the right
               Inward | Outward
Width          819 mm
Height         1689 mm
Position       left section — 819 × 1689 mm
```

Changing the direction changes which edge the leaf swings about, in the CAD
drawing and in the model, and nothing else: the sections keep their shapes,
the bars keep their places, the finishes keep their colours. Width and
height move the bar beside the section, as they do everywhere else. Position
moves the opening to a different section — neither section changes shape,
because an opening is a property of a section rather than a shape of its
own.

Where you change a direction you drew, both are kept: the drawing shows what
is built now, and the panel says *"You drew > here. You have since changed
it to <."*

## What the 3D view is not

It is not a picture of the drawing tipped into perspective, and there is no
stock model anywhere in the repository to stretch to fit. The mesh is built
face by face from the design: a ring following the outline's own corners, a
box for each bar at the angle it was drawn, a slab filling each section the
bars enclose. Turn on wireframe and count the edges.

Tests assert the correspondence directly: every section in the drawing is a
pane in the model and no more; every bar is a bar and no more; the one
horizontal divider is one horizontal bar spanning exactly the column it was
drawn across; glass is in the section the glass was put in and the panel in
the section the panel was put in; and nothing exists in the model whose id
is not in the drawing.

## Snapping

Dragging a bar snaps to the frame's edges, to the faces and centre lines of
the other bars, and to the edges of the sections — every position where
something already is. It deliberately does **not** snap to halves, thirds or
equal spacings. Those would quietly pull a design towards being symmetrical,
which is the one thing this application must never do.

## Tolerances

Every one lives in `lib/domain/geometry/tolerances.dart`, with the reason it
is the size it is. They are mostly relative rather than absolute, because a
three-pixel wobble is twenty-three millimetres on a three-metre sheet: a
fixed figure is either blind to real corners on a small drawing or sees a
corner in every tremor on a large one.

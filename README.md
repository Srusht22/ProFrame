# ProFrame

Draw a door or a window by hand. The drawing becomes editable geometry, and
the geometry becomes the 2D design and the 3D model — exactly as drawn.

## What it does

```
I DRAW MY DOOR/WINDOW
        ↓
MY EXACT DRAWING IS PRESERVED
        ↓
CAD / SKETCHUP-STYLE DRAWING
        ↓
I MARK OPENINGS USING < OR >
        ↓
I EDIT ANY PART
        ↓
3D SKETCHUP-STYLE MODEL
        ↓
THE 3D MODEL IS THE SAME DESIGN I DREW
```

Every step is a conversion, never a decision.

## The rule the whole thing is built on

**DO NOT DESIGN THE DOOR OR WINDOW FOR ME. I DESIGN IT. THE APPLICATION
ONLY CONVERTS MY DESIGN INTO EDITABLE CAD AND 3D.**

THE USER'S DRAWING IS THE SOURCE OF TRUTH. It is not a preference and it is not negotiable against any other goal here.
A change that makes the output prettier, more regular or easier to build, at
the cost of it no longer being what the user drew, is a bug — however good it
looks.

| The application may | The application must not |
| --- | --- |
| Clean slightly imperfect lines | Redesign |
| Snap lines to horizontal or vertical | Beautify structurally |
| Recognise geometry | Add random parts |
| Calculate dimensions | Remove lines |
| Create 3D geometry | Equalise sections |
| | Force symmetry |
| | Move openings |
| | Change proportions |
| | Replace custom designs with templates |

The rule is enforced by `test/domain/the_rule_test.dart`, which is the rule
written as assertions rather than as intentions. Sabotage the reader to
centre every vertical bar and eight of its tests fail. **Do not weaken that
file to make a change pass.** If a change cannot keep it true, the change is
wrong.

`CLAUDE.md` states the same rule for anyone — or anything — working on this
repository.

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

It does not interview you about your own drawing. You drew a shape, so it
builds the shape; you put a `<` in a section, so that section opens; you drew
a line at an angle, so it builds a line at that angle. Then you edit whatever
you want changed — every figure can be typed over, every pane can be made
glass or panel, and a diagonal has a button on its own panel that turns it
into the opening it may have stood for.

Two things are asked about, because in each there is nothing to build: an
outline that does not close, and a mark drawn right off the design. Neither
is ever asked twice.

## How it works

```
you draw  →  strokes kept exactly  →  read as geometry  →  you edit
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
flutter test                # 249 tests
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

And only the section you marked opens. Your lines cut the daylight into
regions; your mark lands in one of them; that one opens and every other one
stays fixed:

```
┌──────────────────────────┐
│          FIXED           │
├──────────────┬───────────┤
│      >       │   FIXED   │
│   OPENING    │           │
└──────────────┴───────────┘
```

Three sections, two bars, one opening. The opening never grows to take in the
section beside it, and a window is never an opening because a mark was drawn
somewhere inside it.

The opening has a boundary of its own, and you can see it: the leaf gets its
own frame inside the region that opens, drawn in the elevation and built in
the model from the same description, with the glass stopping at the sash in
both. Everything outside that boundary belongs to the design — the outer
frame, and every section you did not mark. Nothing outside it can be made
part of it: a bar in the fixed light across the window is not the opening's,
and the application will not let you say it is, because the next time the
opening moved it would drag that bar along with it.

Belonging is judged by where the whole line is, not by where its middle
happens to fall — a bar that starts inside the opening and runs out of it is
not the opening's, however central its midpoint. Dimensions, notes and
arrows belong to nothing at all, and an opening never moves them.

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

The mark opens the section it is in, and you will not be asked which one
that was. A mark is in the section its middle is in — which is what being in
a section means — so it works however shakily you drew it and however near a
bar it strays. Only a mark drawn right off the design has no section to be
in, and that is the one you are asked about.

Nor will you be asked to draw it neatly. A chevron is read by its shape, not
by how many corners a fitting finds in it: the point is the corner furthest
from the line joining the two ends, and the rest have to lie along the two
arms. A zigzag, a staircase, a frame corner and a straight line are still not
marks, and each is built exactly as you drew it.

An opening made from a mark lasts exactly as long as the mark does: rub it
out, or say it was not one, and the opening goes with it.

### What is inside an opening

The marked region **is** the opening, all of it. Lines you draw inside it
afterwards are lines inside the opening — bars of the sash — and not new
divisions of the whole design:

```
┌──────────────────────┐      Window
│        FIXED         │      ├── fixed light
├──────────────────────┤      └── the opening
│          >           │          ├── hinged left, >
│                      │          ├── bar, inside
│  ──────────────────  │          ├── bar, inside
│                      │          └── three panes
│  ──────────────────  │
└──────────────────────┘
```

A line drawn a little long is trimmed back to the opening, so it stops at
the sash instead of carrying on across the design. Only the overshoot goes:
the ends move inwards, never outwards, and the angle never changes.

The two lines under the `>` do not cut the opening into pieces and they do
not end it half way down. There is one transom that divides the design, one
opening below it running to the sill, and inside that opening two bars and
three panes. The component tree shows the nesting, the drawing puts the
swing lines across the whole opening, and in the model the leaf swings with
its bars and panes attached — nothing stays behind on the frame.

Every line you draw on the sheet divides the design, and the mark opens the
one region it lands in — never a bigger one, and never the whole window.
That holds whatever order you draw in.

To make a line part of an opening you say so, either by drawing it with the
line tools inside the opening, or by picking the bar and using the **Divides**
control on its panel:

```
Divides        The whole design
               Inside the opening — 1203 × 1507 mm
```

Nothing is guessed there either. The list is offered and you pick.

### Building the inside of an opening

An opening is a container, not a single pane. Pick any part of one — its
mark, the sash, a bar in it, a pane, a hinge, the handle — and the tools for
drawing inside it appear above the drawing:

```
⌗ Inside hinged right — 29 × 138.5 cm   ▸ Select   — Horizontal line   ┼ Vertical line   ⌫ Erase
```

Pick a line tool and the opening is outlined; move the pointer and a ghost
line shows exactly where the line will land, stopping at the opening's own
edges. Click and it is there:

```
┌──────────┐                 ┌──────────┐
│          │                 │  GLASS   │
│          │   horizontal    ├──────────┤ ← the line you drew
│    <     │   line, here    │          │
│          │       →         │  PANEL   │
│          │                 │          │
└──────────┘                 └──────────┘
```

The line is the opening's from the moment you draw it. It divides the
opening; it does not end it, it does not make a new section beside it, and
it goes wherever the opening goes. Then each pane is yours to name — clear
glass, frosted, tinted, solid panel, louvre, insect mesh — and yours to
size.

You do not have to know the inside of a sash before you mark it. Mark it,
then build what goes in it, in any order, as many divisions as you want:

```
┌────────────┐     ┌────────┬────────┐
│   GLASS    │     │ GLASS  │ GLASS  │
├────────────┤     ├────────┼────────┤
│   GLASS    │     │        │        │
├────────────┤     │ PANEL  │ PANEL  │
│   PANEL    │     │        │        │
└────────────┘     └────────┴────────┘
```

**Nothing divides an opening on its own.** An opening you draw nothing in
stays one pane, however tall it is. No middle line appears, no glass/panel
split is assumed, no mullion and no transom — the count of divisions is
yours and only yours.

And reading the sheet again does not undo any of it. Go back to the drawing,
add a transom in the fixed light, read it: the new line divides the design,
and the opening comes back with its own line, its two panes and the glass
and the panel you chose for them. A line you placed inside an opening was
made in the design rather than drawn on the sheet, so a reading of the sheet
has nothing to say about it. Lines you *did* draw still last exactly as long
as the strokes they came from — rubbing one out is how you delete it.

Everything inside is measured from the opening's own corner, because that is
whose it is:

```
Selected: Horizontal divider

Length                       28.9 cm
Bar width                     3.3 cm
From the top of the opening  40   cm
The opening is           29 × 138.5 cm
Divides         Inside the opening — left section
```

Type 40 there and the bar goes 40 cm down the sash. Drag the edge of a pane
and the same bar moves. Type a pane's height and the pane below gives up
what it gained, with the opening and the rest of the design exactly as they
were. In the model the divider is a real piece of material with a front, a
back and sides — not half a pane painted a different colour — and it swings
out with the leaf along with the glass, the panel, the hinges and the
handle.

### Hinges and a handle

Saying a section opens is saying it hangs on something and is worked by
something, so an opening carries hinges and a handle. They belong to the
opening — not to the door, and not to the frame:

```
Door
├── Fixed section
└── Opening
    ├── Hinged left  >
    ├── Hinge      70 cm up
    ├── Hinge      20 cm up
    ├── Handle     45 cm up
    └── the panes and bars inside it
```

Everything in that list moves, resizes and swings together. Change the
direction from `>` to `<` and the hinges cross to the other stile with the
handle following them; resize the leaf and they stay on its edges; open it
in the model and they come away from the frame with it.

**A section you did not mark gets none of this.** No hinges, no handle, no
lock, no letter plate — nothing at all is added to a section that has no
mark on it, and nothing beyond hinges and a handle is ever added to one that
has.

Where they sit is yours to set:

```
Selected: Hinge                        Selected: Handle

First hinge from the top    20  cm     Height from the bottom   45  cm
Last hinge from the bottom  20  cm
Number of hinges           2  3  4
```

Until you say, they follow two stated rules rather than a guess: two hinges,
and one more for every metre of hinged edge, up to four; and the handle a
metre up, which is where a hand falls on a door, or the middle of the stile
on a sash too short for that. Anything you set is used exactly and kept.

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

## One model

There is one document. The sheet, the technical drawing and the solid are
three ways of looking at what is in it, not three things to keep in step:

```
                   Design
                     |
       +-------------+-------------+
       |             |             |
    the sheet    CAD drawing    3D model
     (sketch)     (painter)      (mesh)
```

Each view is a function of that object and holds no geometry of its own. The
CAD painter reads the design and draws. `MeshBuilder.build` reads the design
and returns a mesh that nothing keeps — it is rebuilt from scratch on every
frame, so there is nowhere for a stale copy to live. Change a bar and both
views show it, because there is nowhere else for either of them to look.

Tests state it rather than trusting it: the same design gives a byte-for-byte
identical mesh; building the mesh does not touch the design; two designs that
differ give meshes that differ; and after each of a run of edits, the set of
panes in the model equals the set of panes in the drawing and the set of bars
equals the set of bars.

| Change | Reaches |
| --- | --- |
| A dimension typed in the drawing | the model, scaled in proportion |
| A divider moved | the model, the bar in its new place |
| An opening's direction | the model, the leaf on its new hinge |
| A section from panel to glass | the model, as a see-through pane |
| A colour | the model, on that pane's faces |
| One side of the frame | the model, that side only |
| **Depth, set in the 3D view** | the design, and so the parts list |
| **Frame profile, set in the 3D view** | the drawing, as a heavier frame and smaller daylight openings |

Depth and frame profile are edited in the 3D view because that is where they
can be seen, and they are the design rather than the view. How far the leaves
are swung open is the only control that is purely a way of looking: it
changes the picture and nothing else, and a test asserts the design is
identical before and after.

## Nothing in the output is a picture

```
MY DRAWING  →  MY GEOMETRY  →  MY CAD DESIGN  →  MY 3D MODEL
```

Every pixel of the design is drawn from that geometry. There is no stock
photograph, no generated picture, no ready-made 3D asset and no model file
anywhere in this repository. `pubspec.yaml` bundles two typefaces and
nothing else; `lib/` contains no call that loads a picture from the bundle,
the network, disk or memory. When there is nothing to show, the application
says so rather than reaching for something that looks like a door.

`test/no_stock_content_test.dart` guards it. Add a stock picture and three
of its tests fail: the asset declaration, the code that loads it, and the
picture appearing where a design should be.

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

## Editing

Everything in the drawing is a part you can pick: the frame and each of its
sides — head, sill, left jamb, right jamb, or the raking sides of a frame
that is not four-sided — every bar, every pane, every opening, every piece
of hardware, every dimension, note and arrow. Tap it on the drawing, or find
it in the component tree. Tapping the frame picks the side you tapped.

Each part shows what it is and what can be changed about it, and each field
changes the one thing it names:

```
Selected: Section          Selected: Left jamb        Selected: Horizontal divider

Width    91 cm             Length   173.1 cm          Length   139.4 cm
Height   81.8 cm           Angle    89.9°             Angle    0.0°
Material Clear glass       From     52.1, 190.5 cm    Bar width 4.8 cm
Colour   ▢▢▢▢▢             To       51.8, 17.4 cm     Material uPVC
Opens    Fixed             Profile  6 cm              Colour   ▢▢▢▢▢
```

### Every figure on the drawing can be typed over

The numbers on the technical drawing are not captions. Each one is a real
piece of the design, so you can tap it and type a new one:

```
        ┌─────────────────┐              ┌──────────────────────┐
        │                 │              │  Section height      │
 93.3 ──┤    120.4 × 93.3 │              │  ┌────────────────┐  │
        ├─────────────────┤      tap →   │  │ 150.7       cm │  │
        │        >        │              │  └────────────────┘  │
150.7 ──┤   120.3 × 150.7 │              │    Cancel   Apply    │
        └─────────────────┘              └──────────────────────┘
```

Type 90 and the drawing physically changes: the transom moves, the pane
above it grows by what this one lost, the opening stays the opening, and the
model follows. What moves is what has to:

| The figure you type over | What moves |
| --- | --- |
| Overall width or height | The frame, and everything in it in proportion |
| A pane's width | The bar beside it — or the jamb, when there is no bar |
| A pane's height | The bar above or below it — or the sill |
| A measurement you drew | The whole design, scaled to make your figure true |

The overall size does not quietly change to absorb a pane you resized, and
no pane you did not name is touched.

### Everything is in centimetres

You type centimetres and you read centimetres. Nowhere does the application
ask you for millimetres:

```
Overall width   132.4  cm
Overall height  200.2  cm
Section height   90    cm
```

Figures are written to the millimetre — the tenth of a centimetre — which is
what a workshop cuts to and the finest distinction worth putting on a
drawing. Nothing is rounded past that: a pane 96.4 cm tall is never written
as 96, and a figure you type finer than a millimetre is kept exactly as you
typed it in the geometry underneath.

### Dragging and typing are the same edit

A selected part shows handles. A pane's handles sit on its own edges but move
the bar or the frame side that *makes* each edge — because a pane is the
space between those and has no edges of its own:

```
┌──────────┬──────────┐
│          ▪          │     grab the boundary
│   pane   ▪   pane   │  ←  and the bar moves
│          ▪          │
└──────────┴──────────┘
```

Typing a width and dragging that boundary reach the same geometry by the
same route, and a test asserts they agree to a hundredth of a millimetre. A
bar only moves across itself; a drag along its length changes nothing,
because for a bar it means nothing. A frame side moves square to itself, so
a raking head on a five-sided frame keeps its angle.

### Nothing else moves

The rule the editing is built to: **an edit changes what it names and what
follows from it mathematically, and nothing else.** Moving a bar moves that
bar and the panes it bounds — because a pane *is* the space between bars —
and leaves the other bar, the hardware, the dimensions, the notes and every
finish untouched. Tests take a fingerprint of every other element in the
design and require it to come back byte for byte identical.

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

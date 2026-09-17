# ProFrame

## What the application is

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

That chain is the product. Every step of it is a conversion, never a
decision: the drawing becomes geometry, the geometry becomes a technical
drawing and a solid, and at no point does anything get designed.

**DO NOT DESIGN THE DOOR OR WINDOW FOR THE USER. THEY DESIGN IT. THE
APPLICATION ONLY CONVERTS THEIR DESIGN INTO EDITABLE CAD AND 3D.**

## The rule

**THE USER'S DRAWING IS THE SOURCE OF TRUTH.**

This is not a preference and it is not negotiable against any other goal in
this repository. A change that makes the output prettier, more regular, more
conventional or easier to build, at the cost of it no longer being what the
user drew, is a bug — however good it looks.

### The application may

- Clean slightly imperfect lines
- Snap lines to horizontal or vertical
- Recognise geometry
- Calculate dimensions
- Create 3D geometry

### The application must not

- Redesign
- Beautify structurally
- Add random parts
- Remove lines
- Equalise sections
- Force symmetry
- Move openings
- Change proportions
- Replace custom designs with templates

If the user draws this:

```
┌───────────────────┐
│     │             │
│     │             │
├─────┤             │
│     │             │
│     │             │
└─────┴─────────────┘
```

then that is what gets built. A narrow left column split by a transom, and a
wide right column running the full height. The application must never decide
that it would look better with the columns equal.

## Nothing in the output is a picture

The pipeline is:

```
MY DRAWING  →  MY GEOMETRY  →  MY CAD DESIGN  →  MY 3D MODEL
```

Every pixel the user sees of their design is drawn from that geometry. There
is no stock door photograph, no stock window photograph, no generated
picture, no ready-made 3D asset and no model file anywhere in this
repository — and none is to be added. A picture standing in for a design is
a lie about what was built, however good it looks, and it is worse than
showing nothing.

When there is nothing to show, the application says so. It does not reach
for something that looks like a door.

`test/no_stock_content_test.dart` enforces this on the repository itself: it
fails if `pubspec.yaml` declares any bundled asset other than a typeface, if
any file under `lib/` loads a picture from the bundle, the network, disk or
memory, if a model file appears anywhere, or if a picture is put on screen
where a design should be.

## Where the line falls

The boundary between cleaning and redesigning is the whole design of this
application, so it is written down rather than left to judgement:

| Cleaning — allowed | Redesigning — never |
| --- | --- |
| Smoothing the wobble along a line | Straightening a line drawn at a slope |
| Squaring a line drawn two degrees off vertical | Moving a bar to the middle |
| Welding two ends drawn a few millimetres apart | Making two sections equal |
| Trimming a line drawn past its corner | Adding a panel that was not drawn |
| Reading a `<` as an opening mark | Deciding a section opens |

The test: **does the change alter what the user would have to build?** If it
does, it is not cleaning.

## Build it, do not ask about it

**Do not ask the user to define what they have already defined by drawing
it.** A questionnaire between the drawing and the design is not caution, it
is the application refusing to read. The user drew a shape; build the shape.
They put a `<` in a section; open that section. They drew a line at an angle;
build the line at that angle.

Then let them edit it. Every figure on the drawing can be typed over, every
pane can be made glass or panel, every bar can be moved or deleted, and a
diagonal has a control on its own panel that turns it into the opening it may
have stood for. That is the shape of this application:

```
READ  →  BUILD  →  THE USER EDITS
```

and never

```
READ  →  ASK  →  WAIT  →  ASK AGAIN
```

Building is not guessing. A guess invents something the drawing does not
contain — a panel nobody drew, a section made equal to its neighbour, a leaf
chosen because it is the lower one. Building takes what is on the sheet and
makes it real. Everything above is building.

### The only questions left

A question is for a drawing that says *nothing*, not for one that says
something inconvenient. There are exactly two, and each is asked because
there is nothing to build:

- **The outline does not close.** There is no shape, so there is no frame,
  and joining the ends would move lines the user drew. The lines are kept as
  geometry and the question offers to close them.
- **A mark is drawn right off the design.** There is no section it could be
  in, so there is nothing to open.

A mark that merely strays near a bar or a jamb is *not* one of these. It
opens the section its middle is in — that is what being in a section means,
and it holds however shakily the mark was drawn. `_placeSymbols` and
`sectionFor` in the interpreter are where this lives.

Neither question is ever asked twice. `WorkspaceState.settledQuestions`
remembers what has been answered or waved away for that design, and a
re-reading does not put it again.

If you are about to add a question, add an editing control instead. If the
geometry genuinely cannot be built, the question goes in the list above and
the reason goes beside it.

## How this is enforced

`test/domain/the_rule_test.dart` is the rule as executable assertions. It
holds the drawing above, runs it through reading, re-reading, scaling, 3D
generation, saving and reloading, and every editing operation, and requires
the proportions back unchanged. It also sweeps a few dozen randomly unequal
designs through the whole pipeline and requires each to come back as itself
rather than drifting towards a common shape.

**Do not weaken that file to make a change pass.** If a change cannot keep
those assertions true, the change is wrong.

Alongside it:

- `test/domain/editing_isolation_test.dart` — an edit changes what it names
  and what follows from it mathematically, and nothing else. It fingerprints
  every other element and requires it back byte for byte.
- `test/domain/one_model_test.dart` — the design is the only model; the CAD
  drawing and the solid are functions of it and hold no geometry of their own.
- `test/domain/user_decides_openings_test.dart` — an opening exists only
  where the user marked one.

## Architecture

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
```

The design is the only model. The sheet, the CAD drawing and the solid are
three ways of looking at it.

Sections come from planar subdivision of the user's own lines: the lines are
cut at their crossings, joined into a graph, and the faces of that graph are
the sections. Nothing is laid out to a template, which is what makes the rule
above structurally true rather than merely intended.

### Reading a mark drawn by a hand

A `<`, `>`, `^` or `v` is the only thing that creates an opening, so failing
to read one is expensive twice over: the section the user said opens does not
open, **and** the mark is built as two bars that cut the design up. One in
six shaky chevrons used to be lost this way, because the reader demanded a
fit of exactly three vertices and a hand's wobble is read as four to eight.

`OpeningSymbolReader` now judges the shape rather than counting corners. The
point of the chevron is the corner furthest from the line joining the two
ends; the rest have to lie along the two arms, within
`armWanderFraction` of each arm's own length. A zigzag, a staircase, a frame
corner and a straight line all still fail, because their corners do not lie
along two straight runs — and each of those must be built exactly as it was
drawn.

`test/domain/deterministic_test.dart` sweeps sixty shaky chevrons through it
and requires all sixty, and sweeps forty through the whole reading and
requires forty openings.

### An opening is a container

A mark makes the region it is in an opening, and the opening is a container,
not a leaf of a flat list. A line drawn inside that region afterwards is
drawn *in the opening*: it divides the opening, not the design. It does not
make a new top-level section, and it does not cut the opening short.

```
Window
├── Section          fixed light
└── Section          the opening
    ├── Opening      hinged left, >
    ├── Divider      inside
    ├── Divider      inside
    └── Section ×3   the panes of the opening
```

`DividerElement` and `SectionElement` each carry a `parentId`. Null means the
element divides the design; set means it lives inside that section.
`Design.topLevelDividers` and `Design.topLevelSections` are what the main
subdivision is built from, and `SectionBuilder.rebuild` then subdivides each
parent again with its own children. Because the hierarchy is in the model,
the CAD drawing, the component tree and the solid all follow it without
being told to, and an opening carries its contents whenever it moves or is
resized — `SectionBuilder` applies the same transform to everything inside a
section whose outline changed, so nothing is left behind on the frame.

### Only the marked section opens

**The smallest region holding the mark is the opening, and nothing larger
ever is.** The user's own lines cut the daylight into regions; the mark falls
in one of them; that one opens and every other stays fixed. A window is not
an opening because a mark was drawn somewhere inside it.

```
┌──────────────────────────┐
│          FIXED           │
├──────────────┬───────────┤
│      >       │   FIXED   │
│   OPENING    │           │
└──────────────┴───────────┘
```

Three sections, two bars, one opening — the lower left. Not the lower band,
not the window.

This follows from one flat rule in the reading: **every line the user draws
divides the design.** Nothing in the interpreter works out that a line was
"really" inside something and quietly absorbs it. There used to be two such
rules — one by where a line sat, one by when it was drawn — and between them
an opening could take in the mullion beside it, or the whole window. Both are
gone. `sectionFor` then picks the section the mark's middle is in, and because
top-level sections tile the daylight without overlapping, that is by
construction the smallest region holding the mark.

Being wrong the cautious way is cheap: the user marks another section. Being
wrong the other way is a leaf that swings, in a window somebody has to build.

A line becomes an opening's only when the user says so — with the line tools
inside an opening, or with the **Divides** control on the bar's own panel.
Both set `parentId` outright. `SectionBuilder` then keeps that hierarchy
through every edit, and where a section is *replaced* rather than kept — a
line moving into it leaves one bigger section where two were — the opening
follows its own mark to whatever now covers that ground, and a bar inside
follows to whatever now holds it. Neither is lost because an id changed.

`test/domain/only_the_marked_section_opens_test.dart` holds this, in every
stroke order. `test/domain/opening_containment_test.dart` holds what happens
once a line *is* the opening's.

### The opening's own boundary, and what it owns

The opening is a region of the design, and the leaf filling it is a thing of
its own with an edge of its own. `lib/domain/model/opening_leaf.dart` is the
one description of it: the outside is the section's outline and nothing
wider, the inside is that inset by the leaf's own profile. The elevation and
the solid both read it, so the leaf the user sees and the leaf that swings
are the same leaf, and the glass in both stops at the sash rather than at the
edge of the region.

Ownership runs one way only:

```
Window
├── Frame              ── not the opening's
├── Fixed section      ── not the opening's
├── Opening            ── its leaf, its bars, its panes, its hardware
└── Fixed section      ── not the opening's
```

The frame is not a section, so it cannot be a child of one. A fixed section
is a main division, so its `parentId` is null. Only what is inside the
opening is the opening's.

**Belonging is a fact about where a thing is, not a label that can be pinned
on it.** `DesignEdits.liesInside` is the single test: a bar must lie within
the section — inside it, or along its edge — and both `containersFor` (what
the **Divides** control offers) and `setDividerParent` (what the design will
accept) go through it, so the offered set and the accepted set are the same
by construction. The edge counts because a bar the user wants to put *into* a
section is usually bounding it at the moment they ask. What the test refuses
is a bar somewhere else entirely: one in the fixed light across the design is
nothing to do with this opening, and saying that it is would have the opening
drag it across the window the next time it moved.

`test/domain/opening_owns_only_its_own_test.dart` holds this.

### Drawing inside an opening

An opening is not a single pane waiting to be filled. It can hold its own
bars, and its own glass and panels, and the user builds that *afterwards* —
they do not have to know the inside of a sash before they mark it.

Pick any part of an opening — the mark, the section, a bar inside it, a pane,
a hinge, the handle — and `DesignEdits.openingAround` answers with the
opening, which is what puts the line tools on the drawing. A click with one
of them calls `DesignEdits.addLineInside`, which lays the line right across
that section, at the place the user put it, with `parentId` already set. The
bar is the opening's from the moment it exists: it divides the opening rather
than ending it, and travels with it ever afterwards.

Laying the line across is the tool's job, not a decision about the design.
A tool named *horizontal line* draws a horizontal line, so there is no wobble
to clean and no angle to keep; and a bar that stopped half way across would
divide nothing, so `spanAcross` finds the two points where the line the user
drew meets the boundary of the section they drew it in. A line that does not
cross that section at all adds nothing, rather than landing somewhere near.

Nothing divides an opening on its own. An opening with no line drawn in it
stays one pane, however tall, and `_addFixedInfill` fills it. Two lines make
three panes; a horizontal and a vertical make four. The count is the user's.

A section's edge can only be made by a bar at its own level, which is why
`_dividerAlong` takes the level to look at: the panes of an opening are made
by the bars drawn inside that opening, and a transom on the design outside it
is not what one of them ends at, even where the two lie along the same line.
A pane with no bar beside it *is* the opening, so the question passes outward
to whatever bounds that.

### An opening's own coordinates

An opening is a parent, so where things are inside it is naturally said in
its terms: a bar 40 cm down the sash is 40 cm down the sash wherever on the
sheet the sash is. `DesignEdits.within` converts a point, and
`moveDividerWithin` places a bar that way; the inspector shows every internal
part's place from the opening's own corner. This is the same fact as the
carry-transform in `SectionBuilder` seen from the other side — the children
are the parent's, so they are measured from it and they move with it.

`test/domain/inside_the_opening_test.dart` holds all of this, including the
whole worked example: a 200 × 160 cm window, a 40 cm opening marked `<` down
the left, and a line drawn inside it making glass over panel.

### Every figure on the drawing is the geometry it measures

A dimension is not a caption. Each figure on the technical drawing names a
real piece of the design, so tapping it opens it for typing, and typing over
it moves that piece. There is no way anywhere to change a number without
changing what gets built — a figure that did not match the design would be a
lie about it.

`lib/app/canvas/dimension_handles.dart` holds where every figure is written.
Both the painter and the pointer read it, so what is drawn and what can be
tapped are the same thing by construction rather than by two pieces of
arithmetic happening to agree. `ChainRun` carries `of` and `sectionId` — what
kind of thing it measures and which one — which is what lets a typed figure
find its geometry.

What each one does when typed over:

| Figure | What moves |
| --- | --- |
| Overall width or height | The frame, scaled in proportion |
| A daylight or section width | The bar beside the pane, or the jamb when there is no bar |
| A daylight or section height | The bar above or below it, or the sill |
| A measurement the user drew | The whole design, scaled to make it true |

Nothing else moves. Changing one pane's height moves the transom, so the pane
above it changes too — that is arithmetic, not redesign — and the overall size
stays exactly as it was.

### Centimetres out, millimetres in

The geometry is millimetres throughout the domain, because that is what a
workshop cuts to. The user never sees one. Every figure shown and every figure
typed is centimetres, and `lib/domain/dimensions/units.dart` is the one place
the two meet.

Figures are written to the tenth of a centimetre — the millimetre — which is
the finest distinction worth quoting on a drawing. That is how many digits are
printed, not what the design is: a value typed as 72.25 cm is exactly 722.5 mm
in the geometry, and 96.4 cm is never written as 96.

If you add a field, it takes and gives millimetres and lets `_NumberField` do
the conversion. A field that is not a length — an angle — passes
`isLength: false`.

### An opening's hinges and handle

Marking a section is saying it opens, which is saying it hangs on something
and is worked by something. So an opening carries hinges and a handle, and a
section nobody marked carries neither, however door-shaped it is.

They are worked out from the opening every time rather than placed once and
remembered — `lib/domain/hardware/opening_hardware.dart`, re-run by
`SectionBuilder.rebuild` and after every opening edit. That is what makes them
the opening's: change the direction and the hinges change sides, resize the
leaf and they stay on its edges, swing it and they swing with it. Nothing can
drift, because there is nothing to drift.

Their positions are `parentId` on `HardwareElement` plus four figures on
`OpeningElement` — `hingeCount`, `hingeFromStartMm`, `hingeFromEndMm`,
`handleAlongMm` — each null until the user says, so the defaults are never
recorded as decisions the user made. The defaults themselves are stated rules,
not magic numbers, and each is written down beside the constant.

Hardware the user placed themselves has no `parentId`, is never regenerated,
and stays exactly where they put it.

`test/domain/editable_dimensions_test.dart` and
`test/app/editable_figures_test.dart` hold all of this.

## Working on this repository

- Tolerances live in `lib/domain/geometry/tolerances.dart`, each with the
  reason it is the size it is. Most are relative rather than absolute: a
  three-pixel wobble is twenty-three millimetres on a three-metre sheet.
- `flutter analyze` must be clean. The analysis options are strict on
  purpose, and imports are sorted.
- `flutter test` must be green before anything is pushed.
- Verify visual work by building for the web and driving it in a browser.
  Looking at the thing has found bugs the tests did not: a status bar whose
  text was invisible, daylight openings half a bar too wide, a zoom that
  cancelled itself out.

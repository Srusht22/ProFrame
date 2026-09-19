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

## The absolute rules

These are the project's, kept verbatim. Nothing below overrides them, and a
change that cannot keep them true is wrong:

```
1. THE USER'S DRAWING IS THE SOURCE OF TRUTH.

2. DO NOT REDESIGN THE USER'S DRAWING.

3. DO NOT USE RANDOM IMAGES.

4. DO NOT USE RANDOM 3D MODELS.

5. DO NOT GENERATE A DIFFERENT SKETCH.

6. DO NOT TREAT EVERY LINE AS A TOP-LEVEL SECTION.

7. < OR > IDENTIFIES THE SPECIFIC USER-SELECTED OPENING REGION.

8. THE WHOLE DOOR/WINDOW IS NEVER THE OPENING.

9. A LINE INSIDE AN OPENING BELONGS TO THAT OPENING.

10. INTERNAL LINES DO NOT CREATE NEW TOP-LEVEL SECTIONS.

11. INTERNAL GEOMETRY USES THE OPENING'S LOCAL COORDINATES.

12. AN OPENING IS A PARENT CONTAINER.

13. GLASS/PANEL/DIVIDERS INSIDE THE OPENING ARE CHILDREN OF THE OPENING.

14. HANDLE AND HINGES ARE CHILDREN OF THE OPENING.

15. CAD AND 3D MUST USE THE SAME UNDERLYING GEOMETRY.

16. ALL USER MEASUREMENTS ARE ENTERED IN CM.

17. DO NOT ASK THE USER QUESTIONS THAT CAN BE RESOLVED BY EDITING.

18. ONLY ASK WHEN THE DRAWING IS TRULY AMBIGUOUS.

19. DO NOT FIX GEOMETRY WITH RANDOM OFFSETS.

20. FIX THE UNDERLYING GEOMETRY OWNERSHIP AND COORDINATE SYSTEM.
```

Where each one lives:

| Rule | Where it is kept true |
| --- | --- |
| 1, 2, 5 | `test/domain/the_rule_test.dart`, `editing_isolation_test.dart` |
| 3, 4 | `test/no_stock_content_test.dart` — the repository is scanned for assets and model files |
| 6, 10 | `SectionBuilder.rebuild`; `the_opening_survives_its_own_lines_test.dart` |
| 7, 8 | `SketchInterpreter.sectionFor`, `Hierarchy.settleOpenings`; `the_mark_picks_one_face_test.dart` |
| 9, 12, 13 | `parentId` = the opening's id; `geometry_has_parents_test.dart`, `lines_inside_an_opening_test.dart` |
| 11 | `LocalSpace`; `the_openings_own_coordinates_test.dart` |
| 14 | `OpeningHardware`; `the_openings_hardware_test.dart` |
| 15 | `DesignTree`; `the_solid_is_the_cad_hierarchy_test.dart`, `one_design_two_views_test.dart` |
| 16 | `Units`, and a repository scan in `internal_sections_test.dart` |
| 17, 18 | The two questions listed under **Build it, do not ask about it** |
| 19, 20 | `LocalSpace`, `OpeningLeaf`, `Polygon.sameIn` — and the history in this file |

**Rule 9 has one honest limit**, set out in full under *Only the marked
section opens*: a line the user draws **on the sheet** divides the design
until they say it is an opening's, because no rule for deciding that
automatically survives contact with `only_the_marked_section_opens_test.dart`.
A line drawn *inside* an opening with the opening's own tools is the
opening's from the moment it exists, which is rule 9 where it can be kept.

## The rules about openings that never change

These govern every part of this repository that touches an opening — the
reading, the model, the drawing and the solid. Nothing else here overrides
them, and a change that cannot keep them true is wrong:

> **The `<` or `>` symbol identifies the smallest valid section/region
> containing that symbol as the opening; it does not make the entire parent
> door/window an opening. Geometry outside that section remains outside the
> opening.**

> **Opening geometry must be hierarchical: the door/window is the parent, the
> opening is one child region, and only geometry geometrically contained
> within that opening is a child of the opening.**

And, standing over all of it:

> **NEVER DETERMINE AN OPENING FROM THE WHOLE DRAWING.**
>
> **THE ROOT DOOR/WINDOW IS NEVER ITSELF THE OPENING.**
>
> **AN OPENING IS A SPECIFIC CLOSED FACE/REGION SELECTED BY THE USER'S `<` OR
> `>` SYMBOL.**
>
> **ONLY THAT FACE BECOMES OPENING = TRUE.**
>
> **ANYTHING GEOMETRICALLY INSIDE THAT FACE IS A CHILD OF THE OPENING.**
>
> **ANYTHING OUTSIDE THAT FACE REMAINS OUTSIDE THE OPENING.**
>
> **INTERNAL LINES DO NOT CHANGE THE PARENT OPENING.**
>
> **CAD AND 3D MUST RENDER THE SAME GEOMETRY TREE.**
>
> **DO NOT PATCH POSITIONS WITH FIXED OFFSETS.
> FIX THE GEOMETRY RELATIONSHIP.**

Everything below about openings is those sentences worked out in detail, and
each clause has a place in the code where it is either true by construction
or held by a test:

| The rule | Where it lives |
| --- | --- |
| Never from the whole drawing; the root is never the opening | `SketchInterpreter.sectionFor`, and `Hierarchy.settleOpenings` — an opening naming the frame cannot be written |
| A specific closed face, selected by the mark | `sectionFor`: containment only, smallest face, no fallback to nearest, first, largest or a bounding box |
| Only that face opens | `OpeningElement.sectionId`, one per section, enforced in `Design.copyWith` |
| Inside it is a child of it | `Polygon.holds`, the one test all three ways in go through |
| Outside it stays outside | Every line the user draws divides the design until they say otherwise |
| Internal lines do not change the parent opening | `SectionBuilder.rebuild`: a bar inside a section subdivides that section and never replaces it — `test/domain/internal_lines_keep_the_opening_test.dart` |
| CAD and 3D render the same tree | `DesignTree`, walked by `CadPainter`, `MeshBuilder` and `ComponentTree` |
| No fixed offsets — fix the relationship | `LocalSpace`, `OpeningLeaf`, `Polygon.sameIn` |

**That last one is a rule about how to fix things, not about openings.** When
a part is in the wrong place, the answer is never a constant added somewhere
to move it back. A number chosen to make one drawing look right is wrong for
every other drawing, and it hides the relationship that was actually broken.
Every position in this repository is derived from a relationship — a child
from its parent, a pane from the bars around it, a leaf from the section it
fills, hardware from the leaf it hangs on — and when one is wrong, that
relationship is what gets fixed. The history of this file is a list of times
that mattered: a midpoint standing in for containment, a shear standing in
for a rotation, a proportional carry standing in for a section's own
coordinates.

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
- **No face of the design holds any part of the mark.** Drawn right off the
  design, or entirely on top of the bars, it is in no closed region, so
  there is nothing to open.

A mark that merely strays near a bar or a jamb is *not* one of these. It
opens the face its middle is in, and where its middle lands on a bar, the
face holding most of the rest of it — its point and its two ends. That is
still containment, of the mark's own points, and it holds however shakily the
mark was drawn. `_placeSymbols` and `sectionFor` in the interpreter are where
this lives.

Neither question is ever asked twice. `WorkspaceState.settledQuestions`
remembers what has been answered or waved away for that design, and a
re-reading does not put it again.

If you are about to add a question, add an editing control instead. If the
geometry genuinely cannot be built, the question goes in the list above and
the reason goes beside it.

## The acceptance test

`test/acceptance_test.dart` is the scenario the work is measured against,
and it is done the way the user does it — the window is *drawn*, the mark is
*drawn*, and the design is read from the sheet:

```
A 200 × 160 cm window. A 40 cm light down the left, marked `<`.
A horizontal line 40 cm down that opening. Glass above, panel below.

Window
├── Main/fix geometry
└── Left opening  <
     ├── Glass
     ├── Internal divider
     ├── Panel
     ├── Hinges
     └── Handle
```

It requires that hierarchy, and refuses the two that would mean the model
had not understood: `Window → Opening, Horizontal bar, Panel` (everything
flat, the bar and the panel divisions of the window) and `Window = Opening`
(the root itself opening). Then it takes the same design through the
drawing, the solid, a swing and a save and reload, and requires the same
hierarchy back from each.

**Two of the figures in the brief are not the figures a workshop cuts**, and
the test says so where it asserts them:

- The opening is **148 cm**, not 160. 160 cm is the window over its frame;
  the light inside it is the daylight, with the frame's own section taken
  off head and sill.
- The panes are not 40 and 120. The divider is real material and the glass
  stops at its faces, so glass, divider and panel together are the opening
  exactly — which 40 + 120 in a 148 cm light would not be.

Both are the same rule: every figure is something somebody could cut to.

## The final test

`test/final_visual_and_3d_test.dart` is the second scenario the work is
measured against, and it is about a bar that has somewhere else it could
wrongly go:

```
┌───────────────────────────────┐
│             FIXED             │
├───────┬───────────────────────┤
│ GLASS │                       │
├───────┤          FIXED        │
│ PANEL │                       │
└───────┴───────────────────────┘
```

A band across the head, and beneath it a narrow left column and a wide right
one. The left column is the opening. It is drawn the way the user draws it —
outline, transom, mullion and a `>`, all strokes on the sheet — and then one
line is drawn *inside the opening*, which is where the whole thing is
decided. That line must not appear above the opening, must not become a bar
of the window, and must not move outside the opening into the light beside
it.

Each of those is asserted on the body the painter actually lays down — the
bar clipped to the leaf's daylight, exactly as `_barBody` clips it — rather
than on the centre line, because a bar is drawn with a width and it is the
width that would cross a jamb. Alongside it the drawing is rasterised, and
the same line drawn on the sheet instead of in the opening must be a
**different picture**: that is what says the renderer is not quietly
promoting it.

Then the same design as a solid — frame, two fixed lights, and an opening
holding glass, a divider, a panel, hinges and a handle — where only the
opening moves. Every other part is fingerprinted facet by facet at
`openFraction: 1` and required back byte for byte, and each of the four
parts the phase names is checked by name as well, because "nothing else
moved" is the claim and a set comparison can be true while the wrong thing
is in the set.

**One figure in it is derived rather than quoted.** The narrow light is the
daylight from the jamb to the mullion, with the mullion's own material taken
off, and the test works that out from the design. Writing the number down
would be a second opinion about where the user drew their line, and the
first time the frame profile changed the test would be asserting a drawing
nobody had made.

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
- `test/app/one_design_two_views_test.dart` — one edit reaches **both**
  views. It rasterises the drawing and writes the mesh out facet by facet,
  so each of the three propagations is checked on the thing the user
  actually sees: an opening taken from 40 cm to 50 cm, a divider moved, a
  panel made glass. It also holds the other direction — an edit that changes
  nothing changes neither view, and the same design gives the same picture
  and the same mesh.

  **That test earns its keep by catching a second geometry system.** Giving
  `CadPainter` a static that remembers the first design it is ever handed —
  the smallest possible version of CAD keeping its own geometry — fails all
  three propagations at once. Its limit is worth knowing: the CAD side of
  the part-set comparison is read from `DesignTree`, not from what reaches
  the canvas, so a painter that walked a stale *tree* while still reading
  live positions would slip past that particular assertion, though the pixel
  comparisons would still catch it wherever the structure showed.
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

### What the model will not let you say

The hierarchy is not kept true by each edit remembering to keep it true.
`lib/domain/model/hierarchy.dart` holds the rules and `Design.copyWith` — which
every edit passes through — applies them, so an impossible document cannot be
built rather than being built and then tidied up.

Four states used to be expressible, and each was a phantom: stored in the
document, listed in the component tree, saved to disk, and built by neither
view.

| Used to be storable | Now |
| --- | --- |
| An opening naming the frame | Refused. The frame is not a section, so the root can never open |
| An opening naming a section that has gone | Refused |
| Two openings on one section | The first is kept; the second could not have been made by any user action |
| A section inside itself | Put back among the main divisions, never dropped |

**A bar whose section has gone is deliberately not settled here.** That one
has a better answer than "it divides the design": `SectionBuilder` looks for
whatever now holds it and only falls back to the design when nothing does.
Clearing it in `copyWith` let a stale reference reshape the top-level
subdivision before that reconciliation ran, and took the opening it came from
with it. It *is* settled in `Design.fromJson`, because there is no rebuild
between a file and the first look at it, and a bar belonging to neither the
design nor a real section would be drawn by nothing.

**An opening stores no geometry of its own.** `Design.outlineOf` gives its
place and size — its section's outline, and nothing wider — and
`Design.contentsOf` gives what it holds. An opening carrying its own x, y,
width and height would be a second copy of the section's shape, and the two
would part company the first time a bar beside it moved.

`test/domain/the_opening_is_one_region_test.dart` holds this, on a window of
four main divisions with the middle lower light marked and divided into glass
over panel.

### One tree, walked by both views

The hierarchy is in the model — `parentId` on every divider and every
section — and `lib/domain/model/design_tree.dart` is that hierarchy read
once:

```
Door/Window
├── Frame                the outline, and nothing else's parent
├── Bars                 the lines that divide the design
└── Sections             the main divisions, in reading order
     ├── Opening         where the user marked one
     ├── Bars            the lines drawn inside that section
     └── Sections        the panes those lines make, each a branch again
```

`CadPainter`, `MeshBuilder` and the `ComponentTree` all walk it. None of
them sweeps the flat lists working out what is inside what, because that is
how views come to disagree: one decides a bar belongs to a sash and another
does not, and the drawing, the model and the list of parts stop being the
same design. There is one answer, and it is the model's own.

The component tree is the one place the user actually *sees* the hierarchy
named, so it walking its own version of it was the worst place for a second
opinion: it ordered its sections by the order they happened to sit in the
list while the drawing ordered them by reading order, and the two agreed by
luck rather than by construction.

**`DesignTree` holds no geometry.** Every part is named by its id and looked
up in the design when it is drawn, so nothing in it can drift from the
design or outlive an edit to it. The frame is not a section, so it is not a
branch: nothing is inside it and it is inside nothing. And a window is never
an opening — an opening is one branch of this tree, never the root.

Two things follow from drawing to the tree rather than to a list:

- **A bar is drawn as the member it is.** A bar that divides the design is a
  mullion or a transom and carries `Cad.bar`; a bar drawn inside a section is
  a glazing bar within it and carries the lighter `Cad.glazingBar`. That is
  what a drawing does with a smaller member, and it lets a reader see which
  bars are a sash's without being told.
- **A figure measures the level it belongs to.** The chains down the outside
  of the drawing measure the main divisions, so `DimensionChains.isRectilinear`
  asks about the design's own bars. A diagonal glazing bar inside one sash
  makes that sash unbandable; it says nothing about the lights either side of
  it and must not strike the figures off a drawing that is otherwise square.

`test/app/cad_uses_the_tree_test.dart` holds this, on a window with an upper
light, a fixed lower right, and a marked lower left divided into glass over
panel: every part of the design is in the tree exactly once, nothing outside
the opening is in it, and the solid builds exactly what the tree says is
there. `test/app/cad_renders_the_tree_test.dart` holds the drawing's side of
it: painting reads the design and changes nothing in it, the same design
paints the same picture every time, a figure is written for every pane the
tree calls a leaf and for no branch, the leaf is drawn on the marked section
and nowhere else, and the tree survives a save and a reload unchanged.

`test/app/cad_draws_the_hierarchy_test.dart` holds the same thing against
the picture itself rather than against the model behind it. It rasterises
the drawing and compares the pixels, which is the only way to tell a
renderer that honours the hierarchy from one that happens to agree with it:
the same design draws the same picture to the byte; a window marked on the
left and the same window marked on the right are **different** pictures, so
the drawing cannot be normalising the opening to a side of its own choosing;
and one internal line and two internal lines are different pictures, so it
cannot be drawing a fixed idea of what a sash contains.

Alongside that it holds what the pixels cannot say on their own: the drawn
body of a bar inside an opening, clipped exactly as `_barBody` clips it,
lies within that opening's outline at every corner; no fixed section is
given a bar of the opening's, and no bar of the design is trimmed as though
it were inside one; and a bar appears at one level of the tree only, so
nothing is drawn twice or at the wrong weight.

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

**Containment decides it, and nothing else does.** `sectionFor` asks one
question — which closed faces is this point inside — and answers with the
smallest of them. It never falls back to the nearest face, the first face,
the largest face, the outer rectangle or a bounding box, because each of
those can name a face the mark is not in, which is the whole failure the rule
exists to prevent. Where no face holds any part of the mark there is no
opening and the one question above is put.

*Smallest*, not first. The main divisions tile the daylight without
overlapping, so ordinarily exactly one face holds the point. Two hold it when
the point lands on the line between them, because a point on a boundary is in
the shapes either side of it; taking the smaller is then a real choice, and it
is the one that cannot make an opening too big.

The faces are the ones the **design's own lines** make. The panes inside an
opening are not among them: a pane is a region of the opening, not of the
design, and it exists only because that section is already an opening and the
user drew inside it. Offering them would have a reading reinterpret its own
output — the mark that opened a 40 × 160 cm sash would, next time the sheet
was read, be found inside the 40 × 40 cm pane of glass it had caused, and the
sash the user built would shrink to it. That is not a hypothetical: it is what
`test/domain/internal_design_inside_the_opening_test.dart` caught when the
candidates were briefly widened to every section.

`test/domain/the_mark_picks_one_face_test.dart` holds this on the drawing
above, in the drawing's own terms: three faces, the mark in the lower left,
and each forbidden fallback tried and refused.

**Whether a line drawn on the sheet is inside an opening cannot be decided
by the application, and this has now been established twice.** The two tests
that have been tried both fail on the same drawing:

- *By geometry.* A mullion below a `>` in a door and a rail below a `>` in a
  door are the same picture turned on its side. Both lie wholly within the
  region the mark is in once you take them away, so any containment test
  takes both or neither.
- *By stroke order* — the line drawn after the mark is the opening's. This is
  the more tempting of the two and it is wrong: `only_the_marked_section_
  opens_test.dart` reads the same window in five stroke orders and requires
  the same design from each. Draw the mark before the transom and the
  opening helps itself to the transom, then the mullion, then the window.

So the sheet's lines divide the design, and the user says which are an
opening's. That is not the application declining to read; it is the one
thing the drawing genuinely does not say. **If you are about to try a third
rule, run `only_the_marked_section_opens_test.dart` first — it fails in
seconds and it is right.**

A line becomes an opening's only when the user says so — with the line tools
inside an opening, or with the **Divides** control on the bar's own panel.
Both set `parentId` outright. `SectionBuilder` then keeps that hierarchy
through every edit, and where a section is *replaced* rather than kept — a
line moving into it leaves one bigger section where two were — the opening
follows its own mark to whatever now covers that ground, and a bar inside
follows to whatever now holds it. Neither is lost because an id changed.

**Why a section's outline changed decides whether its contents travel.**
A section moves or is resized when the bars *around* it move, and then what
is drawn in it moves with it — that is what keeps an opening and its
contents one thing. But a section also changes size when one of its own
bounds stops being a bound: the user puts the line that was cutting it short
inside it instead, and it grows back over the ground that line had taken.
Nothing has moved then. The section is the same section, every line in it is
where the user drew it, and the new one is where they drew it too.

Carrying in that case moved lines the user never touched. The first line put
into a sash ended at the sill with the opening showing no panes at all,
which made the **Divides** control useless for the very case it exists for;
and putting a second line in dragged the first one 32 cm down the sash.
`_carryContents` now carries nothing when any child lies outside the
section's old outline, because a child can only be out there by having just
joined. Geometry, not a flag — nothing has to remember what the last edit
was.

**A bar that has joined a section is laid right across it.** This is what
`addLineInside` already did for a line made with the line tools, and
`setDividerParent` now does it too, through the same `spanAcross`. A line
drawn by hand stops a few millimetres short of a jamb or runs a little past
it; while it was dividing the design that did not matter, because it was
cutting the section from the outside. Inside, six millimetres is the
difference between glass over panel and one undivided pane with a line lying
across it — the face simply does not close. The direction and the position
stay the user's; only the two ends move.

`test/domain/lines_inside_an_opening_test.dart` holds this and the rest of
this section's rules, on the phase's own figures: a 40 cm opening standing
100 cm across a window, a line 40 cm down *that opening*, and the structure
opening → divider, upper pane, lower pane.

**An internal line divides an opening's contents; it never replaces the
opening.** One line or five, across or upright, the opening stays one
opening, keeps its id and its section, and its boundary does not move — and
the design's own top-level sections and bars are exactly what they were.
`test/domain/the_opening_survives_its_own_lines_test.dart` fingerprints both
shapes and requires them back unchanged after every line, by both routes in.

`test/domain/only_the_marked_section_opens_test.dart` holds this, in every
stroke order. `test/domain/opening_containment_test.dart` holds what happens
once a line *is* the opening's.

**The mark decides after an edit too, not only when the sheet is read.**
`sectionFor` answers "which region holds this mark" for a drawing;
`SectionBuilder._openingsKept` answers it again every time the design is
rebuilt, and it has to be the same answer or an opening means one thing on
the sheet and another after a bar is moved.

So an opening stays on its section only while that section still holds its
mark. It used to stay whenever the section *id* survived, and an id survives
more than it should: `_carryIdentityForward` matches the nth region to the
nth region when a bar moves, which is right for a colour, a material or a
name — the user set those on that pane — and wrong for an opening, which is
not a label on a region but the region the mark is in. Dragging a mullion
straight past the mark left the opening behind on the 21 cm sliver the bar
had cut off, with the mark outside it: a leaf that swings where nobody
marked one. Now the opening follows its mark to whatever region holds it, at
its own level — the panes of a sash are a different set of regions from the
main divisions — and the smallest one wins, as in `sectionFor`.

**A rescale is not a re-cut, so the mark travels with the design.**
`resizeFrame` scales the frame, the bars and the hardware, and it now scales
every opening's `markAt` with them. Leaving it behind was the one place a
position was stored rather than derived and nothing kept it true: a mark put
in the middle of a light drifted up towards the head as the window was made
taller, and the next edit that moved a bar found it outside its own opening
and either moved that opening somewhere the user had not marked or lost it
altogether. Every other edit leaves the mark where the user drew it, because
every other edit moves the lines *around* it — which is what the user sees on
their own sheet.

An opening made with the **Opens** control rather than by drawing has no
mark, so there is nothing to follow: it stays on its section for as long as
that section exists.

`test/domain/the_mark_keeps_its_region_test.dart` holds this on the drawing
above: three regions and one opening, never the root and never the largest
unless the mark is in it, and then a bar dragged past the mark, a bar
deleted, the design rescaled and the opening resized — each leaving exactly
one opening, on a region that holds its mark.

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
on it.** `Polygon.holds` is the single test, in the geometry layer where
everything can reach it: a line lies within a shape when *every part of it*
is inside, or near enough to an edge to count as along the boundary. Sampled
along the line, never at its middle alone — a bar whose middle happens to
fall inside while its ends reach away out of the section is not that
section's, and the midpoint is exactly the condition this phase forbids.

Three ways in, one test:

| Way in | Goes through |
| --- | --- |
| The **Divides** control offers a section | `DesignEdits.containersFor` |
| The design accepts that choice | `DesignEdits.setDividerParent` |
| A bar is re-homed when its section is replaced | `SectionBuilder._intoWhateverHoldsIt` |

All three call `holds`, so a bar cannot arrive inside a section by a route
the user could not have taken, and what the user is offered is exactly what
the design will accept. The edge counts because a bar the user wants to put
*into* a section is usually bounding it at the moment they ask. What is
refused is a bar somewhere else entirely: one in the fixed light across the
design is nothing to do with this opening, and saying that it is would have
the opening drag it across the window the next time it moved.

A bar whose section is replaced and which now lies in no section goes back to
dividing the design. It is never dropped: losing a line the user drew,
because a section stopped existing, is worse than any question of what it now
divides.

Dimensions, notes and arrows have no parent and are never carried by a
section: `_carryContents` transforms declared children and nothing else.

`test/domain/opening_owns_only_its_own_test.dart` and
`test/domain/inside_or_outside_the_opening_test.dart` hold this — the second
is this phase's own test, with three lines outside an opening and two in it.

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

**The sheet's tools, working on the opening.** Picking any part of an
opening puts up its own strip: Select, Horizontal line, Vertical line,
Straight line, Rectangle, Polyline, Dimension, Arrow, Note and Erase — the
same rail the sheet has, because editing inside a sash is drawing, not a
different kind of activity. `InsideTool` says what each one makes and how it
is worked: a click, a drag, or a click for each corner.

**The opening the user is in is what says where the geometry belongs**, so
nothing is asked after a line is drawn. That is the whole point of the mode:
a question after every line would be the application refusing to read the
one thing the user has already told it by selecting the opening first.
`InsideTool.builds` marks the tools whose output is part of the opening — the
lines, the rectangle, the polyline — and their bars carry `parentId` from the
moment they exist. A figure, an arrow and a note describe the design rather
than build it, and keep having no parent, because `_carryContents`
transforms declared children and nothing else.

**A shape is the lines that enclose it.** `DesignEdits.addShapeInside` is one
operation for all of them: a rectangle is four bars, a polyline is a chain,
and each leg is trimmed to the section it was drawn in rather than laid
across it. Laid across, a rectangle would be a cross — every leg running the
full width or height of the sash and enclosing nothing. A single line on its
own is the exception and goes to `addDividerInside`, because one bar that
stops half way divides nothing; a shape's legs close on each other instead.
A leg with nothing left inside is dropped rather than placed somewhere near.

`test/domain/drawing_inside_an_opening_test.dart` holds this for every tool:
what it makes names the opening, appears in the tree as the opening's, makes
no top-level line and no top-level section, and leaves the opening one
opening with its boundary where it was.

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

### Glass over panel, and reading the sheet again

The internal design is the user's too. Each pane an internal bar makes is a
section like any other, so it takes a material and a colour on its own panel:

```
Opening
├── Section     glass
├── Divider     the line drawn inside
└── Section     panel
```

and the elevation and the solid both follow, because there is one model.

**A reading reads the drawing, and the internal design is not on the
drawing.** A line placed with the line tools inside an opening has no stroke
of its own: it was made in the design, not on the sheet. Reading the sheet
again would find nothing to make it from, and the opening would come back one
undivided pane with the glass and the panel gone with it — a line the user
drew, removed because they drew something else somewhere else.

So the reading keeps every bar whose `fromStrokeId` is null and reads the
strokes alongside them. A bar that *did* come from a stroke still lasts
exactly as long as that stroke does, because rubbing a line out is how the
user deletes it.

`test/domain/internal_design_inside_the_opening_test.dart` holds this, with
the phase's own example: a 40 cm opening, a line 40 cm down it, glass above
and a panel below, a transom then drawn in the fixed light beside it, and the
sheet read again — the new line divides the design, and the opening comes
back with its own line, its two panes and their materials.

**The glass and the panel stop at the sash.** A pane of a divided opening is
a region of the design like any other, but what fills it is bounded by the
leaf it is in, not by the edge of the region — the sash is real material and
the glass stops at its inner face, as it does on the bench.
`OpeningLeaf.fillOf` is the one answer to where, so the elevation and the
solid cannot give two, and `Polygon.clippedTo` is how: the pane's own corners
where they are inside the sash, the crossings where they are not, and the bar
the user drew still bounding it on the side the bar is on. The bars inside a
sash are trimmed the same way, which is what a glazing bar does — it runs
between the sash's faces rather than over them.

**An opening moved to another section takes its design with it.** A sash the
user divided into glass over panel is that sash wherever it is put, so
`moveOpeningToSection` carries its bars and its panes across, each landing at
the same place in the new section as it had in the old.
`Polygon.sameIn` is that place, and it is the same rule `SectionBuilder`
applies when an opening is resized, so there is one answer to where the
inside of a section goes rather than two. The section it leaves is one
undivided fixed light again, and nothing of the opening's is left behind in
it — a division in a fixed light nobody drew one in would be a lie about the
drawing, and handing back an undivided opening would make the user draw it
all again.

An opening cannot be moved into one of its own panes: a pane is part of the
leaf, so that would make the leaf its own parent. `DesignEdits.placesFor` is
what the **Position** control offers and `moveOpeningToSection` applies the
same test, so the offered set and the accepted set are the same by
construction — the same arrangement as `containersFor` and
`setDividerParent`.

### Only the opening moves

The solid has the drawing's structure because both are built from
`DesignTree`, and when an opening opens **only that branch moves**. The frame
stays, the fixed sections stay, the bars that divide the design stay, and
everything inside the opening — its glass, its panel, its bars, its hinges
and its handle — goes with it. `openFraction` is a way of looking at the
model, not a property of the design: swinging a leaf changes no part of the
document.

**A leaf turns; it is not squashed towards its hinge.** `_swingFor` rotates
about the hinge line, depth and all. Rotating the distance from the hinge
while leaving the depth where it was made the leaf thinner the further it
opened, and at ninety degrees flattened it into the plane of the frame with
its thickness pointing the way it had swung. Because it is a rotation, every
distance within the leaf is the same afterwards as before — which is what
makes the glass, the panel, the bars and the hardware one thing that moves
together rather than four things that happen to move similarly. It also means
the hinge stile stands its own thickness off the hinge line at ninety
degrees, as a real door does; a test that wants it exactly on the line is
describing a leaf that never turned.

**A section the user marked is a leaf wherever it sits.** `_addSection` is the
one place that decides, at every level of the tree, so a pane of a sash the
user also marked is a leaf inside a leaf: it gets its own sash, its own
hinges and handle, and it swings *within* its parent, because the parent's
movement is applied outside its own. Deciding this at the top instead left the
model showing no swing where the drawing showed one, and building none of that
opening's hardware at all.

**Picking the opening picks all of it.** An opening is one thing made of
several — its sash, the bars drawn inside it, the panes those bars make, its
hinges and its handle — so the 3D view outlines all of them, from
`Design.contentsOf` and nothing else. It used to match one facet id at a
time, so selecting the opening lit its sash ring and left its own glass and
its own panel dark inside it, which says the opposite of what the design
means. Picking one pane, or one bar, stays that one part: the whole is picked
by picking the whole.

`test/domain/only_the_opening_moves_test.dart` holds all of this, and holds it
by fingerprinting: every part outside the opening must come back byte for byte
at every angle the leaf is swung to.
`test/domain/the_solid_is_the_same_tree_test.dart` holds the solid's side of
the tree: the source and the result are the same set of parts, two fixed
sections carry no sash and the opening does, the divider is a bar and the
panes are glass and panel, every face belongs to a part of the design rather
than to a picture of one, what is inside the leaf never reaches past the leaf
as it swings, and what lights up when the opening is picked is exactly what
moves when it opens.

**The two views are held to each other, not just to the tree.**
`test/domain/the_solid_is_the_cad_hierarchy_test.dart` builds the set of
parts the drawing puts on the sheet and the set the solid builds, and
requires them equal — with one internal line, two, and five. Both walking
`DesignTree` is the reason they agree; this is the test that would notice if
one of them stopped. It also holds that every facet belongs to a part the
design actually has, so the solid cannot build something out of nothing, and
that the same design gives the same mesh facet for facet.

Then the four things the phase asks of an opening: what is inside it never
reaches past the leaf at any angle, everything inside it turns when it
turns, nothing outside it moves at all, and moving the opening to another
light or resizing it leaves its bars and its panes inside it — checked by
rebuilding the part sets after each and requiring them still equal.

**The ironmongery is the one thing inside an opening that reaches past it.**
A handle stands proud of the leaf, as a handle does. A test that asks
whether *everything* inside the opening stays within the sash is describing
a door with no handle on it; the bars and the panes are what must stay
inside.

`MeshBuilder._addLeafHardware` finds a leaf's hinges and handle through
`Design.sectionHolding` rather than comparing `parentId` to the section id
by hand. That was the last direct comparison in the solid, and it worked
only because hardware happens to be stored against the section: the day it
is not, a leaf would swing with its hinges and its handle left behind on the
frame.

### A child names the opening, not the ground it stands on

A bar drawn inside an opening, and each pane it makes, stores the **opening's**
id in `parentId` — not the id of the section the opening happens to occupy.
The two would answer the same question today and different questions tomorrow,
because they have very different lives:

| | Made by | Lives as long as |
| --- | --- | --- |
| `OpeningElement` | the user drawing a mark | the mark does |
| `SectionElement` | planar subdivision | the next edit |

`SectionBuilder` deletes and rebuilds every section on every edit. A child
anchored to one is anchored to the least stable object in the model, and when
that id changed the child was orphaned — a line the user drew inside a sash
came back dividing the whole window. Anchored to the opening, it is anchored
to the user's own decision.

That only holds if the opening's id is stable too, so **it is the mark's**:
`_openingIdFor` in the interpreter gives `opening-<the stroke's id>` and reuses
whatever is already on that stroke, rather than taking the next number from a
counter. Before that, every reading of the sheet renamed the opening.

**Both forms are understood everywhere, and only one is written.**
`Hierarchy.underOpenings` — applied by `Design.copyWith` and `Design.fromJson`,
which every edit and every load passes through — rewrites a parent naming a
section that opens into the opening on it. `Design.sectionHolding` turns either
form back into the section, and `Design.openingHolding` answers which opening a
thing is in, or null for top-level geometry. **That pair is how top-level
geometry is told from an opening's own**, and everything that used to compare
`parentId` to a section id asks one of them instead, so no caller can be
holding the other opinion. A design saved before this change still loads: it
says the same thing in the older words.

Hardware names the opening too. It was left naming the section at first,
because it is regenerated from the opening on every rebuild and so has no
identity to lose — but a child of the opening is what it *is*, and leaving
one thing in the old words meant every reader had to know both. The pieces
are rebuilt from scratch on every rebuild, so there was nothing to migrate,
and `contentsOf` still accepts either form for a design loaded from disk
before its first rebuild.

`test/domain/geometry_has_parents_test.dart` holds this: a line belongs to the
opening and not to the design, it survives a second reading of the sheet, a
save and a reload, a resize, a neighbouring bar moving and the opening being
moved to another section, and an older document naming the section loads as
meaning the same thing.

### An opening's own coordinates

An opening is a parent, so where things are inside it is naturally said in
its terms: a bar 40 cm down the sash is 40 cm down the sash wherever on the
sheet the sash is. `lib/domain/geometry/local_space.dart` is the one
description of what that means, and everything that reads or writes a
child's place goes through it — `DesignEdits.within` for a point,
`alongWithin` for the figure on a bar's panel, `moveDividerWithin` for
typing over it, and the inspector for showing it. One answer, rather than
the same arithmetic written out in four places and quietly disagreeing in
the corners. This is the same fact as the carry-transform in
`SectionBuilder` seen from the other side — the children are the parent's,
so they are measured from it and they move with it.

**Every bar has a place in its parent, at any angle.** `LocalSpace.alongIn`
measures from the parent's own top left corner, square to the bar: for a bar
across the opening that is how far down it is, for a bar up the opening how
far across, and for a diagonal the perpendicular from the corner to its line.
The two square cases used to be measured separately and the third left out
altogether, so the figure on a diagonal glazing bar's panel did nothing at
all when it was typed over. The measurement is turned to point into the
parent, so it does not change sign because the user drew the bar right to
left.

**Nothing is stored twice.** A child keeps the one set of coordinates it has,
and its place in its parent's terms is worked out from them. Storing both
would be two descriptions of one fact, and the first edit that touched one
and not the other would make the design mean two things at once. What matters
is that the figure the user typed comes back unchanged, and it does: a bar put
40 cm down an opening reads 40 cm down that opening after the opening has been
moved to a section three times the width, and after the opening has been made
wider where it stands.

`test/domain/the_openings_own_coordinates_test.dart` holds this.

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

**A bar's own figures are editable too, and both are about its middle.**
`Length` and `Angle` on a bar's panel were readouts, so a line drawn by hand
could be moved and re-homed and recoloured but never made a given length or
turned to a given angle. `DesignEdits.setDividerLength` takes the same off
each end and `setDividerAngle` turns it about the same point, so changing
the length does not slide the bar along and changing the angle does not
shift it sideways. Anything else would be the application deciding which end
of the user's line was the important one.

**Turning a bar keeps its length, so it can stop spanning.** A bar that ran
jamb to jamb, turned to 25°, needs to be `width / cos 25°` long to reach
them again — so it now stops short, and a bar that stops half way divides
nothing. The sash goes back to one pane until the user types a longer
`Length`. That is the rule already stated above, seen from a new angle, and
it is the honest answer: stretching the line to fit would be moving a line
the user did not move.

`test/domain/everything_is_editable_test.dart` walks the whole list — frame,
fixed section, opening, internal line, glass, panel, handle, hinge — and for
each figure on each panel requires the geometry to move, not the label: a
pane's height moves the bar beside it, a pane's material changes what the
solid builds for it, and an opening's direction rebuilds its hinges on the
other stile.

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

**This is enforced on the repository, not just intended.**
`test/domain/internal_sections_test.dart` scans every file under `lib/app`
and fails on any millimetre value put straight into a string without going
through `Units` — which is how one leaked out: a dimension the user had
drawn on the sheet was painted as `1600`, a bare millimetre count with no
unit on it, while every other figure on the same screen was centimetres.

### Internal sections are the opening's

A divider drawn inside an opening makes sections, and they are the
opening's:

```
Opening 40 × 160 cm, a divider 40 cm down it

┌──────────┐        Opening
│  GLASS   │        ├── Glass section   40 × 38.6 cm
├──────────┤        ├── Internal divider      2.8 cm
│  PANEL   │        └── Panel section   40 × 118.6 cm
└──────────┘
```

They are sections like any other — each takes its own material and colour on
its own panel — but they are never top-level: the window still has the main
divisions it had, and the panes are inside the opening. The component tree
says so in the one place the user reads the hierarchy: the opening *holds 2*,
with the divider and both panes under it.

**The figures are what a workshop cuts.** A divider 40 cm down a 160 cm sash
does not leave 40 and 120: it is real material 2.8 cm wide and the glass
stops at its faces, so the panes are 38.6 and 118.6, and the three together
are 160 exactly. Quoting 40 and 120 would be a drawing that does not add up.

`test/domain/internal_sections_test.dart` holds this on those figures, and
holds that the panes stay the opening's through a save and a reload and
through the opening being moved to another light.

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

**`parentId` is the opening's id.** A hinge is a child of the opening, not of
the door: it hangs on the leaf, it goes where the leaf goes and turns when it
turns, and it is not the window's business. Nothing reads that id by
comparing it to a section id any more — `Design.sectionHolding` and
`Design.openingHolding` answer for the solid, the component tree and the
inspector alike, so a piece cannot be the opening's to one of them and the
design's to another.

Hardware the user placed themselves has no `parentId`, is never regenerated,
and stays exactly where they put it. That is the whole of the distinction:
`isOpeningHardware` is `parentId != null`, so a piece either hangs on a leaf
or it is the user's own.

The component tree is where this is visible: the opening's branch holds its
hinges and its handle, and a section nobody marked holds neither, however
door-shaped it is.

`test/domain/the_openings_hardware_test.dart` holds the phase's own claims —
both kinds present and both the opening's, the parent never the frame or the
design, none on a fixed section, none at all on a design with no opening,
and the lot going with the opening when it is moved, resized or swung while
nothing else moves at all.

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

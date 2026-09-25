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

**Rule 9 holds in three ways, and the limit left is narrow.** A line drawn
with an opening's own tools is the opening's from the moment it exists. A
line drawn **on the sheet inside a region the design already opens** joins
that opening when the sheet is next read. And **Divides** says it by hand,
for anything else — and now outlasts every later reading. What is left is a
first reading, where nothing is open yet and every line divides the design,
because deciding otherwise there is the inference
`only_the_marked_section_opens_test.dart` refuses. See *Only the marked
section opens*.

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
something inconvenient. There are exactly three, and each is asked because
the drawing does not hold the answer:

- **The outline does not close.** There is no shape, so there is no frame,
  and joining the ends would move lines the user drew. The lines are kept as
  geometry and the user is asked to finish it — or, where one side is all
  that is missing, whether they meant it (see *A side left open*).
- **No face of the design holds any part of the mark.** Drawn right off the
  design, or entirely on top of the bars, it is in no closed region, so
  there is nothing to open.
- **What a new opening is — a door or a window.** A `<` or a `>` says the
  section opens. It does not say which of the two it is, and no amount of
  looking at the sheet will: a leaf is a door or a window because of what
  the user is building, not because of its proportions. It was read off the
  height before, which is the application deciding from a shape, and it put
  a door's lever on a tall window sash. See *An opening's hinges and
  handle*.

The third one is the only one that is asked about something the application
*has* built, and it is still not a questionnaire between the drawing and the
design: the opening is made first, exactly as the mark says, and the design
stands whether the question is answered or waved away. It has an editing
control beside it, as rule 17 requires — the same control answers it later
and changes it afterwards.

It is also raised as an **alert over the work**, with the drawing behind
it blurred back — `OpeningKindAlert`, and see *One design, many openings,
each its own kind*. The questions about the sheet stay in the panel below
the drawing, except one: an outline with a single side missing, which is
`OutlineGapAlert` over the work, because until it is answered there is no
frame and so nothing to draw, open or build. Being an alert
does not make it a gate: *Not now* puts it away and nothing was waiting on
it. In a design begun as holding both kinds it is the only way a leaf gets
a handle at all, which is why it is worth interrupting for.

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

## The mixed test

`test/mixed_door_and_window_test.dart` is the third scenario the work is
measured against, and it is the one where both kinds of leaf are in the same
frame:

```
Design
├── Fixed area
├── Window opening  <
│    ├── Glass
│    ├── Internal divider
│    ├── Panel
│    └── Window handle, and the hinges it hangs on
├── Fixed area
└── Door opening  >
     ├── Glass
     ├── Internal divider
     ├── Panel
     ├── Door handle
     ├── Lock
     └── Hinges
```

Drawn the way the user draws it — an outline, three mullions and two marks,
all strokes on the sheet — then each leaf said to be a door or a window and
each divided into glass over panel with a line drawn inside it.

**A window sash hangs on hinges too.** The brief's list shows them only
under the door, but a leaf that opens hangs on something, and a window
carrying none would be a drawing nobody could build. They are the leaf's,
exactly as the door's are, and the test says so rather than quietly
matching the list.

What it holds, beyond the shape of the tree:

- **A door behaves as a door and a window as a window.** The door carries a
  lever and a lock, the window an espagnolette and no lock, and the two
  handles are built as different objects — the test compares how many faces
  each has rather than trusting their names.
- **Only the designated leaves open.** Everything outside them is
  fingerprinted facet by facet at four angles and required back unchanged;
  everything inside each of them is required to have moved.
- **What is inside a leaf never reaches past it**, at every angle — the bars
  and the panes, not the ironmongery, which stands proud as a handle does.
- **Nothing is randomly added.** Every facet belongs to a part the design
  actually has, and the part counts are exactly what the drawing and the
  edits made: five bars, eight sections, no loose ironmongery.
- **The drawing and the solid are the same design**: everything the solid
  builds is on the sheet, and every pane of every leaf is in both.
- Then a save, a reload, a second reading, and an edit to one leaf with the
  other required back exactly as it was.

## The final acceptance test

`test/final_acceptance_test.dart` is the whole system measured at once, and
its seventeen tests are the brief's seventeen claims under the brief's own
numbers, so the file can be read against it line by line:

```
Design
├── Fixed light
├── Opening 1  >   a window   glass over panel
├── Opening 2  >   a door     glass over panel
├── Fixed light
└── Opening 3  >   a window   its own design: four panes
```

Five lights and three marks, all strokes on the sheet; the reading asks
what each new leaf is; the answers are given; and only then is the inside
of each one drawn. Two of the claims are about that order and nothing else
— the question is asked when the opening is made, and never again — so the
test puts it to a re-reading, a switch between the views, a line drawn
inside a leaf and the design opened afresh tomorrow.

**The fixed light between the door and the third leaf is there on purpose.**
A bar shared by two leaves bounds both, so moving it moves both — rightly —
and "moving one opening does not move the others" would then fail for a
reason that has nothing to do with ownership. With a light between them,
the bar the test drags is the third leaf's alone.

**Three of the claims cannot be settled by a name.** That the handles are
geometry rather than pictures is held on the facets — every one of them
belonging to a part the design actually has, and the ironmongery running to
hundreds of them; that a door's lever and a window's fastener are different
objects is held on how many faces each is built from, not on what they are
called; and that the two views are one design is held by building the set
of parts the drawing lays down and the set the solid builds and requiring
them equal.

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

**`lib/` holds those three layers and `main.dart`, and nothing else**, and
`test/the_source_tree_is_the_architecture_test.dart` says so on the working
copy rather than on the code. The application used to have a localisation
layer under `lib/core/localization/`, half hand-written and half generated by
`flutter gen-l10n`. Rebuilding took the layer out, but git removes only what
git tracks and generated files were never tracked: they stayed on disk, in a
folder nothing references, importing packages the pubspec no longer has. The
editor then reported a dozen errors in a project whose own `flutter analyze`
was clean — and there was nothing to find in the code, because the fault was
not in the code. The test names the folder and says to delete it, so the next
person loses a minute instead of a morning.

Sections come from planar subdivision of the user's own lines: the lines are
cut at their crossings, joined into a graph, and the faces of that graph are
the sections. Nothing is laid out to a template, which is what makes the rule
above structurally true rather than merely intended.

**A bar is cut in as its two faces, not as its centre line**, because a bar
is real material with a width and the glass stops at its face. So the faces
that come back include the bars' own bodies, and `SectionBuilder._subdivide`
has to tell those from the daylight. **A face is a bar's own material when
the face *is* the bar** — when what it shares with that body is most of it.
It used to ask whether the face's *middle* fell inside a body, which is the
midpoint standing in for containment yet again, and it failed exactly where
a midpoint always does: a bar hanging from nothing leaves the daylight in
one piece with a slot down the middle of it, and the centroid of that
U-shaped piece is in the slot. The whole daylight was thrown away as though
it were the bar, so a door with a line drawn in the lower half came back
with **no sections at all** — no leaf, no opening, nothing to draw and
nothing to build — while the same door with the line in the upper half came
back correctly.

*Most of it*, and not all of it, because a bar's own face is not always
exactly the bar: a diagonal whose end is trimmed by the frame comes back
with the little triangle of daylight beyond its end joined on. There is
nothing in between to be uncertain about — a bar's face is all but a sliver
of the bar, and a daylight face shares a boundary with it and nothing more.
`test/domain/a_line_that_divides_nothing_test.dart` holds this on every line
that encloses nothing: hanging from one end, touching nothing at all, drawn
past the sill, drawn past both jambs. None of them makes a section, and none
of them takes the sections that are there with it. It holds the same lines
drawn rather than constructed — through `addDivider`, which is the route the
user takes and where this was first seen, a short line dropped in the middle
of a door taking the whole design with it — and requires each one back with
both its ends where they were put.

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

### An end drawn onto a line stays on it

**An end that touches a line on the sheet touches it in the design**, and
straightening is not allowed to break that. The outline is straightened leg
by leg with the fitter's corner tolerance — a kink of a few centimetres in a
metre-long jamb is a hand's wobble, and taking it out is cleaning — but the
straight leg can then lie a hand's width from where the user actually drew
it. A transom drawn to *their* jamb stops short of the straightened one and
divides nothing on that side.

That is what happened on a real drawing: a jamb upright above the transom
and leaning out below it, a small upper-left light marked `<`, and the
window came back as the whole left column from head to sill, because the
light above the transom and the light below it ran together. A few
millimetres decided it — a third of hand-wobbled copies of that drawing
read wrong — which is the sign of a relationship being lost rather than a
tolerance being a little off.

`_ontoWhatTheyWereDrawnOn` asks the **ink** rather than the fit. An end
within a weld of another stroke's own samples was drawn onto it, and is
carried along its own line to where that line meets the leg the stroke
became — along its own line, so the angle it was drawn at is kept; never
further than that stroke's straightening was allowed to move it, so this can
only undo the fitter's own displacement; and only when the fit really did
move the line away. A line drawn to stop part way is nowhere near the ink of
anything and is left exactly where it ends.

The limit is a weld, stated rather than hidden: an end further than that
from the ink was not drawn onto the line by the same measure the rest of the
reading uses. `test/domain/a_line_drawn_to_the_frame_reaches_it_test.dart`
holds the traced drawing, a hundred and twenty hand-wobbled copies of it,
the transom started either side of the jamb, the angle kept, and a line that
genuinely stops short staying short.

### Pause to straighten

Drawing with the pen, the user rests it — still down — for a second, and the
line just drawn is straightened where it lies. Keep moving, or lift sooner,
and the ink is exactly what the hand put down. Once a single line has
snapped, moving on swings its far end, squared near the axes as the reading
squares a line.

**What snaps is the reading, drawn back onto the sheet, and nothing more.**
`StrokeFitter.straightRuns` is `StrokeFitter.fit` — the same corners the
design is built from — so what the user sees straighten is exactly what gets
built. The wobble along each run comes out, every corner stays at the angle
it was drawn, both ends stay where the pen put them, and a stroke too short
or too scribbled to be a line is left alone rather than turned into one. A
straightened stroke is laid down as ink along its runs, by `samplesAlong`,
because the eraser finds a stroke by its samples.

It is the user asking, which is what makes it cleaning rather than
redesigning: nothing is straightened that was not paused on. The pause is
the user's own figure, a second; the rest radius is a few screen pixels,
because a still hand trembles by pixels whatever the zoom.
`test/domain/pause_to_straighten_test.dart` holds the rule and
`test/app/pause_and_take_it_back_test.dart` holds the gesture on the real
app.

### A note is written on the sheet

A note is part of the drawing, so it is the drawing's size: zoomed out, it
shrinks with everything else and stays at the point it was put.
It used to have a floor of eleven pixels in the drawing and a fixed size in
the technical drawing, so a design zoomed down to a postage stamp had its
note sprawling over it. `ViewTransform.letteringFor` is the one rule both
painters read, with no floor — far enough out, a note is too small to read,
as every other line on the sheet is.
`test/app/a_note_is_written_on_the_sheet_test.dart` holds it on the pixels
of both views.

### Nothing overflows

A render error laid over the design is the worst thing the screen can show,
and the 3D view's bar of depth, profile and **Open** used to be a `Row`
that overflowed by 121 pixels once the list of parts narrowed it. It wraps
now, as the CAD status bar does. `test/app/nothing_overflows_test.dart`
opens every view at laptop widths with the parts list open and an opening
picked, and fails on any overflow at all.

### The workspace fits the screen it is on

The user's screenshot at 440 × 956: the bar of views striped with an
overflow and most of the controls off the edge. The workspace is laid out
by `WorkspaceLayout.of` the width it is actually given — a `LayoutBuilder`,
not `MediaQuery`, so a phone-sized browser window on a laptop is a phone:

| | Under 600 | 600 – 900 | Wider |
| --- | --- | --- | --- |
| Tools | the navigation bar along the bottom, scrolling | the same, spread out | the same, spread out |
| Views | Draw / CAD / 3D sharing the width | full names | full names |
| Read again, Parts, Details | icons | a word and icons | words |
| What is picked | `_PickedBar` under the drawing, **Edit** opens a drawer | the same | the panel beside it |

**Two navigation bars, one design.** The user asked for a bottom
navigation bar with an active tab indicator for the tools, and a top one
for Draw, CAD and 3D. `ToolBar` (`tool_bar.dart`) is the bottom one on
every screen — each tool a thumb's width at least and at most
`ToolBar.widest`, so it scrolls on a narrow phone and spreads on a laptop
— and `ViewTabs` is the top one. Each marks what is active with **one
indicator that moves**: a pill behind it and a short bar on the edge of
the navigation bar beside it (the top edge of the tools, the foot of the
views), both gliding there with a slight overshoot. Off the drawing the
tools' indicator stands on **Select**, because picking parts is what a
tap does on the technical drawing and the model.

The drawing always gets the room; everything else moves round it. A tab's
width is set outright rather than animated, because an animated width
passes through its old value as the screen changes and pushes the other
tabs off the bar for a moment.
`test/app/it_fits_a_phone_and_a_tablet_test.dart` walks every view, picked
and with the drawer open, at three phone and three tablet sizes, and fails
on any flex that is overflowing — all of them, not only the first error.

Answering what an opening is leaves nothing at the bottom of the screen:
the answer is visible on the drawing and under **Opening types** in the
design's own panel, which is where it is changed. The notice that repeated
it was noise and is not to come back.

### The launch

The app opens on the workshop's mark, once, and then the designs —
`lib/app/screens/launch_screen.dart`. One emblem, three things the workshop
makes and fits in one frame: a hinged door down the left, a four-pane window
above on the right and a sliding panel below it. The frame draws itself in,
the three come into it, then each shows how it works — the door turns on its
hinge (`LaunchMotion.doorLeaf`: the hinge edge never moves, the free edge
comes round in perspective), the window's sash tilts in at the top about its
bottom edge and shuts again before its glass takes one pass of light
(`LaunchMotion.windowSash`), and the sliding panel runs along its track and
only along it.

**The name is the workshop's own and is never altered**:

```
کارگەی وەستا سۆران شارباژێڕی
```

It is `brandName`, exactly as given, and it is set as a composed mark rather
than one flat line — the user's own ask, *I don't want it in a straight
line, it looks very simple*:

```
        ── کارگەی ──          small, gold, between two fine rules
        وەستا سۆران           large, in a Ruqaa hand: the signature
           ──◆──              a flourish drawing out from the middle
         شارباژێڕی            light, beneath it
```

`brandLines` breaks it only where it already breaks — whole words, in their
own order, so joined with spaces the lines are `brandName` exactly — and a
test says so. The user did not like it set in one geometric Kufi, so the
master's name is now written in **Aref Ruqaa** (`brandDisplayFamily`) — the
everyday calligraphic hand of the region, the way a craftsman signs — and
the lines either side are set plainly in **Vazirmatn** (`brandFontFamily`),
so the signature is the one flourish. Nothing is letter-spaced, because
spacing the letters of a joined script pulls them apart, and nothing is
split inside a word. Both came from Google's own Arabic subsets, converted
to TTF, and were chosen from a score of candidates on one test — most
Arabic faces lack ە, ۆ, ێ or ڕ — which `test/app/the_launch_test.dart`
keeps: it reads each file's character map and requires a glyph for every
letter of the name, so a font change cannot quietly turn them into boxes.

**It moves in, and it goes.** The first word drops in as its rules draw out;
the master's name rises into focus a word at a time, right word first as it
is read (`brandMainWords`, `LaunchTiming.mainWords`), and settles; a
flourish draws out under it and the last line comes up beneath; one band
of light passes across the name. Then it disappears — the user's ask — a
line at a time from the top, each lifting and blurring away, while the mark
recedes behind it (`LaunchTiming.leaveLines`, `leaveMark`), so the start
screen comes up out of an empty field rather than cutting across the name.
Nothing leaves before everything has arrived, and the test holds that
order, each word in turn, and the whole name gone by the end.

**`LaunchScreen.duration` is the one figure for its length** — four seconds
— and every part is a share of it in `LaunchTiming`, so changing it changes
the pace of all of it together. It replaces itself with the designs
when it is done, so nothing navigates back to it and no rebuild starts it
again. A device asking for less motion gets the finished mark and the name
faded in and out over `reducedDuration`, with nothing moving or blurring,
and then the designs; its clock is
`AnimationBehavior.preserve`, because left to the controller that request
squeezes the whole thing to a flicker. It is drawn in the app's own colours
and nothing loops, so `pumpAndSettle` runs straight through it — which is
why every app test that opens the app still passes unchanged.

### The designs, before door or window

A workshop draws for hundreds of people, so the app does not open on *door
or window*. It opens on **Designs** (`designs_screen.dart`): every design
kept, the most recently edited first, a search, and **New Design**. The
user's words: create a new design, or open an existing one.

```
Designs  →  New Design  →  who it is for, what it is called  →  Continue
                                                                    ↓
          ←───────── back ─────────  the workspace  ←  Choose your design
```

- **A card is the design itself, drawn.** `DesignPreview` draws a read
  design with the same `CadPainter` as the technical drawing — figures,
  grid and handles left off — and a design not read yet as its own strokes.
  Nothing on the screen is a picture of doors in general
  (`no_stock_content_test.dart` still holds), and a design with nothing
  drawn says *Nothing drawn yet*. Each card carries who it is for, its name,
  its kind, its size where it has a frame, when it was last edited and its
  number (`shortIdOf`: the moment it was made, to the millisecond, in eight
  letters and figures — the web's clock stops at the millisecond, so the
  last six digits of an id are always `000` there).
- **Who a design is for is `Design.customer`.** Metadata, nothing to do
  with the geometry, written to the file only when there is one, so every
  design saved before it still loads. `designMatches` finds a design by
  customer, name, id or number.
- **New Design asks two things and nothing else**, both optional, then
  goes into **Choose your design** (`StartScreen`, given the two answers). Choosing keeps the design at
  once, so it is in the list from the moment it exists, and goes into the
  workspace with the designs underneath it — back is to the list, not
  through the steps that began it.
- **Opening a design is `openDesign` on exactly what was saved** — nothing
  read again, nothing rebuilt — and the test compares the two as JSON.
- **An edit brings a design to the top, by being kept.** The workspace
  keeps the design without being asked once it has stood still for
  `WorkspaceScreen.keepAfter`, and again when it is left, through
  `WorkspaceController.keep`, which swallows a failure to store: keeping is
  never a reason for the work to stop. Only a change to the design counts —
  looking at one, picking a part or swinging a leaf leaves it where it is
  in the list. `Design.copyWith` stamps `updatedAt` on every edit, and the
  store sorts by it.

A phone gets a list of cards a thumb works down, the picture beside the
words; anything wider a grid, every picture the same height.
`test/app/the_designs_screen_test.dart` holds all of it, and
`test/app/new_design.dart` is how every other app test now gets from the
designs to the choice of door or window.

### Choose your design

After the new design's form, one question: what the product is.
`StartScreen` puts **Door** and **Window** as the two large main choices —
side by side where there is room, one above the other on a phone, each
most of the width and a thumb's target — and **Door & window** and
**Sliding** as smaller cards under *More types*. The user was asked whether
to drop those two, since the brief named only door and window, and said
*I want all of them*: a sliding design cannot be begun any other way,
because a design's kind is fixed once it is started.

A card is chosen by tapping it and stays plainly chosen — the brand's green
edge, a tint, a tick, and *Door selected* in the bar at the foot — and a
second tap on another moves the choice rather than adding to it. **Start
drawing**, in that bar and so always in reach, is off until something is
chosen; it begins the design with the kind, the customer and the name,
keeps it, and goes into the existing drawing with the designs underneath.
Nothing else is asked.

**The kind is where the design starts, not a fence round it**, and the
screen says so: every opening can still be said to be a door or a window
of its own (`OpeningElement.kind`), beside fixed areas in the same frame.
Opening a saved design never comes here — `the designs screen` goes
straight to `openDesign`.

Each card is drawn by a pen as it arrives — the outline, the bars, then
the mark in gold — and again when it is chosen or the pointer comes onto
it; `_PenDrawing` is the one set of drawings, and the sliding one is the
user's first reference. Painted from lines, never a picture. Every movement
finishes, so `pumpAndSettle` settles and a device asking for less motion
sees it drawn. `test/app/choose_your_design_test.dart` holds all of it, and
`chooseDesign` in `test/app/new_design.dart` is how every other app test
gets from the choice into the drawing.

### A sliding design

Sliding is a fourth thing to begin from, beside a door, a window and both,
and like *both* it is a fact about the assembly: `DesignKind.sliding`. The
drawing says the rest. The panels are the lights the user drew; a `<` or a
`>` in one says that panel slides, **the way the chevron points** — its
point is the edge that moves, as on every mark, and on a sliding panel that
edge leads. A panel with no mark stays where it is. So the two kinds in the
user's photographs are two drawings and not two templates: one panel marked
beside a fixed light is a single slider, left or right; two marked are a
pair that both slide. `SketchInterpreter._said` is the whole of the
difference, and the same sheet begun as a door is hinged exactly as before.

**A sliding panel hangs on no hinge and is pulled, not turned.** It carries
one piece, `HardwareKind.pull`, on the stile it **closes with** — away from
the way it slides, where it meets the jamb or its partner when shut. That is
where the photographs have it, and a pull on the leading stile would run
into the panel it slides behind. `OpeningHardware.forOpening` puts it there
by `handleAt` with the leading edge standing where a hinged leaf's hinges
would, so it is half way up like every handle and the user's own figure
moves it. Its leaf follows a door unless they say otherwise, so its pull is
on both faces.

**In the solid every panel stands in the frame, on a track.** `_Tracks`
in `mesh_builder.dart`: the frame's depth holds tracks, the fixed panels —
each a sash of its own, as on a real sliding door — share the outermost, and
each sliding panel stands on the first track behind that where nothing is in
its way. A slider beside a fixed light runs behind it; two sliders that pass
each other are on two tracks; the two middle panels of a four-panel door
that part to either side share one, because they never meet. Opening a
slider is a translation along its own track and nothing else
(`MeshBuilder._slideFor`) — its own width, stopping at the jamb where that is
nearer — and nothing else moves.

**The line between two panels is where they meet, not a post.** Each panel
reaches to the middle of it, so it is the two panels' own stiles, one on
each track. A post there would stand in the very track the slider runs
along, which is what the first version got wrong: it kept the post and
stepped the slider out of the back of the frame to get past it, which is
not how any sliding door works and which the user said was wrong. The line
stays the user's, on the drawing and in the design.

**The user's two references are two drawings.** They described two videos:
a two-panel patio door whose left panel slides right, uncovering the
passage on the left, with a long pull on that panel's left stile; and a
four-panel entrance whose middle two leaves part to either side over the
fixed outer ones. The first is `>` in the left panel; the second is `<` and
`>` in the middle two. Nothing else is needed to build either, and a panel
clears **its own light** — its closing edge comes to rest where that light
ends, its meeting stile still reaching half the line it met at.

**In a sliding design the user draws arrows: `<-` and `->`.** Their words:
*`<-` goes to the left side and `->` goes to the right side.* So:

- **The shaft is part of the mark.** `SketchInterpreter._shaftOf` takes a
  short straight stroke behind a chevron's point — along the way it points,
  starting within the mark's own arm's reach of the point and running back
  from it, no longer than a few of its arms — as that mark's shaft, and it
  is never built as a bar. Every figure is the mark's own, so a rail the
  mark happens to sit on, which runs far beyond it, is never taken for one.
  Only in a sliding design: a door or a window reads its sheet exactly as
  before.
- **Two marks in one light are two equal panels.** `<-  ->` side by side
  in one light is a pair parting in the middle, and the user said what the
  symbol means: *it splits the opening part into two equal parts and opens
  it.* So `_meetingsOf` divides the light equally — the daylight either side
  of the meeting line the same, three marks three equal panels — by what
  the symbol says and not by where the hand put each arrow. This is the one
  place a division is made equal, and it is because the user's own notation
  says so; nothing else in this file is licensed by it. The meeting line is
  read from the marks at every reading, named after them, and goes when
  either is rubbed out. Each panel then opens by its own mark.

`test/domain/arrows_mean_sliding_panels_test.dart` holds the user's own
drawing, traced from their screenshot.

**The pull is a long bar**, `OpeningHardware.pullOfLeafHeight` of the leaf,
because a whole hand draws a heavy panel along by it; `pullLengthOf` is the
one figure the solid and both drawings read.

**What the references also showed is fitted when the user says, never
before.** Both are switches on a sliding panel's own settings, off until
turned on, carried across every reading and saved:

- **Pleated screen** (`OpeningElement.pleatedScreen`,
  `HardwareKind.screen`). A cassette at the jamb the panel closes against —
  as wide as a sash stile, hidden behind the shut panel's stile, and so on
  the inside face like a hinge — and a screen that fans out of it across
  exactly the passage the panel uncovers, its free edge following the
  panel. It runs on a track of its own behind every panel. It pleats: each
  face of each fold is as long as its track is deep and stays that size as
  the screen gathers or spreads, so it folds rather than stretches.
- **Automatic, by sensor** (`OpeningElement.automatic`,
  `HardwareKind.sensor`). One sensor for the entrance, on the outside face
  of the head, centred over all the automatic leaves together — for a
  centre-opening pair, over the line they meet at.

Both are `HardwareKind.staysOnFrame`: the opening's, but fixed to the frame,
so the solid builds them apart from the leaf and they do not move with it.
`OpeningHardware.footprintOf` is where each stands, read by the solid and
both drawings.

**Play** beside the **Open** slider runs the leaves open, holds them, and
closes them again — once. It is the slider moved for the user, a way of
looking, and it changes nothing.

`test/domain/a_sliding_design_test.dart` holds all of it, with both
references drawn stroke by stroke.

### A side left open

A door drawn as a head and two jambs with nothing across its foot is how a
door frame is very often built — with no sill — and it is also how an
outline looks before it is finished. The drawing cannot say which, so the
user is asked, in their words: *the design is not closed — do you want it
this way, or are you going to change it?*

- **Keep it open** builds it exactly as drawn. `FrameElement.openEdges`
  names the side with no member; `innerOutline` is not inset there, so the
  daylight — and a door leaf — runs right out to the floor; there is no
  sill in `frameMembers`; and both drawings draw `FrameElement.lines`
  rather than two closed outlines, because a closed outline has a line
  along the open side, which is a member nobody drew. The solid builds the
  cut end of each jamb and nothing across the gap.
- **Close it** puts a member across, straight between the two ends drawn.
- **I will change it** changes nothing; the drawing is theirs to finish.

The answer is `Design.outlineGap`, saved with the design, so the same sheet
read again is built the same way and the question is never put twice.
Nothing is added to the sketch either way.

**One side missing is found by the shape it would close.** `_gapIn` takes
the loose ends — ends touching no other line — and tries a line across each
pair; the pair closing the **largest** shape is the side left off, because
that is the outline the user drew. A shape can close and still not be it:
a transom near the head closes the strip above it, with the jambs hanging on
below, and that door came back as the strip alone. So the gap is also the
answer when the shape it closes is bigger than the one already closed by
more than `Tol.openSideFraction` — which a jamb drawn a hand's width past a
sill never is. `test/domain/a_side_left_open_test.dart` holds the door both
ways and both of those near misses, and
`test/app/the_design_is_not_closed_test.dart` holds the alert and each of
its three answers on the real app.

### How the alerts and the tools move

Both alerts over the work come and go through one widget, `AlertLayer`, so
they cannot drift apart. Arriving (`AlertLayer.arriving`, about half a
second) the work behind blurs back and dims over a moment, the card rises
and settles with a slight overshoot, its icon pops into its badge
(`AlertBadge`), and its parts follow one another in (`AlertStep`) — the
question, then the choices. Leaving (`AlertLayer.leaving`) is quicker, and
the card on its way out takes no second answer. The next of several
questions plays its arrival again, so three read as three. The buttons on
them (`AlertPressable`) lift under the pointer and give when pressed; the
tools along the bottom bounce once when chosen;
the panel of questions under the drawing opens up from its foot.

The bars move the same way, by `BarMotion` in `workspace_bars.dart`. The
tools along the bottom (`ToolBar`) and the views across the top
(`ViewTabs`) each have **one** active indicator that glides to what is
chosen, settling with a slight overshoot, rather than nine that switch on
and off — so every tool takes the same room. When the workspace opens, the title, the top icons and the
tools arrive one after another (`BarArrival`). The top icons (`BarIcon`)
take a halo under the pointer, squeeze when pressed, fade when there is
nothing to undo, and turn as their icon changes; save becomes a tick for a
moment (`SaveIcon`).

**Every movement finishes.** Nothing loops, so the screen is still while it
is read and `pumpAndSettle` settles; and a device asking for less motion
gets each alert and each highlight already in place.
`test/app/the_alerts_move_test.dart` and `test/app/the_bars_move_test.dart`
hold all of it.

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

**A line the user drew their mark straight *through* is inside what the mark
opens.** A door with a rail across it and a `>` drawn over the whole leaf is
one leaf with a rail in it; reading it as two lights with only the lower one
opening is not the drawing. Nothing is worked out here — the user drew one
mark through the other, and where the two touch on the sheet is the whole of
the test. `_barsTheMarkRunsThrough` finds them, and each is then given to the
opening by the same `setDividerParent` the **Divides** control calls, so
nothing arrives inside a section that the user could not have put there by
hand.

**Those lines are stood aside before the region is chosen, and that is the
order the whole thing turns on.** A line the mark runs through is inside
what the mark opens, so it is not one of the *edges* of it, and a reading
that picks the region first has already used it as one. A door cut into
three by a rail and an upright, with a `>` drawn over the lot, then opened
whichever quarter the mark's middle happened to land in — and the rail could
not be absorbed afterwards either, by the reading or by the user, because
`setDividerParent` asks whether the bar lies within the section and a rail
running the width of a door lies within neither half of the door it has just
made. There was no order to do it in, because the first one could not go in.
Worse, *which* quarter it was depended on where the user had drawn their
upright, so the same mark on the same door meant two different things.

So `_placeSymbols` reads the bars the mark runs through, rebuilds the design
without them, and asks `sectionFor` of *that* — the region the mark is in
once the lines it was drawn across are not cutting it up. Then they go back
in one at a time by the ordinary route, each one offered the region the last
one left. A line the design will not take goes back to dividing it, as it
was: a line the user drew is never lost.
`test/domain/the_mark_means_the_same_wherever_the_line_is_test.dart` holds
the door both ways round — the upright above the rail and below it — and
requires one leaf, both lines inside it and three panes from each.

**Through, not into**, and that is the difference between this and a hand
straying over a mullion. `the_mark_picks_one_face_test.dart` holds a `>`
whose point pokes six millimetres past a mullion and stops: that mark is in
the light it was drawn in, and the mullion is nothing to do with it. So the
arm that crosses a bar has to **get across whatever it went into** rather
than stopping out in the middle of it — its end nearer the far side of that
light than the bar it came in over. `spanAcross` says where the far side is
along the arm's own line, so both distances are the drawing's own and there
is no chosen size in it at all: an arm crosses a light whether that light is
a hand's width or three metres.

*Nearer, rather than near enough.* The measure was a weld tolerance at
first — reach the far side, give or take a hand's width — and a weld is a
couple of centimetres, which is the wrong scale entirely for where a
chevron's point comes to rest. A `>` drawn across a door stops a hand short
of the stile, not a weld short of it, so that rule read a mark as having
strayed over an upright it plainly crossed, and whether it had crossed it
depended on how big the light beyond happened to be — which is to say, on
where the user's other lines were. Two earlier shapes were wrong in the
other directions: requiring the arm to leave the region altogether was too
strict and left ordinary drawings cut into lights, and measuring the arm
against the bar's own thickness was too loose. The six-millimetre mark
caught every one of them. `test/domain/the_mark_drawn_through_a_line_test.dart` holds the door,
and holds the two marks that must leave the rail alone: one that stops inside
the far half, and one drawn clear of the rail altogether.

**Which end of the arm is the one past the bar is the whole of it, and
getting that wrong made every mark "through".** The test above measures from
the arm's far end, so it has to *have* one. When neither end was strictly
beyond the bar the code fell back to the **apex** — a point on the near
side, the mark's own middle end of the arm — and then measured a line
running the wrong way across the light. Every distance came out favourable
and the bar was taken every time.

That is not a rare shape. **A chevron drawn to fill its light ends on the
bar bounding that light**, which is how anybody draws one. A window with a
full-height mullion, a transom across one side and a `>` in each of the two
lights the transom made came back as **one** opening with the transom
swallowed into it: two leaves marked, one leaf built, and one question asked
where there should have been two — so the user could not say that the upper
light was a window and the lower one a door, which was the whole of what
they had drawn.

An arm that comes to rest *on* a bar has not got past it, and then neither
of its ends is the far one, so that arm went through nothing.
`_barsTheMarkRunsThrough` says so outright now, and the side test is a real
perpendicular distance — the bar's *unit* normal — rather than a cross
product that grows with how long the bar happens to be, so the tolerance it
is compared against is a length like every other in this repository.
`test/domain/two_marks_two_leaves_test.dart` holds the drawing, with the
tails stopping short of the line, on it, and past it, and holds that a mark
genuinely drawn across the transom still takes it.

**A line drawn on the sheet inside a region the design *already* opens joins
that opening.** This is the one automatic case, and *already* is the whole
of what makes it safe rather than a third go at the two rules above. Both of
those ask a reading to work out, from the lines in front of it, a region
that depends on the answer — which is why a mullion and a rail come out the
same, and why stroke order helps itself to the window. This asks nothing of
the kind. The opening was marked in an earlier reading, drawn on the screen,
and looked at; the user then drew inside it. The region is read from the
design as it stands **before** this reading, and it is there whether or not
this line joins it.

So on a first reading nothing is decided — there are no openings yet, every
drawn line divides the design, and
`only_the_marked_section_opens_test.dart` reads its five stroke orders
exactly as before. Only a line with its own thickness clear of the sash all
round counts, because a line along a jamb is bounding that region rather
than dividing what is inside it; `_openingAlreadyHolding` is the test, on
the section's outline inset by the bar's own width. The line is then laid
right across the sash by the same `spanAcross` the **Divides** control and
the line tools use, because a hand-drawn line stops short of a stile and
inside a sash that is the difference between two panes and one pane with a
line lying on it. `test/domain/a_line_drawn_in_the_opening_joins_it_test.dart`
holds this, and holds the four things that must *not* join: a line in the
fixed light, a line right across the window, a line along the sash's own
jamb, and any line at all on a first reading.

**A reading re-reads the drawing; it does not overturn what the user said
about it.** Every bar was rebuilt from its stroke on every reading, with a
new id and no parent, so saying a line was an opening's lasted exactly until
the sheet was read again — and then the line went back to cutting the whole
door in half and took the opening down to one side of it, with nothing in
the drawing having changed. Runs are now paired with the bars the last
reading made from them, by stroke and by order within it, so a bar keeps its
id, its parent, its width and its colour. A bar that divides the design is
still read from its stroke again, because it is a faithful copy of it; a bar
the user has put inside an opening is not, because joining it moved its ends
to span the sash, and reading them back off the stroke would undo that.
Rubbing the stroke out still takes the bar with it.
`test/domain/the_sheet_keeps_what_the_user_said_test.dart` holds both
directions.

**The same goes for how a leaf opens.** A `>` says *hinged left, inward* the
first time it is read, and the user may then make that leaf hinge right,
open outward, hang from the top or carry a knob. Those were read back off
the mark on every reading, so **Read again** put every one of them back to
what the mark first said. A mark still saying what it said is the same mark
read again, not a new instruction, so `_placeSymbols` keeps the opening's
mechanism and direction while its glyph is unchanged, and `setOpening`
carries the handle form with the kind and the figures. A mark rubbed out
and drawn afresh is a new instruction and is read as one.
`test/domain/the_direction_you_chose_stays_test.dart` holds both.

A line becomes an opening's only when the user says so — with the line tools
inside an opening, by drawing it inside an opening that is already there, or
with the **Divides** control on the bar's own panel.
All three set `parentId` outright. `SectionBuilder` then keeps that hierarchy
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

**A bar that has joined a section reaches where the user drew it**, cleaned
at the ends and nowhere else. `setDividerParent` works out the full span
with `spanAcross` as `addLineInside` does, and then `_weldedTo` decides, end
by end, whether that end is the drawing's or the hand's. The two halves are
the two rows of the table under *Where the line falls*, and they are not
symmetrical:

- **Trimming a line drawn past its corner** is cleaning, always. Outside the
  section the line is not the section's anyway, so the end comes back to the
  boundary whatever the distance.
- **Welding two ends drawn a few millimetres apart** is cleaning too, but
  only for a few millimetres — the section's own weld tolerance, which is
  relative, so it is a couple of millimetres on a small sash and twenty-odd
  on a three-metre one. Inside a section that little is the difference
  between two panes and one pane with a line lying on it, because the face
  does not close.

**A line drawn to reach only half way is neither, and it used to be
stretched.** Every joined bar was laid right across, so an upright drawn
from a rail down to the sill came back running head to sill and the sash had
four panes where the drawing showed three — a division nobody drew, which is
the one thing this repository is for not doing. The end now stays where they
put it, and what the line does or does not divide follows from where it
actually reaches. `test/domain/a_line_reaches_where_it_was_drawn_test.dart`
holds all three: the half-way upright stays half way, the overshoot is
trimmed, and the four-millimetre gap is welded.

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

### One design, many openings, each its own kind

A design holds as many openings as the user marked — that has been true for
a long time, and `Hierarchy.settleOpenings` allows one per section and any
number of sections. What each one *is* belongs to the opening too:

```
Overall design
├── Fixed section
├── Window opening
├── Fixed section
├── Door opening
└── Window opening
```

`OpeningElement.kind` is the user's answer for that leaf, and
`Design.kindOf` reads it. **Null is the whole of "nobody has said."** It is
not a door and it is not a window: `kindOf` then answers with the design's
own kind, which is the kind the user chose when they started the drawing —
so an opening that follows it is following something they said, not
something worked out for them. Writing a default into the opening would
record a decision they never made, which is why `hingeCount`,
`hingeFromStartMm` and `handleAlongMm` are null until asked for too.
`copyWith(clearKind: true)` puts a leaf back to following the design, which
is the one thing `kind: null` cannot say — the same arrangement as
`clearParent` on a divider.

**And a design can be started as holding both, which is the kind with no
default at all.** `DesignKind.both` is a third thing to begin from beside a
door and a window, for the set that has leaves of each:

```
┌──────────┬──────────┬──────────┐
│  FIXED   │    >     │    >     │
└──────────┴──────────┴──────────┘
             a door    a window
```

It is a fact about the **assembly** and never about one leaf, so it is not
among the answers to *what is this opening*: `DesignKind.leafKinds` is what
the question offers and what the opening's own panel offers, and
`setOpeningKind` refuses anything else, so `both` cannot be written onto a
leaf by any route. `DesignKind.leafDefault` is the other half — itself for
a door or a window design, and **null for this one**, because an assembly
the user says holds both says nothing about any particular leaf. So
`Design.kindOf` is nullable, and null is a real answer meaning nobody has
said.

**What is built for such a leaf is what the mark alone says.** It opens, so
it hangs on its hinges. It carries **no handle**, because which handle is
precisely the question outstanding, and a door's lever and a window's
espagnolette are different manufactured objects. Putting one of them on so
that something is there would be the application answering its own
question, and the user would find a decision they never made already built
— the exact failure *do not design the door for the user* names. The handle
appears the moment they say, by the alert or by the opening's own panel.

A door design and a window design are untouched by any of this: their
leaves follow the design as they always did, because `leafDefault` gives
them something the user did choose.

`test/app/a_design_of_both_kinds_test.dart` holds it: the third category on
*Choose your design*, a door and a window in one frame, a leaf nobody has named
carrying hinges and no handle, the handle appearing when they say, the two
older kinds still following their design, the reading of the sheet
unchanged by any of it, and a save and a reload.

**The question is put as an alert over the work, with the work blurred
back.** `OpeningKindAlert` is a layer of the workspace rather than a pushed
route, so the design underneath goes on being the design: it is blurred,
not replaced, and nothing about it is waiting. One leaf at a time, in
reading order, each naming the opening it is about, with how many are left
to say — three marks must not read as one question coming back three times.

**An answer given in a hurry is as easy to take back as it was to give.**
The design's own panel — the one showing whenever nothing is picked, in the
drawing and the model alike — lists every opening with its own Door | Window
switch under **Opening types**. It calls the same `setOpeningKind` as the
opening's own panel, so there is one way to say what a leaf is and two
places to reach it, and nothing is asked again.

There was a notice across the bottom of the work confirming each answer,
with *Change to …* on it. The user asked for it to go: it sat over the
drawing after the question had already been answered, and the switch on the
panel already says the same thing where the opening is shown. It is not to
come back.

**It is an alert and not a gate.** *Not now* puts it away, the leaf keeps
no kind, and the design is exactly as the mark made it — which is what
keeps this on the right side of rule 17: the opening is built first and
stands whether the question is answered or waved away, and the same control
on the opening's own panel says it later. `WorkspaceState` splits the two
streams for this — `openingKindQuestions` is raised as the alert and
`sheetQuestions` stays in the panel below the drawing, because everything
the reading could not settle is about the sheet rather than about one leaf.

**Which face the drawing is of is one fact about the whole assembly, and
must not be asked leaf by leaf.** You stand on one side of the wall and look
at the whole thing, so the side you are on is a fact about the thing. A
window light in a door set does not put you indoors for that one leaf.
`Design.isConcealed` reads `Design.seenFrom`, which answers once for the
design — see *Which face you are looking at*. Making it read `kindOf` of the
leaf being drawn is the obvious next move and it is wrong: the two leaves
would disagree about which way round their own wall is, and a hinge would be
behind the leaf in one and in front of it in the other.

**A door in the assembly decides it.** `seenFrom` asks whether *any* leaf is
a door, and only where none is does it fall back to the kind the user began
the drawing as. A set with a door in it is a set you walk up to, and you walk
up to a door from outside; one window light or five does not change that,
because the door is what you meet. It read `kind.seenFrom` alone before,
which put a door standing in a window assembly **indoors** — its hinges
drawn on the face you are at, which is a drawing of the wrong side of the
door. A `both` assembly comes out outside by the same question rather than by
a special case, because a set the user says holds both holds a door.

`test/domain/two_marks_two_leaves_test.dart` holds this, and
`mixed_door_and_window_test.dart` holds it on its own screen: one leaf said
to be a door, and then every hinge in the assembly is round the back — the
window sash's as much as the door's, because they are on the same wall —
while the handles stay on the face you are at, since a handle goes through
the leaf and is worked from either side.

`Face` and `DesignKind` sit in `elements.dart` with the other element enums
now that an element carries one; `design.dart` gives them again, so
importing the design still brings them.

**Each one has an identity of its own, and it is worked out rather than
stored.** Three leaves in a row all call themselves "Hinged left", which is
three identical rows in the component tree and no way to say which is which.
`Design.openingsInOrder` is the openings in the order the drawing reads them
— the sections are already in that order, so this is that order with the
fixed lights left out, and there is no second opinion about which opening is
the first. `numberOf` is its place in that order and `nameOf` is what to
call it: *Opening 1*, *Opening 2*, *Opening 3*, with the user's own mark
beside it. A number written into the document would be one more thing to
keep true and would be wrong the moment an opening was marked to the left of
it; asked afresh, it is always the position the opening actually has.

The component tree and the inspector heading read `nameOf`, because the
design is the only thing that knows whether a leaf is the first of three or
the only one. `_Row` takes a `title` for that, and falls back to the
element's own label for everything else.

```
┌─────────────────────────────────────┐
│               FIXED                 │
├───────────────┬──────────┬──────────┤
│   OPENING 1   │ OPENING 2│ OPENING 3│
└───────────────┴──────────┴──────────┘
```

`test/domain/many_openings_in_one_design_test.dart` holds that drawing, done
the way the user does it — outline, transom, two mullions and three marks,
all strokes on the sheet. Four top-level sections and three openings; the
whole design is never one of them and the frame can never be the thing that
opens; each numbered across the drawing rather than by the order they happen
to sit in a list. Then a line drawn *inside each* opening, and the lower
pane of each made a panel: every opening keeps its own line, its own two
panes and its own materials, nothing of one is in another's `contentsOf`,
and not one of them became a division of the design. Then an edit to one —
its direction changed, a second line drawn in it, the opening cancelled
altogether — with the others fingerprinted and required back unchanged. Then
the solid: every facet belongs to a part the design actually has, each
opening's own contents are built, and swinging the leaves moves the leaves
and nothing else. Then a save, a reload and a second reading of the sheet.

**What a leaf is says nothing about what is inside it.** The kind chooses
the ironmongery and nothing else:

```
Opening                       Opening
├── Glass                     ├── Glass
├── Internal divider          ├── Internal divider
├── Panel                     ├── Panel
├── Handle   (lever)          ├── Handle   (espagnolette)
├── Lock                      └── Hinges
└── Hinges
    a door                        a window
```

A line drawn inside an opening is that opening's whichever kind it is; it
never becomes a division of the design; and changing the answer from door to
window and back leaves every line where it was drawn and every pane what it
was made. The ironmongery is the only difference, and
`the_kind_does_not_touch_the_inside_test.dart` proves that the strong way —
it builds the solid for a door and for a window, takes every piece of
ironmongery out of both, and requires what is left equal facet for facet.

`test/domain/each_opening_is_its_own_kind_test.dart` holds this on the
drawing above — five lights with the 2nd, 4th and 5th marked: each opening
unasked-for until it is said, a door leaf in a window design staying a door,
saying one leaving every other alone, a leaf put back to following the
design, and the answer surviving a save, a reload and a rebuild. It also
holds that saying what an opening is moves no geometry at all.

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

**The strip flows onto another line rather than running off the edge.** Ten
tools and a caption are wider than the drawing is on any ordinary screen,
and a `Row` has no answer to that but to overflow — which put the render
error over the whole view the moment any part of an opening was picked, and
so closed off both ways of giving a line to an opening at once: these tools,
and the **Divides** control, which selects something inside an opening too.
The caption is bounded by the width there actually is, which is a
relationship and not a chosen number.
`test/app/the_inside_tools_fit_test.dart` requires every tool to be on the
strip and within it, and `test/app/divides_inside_the_opening_test.dart`
requires choosing **Divides → inside the opening** to raise nothing and to
leave the line naming the opening.

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

**Inward is into the building, and which way that is on the screen depends
on which face the drawing is of.** A window is drawn from inside, so an
inward sash swings towards the viewer; a design with a door in it is drawn
from outside, so an inward door swings *away*, into the room — the door you
walk up to and push. Every inward leaf used to swing towards the viewer,
which opened a front door out into the street. `MeshBuilder.swingsTowardViewer`
reads `Design.seenFrom`, the one answer for the assembly, and the leaf turns
about the face it swings towards — `leafFront` or `leafBack`, the face its
hinges are on — so it comes out of the frame rather than through it.
`test/domain/a_door_opens_into_the_room_test.dart` holds it.

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

**The handle goes at the middle of the edge it is on, on every leaf.**
Which edge that is comes from how the leaf is hung; how far along it is the
middle, and the user's own figure on the opening's panel overrides it
wherever they want it. `handleAt` therefore takes no kind at all, and the
top and bottom hung cases, which always used the middle, are no longer a
separate rule from the side hung one.

It went through two wrong shapes first, and they failed in opposite
directions. It was read off the leaf's height alone — a metre up unless the
leaf was too short to leave any stile above the lever — which is the
application reading what a leaf *is* off its proportions: a tall window sash
got a door's lever and a short door got a window's fastener. Then it was
read off `Design.kindOf`, which is at least the user's answer, but it made
the handle **jump on a leaf whose geometry had not moved at all**: saying
*door* about a sash slid its fastener up the stile, which is what *do not
fix geometry with random offsets* forbids seen from the other side — a
metre is a figure with nothing in the drawing behind it, right on a leaf of
one height and wrong on every other.

The middle is derived from the leaf, as every other position in this
repository is. The trade-off is stated plainly rather than hidden: on a very
tall door the middle is higher than a joiner would set a lever, and the
answer to that is the `Handle height` figure on the opening's own panel,
which is an editing control and not a question — rule 17. It is labelled
*Height from the bottom* on a side hung leaf and *From the left* on a top
or bottom hung one, because that is what it measures.

So nothing about **where** the ironmongery goes follows the kind any more.
What the kind still decides is what is *there*: a lever and an escutcheon
on a door, an espagnolette and no lock on a window.

### Ironmongery is built as ironmongery

A lever on a backplate, an espagnolette with a curved arm, an escutcheon
with a keyhole through it and a butt hinge with a knuckle are real pieces
with a shape. A flat tab standing on the leaf is a placeholder for one, not
one of them:

```
Door opening                        Window opening
├── Lever on a backplate            ├── Espagnolette handle
│     out of the leaf, and back     │     short base, boss, an arm that
│     across it towards the hinges  │     curves off the face and hangs
├── Escutcheon                      └── Hinges
│     with the keyhole bored              leaf and knuckle, on the face
│     through it                          you are standing at
└── Hinges
      on the inside face
```

**A window handle is not the door's lever made smaller.** It is a different
manufactured object: a short base on the stile rather than a plate long
enough to cover a lock case, a boss the spindle turns in, and a cast arm
that curves away from the face and *hangs down*, because that is where the
handle of a shut window sits. `test/domain/a_window_has_window_furniture_test.dart`
tells the two apart on their built shapes rather than on their names — the
window's arm reaches further down than across, the door's further across
than down, and the window's plate is the shorter of the two.

**The form is the piece's own, and the leaf's kind only chooses the
default.** `Design.kindOf` gives a door a lever and an escutcheon and a
window an espagnolette and no lock, because a window fastens and does not
lock. `MeshBuilder` then builds whatever form the piece actually carries, so
a window the user puts a lever on gets the lever and a door they put a
window handle on gets the window handle. Nothing reuses another part's
shape unless that is what was asked for.

**It is geometry, all of it.** `_ring` is a cross-section, `_sweep` takes one
along its own axis, and `_stadium` is a plate with radiused ends, because
pressed metal has no sharp corners. That is enough to build a lever that
comes *out of* the door and turns *across* it, which is the thing a flat
overlay cannot show, and it is the only way this repository is allowed to
show a handle: *Nothing in the output is a picture* is scanned for by
`test/no_stock_content_test.dart`, and a photograph of a handle would be the
same lie as a photograph of a door.

Every size is taken from the leaf, so a garden gate and a front door each get
ironmongery in proportion to themselves rather than to a number that looked
right on one drawing. **The lever points back across the leaf**, from the
stile it is on towards the stile it hangs on, because that is the way a hand
closes on it; pointing it the other way runs it off the edge of the door into
the frame, which is what the first attempt did and what looking at it caught.

**A door's handle is on both of its faces; a window's is not.** A door is
opened from the room as well as from the street, so the solid builds its
lever, knob or lock's escutcheon on the face the drawing is of and again on
the other, the same piece turned through the middle of the leaf, and both
turn with it. A window is opened from inside only, so its handle is on the
one face you are standing at. Which the leaf is comes from `Design.kindOf`,
the user's own answer, so saying a window is a door doubles its handle. A
hinge is screwed to one face of either and is never doubled. The far copy carries `Facet.part`, so the painter
orders each copy by itself: taken together, a lever in front of the leaf
and its twin behind it are neither in front of nor behind anything, and the
near one was being painted under the stile.
`test/domain/the_handle_is_on_both_faces_test.dart` holds it — from the
street and from the room.

`HardwareKind.isHandle` is how anything asks *where is this leaf's handle*.
A lever, a knob and a pull are one part of the leaf in three shapes — the
user's choice, on `OpeningElement.handleKind`, null until they say — so
choosing a knob must not make the handle vanish from everything that was
looking for `HardwareKind.handle`.

`_tube` is how a curve is built: a ring at every point along a path, each
standing square to the way the path goes there, and the wall run between
consecutive rings. A window's arm and a knob's turned ball are both that
one primitive — a lever with a bend in it is a stick, and a ball with a lid
on it is a cylinder.

### A handle is bought in a finish

A piece of ironmongery is ordered by name, not mixed to a colour, so
`HardwareColour` is the short list a joiner orders from — black, white,
silver, grey, bronze, brown — and **Custom** opens the full picker for
anything else. It is in the domain rather than in the inspector because the
solid has to build the piece in the chosen one and a test has to be able to
ask what *silver* is: one list, read by both, rather than a row of swatches
in a widget and the same numbers written out again somewhere else. Nothing
in it limits what can be built — `Finish.colour` takes any value.

`hardwareMaterials` is the other half. A handle is not made of clear glass,
and offering it would be a panel asking a question with no sensible answer.

**The colour is what the geometry is built in.** It goes on the piece's own
facets, and there is nothing to tint over because there is no picture. What
the renderer does on top is shading: a face turned away from the light is a
darker version of the same finish, which is a solid being lit rather than a
part being painted something the user did not choose.
`the_handle_is_the_colour_you_chose_test.dart` tests it that way round — it
allows a shade of the chosen colour and refuses a different hue.

**And it has to last, which is where this was broken.** The ironmongery is
worked out again from the opening on *every* rebuild, so anything the user
said about it was thrown away by the next edit: a handle set to silver went
back to stock grey the moment a bar moved. The panel appeared to work and
then quietly undid itself, which is worse than not offering the control at
all. `OpeningHardware._finishOf` carries the finish across by id — the
pieces have settled ids, so the one being replaced is found exactly, the
same arrangement as `_openingSaid` for an opening's own answers.

Only the *finish* is carried. Where a piece sits is worked out from the leaf
every time and must stay that way, or a resize would leave the handle where
the old leaf had it. So each piece keeps its own finish and hinges need not
match the handle, while every position stays derived.

`test/domain/a_door_has_door_furniture_test.dart` holds all of it: what a
door carries and a window does not, the handle real in all three directions
and standing off the face, the lever reaching back across the leaf and not
past its edge, every piece naming the opening as its parent, the lot turning
with the leaf while nothing else moves, staying on the leaf when it is
resized, and every facet belonging to a part the design actually has.

**Asked once, when the opening is made, and never again.**
`WorkspaceState.allQuestions` is the questions the reading raised plus one
for every opening with no answer on it. That second list is *worked out from
the design*, so the question appears the moment an opening exists — by a
mark or by the **Opens** control, it makes no difference — and is gone the
moment it is answered, because the answer is on the opening and the opening
is in the file. Nothing has to remember to raise it and nothing can raise it
twice: not a re-reading, not switching between the drawing and the model,
not a line drawn inside the leaf, not opening the design tomorrow.

That last one only holds because **what the user said about an opening
outlasts a re-reading**. `setOpening` builds a fresh `OpeningElement` every
time the sheet is read, and it used to build it empty, so the answer lasted
until the next reading and the question came straight back — asking them to
say again what they had already said. It now carries forward what the sheet
cannot say: the kind, and the hinge and handle figures. This is the same
rule the bars keep, and it is in `_openingSaid`, which finds the opening
being replaced by id — an opening's id is its mark's and outlives every
reading — or by section for one made with the **Opens** control, which has
no mark to be named after.

Waving the question away is not an answer to it: the opening keeps no kind
and goes on following the design, which is a kind the user did choose.
`test/app/what_is_this_opening_test.dart` holds all of it.

**Which face you are looking at, and so which side the hinges are on.** A
joiner's elevation is drawn from the side the design is met from, and that
is not the same side for the two kinds:

| | Drawn from | So its hinges are |
| --- | --- | --- |
| Door | outside — where you walk up to it | round the back, out of sight |
| Window | inside — where you stand to open it | on the face you are at |

**And a door anywhere in the assembly settles it.** The table is about a
design of one kind throughout; a set holding both is a set you walk up to a
door in, so `Design.seenFrom` answers *outside* whenever any leaf is a door
and falls back to `DesignKind.seenFrom` only where none is. It is still one
answer for the whole design — see *One design, many openings, each its own
kind* — and never one per leaf.

`DesignKind.seenFrom` says which for a design with no door leaf in it,
`HardwareKind.onTheInsideFace` says which
pieces are fixed to one face only — a butt hinge is screwed to the inside
face; a handle, a lever, a knob and a lock go through the leaf and are
worked from either side — and `Design.isConcealed` is the one answer both
views read. Two answers would be two opinions about which way round the
design is, and the hinge would be behind the leaf in one view and in front
of it in the other.

**Nothing is turned round or mirrored to achieve this.** The drawing is the
face the user drew, so the solid's near face is theirs by construction, and
a door hinged where they marked it is hinged there in both views. What the
kind decides is only what is on the *other* side. In the solid a concealed
piece is simply placed behind the leaf, so it is out of sight because of
where it is and not because the renderer declined to draw it.

**By default it is not seen, in any view.** The user's words: *when we have
a door in a design it means we see the design from outside, so we don't see
hinges by default.* The drawing they draw on leaves a concealed piece out,
and so does the technical drawing — unless its **Hidden** layer
(`CadLayers.hiddenDetail`) is switched on, when it is drawn as hidden
detail, dashed in `Cad.hidden`, because somebody still has to fit it. Off
is the default because the elevation is of the face you are standing at.

**Behind the leaf means behind the leaf's own face.** The frame's face is at
zero and the design runs back from it; the leaf stands between
`MeshBuilder.leafFront` and `MeshBuilder.leafBack`. The ironmongery was
measured as though the leaf ran *forward* from zero to the frame's depth,
so every handle floated seven centimetres in front of its door and a door's
"concealed" hinges were built into the front of the leaf — where the user
saw them. Both faces are now the leaf's own, read from one place, and a
test that asks whether a handle stands off the leaf asks of `leafFront`.

**And the renderer has to agree about what is in front.** The model is
painted far to near by each face's average distance, which is wrong exactly
where a small thing sits against a long one: a stile's face is as long as
the door, so its average is its middle, and a hinge near the foot came out
nearer than the stile it was behind. `Camera.project` settles every piece
of ironmongery by planes instead — wholly behind a face it overlaps, it is
painted before it; wholly in front, after.
`test/domain/hinges_round_the_back_test.dart` holds it on what is actually
painted last at each point of every hinge, from five angles outside and
from behind, where the same hinges must be what you see.

`test/domain/the_face_we_are_looking_at_test.dart` reads one drawing as
each kind and requires the same design from both — the same frame, the same
bars, the same hinges in the same places — with only the side of the leaf
they sit on differing, and the handle on the near face either way.
`test/app/the_drawing_is_of_one_face_test.dart` holds the drawing's side of
it on the pixels: a door and a window are different pictures, taking the
hinges off both makes them the same picture again, a door with hinges is
the same picture as a door without them — on the technical drawing and on
the sheet — and with **Hidden** switched on it is not.

**Each leaf's ironmongery is its own, and the movement tests say so.**

```
Design
├── Fixed section
├── Door opening        ── its lever, its lock, its hinges
├── Fixed section
└── Window opening      ── its handle, its hinges
```

Move the door opening and the door, its handle and its hinges move; the
window opening does not. Move the window opening and its handle moves; the
door does not. Nothing is ever attached to the design itself, so nothing is
left behind on the frame when a leaf goes somewhere.

**The two openings are given a fixed light between them on purpose.** A bar
shared by two openings bounds both, so moving it changes both regions and
both sets of ironmongery move — which is right, and would make "the other
one does not move" fail for a reason that has nothing to do with ownership.
With a light between them each opening has a bar of its own, and the claim
is about whose piece is whose.

**Held by id, not by position.** Moving an opening changes which one is
first across the drawing, so *Opening 1* is a place and not a thing:
`numberOf` renumbers, exactly as it should, and a test that looks an
opening up by its number after moving one is asking about the wrong leaf.
That is what the first run of this test did.

`test/domain/hardware_belongs_to_its_opening_test.dart` holds the whole of
it: every piece naming an opening and none naming the frame or the design,
the two sets disjoint, the fixed lights carrying none of it, both movement
tests each way round, an opening taken to another light bringing its own
and leaving nothing behind, the frame and the fixed lights never moving
whatever swings, and the parents outlasting a save, a reload, a re-reading
and one opening being cancelled.

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

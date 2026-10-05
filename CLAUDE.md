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
| 17, 18 | The questions listed under **Build it, do not ask about it** |
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
| Completing a level or upright line stopped short, to the first line it was heading for | Carrying a line past a line it reached |

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
something inconvenient. There are exactly five, and each is asked because
the drawing does not hold the answer:

- **The outline does not close.** There is no shape, so there is no frame,
  and joining the ends would move lines the user drew. The lines are kept as
  geometry and the user is asked to finish it — or, where one side is all
  that is missing, whether they meant it (see *A side left open*).
- **No face of the design holds any part of the mark.** Drawn right off the
  design, or entirely on top of the bars, it is in no closed region, so
  there is nothing to open.
- **What a new opening is — a door or a window — in a design begun as
  holding both.** A `<` or a `>` says the section opens. It does not say
  which of the two it is, and no amount of looking at the sheet will: a
  leaf is a door or a window because of what the user is building, not
  because of its proportions. It was read off the height before, which is
  the application deciding from a shape, and it put a door's lever on a
  tall window sash. See *An opening's hinges and handle*. **Only a Door &
  window design and an Angled / Asymmetrical one are asked** — the two
  categories that say nothing about any one leaf (see *An angled or
  asymmetrical design*). The user's words: *for the door and the window
  category there is no need to ask whether it is a door or a window.* A
  door design's leaves are doors and a window design's windows — they said
  so when they chose what to draw — and a sliding design's leaves follow a
  door; each leaf can still be made the other kind on its own panel.
- **The real size of every part.** A sketch has proportions and no scale,
  so a size read off it is a guess — and the user said never to write a
  guess as a number. See *Sizes are asked for, never guessed*.
- **What a door is built of — panel, glass or both — as a door or a door
  & window design starts**, and, where it is both, which of the parts the
  user drew are which. Lines say where the parts are, never what fills
  them. A window and a sliding set are not asked; they have the
  **Material** tool. See *Glass or panel*.

The third and fourth are the only ones asked about something the application
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

Five lights and three marks, all strokes on the sheet, in a design begun
as holding both — the one kind of design that is asked; the reading asks
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
    pricing/       what a design costs, read from it, by the workshop's price list
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

`test/app/cad_draws_the_opening_s_line_inside_it_test.dart` holds the same
for a line **drawn on the sheet**, stopped short inside an opening under a
band across the head: every pixel the line adds to the technical drawing,
on every layer setting, is inside the opening — none above it, none in the
band, none in the fixed light — and with the opening moved to the other
light the line is drawn there, as far down it as before. CAD positions an
opening's child from the child's own geometry, which the model keeps in the
opening's terms by carrying it whenever the opening moves or is resized; it
does not add the opening's position again, which would count it twice.

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

`GeometryNormalizer._ontoWhatTheyWereDrawnOn` asks the **ink** rather than
the fit. An end
within a weld of another stroke's own samples was drawn onto it, and is
carried along its own line to where that line meets the leg the stroke
became — along its own line, so the angle it was drawn at is kept; never
further than that stroke's straightening was allowed to move it, so this can
only undo the fitter's own displacement; and only when the fit really did
move the line away. A line drawn to stop part way is nowhere near the ink of
anything, so this leaves it alone — and the next section finishes it.

The limit is a weld, stated rather than hidden: an end further than that
from the ink was not drawn onto the line by the same measure the rest of the
reading uses. `test/domain/a_line_drawn_to_the_frame_reaches_it_test.dart`
holds the traced drawing, a hundred and twenty hand-wobbled copies of it,
the transom started either side of the jamb, the angle kept, and a line
started well short of the jamb completed to it.

### A line stopped short is completed

The user's words: *when I start drawing a straight line and stop before
reaching the boundary, complete it to that boundary — horizontal and
vertical.* A hand drawing a transom across a door lifts a finger's width
before the far jamb, and a line that stops short divides nothing: the door
came back one part with a line lying in it, which is not what they drew.

So `SketchInterpreter._completed` carries **an end that touches nothing**
along the line's own direction to the **first** line it meets — the outline,
another line on the sheet, or a bar made inside the design with its tools.
The first and never further: a line heading for a transom stops at the
transom, not the sill beyond it. **An end already touching a line**, by the
weld the rest of the reading uses, is where the user put it and does not
move — which is what keeps the old bug fixed, the upright drawn from a rail
down to the sill that came back running head to sill. Only level and
upright lines, because a line at a slope says nothing about where it was
going; only ends inside the outline; and only lines that divide the design —
a line drawn inside an opening that is already there, or started inside it,
is the opening's and is laid across its sash, never the design (see *Only
the marked section opens*).

**A line started outside an opening belongs to the surrounding design, and
is completed against the surrounding design** — the user's words: *complete
it to the boundary of that surrounding design area; do not extend it through
the opening, and do not use the opening's boundary for it.* Which lines are
an opening's is settled before any line is completed (next paragraph), and a
line of the design is completed only against the outline, the design's own
lines and the bars made in the design — never a line of an opening's. It is never run
through an opening either: a line heading for one stops at its edge, which
is where the surrounding design ends in that direction, and an end the hand
carried *into* a region the design already opens is left where it was
drawn rather than run on across it.
`test/domain/a_line_outside_the_opening_is_completed_to_the_design_test.dart`
holds the user's own test — one line inside the opening completed inside
it, one outside completed frame to frame — and the line heading for the
opening, the line level with it, and the end carried into it.

**Where the line was started decides whose it is, and that is decided
first.** The user's words: *before completing any line, determine where the
user started it — inside Opening #1 it is Opening #1's, inside the main
design and outside every opening it is the main design's; not by the nearest
line, not by the largest rectangle, not by the drawing's bounds.* So the
reading does it in that order: every new line is given its scope by
`SketchInterpreter._scopeOf`, then each is completed inside its own scope
against its own scope's lines — an opening's by `_completedWithin`, which
trims what the hand drew past the opening's edge and completes the rest
inside it, and the design's by `_completed`. `_scopeOf` asks of the **start**:

1. Inside an opening, by the line's own thickness — that opening's, whatever
   the line does afterwards; the smallest where openings nest.
2. Inside a part of the main design — the design's. A part with an opening
   lying loose inside it is kept as the whole of its ground, because a part
   has no holes, so it does not claim a start that is on that opening's edge.
3. On an edge — the frame or a bar, the edge of two areas at once, which says
   nothing by itself — an opening's only when the line lies within that
   opening, give or take the member it was started from, and runs well inside
   it somewhere: the rail drawn from a sash's jamb. A line from the frame
   right across the window, or along a sash's jamb, is the design's.

A line re-read from a bar the last reading made keeps that bar's scope, and
on a first reading there are no openings, so every line is the design's.
`test/domain/the_start_point_decides_the_line_s_scope_test.dart` holds the
user's test — a main design and two openings, one line started in each — and
a line started in Opening #1 and run across the mullion staying Opening #1's
and inside it, one started in the design and run into Opening #2 staying the
design's, one started right beside a shared mullion, lines drawn backwards,
starts on the frame, a first reading and a second. The ink is not touched: completing is the reading of the line,
and nothing moves but its free end. No part is made that the completed line
does not cut off, no opening is made or moved, and nothing is asked.
`test/domain/a_line_stopped_short_is_completed_test.dart` holds both
directions, the first-line rule, a line between two lines left alone, a
diagonal left alone, and the frame, the other lines and the opening
fingerprinted and required back unchanged.

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
| Read again, Parts, Details — under **More** | icons | icons | words |
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

### Simple until More

The user's words, over a phone screenshot of the technical drawing: *it is
so overwhelming, there are a ton of things. I know they are necessary, but
the app is used by people who do not know much about technology; they want
it clear and simple. Use a button to show all those icons.*

So the workspace opens simple, and **More** beside the views
(`MoreButton`, `everythingShownProvider` in `everything_shown.dart`) shows
the rest; it reads **Less** while they are shown.

| Always | Under More |
| --- | --- |
| Back, the design's name, **Sizes**, Undo, Save | Redo, Show my drawing, Read again, Parts, Details |
| Draw / CAD / 3D | The technical drawing's layers, the strip of tools inside an opening, the status bar |
| Select, Freehand, Straight line, Rectangle, Eraser (`ToolBar.simple`) | Polyline, Dimension, Arrow, Note, the pen's colour |
| The model, **Open** and Play where there is a leaf, how it is shown — Technical, Shaded, Material, Realistic — and the camera's own controls — Perspective \| Orthographic, zoom, **Fit**, **Reset** | The named views, the wireframe, Depth, Profile, the readout |

**Nothing is taken away.** Every control is one tap off; the drawing still
reads itself, a line drawn inside an opening still joins it, and a
picked part's panel still opens from the bar under the drawing. A tool
chosen under More stays on the bar under Less, so what is active is never
hidden. The choice is kept on the device (`proframe.everything-shown`), so
someone who wants everything has it next time too.
`test/app/simple_until_more_test.dart` holds it, and `showEverything` in
`test/app/new_design.dart` is how a test about a control under More gets
to it.

### The launch

The app opens on the workshop's mark, once, and then the customers —
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

**`LaunchScreen.duration` is the one figure for its length** — six seconds
— and every part is a share of it in `LaunchTiming`, so changing it changes
the pace of all of it together. The user asked for it longer, text and
emblem both: at four the whole name stood for barely a third of a second
before it began to leave, so the shares were moved as well as the total —
everything arrives a little sooner in proportion, and the name then stands
whole for over a second before the first line lifts away. It replaces itself with the customers
when it is done, so nothing navigates back to it and no rebuild starts it
again. A device asking for less motion gets the finished mark and the name
faded in and out over `reducedDuration`, with nothing moving or blurring,
and then the customers; its clock is
`AnimationBehavior.preserve`, because left to the controller that request
squeezes the whole thing to a flicker. It is drawn in the app's own colours
and nothing loops, so `pumpAndSettle` runs straight through it — which is
why every app test that opens the app still passes unchanged.

### Light and dark

The application has a dark appearance beside the light one. It follows the
device until the user says otherwise, with **Match device**, **Light** and
**Dark** behind one button on the designs' header (`AppearanceButton`), and
the choice is kept on the device (`appearanceProvider`,
`proframe.appearance`).

**The light appearance is exactly what it was.** Every colour a widget
shows comes from `context.palette` — a `Palette`, the theme's own extension
— and `Palette.light` is the `AppTheme` constants themselves. A painter is
handed its palette and defaults to the light one, so every test that builds
a painter without saying so still draws, and compares, what it always did.

**Dark is chosen, not inverted.** Each colour is picked for what it is *for*
and checked against what it sits on:

- **The house green plays two parts in the light, and they are split in the
  dark.** As a *ground* — a heading's band, a filled button, the chosen
  tool's pill — it is `band`, still deep green, carrying cream. As a
  *colour on a surface* — a chosen word, an icon, a focus ring — it is
  `primary`, which in the dark is a clear mint, because deep green
  lettering on a near-black surface would vanish. Every one of the house
  green's uses was sorted into one or the other by hand; a new one has to
  say which it is.
- **A note across the work** (a question about the sheet, a drawing not yet
  read) is `notice` and `onNotice`: cream in the light, a deep olive with
  cream lettering in the dark, so it does not glare.
- **A shadow is always `shadow`**, which is black in the dark. Shadows used
  to be the ink at a low alpha, which in the dark would have been a glow.
- **The technical drawing has its own set**, `Cad.night` beside
  `Cad.paper` in `cad_style.dart`: the same weights and the same ranks —
  the heaviest line still stands out most, annotation least — light on a
  dark sheet. The 3D view's backdrop darkens; the design's own finishes do
  not change, because they are the design.

**The user's own colours are never changed, only shown so they can be
seen.** A pen colour chosen on white — the house green, black — would all
but disappear on a dark sheet, so `legibleOn` draws a colour too close to
the sheet to read at the mirrored lightness in its own hue, softened: dark
green ink shows as pale green. It applies only on a dark sheet, never to
the finishes, and the design keeps the colour the user gave it; the pen's
swatch shows what will be drawn, and the colour dialog says so in the dark.
Ink shown faded under the design read from it lies over the design's light
fills and the dark sheet at once — a mark drawn off the design lies only on
the sheet — so there it is the ink's hue at a middle lightness, clear of
both. And what is drawn *on* the design — a frame's edges, a bar's outline,
an opening's triangle on the sheet — keeps the house green in both, because
it sits on the user's finishes, which are usually light, not on the sheet.

The launch has its own colours and is the same in both.

### The customers, before any design

A workshop draws for hundreds of people, so the app does not open on *door
or window*, and it does not open on a list of designs either. It opens on
**Customers** (`customers_screen.dart`): every person kept, by their name
and their information, a search by name or phone, **New Customer** and
**New Design**. The user's words, over a phone screenshot of the list of
designs it used to open on: *I want only the name of the customer with its
info; when I click the customer name it goes to the design cards — even if
there is only one design — and I pick which design I want.*

```
Customers  →  a customer  →  their designs, as cards  →  the one picked
    │                              │
    │                              └→  New Design  →  Design name  →  Choose your design
    └→  New Design  →  who it is for  →  Design name  →  Choose your design
```

- **The first screen holds no design.** A customer's card is their
  initials, name, phone and how many designs are theirs (`CustomerCard`) —
  no picture, no design's name, no **Open**. There used to be a list of
  *Recent Designs* there, each card a design, and a tap on one opened that
  drawing; the user did not want it, and it is not to come back.
- **A tap on a customer is never a drawing**, however many designs they
  have. It opens their page (`CustomerScreen`), where the designs are
  cards and the user picks one — one design is still one card to pick.
  See *Customers and their designs*.
- **A card is the design itself, drawn.** On the customer's page
  `DesignPreview` draws a read design with the same `CadPainter` as the
  technical drawing — figures, grid and handles left off — and a design
  not read yet as its own strokes. Nothing on the screen is a picture of
  doors in general (`no_stock_content_test.dart` still holds), and a
  design with nothing drawn — nothing read and no stroke that goes
  anywhere, so a dot does not count — says *Nothing drawn yet*
  (`PreviewPlaceholder`); one whose record cannot be read says *Preview
  unavailable*, so a spoiled design never passes for an empty one, and
  while a design is being read the card shows the bare sheet. No geometry
  is made up for any of them. The picture is only a picture:
  `DesignPicture` reads the design by its id, redraws it when it is
  edited, and opening the card reads the design afresh.
  `test/app/real_design_previews_test.dart` holds it on the pixels — the
  Basement Door card is exactly the preview painter drawing the saved
  Basement Door — and on every fallback. A design's number is `shortIdOf`:
  the moment it was made, to the millisecond, in eight letters and figures
  — the web's clock stops at the millisecond, so the last six digits of an
  id are always `000` there.
- **Who a design is for is `Design.customer`; what it is called is
  `Design.name`, and the two are never the same field.** Who it is for is
  metadata, nothing to do with the geometry, written to the file only when
  there is one, so every design saved before it still loads — and one
  saved before is known by its own name (`DesignSummary.title`). The
  design's own name was once taken out (*only the person / customer is
  enough*) and has since been asked for again, required: see *A new design
  is named*.
- **New Design on the first screen asks who the design is for**, and needs
  it — **Continue** waits for a name; an existing customer is found by it
  and a new one made. Then the design's own name (`DesignNameScreen`),
  then **Choose your design** (`StartScreen`). Choosing keeps the design at
  once and goes into the workspace with the customers underneath it — back
  is to the customers, where that person now has one design more, not
  through the steps that began it. From a customer's own page New Design
  asks only the name and the category.
- **Opening a design is `openDesign` on exactly what was saved** — nothing
  read again, nothing rebuilt — and the test compares the two as JSON.
- **The lists read pages, never the whole store** — the user's words:
  *the recent section must be able to have millions of customers*.
  `CustomerStore` and `DesignStore` each keep a record a key and an index
  beside them. The customers screen asks `page(query, offset, limit)` for
  `CustomersScreen.pageSize` at a time and the next page as the end comes
  into view, a customer's page does the same for their designs, and a card
  reads its own design by `load` only when it is built, so only what is on
  the screen is ever read in full. Designs kept in the old single list are
  moved over, whole, the first time the store is read.
  **The limit is the device, stated rather than hidden:** this store keeps
  designs in the browser's own storage, which holds a few megabytes. Every
  screen asks only for pages and single designs, so a store on a server —
  which millions need — stands in for this one without the screens
  changing. `test/infrastructure/many_customers_test.dart` holds the
  paging, a search among thousands, the migration, and the screen
  scrolling past its first page.
- **An edit brings a design to the top of its customer's cards, by being
  kept.** The workspace keeps the design without being asked once it has
  stood still for `WorkspaceScreen.keepAfter`, and again when it is left,
  through `WorkspaceController.keep`, which swallows a failure to store:
  keeping is never a reason for the work to stop. Only a change to the
  design counts — looking at one, picking a part or swinging a leaf leaves
  it where it is. `Design.copyWith` stamps `updatedAt` on every edit, the
  store sorts by it, and `designsRevisionProvider` tells the lists to read
  their page again.
- **Everything else is on the card's ⋮**, or by pressing and holding the
  card — the user's words, over a phone screenshot of their designs: *what
  if I want to delete one of them, or other things?* `DesignActionsSheet`
  rises from the foot of the screen with **Open**, **Edit information**,
  **Duplicate** (`DesignStore.duplicate`: the same design for the same
  customer, under an id and a number of its own, the original untouched)
  and **Delete**, each in words. Delete is asked about first, because the
  card simply goes, and can then be undone for as long as the notice
  stands: the design is kept in hand and saved back exactly as it was.
  Nothing on the sheet touches the drawing or the geometry. Who a design is
  for is not changed from its card — that is the customer's, edited on
  their page. `test/app/what_can_be_done_with_a_design_test.dart` holds
  each of them, and that the other designs come back byte for byte.

A phone gets a list of customers a thumb works down; anything wider a grid.
`test/app/the_designs_screen_test.dart` holds all of it — the first screen
holding customers and no design, a customer with one design opening on
their page with that one card, several designs several cards and the one
picked the one opened, and every screen size — and `test/app/new_design.dart`
is how every other app test gets from the first screen to the choice of
door or window.

### Customers and their designs

**A customer is not a design.** One customer has many designs, and each
design belongs to exactly one customer:

```
Customer  (lib/domain/model/customer.dart)      Design
  id  ◄──────────────────────────────────────── customerId
  name, phone, address, notes                    name, kind (the category:
  createdAt, updatedAt                           door, window, door & window,
                                                 sliding, angled /
                                                 asymmetrical), the drawing
```

The person's phone, address and notes are the customer's and never in a
design; the design's name and category are the design's and never on the
customer. **Neither holds a copy of the other**: a customer's designs are
the designs naming it, `DesignStore.page(customerId: …)`, so changing a
phone number touches no design and a customer with forty designs is kept
as small as one with none.

`CustomerStore` (`lib/infrastructure/customer_store.dart`) is laid out as
`DesignStore` is — a key a customer and an index of `CustomerSummary`
beside them, paged and searched by name or phone — and
`customerStoreProvider` is the one both stores share.

**Every design kept belongs to a customer.** `DesignStore.save` gives a
design without a `customerId` the customer it was typed as being for — the
one already called that (`CustomerStore.obtain`, by name however it is
spaced or capitalised) or a new one — and returns the design as kept; the
workspace takes the id back without counting it as an edit. Designs kept
before customers existed are brought over the first time the store is
read, each given the customer its name says and nothing else about it
changed; one kept before anybody was asked who it was for becomes the
customer its own name stands for, as the list already showed it. A
duplicate is another design of the **same** customer, named `(copy)`; a
design said to be for somebody else moves to that customer.

**The customers screen** (`customers_screen.dart`) is where the app opens:
a band with the count, a search, **New Customer** and **New Design**, then
a card a customer
— their initials, name, phone and how many designs are theirs
(`DesignStore.countsByCustomer`, one pass over the index), newest first,
read a page at a time. The search is the customer's own — name or phone,
never anything inside a design — and a phone number is found written the
local way or the international way: `0750 123 4567` and
`+964 750 123 4567` are one number to `Customer.matches`, which drops the
`+`, the `00` and the home `0` before comparing digits, and only treats a
search as a number when it is one.

**New Customer** (`new_customer_screen.dart`) asks for a name and offers
phone, address and notes; saving makes the customer and nothing else — no
design is begun — and goes to the customer's page. **Tapping a customer
opens that customer, never a drawing**, from the list, from a search and
on saving a new one.

**The customer's page** (`customer_screen.dart`) is the person first —
their initials, name, how many designs, then *Customer information*:
phone, address and notes, each said to be *Not given* where it was not —
and **Designs** beneath: their own designs — every design whose
`customerId` is theirs and no other — read a page at a time and shown as
cards (`CustomerDesignCard`), one above another on a phone and two or three
across where there is room. A card is the design's picture, then its name,
its category, *Last edited:* as a date and a time (`lastEdited`), and
**Open**, which opens it exactly as kept. **The picture is the design
itself**: `DesignPicture` (`designs_screen.dart`, with the other pieces
a design's card is made of) reads the
design and draws it with `DesignPreview` from its own geometry, or shows
the empty sheet saying *Nothing drawn yet* — never an invented drawing and
never an image. With no designs the page says *No designs yet*.
**New Design** is in the empty state, or — once there are designs — a
button standing at the foot of the screen through any scroll, with room
left under the last card so it never covers one. It is the only way on: **opening a customer asks nothing, begins nothing and opens no
drawing** — door, window or sliding is asked by *Choose your design* when
New Design is pressed, and not before. A design begun there is the
customer's from the start, and the way back from it is to the customer's
page (`CustomerScreen.route` names it on the navigator).

**New Design starts a setup, not a design.** It hands the steps of a new
design a `NewDesignSetup` (`lib/domain/model/new_design_setup.dart`)
that knows the customer's id and nothing else: no name until one is
typed, no category until a card is tapped. `NewDesignSetup.begin` is the
one way a setup becomes a design, it refuses a setup that is not
`isComplete` — named and with its category — and it fills in nothing the
setup does not say: no drawing, no size. Nothing is kept while the setup
is under way, so turning back from any step leaves the customer with
exactly the designs they had; it is kept the moment **Start drawing**
finishes it. A later step is another field on the setup and another
condition in `isComplete`, carried from screen to screen. The designs
list's own **New Design** goes through the same setup
(`NewDesignSetup.forPerson`). `test/app/a_new_design_for_a_customer_test.dart`
holds it.

**A new design is named, and the name is required.** The user's words:
*the customer name and design name are different — Adam is the customer,
Basement Door is the design.* `DesignNameScreen` is the first step after
**New Design**, from a customer's page and from the first screen alike.
Its field starts empty — never the customer's name, which
`forCustomer` and `forPerson` both leave out of `name` — and nothing is
ever numbered for the user (*Door 1*, *Window 1*) unless that is what
they type. `NewDesignSetup.nameProblem` is the one rule: only emptiness
is wrong, and whitespace either side is trimmed away, so **Continue**
with nothing in the field says *Enter a name for this design…* under it
in the theme's error colour and goes nowhere; typing takes the message
away. `withName` refuses an empty name, so none can get into a setup by
any route. The name is the design's — `Design.name`, saved with it,
shown on its card and at the top of the drawing, and on *Choose your
design* beside the customer's chip — and never on the customer record.
`Design.shownName` still labels a design with no name, as one begun
through `startDesign` (for tests only, `@visibleForTesting`) may be, as
*Untitled window*, and never stores it.
`test/app/a_design_is_named_test.dart` holds it: the field empty and not
Adam, an empty and an all-space name refused with the message, the name
trimmed and kept as the design's, the customer's record byte for byte
unchanged, the user's own four names kept exactly, nothing numbered,
back through the steps keeping nothing, and the message fitting a phone,
a tablet and a laptop.
**Opening a card is opening that design, by its id, and nothing else.**
Open, or a tap on the card, reads the design kept under its id and hands it
to `openDesign` exactly as kept — its drawing, geometry, sizes, openings,
the lines inside them and every glass and panel — and goes into the
workspace. *Choose your design* is never shown, nothing is asked about
what it is (that was said when it was begun, and is kept in it), nothing is
read again, and nothing is kept until the user changes something, so
opening and coming back makes no design and no copy. A second tap while it
is opening does nothing, and a design removed elsewhere says it could not
be opened rather than beginning one. The sizes form can still come up over
it, as over any design with sizes not yet given — that is a question about
this design, not the start of another.
`test/app/opening_an_existing_design_test.dart` holds it on Adam's
basement door, drawn, divided, glazed and measured.
**And the design opened is the one design every view shows.** Customer →
design → the saved design → Draw, CAD and 3D: `openDesign` puts the saved
design into the workspace as it is, and the drawing (`DesignPainter`), the
technical drawing (`CadPainter`) and the solid (`MeshBuilder`, through
`ModelView`) are each built from that very object — nothing rebuilt, read
again, re-measured or approximated on the way in, and no view with a
geometry of its own. The customer and design layer holds none either:
`DesignSummary`'s size is a label written from the design on each save and
never built from. `test/app/a_design_in_every_view_test.dart` holds it on
Adam's Basement Door: the design in hand is the saved text exactly, each
view's painter holds the same object (`identical`), the solid is facet for
facet the one the saved design builds, looking through all three leaves
the undo history empty and the device's storage byte for byte, an edit
made in one view is the edit the others show and the one kept, and a
design with nothing drawn has no geometry made for it in any view.
`test/app/a_customer_s_page_test.dart` and
`test/app/a_customer_s_designs_as_cards_test.dart` hold it — the second
with three customers' designs made interleaved and each page required to
hold exactly that customer's. `customersRevisionProvider` tells the list and the page to read
again when a customer is made, and they listen to the designs' revision
too, because keeping a design can bring a customer with it.
`test/app/customers_screen_test.dart` holds all of it on the real app,
from a phone to a laptop.

**A customer with many designs finds one by name or by category.** Above
the cards on the customer's page stand a search (`CustomerScreen.searchField`)
and a chip a category (`CustomerScreen.filterKey`): **All**, then Door,
Window, Sliding, Door & window and Angled / Asymmetrical in the order a
design is begun as, each
with how many there are — `DesignStore.kindsOf`, one pass over the index — and
a category the customer has none of left off. The search is by what a design
is called — *Basement*, *Kitchen*, *Third Floor*, whatever the case — and,
within one customer, never by the customer's own name, which is in every one
of their designs and would tell none apart; `DesignSummary.matches(byCustomer:)`
says so and `DesignStore.page(customerId:, kind:, query:)` does both, a page at
a time. The heading says *12 of 36* while either is narrowing the list, the
customer's own count stays the whole, and finding nothing says what was
looked for and offers **Show all designs** — never New Design. Both are only
a way of looking: nothing kept changes, nothing is begun, and New Design with
Window chosen still asks the category afresh.
`test/app/finding_a_customer_s_designs_test.dart` holds it on Adam's 36
designs — 15 doors, 12 windows, 6 sliding, 3 door & window — beside Sara's
kitchen window, which his page never shows.

**Deleting a design is one design, asked about by its name, and never
the customer.** A design is deleted from the ⋮ on its card — on the
customer's page (`CustomerDesignCard.moreKey`: Open, Edit information,
Duplicate, Delete) — and goes through `deleteDesign` in
`design_actions.dart`. It asks first, *Delete Basement Door?*, with the
design's category, customer and number under it and a plain word that the
customer, their phone, address and notes, and their other designs stay;
nothing is removed until **Delete design** is pressed, and Cancel, a tap
outside or back keeps it. `DesignStore.remove` then takes that design's
record and its line of the index and nothing more — no customer record, no
customer index, no other design — and **Undo** on the notice puts it back
whole. Deleting every design a customer has leaves the customer, with *No
designs yet*. There is no way here to delete a customer.
`test/app/deleting_a_design_test.dart` holds it on Adam's four designs —
Basement Door deleted, the device's storage compared key by key before
and after, his three others and his record byte for byte, and so after a
reload.

**A customer cannot be deleted, and that is deliberate.** The user's
rule is to offer deleting a customer only where the application already
has administrative deletion — somebody entitled to remove a person and
everything drawn for them — and to protect it heavily when it is offered.
This application has no administrator, no roles and no permissions, so it
is not offered: `CustomerStore` has no way to remove a customer, no screen
says *delete* about one, and pressing and holding a customer only opens
them. Whatever else changes, three operations stay apart: deleting a design
never deletes its customer (deleting all of them leaves the customer with
*No designs yet*), editing a customer never deletes a design, and nothing
deletes a customer silently.
`test/app/customers_are_never_deleted_test.dart` keeps it so: it reads
every line under `lib/` that takes something off the device and allows only
a design's record, that design's own kept price, and the list of designs
kept before customers existed,
and holds each separation on the stores and the screens. When customer
deletion comes, it comes with an administrator, and with the customer's
name, how many designs are theirs and what goes with them, confirmed on
purpose — and that test changes with it, not before.

**A customer's information is edited on their page, and only there.**
**Edit**, beside *Customer information* (`CustomerScreen.editButton`), opens
the form a customer is made with — `NewCustomerScreen(editing:)` — filled
in with the name, phone, address and notes as kept. **Save changes** keeps
the same customer, same id and same designs, with what was typed, trimmed;
a name is still needed, so an empty one or one of only spaces cannot be
saved. It writes the customer's record and nothing else: no design holds
the person's phone, address or notes, so changing Adam's phone cannot
touch Basement Door and changing his address cannot touch Kitchen Window.
**A renamed customer is shown by the new name without any design being
rewritten.** `Design.customer` keeps the name typed when the design was
begun, and it stays exactly as kept; where a name is shown the customer's
own is asked for by `customerId` — `DesignStore.page` lists each design
under `CustomerStore.namesNow`, so a design is listed and searched under the
name as it is now, and the design's own panel reads `customerNameProvider`.
`test/app/editing_a_customer_test.dart` holds it: every field edited and
kept through a reload, every design's stored text and the index of them
byte for byte unchanged, none of the person's details in any design, the
other customers untouched, an empty name refused, the new name found in
the customers, the designs and the workspace, and the form fitting a
phone, a tablet and a laptop.

**A design's information is edited without touching the design.**
**Edit information** — on a design's card on the customer's page
(`CustomerDesignCard.editKey`), on the ⋮ sheet of that card, and on
the design's own panel in the workspace (`InspectorPanel.editInformationKey`)
— opens `DesignInformationScreen`: the name, to be typed over, and the
category, shown and not changeable, because everything drawn in the design
was drawn in it. The name is held to `NewDesignSetup.nameProblem`, as a new
design's is. **Save changes** renames the same design by its id —
`DesignStore.retitle` from the lists, `WorkspaceController.rename` for the
design in hand, both `Design.copyWith(name:)` and nothing else — so no
design is made, and its drawing, lines, openings, the divisions inside
them, materials, sizes, drawn dimensions, the technical drawing and the
solid all stay exactly as kept.
`test/app/editing_a_design_s_information_test.dart` holds it on Adam's
basement door, drawn, divided, glazed and measured: *Basement Door - New
PVC* from the card and from the workspace, the design's JSON the same but for its name
and edited time, the technical drawing the same to the pixel and the solid
facet for facet, every other design byte for byte, the name through a
reload and the design opening as itself, an empty name refused, and the
form fitting a phone, a tablet and a laptop.

**The whole workflow is held end to end.**
`test/app/the_whole_customer_workflow_test.dart` does everything above the
way the user does it, through the screens and nothing put into storage by
hand: Adam made with his phone, address and notes; Basement Door and
Front Entrance Door (Door), Kitchen Window (Window) and Third Floor Sliding
(Sliding) each named, begun, drawn and saved; the app closed and opened
again; and then the eight checks in order on that one set of data — Adam's
page with his information, all four cards and New Design; Basement Door
and Kitchen Window each opening directly with no category asked; Garage
Door made as a fifth design of Adam's replacing none; Sara made and seeing
none of his; Adam's phone edited with every design byte for byte; Basement
Door renamed with its geometry unchanged; Kitchen Window deleted with every
other design and Adam kept — and all of it again after another reload, at a
phone's width and a laptop's. A design whose sizes are not yet given has
them asked for over the drawing whenever it is opened; that is a question
about the design, not a new one, and the test puts it away as a user would.

**Nothing kept is lost to something else being kept at the same
moment.** Each store keeps a record a key and an index beside them, so
keeping is a read of the index and a write of it back — and a read, then
a wait, then a write let two keepings each read the index as it was
before either wrote: **four designs saved at once came back as one** in
every list, the other three on the device with nothing pointing at them.
`DesignStore._indexNow` and `CustomerStore._indexNow` read the index as the
device holds it at that moment, and every change writes it back **with
nothing awaited in between**; storage takes a value the moment it is set,
so nothing can come between the two, from this instance or any other.
`CustomerStore.obtain` finds and makes in the same step, so two designs
kept at once for somebody nobody has made yet make one customer, not
two, and a new customer's id counter is shared by every instance, so two
made in the same millisecond are still two. A queue of promises was
tried first and is not to come back: every operation waited on the one
before it, so one that never finished stopped all the rest — which a
test's own clock did at once.
`test/app/designs_are_kept_for_their_customer_test.dart` holds it on the
real app — Adam made, Basement Door drawn and saved, Adam left and
reopened, the app closed and opened again from nothing but what the
device kept, three more designs and all four his in the list and in
every design's own file, and a second customer who sees none of them —
and holds the stores themselves: twelve designs saved at once all kept,
two stores saving at once, one design saved twice at once still one,
two designs for a new person making one customer, and customers made at
once all kept.

`Design.customer` is the name typed when the design was begun; the
customer record is what is true of the
person.
`test/infrastructure/customers_and_designs_test.dart` holds all of it: a
customer with no designs, one with four, every kept design naming its
customer, the name and category the design's own, the person's details
never in a design, searching, both older stores brought over with nothing
lost, and a design made for, listed under and removed from a customer.

### How customers and designs are put together

```
CUSTOMER            domain/model/customer.dart    kept by CustomerStore
   │ customerId        (one customer, many designs; neither copies the other)
DESIGN              domain/model/design.dart      kept by DesignStore,
   │                   listed by DesignSummary lines of its index
THE DESIGN ITSELF   the one document: sketch, frame, bars, sections,
   │                   openings, hardware, dimensions, sizes, finishes
DRAW / CAD / 3D     WorkspaceController.openDesign or .begin, then
                       DesignPainter, CadPainter and MeshBuilder
```

Each layer has one place. The models are the domain's; the stores are
`lib/infrastructure`; the providers that hand them out and say when they
changed — `customerStoreProvider`, `designStoreProvider`,
`customersRevisionProvider`, `designsRevisionProvider`,
`customerNameProvider` — are in `lib/app/state/workspace.dart`; the screens
are `customers_screen`, `customer_screen`, `new_customer_screen`,
`designs_screen`, `design_name_screen`, `start_screen` and
`design_information_screen`; and what can be done with a design from its
card — open it, edit its information, delete it — is `design_actions.dart`,
which a customer's page calls.
`kindIcon` is the one mark for a category. `Design.customer` is the name
typed when a design was begun, kept for designs made before customers and
for the first screen's own New Design; whatever shows a customer's name
asks the customer by `customerId`.

The twelve things the restructuring was measured against, and where each
is held:

| | Held by |
| --- | --- |
| One customer, many designs | `customers_and_designs_test`, `designs_are_kept_for_their_customer_test` |
| Designs shown as cards | `a_customer_s_designs_as_cards_test`, `the_designs_screen_test`, `real_design_previews_test` |
| Customer information available and editable | `a_customer_s_page_test`, `editing_a_customer_test` |
| New Design makes a new design | `a_new_design_for_a_customer_test` |
| A specific name is required | `a_design_is_named_test` |
| A category is required | `a_new_design_s_category_test` |
| Existing designs open directly, never asked the category | `opening_an_existing_design_test`, `the_designs_screen_test` |
| Designs stay with their customer | `designs_are_kept_for_their_customer_test`, `finding_a_customer_s_designs_test` |
| Design data preserved | `editing_a_design_s_information_test`, `deleting_a_design_test`, `customers_are_never_deleted_test` |
| Draw, CAD and 3D preserved | `a_design_in_every_view_test`, and every test of the drawing itself |
| The whole workflow at once | `the_whole_customer_workflow_test` |

### Choose your design

After the new design's name, one question: what the product is — its
**category**. `StartScreen` offers **Door**, **Window**, **Sliding**,
**Door & window** and **Angled / Asymmetrical**, in that order — the user's
own — as five cards, **all alike** — the user asked *why are all four
cards not the same?* when two were large and two were smaller under *More
types*. They are one row of five where the screen holds them, two to a row
on a tablet — the fifth on a row of its own, as wide as every other card,
because a row the cards do not fill keeps its gaps — and one above another
on a phone, each most of the width and a thumb's target. The two that are not door or window stay because the
user said *I want all of them*: a sliding design cannot be begun any other
way, because a design's kind is fixed once it is started.

A card is chosen by tapping it and stays plainly chosen — the brand's green
edge, a tint, a tick, and *Door selected* in the bar at the foot, with the
edge the same width chosen or not so nothing moves — and a
second tap on another moves the choice rather than adding to it. **Start
drawing**, in that bar and so always in reach, is off until something is
chosen; it completes the setup with the kind, begins the design from
it, keeps it, and goes into the existing drawing with the designs underneath.
Nothing else is asked. Under the cards one sentence says what separates
the four standard categories from the fifth: they straighten a line drawn
a little out of square, and Angled / Asymmetrical keeps every slope. See
*Telling the categories apart*.

**The category is saved into the design and builds nothing.** It is
`Design.kind` — `Design.category` by the user's name for it — written to
the file as `category` (a file saved before, which says `kind`, still
loads as what it was). The design it begins is its id, its customer, its
name and its category, and nothing else: no line, no frame, no section,
no opening, no template — the user draws those. It is only for a new
design: a design opened from its card goes straight to `openDesign` and
never comes here. `test/app/a_new_design_s_category_test.dart` holds it:
the five in order on a phone and a laptop, none chosen, each saved as
the design's category with nothing built, a second tap moving the
choice, an existing design opening as itself, and older files loading.

**Start drawing hands the workspace the design, and the workspace knows
which one it is.** The existing drawing workspace is not a new screen and
nothing in it was rebuilt: `WorkspaceController.begin` puts the design the
setup made into it, and everything the workspace does — drawing, reading
the sheet, sizes, materials, keeping — is an edit to that design.
`Design.identity` (`DesignIdentity`: id, customer's id, name, category) is
who the design is, read from the design itself and never kept beside it,
and the design's own panel — whenever nothing is picked — opens with it
(`InspectorPanel.identityKey`): the name, the category and who it is for,
under the name at the top of the screen.
`test/app/a_new_design_reaches_the_workspace_test.dart` holds it: the
workspace given the new design's id, Adam's id, its name and its category
for each of the four; the identity shown; a sheet drawn and read in the
workspace and the design left, with exactly one design more, every other
byte for byte, and the same identity coming back from its card; and the
drawing engine reading a design begun by the setup exactly as it reads
any other.

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

### An angled or asymmetrical design

The fifth category, `DesignKind.angled`, shown as **Angled /
Asymmetrical** with *Sloped, under-stair & custom shapes* under it and a
triangle's outline for its mark (`kindIcon`). It is for a design whose
shape is not square **on purpose**: a window under a stair, a sloped head,
a trapezoid, two sides of different heights, edges that are not parallel.
Choosing it is the user saying, before a line is drawn, that the slopes
they draw are meant.

It is a category like the other four and nothing more yet: the same
`Design`, kept as `category: "angled"`, listed, filtered and searched as
the others are. A design kept before it existed loads exactly as it did. Its card on
*Choose your design* is drawn by the same pen as the others: a window under
a stair, one jamb taller than the other, the head running up between them,
a mullion stopping at the head and a `<` in the lower light.

**It says nothing about any one leaf.** An angled design can hold doors,
windows or both, so `leafDefault` is null, as it is for Door & window: a
leaf marked in it hangs on its hinges and carries no handle until the user
says what it is, and the door-or-window question is put for it. It is seen
from inside unless a leaf is said to be a door — `Design.seenFrom` settles
that from the leaves, as it does for every design. It is not asked what it
is built of; it has the **Material** tool, as a window has.
`DesignKind.noun` is what it is called in a sentence — *your angled
design*, *Untitled angled design* — where its label is what it is called
on its own.

The label is the longest a category has, so the category tag on a design's
card and on its information form now shrinks to the room it has, rather
than running off a narrow card.

`test/app/an_angled_design_test.dart` holds it:
- the five categories, the four that were there neither removed nor renamed;
- its label, its line, its own mark, and how it behaves about leaves and
  materials;
- `"angled"` saved and read back in a design and in the list of designs;
- through the screens: an Angled / Asymmetrical design made, saved, closed,
  and the app closed and opened again — its card saying what it is, and the
  design opening as itself with its category as kept;
- a leaf in it asked door or window, and given its handle once said;
- the filter chip;
- the five cards the same size at a phone, a tablet and a laptop.

`test/app/a_new_design_s_category_test.dart` now holds five categories
where it held four.

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
than dividing what is inside it; `_scopeOf` is the test, on the section's
outline inset by the bar's own width (see *A line stopped short is
completed*). The line is then laid
right across the sash by the same `spanAcross` the **Divides** control and
the line tools use, because a hand-drawn line stops short of a stile and
inside a sash that is the difference between two panes and one pane with a
line lying on it. `test/domain/a_line_drawn_in_the_opening_joins_it_test.dart`
holds this, and holds the four things that must *not* join: a line in the
fixed light, a line right across the window, a line along the sash's own
jamb, and any line at all on a first reading.

**A line started inside the opening and stopped early joins it too** — the
user's words: *if I start a line inside an opening, complete it to the
opening's boundary; do not expand, move or resize the opening.* A hand draws
a rail from the sash's jamb and lifts before the far one, so the line touches
the sash at one end and is not clear of it all round; read as a line of the
design, the completion in *A line stopped short is completed* then carried
it across the whole design and cut the opening in two. So `_scopeOf` also
gives the opening a line started on its edge that runs well inside it — by
the line's own thickness — and lies within it all the way, give or take the
frame's profile for the member it was started from. `_completedWithin` then
completes it inside the opening's own outline, so it reaches the opening's
boundary and no further. A line along a jamb has no
end well inside and a line across the window leaves the opening, so neither
joins, as before. `test/domain/a_line_started_in_the_opening_is_completed_to_it_test.dart`
holds it from either jamb, stopped short at both ends, upright, in a door
that is one light, and in a line started in the fixed light instead — with
the opening and everything outside it fingerprinted and required back
unchanged.

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
`dividerAlong` takes the level to look at: the panes of an opening are made
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

**One transform places the whole leaf.** `_addLeaf` works out the leaf's
swing once — its own, then its parent's where it hangs inside another leaf —
and hands that one function to the sash, the ironmongery and, through
`_addSash`, the panes and the bars inside it. Nothing inside an opening is
placed by a route of its own, so nothing can turn by a different amount or
be left behind. `test/domain/the_solid_moves_the_opening_as_one_test.dart`
holds it on a sheet-drawn opening holding glass, an internal divider, a
panel, a handle and hinges: moved to a light of the same size, every facet
of it is carried by exactly the move and nothing else is built differently;
swung, every point of it keeps its distance from the sash, so it all turns
as one body. Handing the bars inside a leaf the identity instead of the
leaf's transform fails it.

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

**When the opening goes, what was inside it stays in the region.** An
opening goes when the user deletes it, says it is fixed after all, or rubs
its mark out — and the region it was on stays, because the user's lines made
that region and the mark did not. Its lines and panes were left naming an
opening that no longer existed: a line no view drew, and panes that came
loose into the main divisions on top of the light they were in.
`Hierarchy.outOfClosedOpenings`, applied by `Design.copyWith`, hands every
child of an opening that has just gone to the section it was on, so each
keeps one owner — never the design, never nothing. Marking the region again
gives them back to the new opening by `underOpenings`.
`test/domain/an_internal_line_has_one_owner_test.dart` holds this, and holds
that a line drawn inside an opening is one bar with one owner: the opening's
in the model and in `DesignTree`, never also a line of the design, moving
and resizing with the opening at the same place in its own coordinates.

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
| Overall width | The width alone: the sheet stretched across, the height untouched |
| Overall height | The height alone, the same way down |
| A daylight or section width | The bar beside the pane, or the jamb when there is no bar |
| A daylight or section height | The bar above or below it, or the sill |
| A measurement the user drew | The whole design, scaled to make it true |

Nothing else moves. Changing one pane's height moves the transom, so the pane
above it changes too — that is arithmetic, not redesign — and the overall size
stays exactly as it was.

**The editor a figure opens stands above the drawing, never inside it.** It
used to sit inside the drawing's own pointer handling, so pressing **Apply**
was first a press on the drawing away from any figure — which put the editor
away before the button was let go. A quick click sometimes got through; a
finger held for a moment never did, and the user's typed height simply did
not happen. `test/app/the_sizes_are_asked_test.dart` presses **Apply** the
way a finger does, held for a frame, and fails with the editor back inside.
Giving a figure there does not bring the whole Measurements form back: it
reopens only for a size it has not asked about before.

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

### Sizes are asked for, never guessed

The user's words: *never write any number for width and height as a guess
— when it runs, ask the width and height of everything: the border, the
opening part, the glass, a line in the opening.* A hand drawing has
proportions and no scale, so every figure a reading works out is the
drawing's size at whatever size the hand happened to draw it. That is not
a measurement, so it is not written as one.

**`Design.measured` is what the user has given**, a set of keys —
`profile` (the frame's border), `bars` (their thickness), `width`,
`height`, and `x:<bar>` / `y:<bar>` for the bar a light's width or height
moves. Null is a design kept before sizes were asked for, whose figures
are all shown as they always were. A new design starts with the empty
set, so until a size is given it is written **`?`** — on the technical
drawing's chains and panes, in every panel, in the parts list, the 3D
view's box and the design's card — and a size field opens empty rather
than offering the guess.

**`Measurements` (`lib/domain/dimensions/measurements.dart`) says what is
asked.** The frame's border, the bars, the overall width and height, then
each main division in reading order with the panes drawn inside each
opening after it. **A size is asked only where the user's answer can be
built exactly without undoing another**: a row of three lights has two
free widths, and the third is what is left, so it *follows* and the form
shows it worked out — arithmetic, not a guess. Each asked size owns the
one bar it moves (the far one where there is one), and no two sizes own
the same bar, which is what lets every answer be exact at once.

**`MeasureForm` asks**, the moment a reading has something to measure and
nothing else is waiting on the user — after the outline gap and the
door-or-window alerts — and again whenever a reading makes a new size to
give: a line drawn inside a sash asks only for the pane it made, with the
cursor already in that field. *Not now* puts it away; the **Sizes** icon on
the bar at the top (with a dot while anything is missing) and **Enter the
sizes** on the design's panel open it again.

**A size moves the ink as well as the design**, and that was the bug the
user reported as *when we change the numbers and apply it, it doesn't
change to the new one*. It was two faults. The overall width and height
scaled the whole design in proportion, so typing the height undid the
width just typed. And a typed size moved a bar or the frame but not the
ink it was read from, so the next reading — **Read again**, or reading
after drawing anything at all — rebuilt the design from the ink and every
typed size was quietly lost. Now every size goes through
`Measurements.stretch`: the axis is remapped piece by piece, every other
bar and the frame's sides staying put, and a band round each line moving
whole, so the ink a line was read from moves exactly as the line does. A
re-reading finds every line where the size put it, and
`Measurements.keepAfterReading` takes out the last of a hand's wobble by
keeping each given bar, and a frame given its size, exactly where it was.
A frame drawn afresh is a new frame, and its size is asked again.

Every size typed anywhere comes through here — the form, a panel's field,
a figure tapped on the drawing — so there is one way a size is put into a
design. `test/domain/sizes_are_asked_not_guessed_test.dart` holds it:
nothing known after a reading, every size asked, the answers exact, the
width and the height independent, the last of a row worked out, a size
that cannot fit refused with a reason, a re-reading — even one that keeps
nothing — building the same sizes, and a line drawn afterwards asking for
its one new size and nothing else.

### Glass or panel

The user's words: *door and door & window — ask at startup. Window and
sliding — a material tool in the workspace. In every category the user
decides panel versus glass; the application does not decide for them. The
existing geometry is never redesigned: material selection changes material
and appearance, not geometry.* Their two photographs are the two cases: a
door that is panel all over, and one with frosted glass over a panel either
side of a transom they drew.

```
New Door / New Door & window                New Window / New Sliding
        ↓                                           ↓
"How should this door be constructed?"          the drawing
  Entire design = Panel  → its colour               ↓
  Entire design = Glass  → its glass            pick a part → Material
  Both Panel + Glass     → the drawing              ↓
        ↓                                       Glass | Panel, and its look
  once read: which parts are glass,
  which are panel — part by part
```

- **`Design.construction` is what was said** (`Construction` in
  `elements.dart`). A new design whose kind `asksConstruction` — a door or
  a door & window set — starts `pending` and `ConstructionAlert` asks it
  over the work, before anything is drawn. Null is everything that is not
  asked: a window, a sliding set, a design kept before the question
  existed, and one where the user said **Not now**, which puts it away for
  good.
- **Panel or glass all over is a finish, and it fills every part drawn.**
  The user picks the colour or the glass on the second step — **Continue**
  waits for it, because the colour is theirs to choose — and
  `Infill.fillWhole` fills every part there is and keeps the finish as
  `Design.infill`, which `SectionBuilder._carryIdentityForward` gives to a
  part that is a continuation of nothing. So a door said to be panel is
  panel in every part drawn after, and a line drawn later makes panel
  parts, not glass. Where nothing was said it is the plain clear glass
  every part has always started as, so nothing else reads differently.
- **Both fills nothing.** It goes straight to the drawing, and once the
  drawing is read `PartsAlert` asks, part by part, with each part picked
  out on a small drawing of the design (`PartChoice`, `PartThumb`). No part
  starts chosen — not the top, not the bottom, not half and half — and
  **Done** waits until every part is said. Where there is one part only,
  nothing is divided: it says *your design has no internal division yet*,
  and **Draw divider** puts the user back on the drawing with a straight
  line in hand. Once they have drawn it and read it, the parts are asked.
  The sizes wait until then, so the form does not come up over the
  drawing they are making. `Design.partsAsked` keeps it asked once.
- **A part is a pane of the design tree** (`Infill.partsOf`): a main
  division nobody drew inside, or a pane of one somebody did — inside an
  opening as much as outside, so an opening's glass over its panel is said
  the same way and stays the opening's.
- **The Material tool is in every kind of design** — the paint-roller on
  the bar at the top, never under More, and the same button on the bar
  under a picked part — and `MaterialForm` lists every part, the one picked
  first. It is also how anything said at the start is changed later.
- **The looks are real materials in real colours**: `GlassLook` (clear,
  tinted, frosted, dark, blue-grey) and `PanelColour` (white, black, grey,
  brown), each with **Custom** for any colour, all in `materials.dart` so
  the solid builds them and a test can ask what *frosted* is. The solid
  builds glass as glazing facets and a panel as panel facets in the
  colour chosen; nothing is a picture of either.
- **Only what fills a part changes.** Every edit goes through
  `Infill.fill`, which touches a section's finish and nothing else — not an
  outline, not a bar, not another part. `test/domain/glass_or_panel_test.dart`
  fingerprints the geometry and requires it back unchanged after every
  choice and every change, requires the solid's facets to stand exactly
  where they stood when a colour changes, and holds the choice through a
  save, a reload and a second reading. The technical drawing writes what
  fills each part on it — GLASS, FROSTED GLASS, PANEL — under the
  annotations layer.

`test/app/glass_or_panel_test.dart` holds all of it on the real app: each
of the three answers, the one-part case and **Draw divider**, **Not now**,
a door & window set whose leaves are still asked door or window first, a
window and a sliding set never asked and given their glass and panels with
the Material tool, the door's answer changed later the same way, and every
step fitting a phone, a tablet and a laptop. `chooseDesign` in
`test/app/new_design.dart` puts the question away for tests about
something else, as a user in a hurry would.

### Centimetres out, millimetres in

The geometry is millimetres throughout the domain, because that is what a
workshop cuts to. The user never sees one. Every figure shown and every figure
typed is centimetres, and `lib/domain/dimensions/units.dart` is the one place
the two meet.

Figures are written to the tenth of a centimetre — the millimetre — which is
the finest distinction worth quoting on a drawing. That is how many digits are
printed, not what the design is: a value typed as 72.25 cm is exactly 722.5 mm
in the geometry, and 96.4 cm is never written as 96. On the technical drawing
every figure carries that tenth, `160.0 cm` beside `91.6 cm`
(`Units.formatTo`, `DimensionLayout.places`), so the drawing is one format and
stays it as it is edited; elsewhere a whole centimetre is written `160`.

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

The same holds when the divider is **drawn on the sheet** rather than
placed with a tool: an incomplete line drawn 40 cm down a 40 × 160 cm
opening is completed across it, becomes its one internal divider, and the
glass above and the panel below stay the opening's — the window keeps its
two main divisions. `test/domain/a_drawn_line_divides_the_opening_into_glass_and_panel_test.dart`
holds that, through a second reading, a save and a reload.

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

## The look of CAD and 3D

`docs/cad_and_3d_audit.md` is the audit written before the visual work on
the technical drawing and the model began: where every piece of geometry,
material and depth lives, how `CadPainter` and `MeshBuilder` → `Camera` →
`ModelPainter` draw it, what limits the look today (flat colour × one light
number, shading baked into facets and then applied again, glass as a
translucent box, no seals or rubber, every piece of ironmongery the one
`FacetRole.hardware`, handle sizes worked out differently by CAD and 3D),
and where the look can be improved without moving geometry.

**Appearance may change; geometry may not.**
`test/domain/rendering_geometry_baseline_test.dart` pins the geometry both
views are built from — the design's own shapes and every facet's corners,
part and role, never its colour, transparency or gloss — for a door, a
window and a sliding pair, shut and open. A visual change leaves every
fingerprint as it was. One that moves them has moved geometry: where that is
the point (a seal that is now real material), update the figure on purpose
and say so; where it is not, the change is wrong.

### One geometry, drawn three ways

```
SAVED DESIGN  →  DesignGeometry  →  DesignPainter  (Draw)
                                 →  CadPainter     (CAD)
                                 →  MeshBuilder    (3D)
```

`lib/domain/model/design_geometry.dart` is the one answer to where each part
is and what shape it has, and every view reads it rather than working any of
it out for itself. It holds nothing of its own — everything is derived from
the design, nothing is stored back, and `DesignGeometry.of` gives the same
object for the same design — and it invents nothing: no division, size or
position the design does not already have. What it settles is what the
views used to settle separately, and so could disagree about:

- **Where a bar stops** — `barBody`. A bar of the design runs to the frame's
  inner face and a bar inside an opening to its sash's daylight, in all
  three views; square across where that already stays within, and cut flush
  with the edge where the bar meets it at a slope. The two drawings ran a
  mullion out to the frame's outside edge while the solid stopped it at the
  inside.
- **What a pane is filled to**, and **the leaf** — `fillOf`, `leafOuter`,
  `leafInner`. A sliding design's panels on their tracks reach the middle
  of the line they meet at (`slidingPanelOf`), which the solid used to work
  out by a route of its own.
- **Ironmongery** — `hardwareOf`, from `Furniture`
  (`lib/domain/hardware/furniture.dart`): every piece as the shapes it is
  built as, sized from its leaf — a lever's backplate, rose and arm, a
  window handle's base, boss and arm (the hull of the very rings it is
  turned from, `turned.dart`), a hinge's leaf and knuckle, a pull's bar and
  posts. The drawings used to size a symbol from the whole design, so a
  lever was one size on the sheet and another in the model.

The pinned fingerprints did not move: for every design they hold, the solid
builds exactly what it built before, and what changed is the two drawings
coming to agree with it. `test/app/one_geometry_for_every_view_test.dart`
holds it facet by facet and pixel by pixel — every bar, pane, sash and piece
of ironmongery the solid builds is the geometry's shape, both sheets put
down the same bars and the same ironmongery, a line inside an opening stays
inside it, and no view file works a bar body or an ironmongery size out for
itself. Putting back either drawing's old bar or ironmongery rule fails it
on the pixels.

### What each part is made of

```
Finish (the user's colour + MaterialKind)  →  Surface  →  Shading.of  →  ModelPainter
                                                        →  CadIndication →  CadPainter
```

**A part is made of something, and it is shown as what it is made of — not
as a flat colour.** `lib/domain/model/surface.dart` describes each material
physically: how much light it lets through (`transmission`), how much of
that it scatters (`scatter`, frosting), how rough it is, whether it is a
metal, how much it reflects square on (`reflectivity`), how its edges read
(`EdgeLook`, with glass's green side), its `texture`, and how the technical
drawing indicates it (`CadIndication`). `Surfaces` holds glass (clear,
tinted, frosted), panel, PVC, aluminium, wood, rubber gasket, metal, handle
metal, hinge metal and mesh. The colour is never in it: it is the user's,
on the part's `Finish`, and every material is shown in whatever colour the
part was given.

- **The solid says what each face is made of, and bakes in nothing else.**
  Every `Facet` carries its `Surface` and the user's colour exactly — the
  darkening the builder used to store (`shade:`) is gone, because it was
  lighting applied twice and it made the stored colour not the user's. A
  handle, lever, lock or letterplate in a metal is handle metal, a hinge
  hinge metal; one the user makes plastic is plastic. The thin side of a
  slab is marked `isSide`.
- **One function lights every face**: `Shading.of` in
  `lib/domain/solid/shading.dart`, from the material, the face's direction
  (`ProjectedFacet.normal`) and an `Environment` of one key light, sky and
  ground. Diffuse colour lit by the key; the sky and ground reflected, sharp
  on a smooth surface and blurred on a rough one, more at a glancing angle
  (Schlick's Fresnel, capped by roughness so rubber does not shine); the key
  light's highlight; and a metal reflecting in its own colour where
  plastic, paint and glass reflect white. `ModelPainter` only paints what
  comes back and chooses no colour; the light is the same in both
  appearances, because the design's finishes are the design.
- **Glass is composited as glass**: what is behind it is *multiplied* by its
  filter (each of a pane's two faces taking the square root of what the
  whole lets through), frosting's scattered light is laid *over*, and what
  the surface reflects is *added*. Blending it over the backdrop instead
  made a white pane and a white panel the same picture on the light
  backdrop — found by the test below, not by looking.
- **CAD reads its indication from the material**: glass by the sheet's
  glass tint and the two strokes across a corner, anything solid by its own
  colour and hatching, rubber filled solid. The renderers ask a material
  what it is like and never which one it is, so **a new material is a new
  `Surface` in `Surfaces` and nothing else**.

**Appearance never reaches geometry.** A surface is read only after every
corner is placed. `test/domain/materials_are_physical_test.dart` recolours
the panel, changes the glass, makes the frame black aluminium and the
ironmongery bronze, and requires the design, both meshes and every bar body
and fill back unchanged — and the pinned fingerprints did not move. Making a
panel into glass is the one exception it states rather than hides: the
region and every line are untouched, but a sealed unit and a panel are built
to their own thicknesses, which is construction rather than appearance. The
same file holds the physics: glass seen through where the rest are not, the
two faces of a pane letting through what the glass does, tinted darker than
clear, frosted more opaque and lighter, glass reflecting more at a glance
and green edge on, a metal mirroring sky and ground where a matte panel
hardly does, a metal reflecting in its own colour, a handle catching the
light a hinge spreads, and rubber dark and all but unchanging.
`test/app/materials_can_be_told_apart_test.dart` holds the point on the
pixels: a door whose frame, glass and panel are all *one colour* still
shows three different things, the glass changes with the backdrop behind
it while the panel and the frame do not, and the technical drawing fills
rubber solid.

**Rubber is what closes every sealed unit.** The dark butyl seal round the
edge of each unit's cavity (`MeshBuilder._edgeSeal`, see *One space, and a
depth for everything*) is made of it; there is no gasket round a sash yet,
and adding one is new material in the solid, which moves the pinned
fingerprints on purpose.

### The frame is a real frame

The frame used to be a flat ring pushed back to the design's depth — square
everywhere, the same slab whatever it was made of. It is now its profile
(`FrameProfile`, `lib/domain/model/frame_profile.dart`) swept round the
outline: a front face, the arrises and sightline its material is made with,
a reveal facing into the opening, an outside and a back, each member meeting
the next on its mitre.

- **The shape comes from what it is made of.** `ProfileStyle.of`: a uPVC
  chamber profile is *sculptured* — soft 3 mm arrises and a sightline that
  falls away to the glass in a curve; an aluminium or steel extrusion is
  *extruded* — millimetre arrises and a shadow step down to the glazing
  lip; timber is *moulded* — rounded arrises and an ovolo. The sash is the
  same profile at the sash's width and the leaf's depth, and a bar's long
  front edges are eased by its material's arris (`barArrisOf`), its ends
  left square to butt against what they meet.
- **Its size comes from the frame, never from the design's size.** Every
  figure across the section is a share of the member's own profile width
  (`FrameElement.profileMm`), and the depth is the design's
  (`Design.depthMm`); the depth only limits how far back a curve runs. The
  same profile on a hatch and on a shop front is the same section.
- **It lives wholly inside the ring the plain frame occupied.** It reaches
  the outline and the daylight, the front face and the back, and nothing
  of it goes outside the one or inside the other: a 100 × 200 cm design is
  still 100 × 200 cm, its daylight is its daylight, and the design itself
  is not touched — the profile is worked out when it is drawn and stored
  nowhere. A side left open has no member; the members either side end in
  their section, cut square.
- **A colour is not a profile; a material is.** Recolouring the frame moves
  nothing. Making it aluminium changes the frame's and the sash's section
  inside the same outline, daylight and depth, because an extrusion is not
  shaped like a PVC chamber — construction, like a sealed unit's thickness
  beside a panel's, and stated rather than hidden in
  `materials_are_physical_test.dart` and `rendering_geometry_baseline_test`.
- **CAD stays a drawing.** `DesignGeometry.frameProfile` and
  `frameSightlines` are what both views read: the elevation keeps its heavy
  outline and lighter daylight and adds only the line where the face turns
  into the sightline, as a hairline at exactly the solid's mitre — no
  shading, no render.

**The renderer had to learn where ironmongery is against a curved face.**
The model is painted far to near, and a piece of ironmongery is placed by
the planes of the faces it overlaps. Two things the flat frame never
exposed went wrong: a long, thin face — a sill's sightline running the
width of the frame — has a screen box far bigger than itself, and gave a
hinge a constraint from a face it never touched; and a hinge's knuckle
stands proud of the stile it is screwed to (it is meant to, see
`the_face_we_are_looking_at_test`), so a stile's plane runs through the
edge of it. `Camera.project` now takes constraints only from faces a piece
actually meets on the screen, treats a plane that only nicks the piece
(four fifths of it on one side) as a softer constraint, and puts the piece
where it breaks the fewest — which, where nothing disagrees, is exactly the
old answer. A hinge moved out of the stile it hangs in was tried first and
refused: the knuckle breaking the inside face is the rule.

`test/domain/the_frame_is_a_real_profile_test.dart` sweeps five sizes from
a 45 × 35 cm hatch to a 3 × 2.4 m shop front in PVC, aluminium and timber,
a 40 mm profile 90 mm deep, a divided window with a leaf, a gable and a
door with no sill: the design back as drawn before and after it is built,
the frame on the outline to the millimetre and exactly the design's depth,
nothing in the daylight or past the outline, the reveal on the daylight,
a front, an outside, a reveal, a back and the arrises between them present,
the same section at every size, a wider or deeper profile a wider or deeper
section, each material its own, a colour changing nothing, and the
elevation's sightline standing on the solid's mitre.
`test/app/cad_draws_the_frame_as_a_drawing_test.dart` holds the drawing:
between the outline and the daylight the sightline and nothing else, and
the frame's material changing only the frame on the sheet.

### Glass looks like glass

A pane was shaded once, as one colour over whatever was behind it: a flat
tinted card. Three things make it glass now, each physical rather than a
colour chosen to look glassy.

- **It is shaded where it is.** Glass is the one surface whose look changes
  across a single flat face: in a perspective view the eye meets each point
  at its own angle, so what it reflects and how much — more at a glance than
  square on — change from one side of the pane to the other.
  `ModelPainter._pane` shades each four-sided face of a pane at every point
  of a ten-by-ten grid, along the eye's own ray to that point
  (`ProjectedFacet.eyeCorners`, `viewer`, `towardsEyeFrom`), and draws the
  grid with `drawVertices`, blending between the points. Other faces are lit
  once, from the true direction to their middle.
- **It has something bright to reflect.** At ordinary viewing angles glass
  reflects six to ten per cent, so a smooth sky shows nothing on it: what
  says *glass* in every photograph of a window is a bright light's
  reflection lying across it. `Environment.daylight` is a studio as glass
  is photographed in: a clear sky whose horizon is an edge, a sky brighter
  than what it lights (`skyRadiance`), and two tall strip lights either
  side of the camera (`stripsAt` 67.5°), travelling with it as a
  photographer's lights do. A strip seen in a pane is the sheen across it —
  where it falls on the pane is worked out point by point, it moves as the
  view turns, and glass square on to the eye, which reflects neither strip,
  is simply transparent, as it is. The strip lights are only what glass
  reflects (`radianceToward`); nothing else is lit by them.
- **It lets through what is behind it.** The pane multiplies whatever is
  behind it on the screen — the backdrop, and the model's own parts behind
  it — by its filter, lays what frosting scatters over it, and adds what it
  reflects. A "room behind the glass" was tried and taken out: what shows
  through a pane is what is actually behind it.

**Each glass is its own material, and only a material.** Clear lets most
through with a faint cool cast; tinted, dark and blue-grey let through less
and take their colour; frosted scatters, so it glows with the light, hides
what is behind it and spreads the sheen soft. The pane has thickness, and
its thin side is not seen through: it is the green of the iron in the
glass. Changing one glass for another changes no width, height, position,
opening, divider or dimension — nothing but how it looks.

**On the technical drawing glass stays a drawing**: the sheet's light glass
tint, the two strokes across a corner, the part's name, and its own outline
drawn over the tint. Tinted glass takes a controlled share of its own colour
(`CadIndication.shade`), so it reads darker than clear without hiding a
line; frosted glass is stippled (`CadIndication.stipple`), the drawing's
mark for obscured glass. No line of the drawing moves with the glass.

`test/app/glass_looks_like_glass_test.dart` holds it on the pictures: every
glass choice is the same geometry — design, both solids, every fill, every
bar and every dimension; each glass is a different picture; clear glass
changes with what is behind it and frosted hardly does; tinted is darker
than clear and dark darkest; a pane is not a flat rectangle where a panel
in the same place is one even face; the sheen moves as the view turns;
frosted spreads it; the pane has thickness and a green edge; and on the
drawing the tint is never so dark or so pale that the lines go, tinted is
shaded, frosted is stippled, and outside the panes not a pixel changes.
Drawing the glass flat again fails four of those tests.

### Panels are solid

A panel was a slab painted one colour: from the front, a rectangle, and
nothing to say it was a solid thing set into a sash. It is shaded as what it
is now, and nothing about it is a texture or a colour chosen for it.

- **Its edges are eased**, as a finished panel's are. `_panel` in
  `mesh_builder.dart` builds the front and the back as the fill inset by
  `panelArrisOf` (`frame_profile.dart`: at most 2 mm, and a small share of
  the thickness), with an arris and a side round every edge — the arrises
  catch the light differently from the face. Every corner is inside the
  pane's fill and its thickness, so its width, height and position are what
  they were; the fill is `DesignGeometry.fillOf`, unchanged.
- **It sits back in what holds it.** Each face records how far what
  surrounds it stands proud of it (`Facet.recesses`, an edge at a time,
  from the sash's front for a pane of a leaf and the frame's for a fixed
  light, `DesignGeometry.surroundOf` / `isInLeaf`). `ModelPainter._recessed`
  shades such a face on a grid packed close at its edges, and `recess` in
  `shading.dart` says, for each point, how much sky the step shuts out and
  whether it lies in the shadow the step casts on the side the key light
  comes from. `Shading.of` takes both — `occlusion` dims the ambient and
  reflected light, `shadowed` the key — so the corner of the step is darker
  and the middle of the panel is lit as it always was.
- **The colour is the user's.** Every panel facet carries the finish's
  colour exactly; what changes on the screen is lighting of that colour, a
  shade of the same hue, never a different one. It is opaque, so what is
  behind it never shows.
- **Glass, panel and frame are three things** even in one colour: the glass
  is seen through and carries its sheen, the panel is an even, matte face
  set back with a shadowed edge, and the frame is its profile.

Changing a panel's colour changes nothing but how it looks. The door's
pinned solid fingerprints in `rendering_geometry_baseline_test.dart` moved
once, on purpose, for the arris; the designs' did not.
`test/app/panels_look_like_panels_test.dart` holds it: every colour and a
custom one the same geometry — design, solid shut and open, fills, bars and
dimensions; every facet the user's colour; a slab with sides and eased
faces inside its fill; on the pictures, opaque on a light and a dark
backdrop, keeping its hue, even across its middle, darker in the corner of
its step and back to its own colour a little way in; and a panel, a pane
and the frame in one colour three different pictures. Switching the
recessed shading off, or the arris, fails it. The technical drawing is
unchanged: a panel is still hatched.

### Ironmongery is metal

The ironmongery was already geometry — see *Ironmongery is built as
ironmongery* — but it was lit a flat facet at a time, so a round lever was
a prism with a stripe on each flat, its plates were sharp-edged card, a
hinge's leaf stood a few millimetres off the face it is screwed to, and
nothing sat on the door because nothing cast a shadow. It is shaded and
built now as the metal pieces it is. Where it goes, and which piece a door
or a window gets, did not change: a door still has its lever and lock, a
window its espagnolette and no lock, and every piece is still placed from
its opening's own outline by `OpeningHardware` and goes where the opening
goes.

- **Round is round to the light.** A facet of a round part carries the way
  the surface faces at each of its corners (`Facet.normals`), turned with
  the model by `Camera.project` (`ProjectedFacet.cornerNormals`), and
  `ModelPainter._smooth` lights it point by point from them — so a
  highlight runs along a lever instead of lighting one flat of it. The
  normals are only light: they move nothing, and a flat face has none.
- **A metal mirrors its studio, in its own colour.** `Shading.of` gives a
  metal the sky at its own brightness and the strip lights either side of
  the camera, spread by its roughness (`radianceToward(blur:)`), and a
  dimmer studio on the camera's side (`Environment.studioColour`), so a
  plate facing the lens shows its own colour and not a white mirror of the
  sky. **A metal's colour is what it reflects**: its reflectivity figure
  says how polished it is, and multiplying the colour by it as well, as it
  once did, turned a grey handle near black. Paint and plastic reflect the
  same sky at the same brightness, in white.
- **Built as the pieces they are**, in `Furniture`, which the solid and
  both drawings read: the lever is one bent tube out of its rose, across
  the leaf and round towards the door, closed in a dome (`leverArm`); the
  rose, the boss and the knuckle are turned, their edges rounded
  (`rose`, `boss`, `knuckle`, with a groove where a hinge's two halves
  meet); a pull's bar has rounded ends; and every plate — backplate,
  base, rose, escutcheon, hinge leaf — is pressed, its edge rounded over,
  and lies flat on its face (`MeshBuilder._plate`). Everything is within
  the outline the drawings draw, so the two views still draw one piece.
- **A tube is not twisted at its bends.** `tubeRings` carries each ring's
  turn on from the one before, where it used to choose each afresh from a
  fixed reference that swapped at every bend of a lever and joined each
  point to one a third of the way round.
- **Every piece is fixed to a face and casts its shadow there.** Each
  facet records the face it is fixed to (`Facet.mountAt`, `mountNormal`):
  the leaf's face for a plate, the plate's top for what stands on it.
  `Camera.project` carries every corner along the key light onto that
  face (`ProjectedFacet.shadow`), and the painter lays it down just
  before the piece — taking away the key light's share and no more, soft
  by the size of the light and the distance cast, and only on what can
  take a shadow: never glass, which lets the light through. A piece is
  painted plate first and what stands on it after, seen from the side it
  stands out towards.
- **The technical drawing stays a drawing**: the same simplified shapes in
  line and the sheet's colour, and a keyhole filled solid, as a hole is
  drawn (`Furniture.bores`, `DesignGeometry.boresOf`).

The pinned solids in `rendering_geometry_baseline_test.dart` moved on
purpose, and only their ironmongery: every other facet was checked
unchanged, shut and open. `test/app/ironmongery_is_metal_test.dart` holds
it: a door's lever and lock and a window's espagnolette, two different
objects; each placed from its opening and following it when a bar moves
and when the design is resized, every piece naming its opening and
swinging with it; each lying on its face and standing out of it; round
parts carrying unit normals on the side they face; and on the pictures a
lever lit smoothly with a highlight, casting a shadow on its door and none
on glass, and black, grey and silver in that order — with the drawing's
keyhole solid and its plate one flat colour. Flat shading, no shadow, or
the old ring frames each fail it.

### One space, and a depth for everything

The user's words: *the 3D model must stop looking like a collection of flat
planes; depth must be consistent and controlled; the front-facing design
dimensions remain the source of truth; define one coordinate system and use
it across the whole renderer.* So:

- **One coordinate system**, written down once at the head of
  `lib/domain/solid/depth_layout.dart`: **X** across and **Y** down the
  elevation — exactly the drawing's own, so every figure the user drew or
  typed goes into the solid unchanged — and **Z** out of the face the
  drawing is of, towards whoever is looking at it; the frame's drawn face is
  Z = 0 and the design runs back to Z = −`Design.depthMm`. Y runs down as
  the drawing's does rather than being turned up for the solid, because a
  second convention for one design is how two views come to disagree; the
  camera's eye space has the same turn of hand. Every part — frame, sash,
  bars, glass, panels, beads, ironmongery — is placed in it; none has a
  convention of its own.
- **One description of depth**, `DepthLayout`, and every figure in it a
  share of what holds the part: the frame's whole depth; the design's bars
  set back a tenth from both faces; a leaf set back from the face of
  whatever holds it and two thirds of its depth; **the bars and panes drawn
  inside a leaf standing in that leaf the way the design's own stand in the
  frame**; glass and panels centred in what holds them, as thick as they are
  made; the bead; the faces the ironmongery stands out of; a sliding panel's
  track. `MeshBuilder` hands a `DepthBand` down the tree — the frame's to a
  main division, a leaf's to its panes — where it used to hand the frame's
  depth to everything. That was a real fault: a glazing bar inside a sash
  was measured against the frame, so it stood proud of the sash, and the
  panes of a divided sash sat off its middle; the sliding tracks borrowed a
  made-up depth to get their leaves the right size. Glass and panels also
  had two rules each, one for a fixed light and one for a leaf; there is one.
- **Depth never moves a point on the face.** Every point the solid has on
  the face is where the drawing puts it at every depth; a panel's eased edge
  is a size (`panelArrisOf`), not a share of how thick the panel is, which
  it had been — the one place depth reached the face.
- **Glass is as thick as glass is**: a sealed unit of two 4 mm sheets with
  a cavity between them (`DepthLayout.litesOf`), each sheet green on its
  edge, the cavity closed round the edge by a dark seal — not a block of
  glass as deep as the unit. A unit too thin for a cavity (a narrow sliding
  track) is one sheet. A line of sight crosses four faces, and each takes
  its share of what the glass lets through and reflects
  (`Facet.glassFaces`, `Shading.of(glassFaces:)`), so the unit is exactly
  the glass the user chose — letting through and reflecting what a sheet of
  it does, not washing out white for having more faces.
- **A glazing bead holds every unit, from the room.** It is the frame's
  material (`FrameProfile.bead`, `FacetRole.bead`), runs from the unit's face
  to a little short of the frame's or the sash's, and covers the glass's
  edge by `beadWidthOf` the frame's profile — `DesignGeometry.beadAround`,
  the one line the solid and the drawing both use. The room is on the face
  the drawing is of for a design seen from inside, so a window's
  elevation draws the bead's line (`beadLineOf`) and a door's does not. Like
  the hinges, the side it is on is the one other thing the kind decides:
  `the_face_we_are_looking_at_test`, `the_kind_does_not_touch_the_inside_test`
  and `the_drawing_is_of_one_face_test` say so and require its footprint on
  the face to be identical either way, and the drawings' difference to lie
  on its line and nowhere else.

`test/domain/depth_is_consistent_test.dart` holds it: every corner within
the outline and every part but the ironmongery within the frame's depth;
the face identical at 60, 70 and 110 mm and the frame exactly as deep as
asked; the design's bars, the sash, a bar inside the sash and the sash's
panes each in their own band, and a fixed light's glass centred in the
frame; the sliding panels on two tracks that do not overlap; each unit two
sheets, a cavity and a seal, with four faces of glass; the bead on the
glass, on the room side, between the glass's edge and its line; the lever
out of both faces of a door and its hinges behind, the window's handle out
of the face you stand at; and turned, the frame's side as wide on the
screen as the frame is deep — twice as deep, twice as wide. Placing a
sash's bars against the frame again, or glass as one block, fails it. The
pinned solids moved on purpose; the designs' fingerprints did not, and
every point the solids had on the face is still there.

### The camera

The user's words: *the model may be correct, but presentation also
matters: orbit, zoom, pan, reset and fit; a default view that presents the
design attractively and clearly, without an extreme perspective; an
orthographic option for technical inspection; the model fitted to the
viewport without the user zooming to find it; and camera movement never
modifying the design.*

- **The first view is a product photograph** — `Camera.presentation`:
  turned 28°, so the depth is seen while the face is still read whole;
  10° above the middle, as somebody stands in front of it; and a long lens,
  the eye five times the model's size away, so the near jamb of a door is
  barely taller than the far one. A short lens is what makes a door lean
  out of the picture. **Reset** returns to it, in whichever projection the
  user has chosen.
- **The model is fitted to the view without being asked**, by
  `Camera.framing`: centred on the model as it is seen, and as close as lets
  it fill `Camera.framedShare` of the view in whichever direction is
  tighter — of the view's own shape, not a square, so a door fills an
  upright phone's height and a wide window a laptop's width — and fitted
  between the controls over the top and the foot of the view
  (`ModelView.controlsTop`, `controlsBottom`), so nothing is ever under a
  button. Only the camera's target and zoom change: where it looks from and
  how it projects are kept. It happens when the view opens on a design,
  when the view changes size, and when the design's own size does
  (`WorkspaceState.framedFor`) — and never over a view the user has turned,
  zoomed or panned, which is theirs until one of those changes, including
  across a trip to the drawing and back. **Fit** does it on demand from
  wherever they are looking.
- **The controls**: a drag turns it — down the screen rises over the model,
  as turning a thing in the hand tips its top towards you; two fingers,
  **Shift** and a drag, or the middle mouse button pan it — and the middle
  button only pans: the orbit gesture hears the same drag and is told to
  leave it alone — at the pointer's own speed at every zoom
  (the pan was converted without the zoom, so zoomed in five times the
  model ran five times faster than the finger); the wheel and a pinch zoom,
  the wheel **towards the pointer** (`Camera.zoomedToward`) so what is under
  it stays under it; and a row along the foot of the view — zoom in, zoom
  out, **Fit**, **Reset**. The named views stay under **More**.
- **Perspective | Orthographic** are side by side and named in the top
  corner of the view, always shown. Orthographic keeps parallel edges
  parallel, so sizes can be compared across the model; `Projection.parallel`
  is labelled so.
- **The camera is not the design.** It is the workspace's
  (`WorkspaceState.camera`), never written into the design, saved with it
  or undone with it, and the solid is built from the design alone.

`test/app/the_camera_test.dart` holds it: the first view turned a little,
from a little above, and a door's jambs within 8% of each other on the
screen; a door and a window framed — centred, filling the tighter
direction, inside the view — in a phone's, a laptop's and a square view,
in both projections, from a view turned and zoomed away, with the view's
direction and projection kept; framed clear of the control bands; parallel
edges parallel orthographically and not in perspective; a point zoomed
towards staying put, exactly orthographically and within a few per cent in
perspective. And on the real view: fitted the moment it opens on a phone
and a laptop; a drag turning it; Shift and the middle button panning it by
exactly the pointer's distance, zoomed and not; the wheel growing it about
the pointer; **Fit** keeping the direction and **Reset** returning to the
first view, both fitted; the projection one named tap away; a view the user
set surviving a trip away and refitted, from their side, when the window
changes size; and after every one of those, the design as it was to the
byte, nothing to undo, and the same solid built. Converting the pan without
the zoom again, or not fitting on opening, fails it.

### The studio lights

The user's words: *lighting that lets the user tell glass, panel, frame,
metal, rubber, depth and edges apart; controlled, not random colours; soft
highlights, readable shadows, material reflections and depth perception;
glass reflections visible without the glass going opaque; the frame's depth
and profile revealed; the panel shown to be solid; nothing cinematic —
clarity over effect.*

`Environment` (`lib/domain/solid/shading.dart`) is a product
photographer's studio, and every face is lit by it through one function,
`Environment.lightOn`, which `Shading.of` and the painter's cast shadows both
read:

- **A key light** — a large soft box over the viewer's left shoulder
  (`light`, `key`, `keySize`) — that lights **only what is turned towards
  it**. It used to light both sides of a face alike (`abs(n·l)`), so the two
  reveals of an opening were the same shade and the frame's depth was read
  only from its drawn edges.
- **A fill** from the other side and a little below (`fill`,
  `fillStrength`), weaker, so what is turned from the key is in shade and
  never in darkness.
- **Light from all round**, a little stronger from above than what the
  floor gives back (`ambient`, `ambientSpread`), so a sill's top reads
  lighter than a head's underside.
- **Strip lights** either side of the camera, seen only in what reflects
  them — two pairs (`stripsAt`), the nearer where a pane facing the design's
  front mirrors in the view a design is shown from, the further a little
  beyond, so the glass keeps a sheen as the model is turned. They were a
  single hard-edged pair placed for the old camera: in the presentation
  view no pane caught them, and a pane that did went white. Now each is a
  narrow core with long soft edges (`stripHalfWidth`, `stripEdge`) and less
  intense (`stripRadiance`): a gradient across the glass that never burns
  it out, with what is behind still showing through.
- **One size for the key light.** A highlight is the key seen in a surface,
  so it is never tighter than the light is wide
  (`Environment.sharpestHighlight`); and a shadow cast a distance away is
  soft by the same figure. The painter's cast shadows take away exactly the
  key's share of what the face they fall on is lit by
  (`ProjectedFacet.shadowNormal`).

All of it white: a grey surface is grey whichever way it faces, and a white
face turned to the viewer is white — exposed exactly as before, so every
finish reads as the colour it is.

`test/app/the_studio_lights_test.dart` holds it: the light neutral; a white
panel square on white; nothing below a quarter of white and nothing burnt
out, brightest to darkest within 3.5 : 1; towards the key lighter than away
and up lighter than down; a face turned from the key lit by the fill and the
room alone; highlights as soft as the light is large; on the model the
frame's faces turned to the key lighter than those turned from it, and its
tops than its undersides; glass in the presentation view carrying a sheen,
no point of it burnt out, and what is behind it showing through at the
brightest; and panel, PVC, metal and rubber in one grey told apart by the
light. Lighting both sides of a face again, or the old strips, fails it.

Two older tests were measuring something the old light happened to give.
`glass_looks_like_glass_test` compared the glasses at a point that lay in the
old saturating sheen: it now compares them where the pane is seen through,
by their distance in all three channels, because the grey-green and the
blue-grey tints differ in hue — they are six levels apart there in the
largest channel, before this change and after. And
`panels_look_like_panels_test` told the frame from a panel of the same
colour at the middle of whichever frame face was painted first; two grey
surfaces turned alike to the same light are, rightly, alike, so it now holds
that the frame is told apart by its form — the light changes across a member
from face to sightline to reveal — while the panel's middle is one even face.

### The studio and the floor

The user's words: *the background should make the model easy to inspect —
a professional CAD and product visualisation environment; no distracting
scenery, no photographs, no fake room; a subtle ground plane or controlled
shadow for position, scale, contact and depth, never hiding geometry; a
clean neutral background. **The ProFrame UI colour is not the same thing as
the customer's material colour.***

- **The studio is not the application's palette.** `Studio`
  (`lib/domain/solid/studio.dart`) is the backdrop — a seamless sweep,
  lighter above, with no horizon drawn on it — the floor's lines, the line
  between two faces of the model (`Studio.edgeInk`) and the monochrome clay
  (`Studio.clay`), and every one of them is a grey, red, green and blue
  equal. The house green and cream stay in the bars, the buttons and what
  is picked; nothing of them reaches the model, so glass shows grey behind
  it and not green, and an edge is dark and not the application's ink. The
  appearance chooses the light studio or the dark one and never supplies a
  colour: `Palette` no longer has a backdrop, a ground line or a model edge.
  The design's own finishes come from the design alone. What the model
  reflects is the studio too: the ground in `Environment.daylight` is a
  neutral grey floor, not warm paving.
- **The floor** (`Floor`) is at the model's lowest point, drawn before the
  model so nothing on it can lie over the design, and seen only from above
  — from beneath it would stand in front of the model, so it is not drawn.
  - **Scale**: a grid of ten-centimetre squares with a metre line every ten,
    laid from the model's own left side and its drawn face
    (`Floor.linesAcross`, `linesDeep`), so the model can be counted in
    squares. It fades out towards `Floor.reach` so the floor has no edge,
    fades as the floor turns edge on, and drops its ten-centimetre lines
    where they would crowd closer than a few pixels.
  - **Contact and position — the shadow is worked out, not painted on.** At
    each point of the floor, how much of the room's light from above the
    model shuts out (`occlusionAt`, ninety-six directions over the sky) and
    how much of the key light (`keyShutAt`, spread across the soft box so
    the shadow is sharp at the foot and soft further out), by rays against
    the model's envelope: its opaque members, each as the box it fills — a
    ring side by side, since light comes through the middle of it. **Glass
    lets the light through**, so the floor's shadow is the shape of what the
    design is made of. The floor is then lit by the same
    `Environment.lightOn` as every face, so a shadow is exactly as dark as
    the light it takes away. The room's share is kept per envelope, so
    turning the view costs only the key's.
- **The view is from where it says.** A positive pitch rises over the model.
  It was applied the wrong way round — the model's y runs down and the turn
  was written as though it ran up — so the first view looked up at the model
  from well below the floor and **Top** showed its underside; the drag was
  reversed to match, so the gesture feels as it did. `EyeSpace` is now the
  one transform the faces and the floor are both projected by.
- **Glass is kept off what is in front of it.** Seen from above, a tall
  pane's average depth is nearer than the full-height stile beside it, and
  the strip of glass running into the rebate was painted over the stile.
  Every face of glass is flat, so its own plane settles it exactly:
  `Camera.project` lists, for each, the faces painted before it that lie
  wholly on the eye's side of that plane (`ProjectedFacet.hiders`), and the
  painter clips the glass off them. `ModelPainter.faceAt` answers what is
  uppermost at a point with the same rule — asked of the face and not its
  id, because a divided opening's sash and the glass it held undivided
  share the section's id. Moving each pane in the order was tried first and
  is not to come back: it fought the depth sort and put the glass's edges
  over the handle.

`test/app/the_studio_test.dart` holds it: every studio colour a grey; the
backdrop grey on the screen in both appearances; a palette in garish colours
painting the model to the byte as the application's own does, in every
display style; the floor at the foot, seen from above and not from below;
the grid's squares laid from the model's side and face with a metre line
every ten; the shadow dark at the foot and falling away to nothing; glass
letting the key light through where a panel does not; the floor darker just
in front of the foot on the picture; not a pixel of the model's opaque faces
changed by the floor; the design and the mesh untouched; the first view from
above, **Top** looking down, the screen's down the camera's; and no pane
painted over the frame or a sash in front of it, from four views. Putting the
application's ink back on the edges, or taking the glass's clip away, fails
it. Two older tests moved with the camera, and say so where they assert: a
pane seen from above reflects the studio's even floor, so the light moving
across it is the strip light's sheen — more than 15 levels, not the 40 the
sky's horizon line gave from below; and the lever's shadow is asked whether
it falls on glass by the face, not the id.

### The technical drawing, drawn as one

The user's words: *the CAD view must look like a professional technical
drawing, not a Flutter canvas with some rectangles — geometric accuracy,
clean lines, hierarchy, dimensions, technical clarity; do not make every
line identical; do not change the geometry, only how it is represented;
dimensions correspond exactly to the saved geometry — if the design says
964 cm, do not display 1000 cm because it looks better.*

- **Weight is the rank of a line**, each rank a clear step from the next as
  a draughtsman's pens are (0.7, 0.5, 0.35, 0.25, 0.18 mm): `Cad.outline`
  (2.4) the outside of the frame; `Cad.profile` and `Cad.bar` (1.4) the
  frame's daylight edge, a leaf, a mullion or transom; `Cad.glazingBar`
  (1.0) a bar inside a section; `Cad.detail` (0.7) where glass or a panel
  meets what holds it; `Cad.annotation` (0.6) dimensions and the swing of a
  leaf, which is a reference line and drawn in the lighter ink so it never
  reads as a member; `Cad.hairline` (0.4) hatching, sightlines, the bead,
  centre lines and the grid. The table is on the constants in
  `cad_style.dart`.
- **Graphite inks, one ink for measuring.** Every line of the drawing is
  neutral grey — the drawing is a drawing, not part of the application
  round it — and everything that measures (dimensions, their names, a
  pane's size, the opening's tag) is one restrained slate blue, clear of
  the geometry and of the selection's gold. The squared paper is quieter
  than any line on it. `Cad.night` is the same drawing on a neutral dark
  sheet.
- **Technical lettering.** Tabular figures, so a column of sizes lines up;
  spaced capitals for what a part is (GLASS, PANEL, OVERALL, DAYLIGHT);
  and no boxes: `Cad.write` masks the paper round each letter, so lines
  run right up to the words. A chain's figure is written just above its
  line — just left of one running down, read up the page — where
  `DimensionLayout` puts it, which the tap targets read too, so what is
  written and what can be tapped are still one thing (see *The dimensions*). The dimension line
  runs a little past its witness lines and ends in the building drawing's
  45° slash, a step heavier than the line. The `<` or `>` the user drew is
  a drafting tag — the glyph in a thin circle — not a chip.
- **Every figure is the geometry**, written by `Units.label` to the
  millimetre: nothing in this pass rounds, snaps or tidies a number, and
  no line moved.

`test/app/the_cad_is_a_drawing_test.dart` holds it: each weight a clear step
from the next; on the pixels, across a window's side, the frame's outside
far heavier than its daylight edge and that far heavier than the sightline
and the bead; every line grey and the paper quieter than any of them; one
ink for measuring, readable and clear of the geometry and the selection; a
window 964.3 cm across written 964.3 cm; every tappable figure reading the
geometry it names; a figure's tap target on the figure, and the dimension
line unbroken under it — putting a box back behind the figures fails it —
and painting leaving the design as it was.

### What each part is made of, on the drawing

The user's words: *CAD should remain technical rather than photorealistic;
glass by a professional convention — a controlled tint, a hatch, a glass
symbol, an annotation — never a heavy opaque colour; the panel clearly
distinguishable from glass; the frame clearly structural; frame, glass and
panel told apart without being noisy; no arbitrary bright colours merely to
differentiate components.*

- **The frame is structure**, and so are a sash, a mullion and a transom:
  one flat light grey band (`CadColours.structure`) under their outlines,
  whatever they are made of. The frame's diagonal hatch was the same as a
  panel's, so a PVC frame and a PVC panel were drawn alike; structure and
  infill now differ by role, not by material.
- **Glass is the sheet's pale glass tint** with the two strokes across a
  corner; frosted glass is stippled and tinted glass a controlled shade
  darker (`CadIndication.shade`). Never a heavy fill: clear glass stays
  lighter than 0.8 luminance and the darkest glass above 0.45.
- **A panel is fine forty-five degree hatching on the paper.**
- **A drawing names a colour; it does not paint it.** `CadIndication` no
  longer has `ownColour` or `tint`: a panel's finish is written on it by
  name — `PANEL · BROWN` — from `PanelColour.of`, and never flooded over
  it, so a brown door and a white one are one drawing but for that word.
  The fills on the sheet are grey, paper and the glass tint, nothing else.
- **A ring is one path filled even-odd.** The structural band was first a
  path difference, and the web's renderer filled the whole outer outline
  with it, over the glass and the panels — which only the browser showed.
  The 3D view's glass clip (*The studio and the floor*) used a difference
  too and is now a clip for each face in front, the view with that face's
  outline cut out, even-odd; clips meet, so what is left is the view with
  all of them cut out.

`test/app/materials_on_the_drawing_test.dart` holds it on the pixels of a
door with frosted glass, a brown panel and a clear light, on paper and at
night: the frame's jamb the structural tone, the light the glass tint
evenly, the panel the paper with hatching across a twentieth to two fifths
of it, and the three different; a mullion the frame's tone; every glass
look light enough and clear glass lightest; every fill grey, paper or the
glass tint; the four panel colours one drawing with the lettering off, and
two different words with it on — flooding the panel with its colour again
fails three of those — and nothing in the design moved.

### The dimensions

The user's words: *dimensions readable, aligned, correctly positioned,
non-overlapping and associated with the correct geometry; one format, in
centimetres; overall width and height, opening width and height, internal
division dimensions and component dimensions told apart; never invented —
every measurement from the design's geometry; text not over the geometry;
readable when the design becomes complex.*

- **Each kind of figure has its side** (`DimensionSide`), as an elevation
  is dimensioned:

  | Side | Nearest the drawing | Beyond it |
  | --- | --- | --- |
  | Foot | main divisions across (DAYLIGHT) | overall width |
  | Left | main divisions down (DAYLIGHT) | overall height |
  | Head | the divisions inside each divided part, across (DIVISION) | each opening's width (OPENING) |
  | Right | the divisions inside each divided part, down (DIVISION) | each opening's height (OPENING) |

  Component dimensions — each pane's own `width × height`, what glass or a
  panel is cut to — stay written inside the pane. A row is named at its
  end. The overall row sits beside the drawing where there is no row of
  divisions on that side, not a row's width out from nothing.
- **Every figure is a section that is there**, measured
  (`DimensionChains.of`): the frame, a main division, an opening's own
  region, a pane a line made — `ChainRunOf` says which and `sectionId`
  names it. A part's divisions are chained only where its own bars are
  square (a diagonal in a sash makes that sash's panes unbandable and
  leaves everything else). **A measurement is written once**: a part whose
  runs are exactly another's — openings side by side at one height — adds
  no second row down the side. Parts that would overlap along a side go on
  rows of their own.
- **One layout, for the painter and the pointer** (`DimensionLayout`,
  `lib/app/canvas/dimension_layout.dart`). Rows are placed most wanted
  first — overall, divisions, openings, divisions inside parts — against
  everything already written and the drawing itself, so no figure or name
  overlaps another or lies on the drawing. A figure goes over the middle of
  its run; one too long for it stands just past an end, the dimension line
  carried on to it; where that would put it alongside another run of the
  row — two narrow lights side by side — it is staggered, a line further
  off over its own run, with a leader from the run's middle.
- **Readable at any size — by writing less, not by scattering.** A row
  that cannot be written legibly at this zoom — every figure over its run
  or just beside it and on the sheet — is left off until the drawing is
  looked at closer; the overall size always stays. So a phone shows the
  whole and the main divisions, and zooming in brings the rest; nothing a
  phone writes is anything a laptop does not. A phone keeps its width for
  the drawing, reserving room only along the head (`roomFor(rightToo:)`),
  and the CAD view refits when a row along the head or down the right
  comes or goes. A pane's own size and name are written only where they
  fit inside the pane, and the IN or OUT of a leaf steps along its stile
  clear of the leaf's ironmongery.

`test/app/the_dimensions_test.dart` holds it on a door, a window, a sliding
pair, three openings in a row, a door and window set and a window with two
lights a hand's width wide: each kind on its side and row; nothing open and
nothing divided keeping to the foot and the left; three openings at one
height one row down the right; no two runs on a row overlapping; every run
exactly the section it names, or the frame; every figure `n.n cm` or
`? cm` and the run to the millimetre; a line drawn in one part rewriting no
other part's figure; on a laptop and a phone no figure or name overlapping
another or on the drawing; a figure too long for its run beside it with its
line carried on, or staggered with a leader; every figure over or just
beside its own run and never alongside another; small showing fewer rows,
the overall always, nothing a laptop does not, and a laptop every row;
every figure tapped where it is written; and nothing in the design moved.
Letting a figure stand beside another run, or writing figures without
looking at what is already there, fails it. Three older tests moved with
it and say so where they assert: a line drawn in an opening adds that
opening's DIVISION row beside the drawing, so its pixels are allowed to
the right of it; the word IN steps round a lever, so the lever's own
outline is compared with the swing symbols off; and a diagonal in a sash
leaves the design's own chains as they were, counted by side.

### Openings and what is inside them, in the solid

The user's words: *complex designs — several openings, doors and windows,
glass and panel sections, dividers inside them — must keep their hierarchy
in 3D: a door with glass above and a panel below is FRAME ├── GLASS └──
PANEL, the glass looking like glass and the panel like panel; each opening
independent, never merged visually or geometrically; a divider inside an
opening stays inside it and is never part of the outer frame; glass → panel
on one section changes that section only; the 3D makes the hierarchy
understandable.*

Most of that was already true by construction — the solid walks
`DesignTree`, every leaf is placed by one transform, a pane's finish is its
own — and this phase holds it on complex designs rather than rebuilding it.
What looking at them found was the floor.

- **A leaf standing open cast a block of shadow.** The floor's shadow is
  rays against each opaque member as the box it fills, and those boxes were
  square to the model: a sash member swung out at an angle fills a box as
  wide as the whole swing, so under every open leaf the floor went solid
  black in a rectangle the leaf does not cover — which reads as a slab, not
  a door standing open. `Floor.under` now blocks each member **square to
  itself**: `Block.axes` is the member's own three directions, found from
  its faces (the direction its faces turn least, by the spread of their
  normals — `_axesOf`), and a ray is turned into those directions before it
  is tested (`Block._hit`). A member square to the model — everything in a
  shut design — has no axes and is exactly the box it always was, so a shut
  design's floor did not change. `Block.square` is the model-square box
  round a turned one, which is what the floor's extent and the quick
  whole-model test still use. The shadow of an open leaf is now the leaf's.

`test/app/openings_and_sections_in_3d_test.dart` holds all of it:

- a door of frosted glass over a brown panel — the tree's opening holding
  exactly the two panes and the line between them, which is not a bar of
  the design; the glass built as glazing and nothing of the panel
  transparent; on the pictures, clear glass changing with the studio behind
  it and the panel not changing at all;
- three openings under a fixed head — a door and two windows, each divided
  glass over panel, the first two either side of one mullion — sharing no
  part, every part built, a lock on the door alone; their sashes not
  meeting, and the mullion between them no opening's; swung, every part of
  every opening moving and nothing else, **each as one body** (every
  distance within an opening kept) and **not one body together** (distances
  from one opening to another changing);
- each opening's divider inside that opening's outline, set back behind the
  design's own bars in the leaf's depth, and never one of the design's bars;
- one pane made panel: that pane's facets changed and every other element's
  identical, facet for facet; on the technical drawing every changed pixel
  inside that pane;
- open, the floor round each turned member lit by most of the sky (at most
  0.4 of it shut out, where the square boxes shut out 0.8 or more), and shut,
  no member turned at all. Blocking the members square to the model again
  fails it.

### One design, three views, always in step

The user's words: *CAD and 3D always represent the same design — the visual
style may differ, but the width, the height, where each opening is and how
big, the internal dividers, which part is glass and which panel, and where
each component is must match; a change to the geometry or the material
updates both; a change of camera or of how it is shown changes no geometry;
no independent geometry for CAD and 3D — the saved design is the source of
truth.*

The structure was already one — `DesignGeometry`, `DesignTree`, a design
that is immutable so every edit is a new object — and this phase measures
it rather than trusting it. Measuring found three places where the views
did not say the same thing:

- **The model on the screen kept its old picture.** `ModelPainter.shouldRepaint`
  compared the number of faces and the first face alone, and a pane given
  another colour or glass, or a handle moved or recoloured, leaves both as
  they were — so the 3D view went on showing the design as it had been (the
  floor, new every build, usually hid it; with the floor off it showed). It
  now compares the picture face by face — where each is on the screen, how
  it is lit, what it is made of and in what colour — a pass far cheaper than
  painting, and compares what is highlighted by its contents.
- **A line that divides nothing was missing from the solid.** A line inside
  an opening or a light that stops short of the far side makes no panes; it
  is still the user's line, and both drawings drew it. `MeshBuilder` built a
  section's bars only when it had panes, so the solid left it out. The bars
  are now built first, whether or not they divide anything.
- **The drawing showed neither glass nor panel in the browser.** Its frame
  was a path difference, which the web's renderer fills as the whole
  outline, so the frame's colour lay over every pane — while every test
  canvas was right. It is one path filled even-odd now, as the technical
  drawing's rings are, and a scan keeps `Path.combine` out of both drawings.

`test/app/cad_and_3d_are_one_design_test.dart` holds it on four designs —
three windows under a fixed head, a window and a door between fixed lights,
the first with a mullion dragged and the width typed, and lines that divide
nothing in an opening and in a light. Each view is measured on what it puts
down: the solid by its facets, each drawing by the pixels that change when
one part is left out of the picture. And they are required to agree, to the
millimetre in the solid and within a line's width on the drawings: the
width and height; each opening's leaf and its ironmongery; every divider
inside an opening or a light; each pane glass or panel in all three — a
sealed unit or a panel in the solid, the glass tint or paper on the
technical drawing, its own finish on the drawing; and every handle and
hinge, a hinge round the back drawn as hidden detail and not at all on the
drawing of the face you stand at. Then: a divider moved reaches all three,
each drawing changing only inside its opening; one pane made panel changes
that pane alone in all three; the painter repaints for a recolour, a glass,
a handle recoloured and a handle moved, and not for the same design; and
eight cameras, every display style in both appearances, and the drawings'
layers and inks leave the design and its solid exactly as they were.
Taking back either code fix fails it, and so does moving the drawing's
ironmongery four pixels.

### Every edit reaches every view at once, and looking does no work

The user's words: *when the design changes — width, height, a divider
moved, an opening changed, a panel colour, a glass type, a component added
or removed — CAD and 3D update reliably, both, never one refreshed by hand;
a material change moves no geometry and a geometry change does not reset
materials; and the whole application is not rebuilt on every tiny
interaction, so the preview stays responsive.*

There is one design, in `WorkspaceState`, and every view is built from it,
so an edit is shown by every view with nothing to refresh. What this phase
changed is what happens *around* that:

- **A geometry edit split a pane's material.** A line drawn across a pane
  makes two panes of it, and `SectionBuilder._carryIdentityForward` gives
  the old pane's identity to one of them only — so the other was a
  continuation of nothing and was filled with plain clear glass: half of a
  pane the user had made frosted went clear the moment they divided it. A
  face cut from a section another face has taken now keeps that section's
  finish under an id of its own. Identity goes to one piece; what the
  ground is made of goes to every piece.
- **Looking is not work.** `WorkspaceState.work` is a token that is new
  whenever anything but a way of looking changes, and the same while only
  the camera, its framing, the leaves' swing, the view mode or the
  floor do. Every widget but the model view — the workspace, its bars, the
  panel, the parts, the drawing and the technical drawing — watches it
  through `WidgetRef.watchWork`, so turning the model (a state a pointer
  move) and playing the swing (a state a frame) rebuild the model view and
  nothing else. `copyWith` treats anything it is given except those five as
  work, so a field added later is work unless it is added to them.
- **The solid is built from the design and the swing, and nothing else.**
  `ModelView` keeps the mesh while the design object and the swing are the
  same, and the floor's shadow for as long as it keeps the mesh; the camera
  only projects what is there. They were both built again for every
  pointer move.
- **A frame of the model costs a third of what it did.** Measured on three
  divided windows with their ironmongery, recording a frame fell from about
  210 ms to 63. A curved facet is shaded on a grid as fine as it is large
  on the screen (`_smoothCell`, four pixels, up to the old six by six) — a
  knuckle's facet a few pixels wide is lit at its corners, a lever filling
  the view keeps the whole grid. And a piece of ironmongery's shadow is
  kept to what can take it by a mask — the solid faces laid in, the glass
  over them cleared out, in the order they were painted — where it was one
  clip made by joining and cutting paths, which cost more than painting the
  rest of the model and which the web's renderer does not take the way the
  others do. The picture is the same; every test of how the model looks
  passed unchanged.

`test/app/live_updates_test.dart` holds it: on the real app, with each of
Draw, CAD and 3D on the screen in turn, the width, the height, a divider
moved, an opening turned outward, a panel recoloured, a glass changed, a
hinge added and taken away, and a line added inside a pane and deleted —
each shown by the painter on the screen the moment it is made, from the
design as it now is. Through the workspace, eight geometry edits — width,
height, a divider moved, a mullion dragged, an opening turned, three
hinges, the depth, the sheet read again — each change the geometry and
leave every part's finish as it was; a line across a frosted pane leaves
two frosted panes; and four material edits leave the geometry to the byte.
Ten ways of looking keep the work and the design, and an edit, a
selection, a tool, a view and an undo each make new work; and on the real
app a drag of twenty moves, a swing and a display style rebuild the model
view and not the workspace, its panel, its parts or its tools, with the
solid built once for the drag. Filling a split pane afresh again, watching
the whole state from the panel, or building the solid for every move each
fail it.

### Four ways of looking at the model

The user's words: *useful viewing modes for professional users — Technical
CAD, Shaded, Material Preview, Realistic 3D; all modes use the same
geometry; changing mode must not modify design data; the selector modern
and unobtrusive, not covering model space unnecessarily.*

`ViewMode` (`lib/app/viewer/view_mode.dart`) replaces the old display
styles, and each mode is a way of painting the **same projected faces** —
`ModelPainter` is handed one list of faces and the mode decides only how
each is painted:

| Mode | What it shows |
| --- | --- |
| **Technical** | A line drawing of the solid, on the technical drawing's own paper and inks (`Cad.paper`, `Cad.night`): glass its tint, the frame, a sash and a bar their structural tone, everything else the paper, filled flat so what is behind is hidden. An edge is drawn only where the form turns — two faces more than twenty degrees apart, or a face with nothing seen beyond it (the outline as seen, and where one part butts another) — ranked as the drawing ranks its lines (`ModelPainter.penOf`: the frame heaviest, a sash, a bar, the ironmongery, glass and panel finest). The overall width, height and depth are written on it (`overallSizesOn`). No floor. |
| **Shaded** | Faces in one colour (`Studio.clay`), lit, with their edges: the form and its depth. The floor's grid; no shadows. |
| **Material** | Every part in its own material — glass seen through with its sheen, the panel matte and set back, the frame its profile, the metal bright — with its edges, and no shadow cast over any of it, so each is seen as itself. |
| **Realistic** | The most the renderer does: the materials, the ironmongery's cast shadows, the floor's shadow, no drawn lines. What the view opens in. |

The wireframe is kept as a fifth, offered under **More**.

- **The figures are the design's.** Technical writes the frame's own width
  and height, to the millimetre as the technical drawing does, and `?`
  where the size has not been given (`Measurements.figure`), and the
  design's depth — each on the edge it measures, placed by the very
  `EyeSpace` the faces are projected by. The depth goes along the foot of
  the side that is seen and is left off square on, and the height goes up
  the other side, so they never meet.
- **A mode is a way of looking**, like the camera: `WorkspaceState.viewMode`
  is never written into the design, saved or undone, and it is one of the
  looking fields, so choosing one keeps the work and rebuilds only the
  model view.
- **The selector is in the top band the model is framed clear of**
  (`ViewModeSwitch`), across from Perspective | Orthographic, in the room
  left beside it: every mode named side by side where it fits, one button
  naming the mode that opens the list where it does not — a phone — and
  the mark alone where even that is too wide. The room is measured from
  the labels as written, never guessed. A tap on the chosen mode, or on
  the chosen projection, is taken by the switch: it used to fall through to
  the model and put down whatever was picked.

`test/app/view_modes_test.dart` holds it: the model at the same place and
size in all five and each a different picture; painting every mode in both
appearances leaving the design and the solid as they were; the figures the
frame's own and `?` where not given, standing on the edges the camera puts
them on, the depth left off square on and the labels unchanged as the view
turns; the pens ranked; the paper, the glass tint and the structural tone
exact on the pixels, with no floor; the figures written only in Technical;
a brown panel grey in Shaded and brown in Material and Realistic; the
floor's shadow in Realistic and not in Material; glass seen through in
both; and on the real app, at a laptop and a phone, the selector in the
band and clear of the projection, every mode chosen showing the same faces
with the design, the work and the undo history untouched — a tap on the
mode already chosen included — and the wireframe under More. Making Shaded
show the finishes, or letting the chosen mode's tap through, fails it.

### The polish, and what it turned up

The user's words: *a visual polish pass — spacing, typography, toolbar,
icons, camera controls, dimension readability, materials, shadows,
reflections, glass, panel, frame, handles, hinges, selection states,
active tools, zoom, reset and view mode controls; clarity, precision and
manufacturing usability, not gradients, animations or glow; the UI keeps
ProFrame's colours and the model the customer's materials.* Looking at every
view on a phone and a laptop found most of it already right, and four things
that were not — three of them bugs a screenshot shows and a test did not:

- **One set of view controls.** The drawing had a column with a fit, the
  technical drawing a column with no fit at its top, the model a row with a
  fit and a reset. `ViewControls` (`lib/app/canvas/view_controls.dart`) is
  now the one row, in the one corner — the foot of the view, on the right —
  of all three: zoom in, zoom out, fit, and reset where there is a view to
  reset to (the model's first view).
- **A press on zoom was a press on the drawing.** The technical drawing's
  buttons sat inside the drawing's own pointer handling, so pressing one
  put down whatever part was picked. The controls, and the status bar
  under More, are laid over the drawing now, never inside it.
- **The first zoom was undone.** The technical drawing worked out the room
  for its rows of figures from its size *before* layout had set it, so the
  refit that followed the first layout waited for the next rebuild — which
  was usually the user's first press on zoom, and put it back. The room is
  worked out inside the layout now, where the size is known.
- **The drawings refit when their room changes.** A window grown from a
  phone's width kept the phone's framing, the design small in one corner.
  The drawing and the technical drawing are fitted again to the room they
  have, as the model always was, unless the user has moved the view —
  a view is still as fitted when it is the fit of its old room
  (`ViewTransform.isSameAs`).
- **What is picked on the model is outlined along its outside.** It was
  outlined round every facet it is built from, which drew a sash as a heavy
  band of gold rings, one for every arris. Now only the edges where the pick
  meets what is not picked, or turns away from the eye, are drawn — the
  painter paints the far side of every part too, so turning away is the
  silhouette (`ModelPainter._outsideOf`). It is **never tinted**: a tint
  over a finish reads as another finish, anthracite went olive, and over a
  sealed unit it gathered once for every face of the glass. The same test
  of facing puts the technical mode's outline pen on the silhouette.

**The materials were left as they are, on purpose.** On one window holding
an anthracite aluminium frame, clear glass, tinted glass, a white panel, a
silver handle and hinges, each already reads as itself — frame `56 59 61`,
clear glass `186 197 199`, tinted `85 91 90`, panel white, handle
`133 145 152` with a highlight across it, hinges `102 111 118`, satin where
the handle is polished — so none of the material figures was touched.
**Bars keep their own finish**: a mullion is not repainted because the frame
was, so a coloured frame with white bars is what the design says until the
user colours the bars too.

`test/app/materials_read_as_materials_test.dart` is the phase's visual
test, on that window seen square on and as first shown: every part on the
screen; each a colour of its own, the closest pair clear by more than
twenty levels; the glass seen through — changing with the studio behind
it — where every solid part is the same to the byte; the tinted glass
darker than the clear; the handle a metal with a highlight and a shade
across it and the panel one even matte face; the handle catching more
light than the satin hinges; nothing of the application's green or gold in
the model; and every facet the colour the customer gave its part.
`test/app/controls_and_selection_test.dart` holds the rest: the one row in
the same corner of all three views at a phone and a laptop, each button
doing what it says; a press on any of them leaving the pick picked, the
design as it was and nothing to undo; the drawing and the technical drawing
refitted when a phone's window becomes a laptop's and left alone once
zoomed; and the frame picked drawn as a line or two across its jamb, not a
band, with the face between them and the middle of a picked pane not
changed by a pixel. Outlining every facet again, or leaving the drawing's
framing behind on a resize, fails it.

### The final quality assurance

The user's words: *a complex real design — outer frame, multiple openings,
clear glass, tinted glass, panel, internal divider, door handle, window
handle, hinges, dimensions, different frame and material settings — and
every claim about CAD, 3D, the materials and the geometry verified on it;
glass, panel, frame, metal and rubber side by side must not look like
rectangles of different colours; fix only what this project broke.*

`test/final_cad_and_3d_quality_test.dart` is that, the whole system measured
at once on one design drawn stroke by stroke (`mixed.theScreen()`): a clear
fixed light, a window opening of clear glass over a brown panel, a tinted
fixed light, a door opening of tinted glass over a brown panel, an
anthracite aluminium frame, white uPVC mullions, an aluminium divider in
each opening, a bronze lever and lock, a silver espagnolette, black hinges
and a dimension the user drew. Its groups follow the brief's own numbers:

- **CAD 1–11**, on the drawing's pixels: the frame, every bar and every
  section where the design has them and the corners inked; every run a
  section that is there, written to the millimetre; the frame's outside
  unbroken; the outline heavier than a divider inside an opening; glass a
  cool tint, a panel hatched paper never flooded with its brown, the frame
  the structural tone, and no fill a saturated colour; each divider inside
  its own opening and its opening's in the tree; moving one opening's
  divider changing the drawing inside that opening and nowhere else; three
  lines across a jamb, outside, sightline and daylight; and no figure on
  another or on the drawing.
- **3D 1–16**: the frame the whole depth with sides and reveals; the panel a
  slab with a front and a back, opaque; every unit two sheets of glass and
  a rubber seal; the frame aluminium and every piece of ironmongery a
  metal; handles standing out of their leaves and hinges with thickness;
  on the picture, glass seen through and carrying the light across it,
  the panel even and the same whatever is behind it, a highlight and a
  shade across the handle; shadows on the floor and from the ironmongery;
  and through the app, the model turned, zoomed and fitted.
- **The material board** — the brief's most important test. Five pieces of
  one shape: glass, panel, frame, metal and rubber, the first four in
  *one* colour, so only the materials can tell them apart, standing on the
  studio's floor as every model does. Each is told from every other by a
  signature of what it does — the colour it shows, whether what is behind
  shows through, how the light varies across all of it that is seen.
  Glass is seen through, the floor's lines running on behind it, and
  carries the light across it; the panel is opaque and one even face; the
  frame is opaque and its reveals take the light unlike its face; the
  metal is opaque and the light varies across it more than across any
  painted face; rubber reflects the least and carries no highlight.
  **Rubber is the one piece in its own colour**, the seal's, because its
  darkness *is* its colour: square on, a matte grey rubber and a matte grey
  panel take the light identically, as they would on the bench, and the
  rubber the model builds — the seal round every unit — is dark.
- **Geometry safety**: the bars where drawn and the dividers where placed;
  painting every view, in every mode, from four sides and in either
  appearance, leaving the design, its geometry and its solid as they were;
  and a change of glass, colour or frame material moving no geometry.
- **Regression through the app**: the design kept for a customer, opened
  as saved, drawn in CAD and 3D from the same object, turned, zoomed and
  fitted with nothing to undo, a pane made frosted, saved, the app opened
  again from nothing but the device, the material and the geometry back,
  the dimension back, and the customer and their designs as they were.

**What it turned up, and the one change it made.** A flat face of metal was
shaded once, as one colour, so on the board a metal plate was a painted
card: glass was shaded point by point along the eye's ray because what it
shows is what it reflects, and metal is the same. `ModelPainter._mirrors`
sends every flat face of metal — metallic a half or more, not a thin side —
through `_pane`, opaque, on a grid as fine as the face is large on the
screen (`_mirrorGrid`, a point every `_smoothCell` pixels, at most a pane's
grid). Round metal already had its own (`_smooth`). Nothing in the geometry
moved and every other test of how the model looks passed unchanged; taking
it back fails the board's metal and rubber.

## Geometry correction and angled designs

`docs/geometry_audit.md` is the audit written before this work began. It
traces drawing → geometry → saved design → CAD → 3D through the code, and
records five faults found by running the reading on hand-drawn shapes:

- the weld undoes the axis snap, so a rectangle drawn about 1° out comes
  back with no square side — **fixed**, see below;
- the weld turns two level transoms into two sloped ones — **fixed**;
- a drag in CAD is undone by the next reading, because the ink is not
  moved — **fixed**, see *An edit on the technical drawing is an edit to
  the drawing*;
- a handle on a raked leaf is placed outside the leaf, because hardware is
  placed from the opening's bounding box — **fixed**, see *An angled design
  keeps its geometry*;
- sizes and the CAD snaps exist only for horizontal and vertical members —
  sizes **fixed** by the side figures (*Dimensions on an angled design*),
  snaps **fixed** for angled designs (*Snapping to the geometry as it is*).

### Where the hand's inaccuracy comes out

```
strokes ─ StrokeFitter.fit ─► raw runs ─ GeometryNormalizer ─► runs
  ─ PlanarSubdivision ─► frame, bars, sections ─► Design (canonical)
  ─► DesignTree / DesignGeometry ─► Draw, CAD, 3D
```

`GeometryNormalizer.normalizeStandardGeometry`
(`lib/domain/recognition/geometry_normalizer.dart`) is the **one place** a
drawing is cleaned, and `SketchInterpreter.interpret` calls it between the
fit and the subdivision with every run of the drawing at once. It is not a
second geometry system: it holds nothing, it returns the runs the design is
built from, and the design is still the only canonical geometry, so the
correction reaches the sheet, the technical drawing and the solid because
all three read the design. Nothing in it draws or knows there are views.

It took over the steps the reading used to do as separate passes, and put
them in one order so a correction stays made:

1. **Square** a run within `Tol.axisSnapDegrees` of an axis
   (`StrokeFitter.straightened`, still the one rule, shared with
   *Pause to straighten*), and mark it `DrawnRun.squaredTo`.
2. **Carry onto the ink** an end drawn onto another stroke
   (`_ontoWhatTheyWereDrawnOn`, moved here unchanged).
3. **Join** ends drawn a little apart (`_joined`, the old weld).
4. **Keep square** (`_keptSquare`) — new. Joining averaged a level run's end
   with an upright's, which is on neither; now the joined points a level run
   runs between are given one height, and those an upright runs between one
   distance across, each the average of its group. A point no squared run
   ends at is not moved, so a slope keeps its angle.

Phase 4 put two more steps between joining and keeping square — see *The
standard rules* below — and keeping square now squares what either marked.

**What it may not do is the table under *Where the line falls*.** A run
further off an axis than five degrees keeps its angle exactly unless the
standard rules below say the drawing round it is square; nothing is made
equal or symmetrical; no run is added; an outline drawn open is not closed;
and every run comes out in the order it went in, from the same stroke, so
the reading still pairs it with the bar it made last time.
`NormalizationContext` carries the design's category — the user's own
answer about what is being built, which the lean rule reads — and the ink.
Every change is a `GeometryCorrection` (kind, stroke, before, after), and
`Interpretation.corrections` hands them on.

**Making the geometry exact found a fault underneath it.**
`Segment.crossing` called two segments parallel when their cross product
was under an absolute `1e-12`, and two collinear edges in millimetres
carry rounding noise far above that: the body of a mullion lying exactly
along the frame's daylight edge was read as crossing it steeply a long way
off, and the light beside the mullion came back with a corner six
millimetres inside the mullion's face. Parallel is now a share of the two
lengths — the sine of the angle between them.

`test/domain/geometry_normalizer_test.dart` holds it: an already correct
rectangle back exactly with nothing corrected, in the normaliser and read
as a design; a rectangle drawn a degree out square with every corner still
joined and within the hand's wobble of where it was put; two transoms a
hand apart level and still meeting; every change recorded against its
stroke; a head at seven degrees, a gable and a diagonal glazing bar left
exactly as drawn; unequal lights left unequal; the same drawing giving the
same runs in the same order; a hand-drawn window with an opening, a line
inside it, glass over a brown panel, hinges, a handle, a dimension, its
design id and its customer id all the same after a second reading; and the
collinear edges and the square sections the crossing fix is for. Taking the
keep-square step out fails four of them.

### The standard rules

The brief: *a rectangle drawn with a leaning right side is still a
rectangle* — in a door, a window, a sliding set or a door & window set,
slightly tilted sides come back upright, a slightly tilted top level, sides
that should be parallel parallel, a slightly inaccurate corner square, and a
closed outline closed; *but do not make every design rectangular, and do not
destroy intentional geometry.* What is a lean and what is a slope is read
from the category, the angle, how far the ends would move, the size of what
the line bounds, the lines round it, the snap that already exists, and what
the user said. Two steps were added to the normaliser, after joining:

- **Trim a corner drawn past** (`_trimmedAtCorners`, `Tol.overshootFraction`,
  `CorrectionKind.trimmed`). Two runs whose ends meet no other end, which
  genuinely cross within a tenth of each one's length of those ends, are
  trimmed back to the crossing — the head run on past a jamb, the loop
  closed past where it began. Left alone the stub came back as **a bar
  lying along the frame** that nobody drew. *Trimming a line drawn past its
  corner* is cleaning, in every category. An end that stops *short* of a
  line further than the join reaches is not touched: that is an outline
  left open, and *A side left open* still asks about it.
- **Square a lean** (`_leansSquared`, `Tol.leanDegrees` = 10,
  `Tol.leanShare` = 0.3, `CorrectionKind.leaning`), **in a standard design
  only** (`NormalizationContext.isStandard`). A run between five and ten
  degrees off an axis is squared when the drawing round it says it was
  meant square — **the side opposite it is square** (a run squared to the
  same axis alongside at least half of it), or **it turns a corner from a
  square side** (it shares an end with a run squared to the other axis) —
  and squaring it moves its far end by no more than three tenths of the
  width of what it bounds: the gap to that opposite side, or the length of
  the side it turns from. It is only marked; keeping square then squares it
  with every corner still joined, so the outline stays closed.

Whatever the user drew on purpose is left: past ten degrees, a slope in any
category; in an **Angled / Asymmetrical** design any slope past a hand's
five, because choosing it said slopes are meant; a narrow light drawn
tapering, whose lean is half its width; a rectangle drawn turned
altogether, which has no square side to go by — a lean is never squared on
the strength of another lean; a gable and a diagonal bar. **A seven-degree
head in a window is now a lean, and squared**, where Phase 2 kept it; a
slope that shallow is meant in an angled design, and kept there.

`test/domain/standard_normalization_rules_test.dart` holds the brief's five
tests, each in all four standard categories, in the normaliser and read as
a design, as one stroke and side by side: a perfect rectangle untouched in
every category; a right side leaning 3° and 7° upright between where its
ends were drawn, the others where they were, and kept in an angled design;
a head tilted 3° and 7° level, and one at 12° kept everywhere; a corner
with ends apart joined, one drawn past trimmed with no bar left, a loop
closed past its start trimmed, a corner off square square, and a door with
no sill still asked about; jambs leaning opposite ways, one slightly and
one further, and a parallelogram, each a rectangle. And what is not made
rectangular, as above. Switching off the lean, the trim or the category
each fails it.

### Telling a wobble from a slope

The user's words: *teach the normaliser to distinguish small accidental
deviations from meaningful geometry — not "any angle = automatically
rectangle"; not an arbitrary angle without the scale of the geometry:
the coordinate system, the object's dimensions, the drawing's scale, the
actual distance error, the category, the snapping that exists.*

So the reading no longer squares by angle alone. `Deviation.of(segment,
span)` (in `geometry_normalizer.dart`) measures each run in the drawing's
own millimetres: its angle off the nearest axis, **how far it is actually
out** — one end against the other, across that axis, which is exactly what
squaring it would move — and the size of the whole drawing, because the
hand's error scales with what it is drawing. Its `kind` is one of four:

| Kind | When | What is done |
| --- | --- | --- |
| `none` | exactly level or upright | nothing |
| `wobble` | out by no more than the hand's precision (the weld, a hundredth of the drawing) at up to `Tol.leanDegrees`, in every design; or, **in a standard design only**, within `Tol.axisSnapDegrees` and out by no more than `Tol.wobbleShare` — a twentieth — of the drawing | squared |
| `lean` | further out than a wobble, up to `Tol.leanDegrees` | squared in a standard design only where the drawing round it is square (*The standard rules*); kept in an angled one |
| `slope` | further off than any lean | kept exactly, everywhere |

What that changes: five degrees is a wobble on a rail and a lean on a jamb
the height of a tall narrow drawing, so an **Angled / Asymmetrical** design
now keeps a long side drawn up to five degrees out when it is a visible
twentieth of the drawing, where it used to be squared — angled designs are
still not made rectangular; a short bar drawn seven degrees out by less
than the hand can place a line is squared, where the angle alone kept it;
and the same drawing at any scale is read the same. **The pause to
straighten and the straight-line tool still square by the snap angle
alone** (`StrokeFitter.straightened`): that is the user asking, not the
reading deciding.

`test/domain/tolerance_based_detection_test.dart` holds it: a side drawn
2, 10, 25, 60, 120, 140, 200, 280, 350, 600 and 1000 mm out, each measured
and each done with in every category — tiny ones corrected everywhere, the
leans in a standard design and not an angled one, the slopes kept exactly
— with each correction recorded as what it was, and the same read from the
sheet; the progression read the same at a tenth and ten times the size; a
short and a long bar at one angle, one a wobble and one not; a tall narrow
design's jamb kept in an angled design while a rail in it is squared;
the same lean squared across a wide light and kept on a narrow one; slopes
of 12° to 45° kept in every design; and a square line no deviation at all,
while the pause to straighten still squares by angle. Putting the angle-only
rule back fails three of them.

### A standard rectangle, and whose figure it is

The brief: *a door, a window, a sliding set or a door & window set drawn as
a slightly inaccurate rectangle — left side 200 cm, right side about 185 —
comes back as a rectangle, its alignment, parallels, corners and closure
corrected and its dimensions consistent. Do not blindly choose the larger
dimension, do not blindly choose the smaller, do not invent one: use the
existing dimension system and what the user entered, so the geometry, the
dimensions, CAD and 3D agree.*

The squaring is the rules above. What this added is **which figure the
corrected side settles at**:

- **A figure the user stated decides it.** Every stated dimension square
  to an axis pins the coordinate it measures at the run ends within the
  join tolerance of its two ends (`GeometryNormalizer._pinned`,
  `DrawnRun.pinA`/`pinB`, `SizePin`), and the pins ride with those ends
  through every step. The axis snap squares a run to its pinned figure
  rather than about its middle, and keeping square gives a joined group
  its pinned value rather than its average (`_Groups.settled`). So the left
  side stated 200 cm gives a rectangle 200 cm high, the right side stated
  185 cm one 185 cm high, and a figure drawn short and typed as 200 scales
  the drawing (`DesignScale.toDimension`, as ever) and then gives exactly
  200. The dimension's ends are on the frame's corners afterwards.
- **Two of the user's figures that disagree are not overruled.** A run
  whose two ends are pinned apart (`DrawnRun.pinnedApart`) is not squared,
  by the snap or as a lean, and a joined group pinned to different values
  keeps each point where it is. Both sides stated, 200 and 185, is a head
  the user has said slopes, and it is kept; both figures stay true.
- **Where nothing is stated, the side settles at the line that best fits
  the ends as drawn** — the average of the group, neither the larger nor
  the smaller — and **its size is `?`** until it is given, on the chains,
  the panels and the form, as every size is (*Sizes are asked for, never
  guessed*). That is a proportion, not a dimension.
- **A stated figure that measures the whole frame is that size given.**
  `Measurements.withStatedOverall`, run after every reading and when a
  dimension's value is typed, marks the overall height or width known when
  a stated dimension square to that axis runs between the frame's two
  extremes and still measures what was typed. Before it, the chain beside
  the user's own *200 cm* said `?` and the form asked for the height again.
- **Sizes given in the form outlast every reading**, as they did:
  `Measurements.keepAfterReading` keeps the frame they sized.

`test/app/standard_rectangle_correction_test.dart` holds it on the brief's
own rectangle, drawn by hand 90 and 200 cm wide with every side a little
out, in a door, a window, a sliding set and a door & window set: nothing
stated gives a rectangle at neither side's height, the fit of the ends as
drawn, with its height and width `?`; the left side stated 200 gives 200
high with the right side the same, the height known and written *200 cm*,
the width not, and the figure's ends on the corners; the right side
stated 185 gives 185; a figure drawn short and typed 200 gives exactly
200; both stated is kept as drawn with both figures true; and sizes given
in the form survive a second reading and a mullion drawn afterwards —
each time the frame, the technical drawing's overall chain and the
solid the same height, and no stated figure in conflict. An angled design
keeps its slope whatever is stated. Taking the pins out fails sixteen of
them, and taking `withStatedOverall` out eight.

### Correcting the frame keeps the hierarchy

The brief: *if the outer frame is normalised, child geometry stays
attached — the opening correctly related, the glass and the panel inside
it, the divider inside it, the handle and hinges attached; internal lines
stay children of the opening and never become root-level geometry.*

Through the reading it already did, because the hierarchy is in the model
rather than in coordinates: an opening is its mark's region, so it is
found again in the corrected frame; a line put inside it has no stroke to
be re-read from, or is a child the reading does not re-read; its panes are
cut from the opening's own outline every rebuild; the hardware is worked
out from the leaf every rebuild; and a section whose outline changes
carries its contents with it (`SectionBuilder._carryContents`). A line
drawn on the sheet inside the opening joins it and is squared like any
other.

**The sizes form did not**, and testing it found why. `Measurements.stretch`
moved every bar by its axis map — lines inside an opening included — and
`SectionBuilder.rebuild` then carried those same lines from the opening's
old outline to its new one. A child placed twice, and once by a map that
does not follow the frame's inner face or a bar's, came off the sash: with
the width given, the line in an opening ended four millimetres short of it
at both ends; with the opening then given its own width, it ended nine
centimetres short, divided nothing, and **the glass and the panel were
gone**. That is *counting it twice* again. `stretch` now leaves a line
inside a section to the rebuild's carry wherever that section changes, and
stretches it by the map only where its section did not — where it is the
bar the size moves, or bound to one.

`test/domain/normalization_keeps_the_hierarchy_test.dart` holds it on a
door, a window and a door & window set drawn by hand with the head sloping,
a mullion and a `>`: the first reading correcting the frame, then a line
inside the opening, glass above and a brown panel below, a handle and
hinges; read again; corrected again by a figure the user states, the
opening growing with the frame; a line drawn on the sheet inside the
opening, leaning and stopped short, squared and joined and staying the
opening's through another correction; and the sizes given in the form.
Each time: the frame square, the opening bounded by the frame's daylight
and the mullion and holding its mark, the mullion the only line of the
design, every line inside the opening its child and within it, its panes
its children and within it with the glass above and the panel below,
every piece of ironmongery its child and on its leaf, `contentsOf` holding
all of it, and the solid's glass and panel within the opening. The old
`stretch` fails the sizes form for all three.

### Correcting the geometry keeps every material

The brief: *geometry normalisation must not modify material assignments —
glass type and appearance, panel colour and material, PVC, aluminium, the
frame's material, the handle, the hinges, metal, rubber. Geometry ≠
material.*

It held by construction almost everywhere, because a material is a part's
own `Finish` and a correction moves corners, never finishes: the frame's
finish rides on the frame through a reading, a bar keeps its finish by
being paired with the bar its stroke made last time, a pane's by
`SectionBuilder._carryIdentityForward`, a piece of ironmongery's by its
settled id (`OpeningHardware._finishOf`), the design's own infill is the
design's, and the rubber seal round every sealed unit is the solid's own.

**One gap, and it was the geometry choosing a material.** A leaf made
taller by the sizes hangs on one hinge more — its count follows its height
— and that hinge had never existed, so it came in the stock grey while the
leaf's other three were the black the user had made them. A new piece of a
set — the hinges of one leaf — now takes the finish the rest of that set
carries (`_finishOf`'s `setOf`), where they all carry one; where they
differ, nobody has said which it is, and it takes the stock finish as any
new piece does.

`test/domain/normalization_keeps_the_materials_test.dart` holds it in all
five categories, on a design drawn by hand with the head sloping, a
mullion, a transom and a `>`, given a material for everything: an
anthracite aluminium frame, a white uPVC mullion, a grey aluminium
transom, an oak line inside the opening, tinted and frosted glass in the
fixed lights, blue-grey glass over a white panel in the opening, a silver
handle, black hinges, bronze for anything else, and a brown panel as the
design's infill. It is then read again, corrected by a figure the user
states, given its sizes, and drawn again more crooked — the geometry
changing in all but the first — and every part's finish, glass look and
panel colour is required back, by what the part is rather than where it
is, in the design and on every face of the solid, the rubber seal
included; a hinge the taller leaf gained is required to be black. Putting
the stock finish back on a new hinge fails it in every hinged category.

### An angled design keeps its geometry, and is checked instead

The brief: *when the category is Angled / Asymmetrical, intentional
non-standard geometry is preserved — a left side of 200 cm and a right of
150, a sloped top, a top and a foot of different widths, in an opening or
a fixed light; do not make 200 = 150. Non-standard geometry is expected,
so standard rectangular normalisation is not applied aggressively. But it
must still validate: coordinates, connected geometry, boundaries,
dimensions, openings, child geometry, and no unintended
self-intersections.*

- **Nothing in it is made square that the drawing does not leave in
  doubt.** The lean rule was already off in an angled design. The wobble
  band is now the category's too (`Deviation.standard`): a run out by
  less than the hand can place a line — the weld, a hundredth of the
  drawing — is a wobble in any design; one out by more than that but
  within the snap angle and a twentieth of the drawing could be the hand
  or meant, and the drawing alone cannot say, so the category does — a
  door's or a window's lines are meant square, and an angled design's
  user said non-standard geometry is meant. So a side drawn 10 cm out over
  2 m is squared in a window and kept in an angled design, and the pause
  to straighten squares any line the user asks it to in either.
- **It is checked rather than mended.**
  `GeometryNormalizer.validateAngledGeometry` — `GeometryValidation.of`, in
  `geometry_validation.dart` — reports `GeometryProblem`s and changes
  nothing: a coordinate that is not a number; an outline or a section that
  encloses nothing, or crosses or touches itself (`Polygon.isSimple`); a
  section outside the frame, or a bar of the design joined to neither the
  frame nor another bar; a line or a pane outside the part it belongs to;
  an opening without its region, or whose mark is not in it; ironmongery
  off its leaf; and a dimension that measures nothing or a stated figure
  the geometry no longer agrees with. Every reading of an angled design
  carries them as `Interpretation.problems`, and the workspace shows
  them under the drawing — see *What the check finds is shown*.
- **Ironmongery goes on the leaf as it is**, which an angled design is the
  first to need. Hinges and a handle were placed from the leaf's box: under
  a raked head the top hinge stood above the head, outside the leaf, and on
  a stile drawn leaning every hinge came together at its foot, the one
  place the stile reaches the box's side. `OpeningHardware.stileOf` is a
  leaf's own stile on either side — the edge running more up than across
  that lies furthest that way — and the hinges run down it, each where it
  is at its height; the handle and the lock go on the opposite stile the
  same way, and a top or bottom hung leaf's sit on its own head or sill
  (`_railAt`). On a rectangle each is exactly the box's, so no square
  design's ironmongery moved, and the pinned solids did not change.

`test/domain/an_angled_design_keeps_its_geometry_test.dart` holds it: a
sloped top with its left side 200 cm and its right 150; unequal heights
and widths; sides that are not parallel, kept, where the same sheet begun
as a window is squared; a wobble under a hand's precision still cleaned
with the slope beside it kept; a sloped transom in a fixed light and a
sloped line drawn inside an opening kept, the opening's raked head kept;
the geometry the same through a second reading, a save and a reload;
every one of those read with no problem; leaves under the raked head hung
on either stile, as a door and as a window, with every piece of
ironmongery on the leaf; a leaf hung on a leaning stile with its hinges on
that stile and spread down it; the solid's glass inside the raked leaf;
and each kind of problem reported — a bow tie, a coordinate that is not a
number, an outline of two points, a bar hanging from nothing, a line and a
hinge off their opening, a mark outside its region, a dimension of
nothing and one the geometry disagrees with — with the design unchanged.
Placing the ironmongery from the box again fails two of them, and squaring
the wobble band in an angled design fails the sides that are not
parallel. Two older tests moved with the band and say so where they
assert: a side 60 and 120 mm out is kept in an angled design, and the
rail an angled design squares is now one out by less than the hand's
precision.

`validateAngledGeometry` is written, and what it finds is shown to the
user (*What the check finds is shown*).

### A window under a stair

```
         ┌──────────────┐
        ╱│              │
       ╱ │              │
      │ >│              │
      └──┴──────────────┘
```

An Angled / Asymmetrical design:
- a short jamb on the left;
- the stair's slope up to a level head;
- a tall jamb on the right;
- a mullion dropped from the corner where the slope meets the head;
- a `>` in the light under the slope.

It is built as drawn. The slope keeps its angle, the two jambs their own
heights, and the outline its five sides. It is never made a rectangle and
nothing asks whether it should be. Getting it right through every step
found five places where a bar meeting a raked side went wrong:

- **A bar's body reaches the line it ends against.** A body cut square at
  its end touched the level head on one side and stopped short of the
  slope on the other. The sliver between them came back as a light made of
  the bar. `SectionBuilder._reachingWhatItMeets` carries each end on along
  the bar's own line to where its face meets that line. The bar is not
  moved; its centre line ends where it did.
- **A size inside the frame leaves the frame alone.** Giving the glass
  under the slope a height stretched the sheet between the bars round it.
  That moved the corner where the slope meets the short jamb, and the size
  was refused. When the frame's own sides do not move, `Measurements.stretch`
  keeps the frame and every stroke no line, mark or figure was read from.
- **A light's size is measured on the result, and put right once**
  (`Measurements._resize`).
- **Two points of one line stay two points.** The mullion's face can meet
  the head two millimetres from the corner the slope meets it. The
  subdivision's weld folded the two together, so the light measured from
  the frame's corner rather than the bar's face, and a 120 cm light with a
  7 cm border was refused. `PlanarSubdivision._twoPointsOfOneLine` keeps
  apart two points that both lie exactly on one line more than half a
  millimetre apart. A hand's end left a few millimetres short of a line is
  still welded to it. Lowering the weld instead was tried and is not to
  come back: a hand-drawn line 6 mm short of a mullion then divided
  nothing.
- **A region keeps its identity by its ground.** With as many regions as
  before, the nth region used to take the nth's identity. The faces do not
  come back in a fixed order: drag the mullion past the slope's corner and
  the two lights came back swapped, so the frosted light on the right was
  frosted on the left. `_carryIdentityForward` now matches by the ground
  regions share. It falls back to their place only where the ground cannot
  say — a bar dragged a long way.

`test/domain/an_under_stair_design_test.dart` holds it:
- the five corners, the slope at 40.91°, sides of 90 and 220 cm, drawn
  exactly and drawn by hand;
- the mullion dividing the two lights at its faces, wherever it stands;
- an opening under the slope with a line inside it, glass over a white
  panel, and its ironmongery on the leaf;
- the width and height given, with the shape kept and read again the same;
- the glass given a height, and the light beside the mullion a width, with
  the frame unmoved;
- every size at once, as the browser gave them;
- the mullion dragged both ways with each light keeping its own glass;
- the design saved, reloaded, kept on the device and opened from its card,
  identical to the byte and building the same solid.

Taking out the subdivision's fix or the identity fix fails it.

### Dimensions on an angled design

The brief's own case:

```
┌╲
│  ╲          left side 200 cm, right side 150 cm, 100 cm wide:
│    │        three figures, each the side that is there, and never
│    │        made equal to one another
└────┘
```

A rectangle's overall width and height say everything about its sides.
Another shape's do not. They are the bounding box: the overall height is
its tallest side and says nothing about the others. So
`lib/domain/dimensions/frame_sides.dart` gives each side its own figure.

- **A `FrameSide` is an upright side shorter than the frame, or a level
  side narrower than it.** A side running the whole height or width is the
  overall figure, not a second figure saying the same thing.
- **A slope is not a side.** It is what joins the sides, and it follows
  them. Its length, angle, rise and run are read on the frame member's own
  panel; no figure along it is invented.
- **Each side is a size like any other**, under `side:<edge>` in
  `Design.measured`. It is asked for in the sizes form (*Right jamb
  height*, *Left jamb height*, *Head width*) and `?` until given. It is
  written on the technical drawing as its own row (`ChainRunOf.side`),
  named SIDE. On the foot and the left that row sits between the divisions
  and the overall. Along the head and down the right it sits nearest the
  drawing, so a phone, which keeps its right edge for the drawing, keeps
  room for that one row (`DimensionLayout.roomFor`). It can be tapped
  there (`DimensionOf.side`) and typed on the frame member's panel. All
  three go through `Measurements.apply`.
- **Typing a side moves its free corner and nothing else of the frame**
  (`FrameSides.sized`).
  - The side's **anchor** stays where the frame stands: on the sill for an
    upright side, at the right-hand jamb for a level one.
  - The slope joining it to the next side follows and stays one straight
    slope.
  - A level edge running from the moved corner is carried with it, so it
    stays level.
  - Right side 150 → 170 cm moves the right side's top corner up 20 cm.
    The left side stays 200, the width 100, and the head is still a slope.
- **Typing the overall size of an angled frame moves its far side, and
  every side standing on it** (`FrameSides.overall`). Each side keeps its
  own figure, and the slope takes the difference: overall height 200 → 220
  makes the left side 220 and leaves the right side 150. A rectangle is
  stretched as it always was (`Measurements.stretch`).
- **Everything that met the frame still meets it** (`FrameSides.reshaped`),
  by the relationship, never an offset.
  - A bar that ended on a side that moved now ends where its own line meets
    the new outline. A mullion dropped from the slope still reaches the
    slope, at the place and angle it was drawn. A transom whose side has
    drawn back below it now meets the slope, at its own height.
  - A bar that ended on a side that did not move is where it was.
  - A line inside an opening is the opening's, and goes with it as any
    resize carries it — from the sides that bound it square, its ends kept
    on the slope it met — so the panel below a rail keeps its height (see
    *Openings inside an angled design*).
  - The ink moves with what was read from it: the frame's along each side,
    a bar's along the bar. A fresh reading gives the same design.
  - A figure the user stated on a side that moved reads the side's new
    length, since a stated figure is held at the next reading.
  - A side shorter than the frame's own border is refused, as is a shape
    that crosses itself or loses a light or an opening.
- **Two sides that add up to a third are not both asked.** On a stepped
  frame, the step and the jamb beyond it make up the height, so only one is
  free and the other follows (`FrameSides.askedOf`). It is the same rule as
  the last light of a row.

`test/domain/angled_dimensions_test.dart` holds the brief's design, drawn
with a transom, a mullion from the slope, an opening, and glass over a
panel inside it:
- three figures, the right side asked and `?` until given;
- right side 150 → 170: only that edge and the slope above it change, and
  the mullion still meets the slope halfway along it;
- every other figure the same, the solid's frame reaching the new corner,
  and the same after a fresh reading, a save and a load;
- 150 → 100 and 150 → 50, and a side too short refused;
- the overall height and width each leaving the sides their own, and all
  three given at once;
- a rectangle unchanged;
- the under-stair window's short jamb and level head;
- the opening's own figures and a pane's height;
- a stepped frame.

`test/app/angled_dimensions_on_the_drawing_test.dart` holds the figure on
the technical drawing: down the right, `?`, tappable, named for its side,
170.0 cm once typed, never overlapping another figure, and its room kept
on a phone.

Putting back the overall's stretch, leaving the ink behind, or leaving a
bar's end where it was each fails it.

### Openings inside an angled design

```
            ╱╲
          ╱    ╲
        ╱│      │╲
      ╱  │      │  ╲
     │ > │      │ <  │
     │───│      │  │ │
     └───┴──────┴──┴─┘
   Opening 1  fixed  Opening 2
```

An opening marked under a slope is the shape the frame gives it — raked,
never made a rectangle — and it is an opening like any other. Its
divider, its glass, its panel, its hinges and its handle are its own and
inside it, and stay so through every edit that reshapes it. Built from the
reading, all of that already held:
- the panes are cut from the raked region;
- the leaf and what fills it follow the slope;
- the ironmongery goes on the leaf's own stiles.

What did not hold was carrying the opening's contents when it changed
shape.

- **The carry is measured from the sides that bound a region square**
  (`Polygon.sameIn`): between its level head and its level sill, and
  between its two upright sides. On a rectangle those are its box, so
  nothing square carries differently. A raked light has no level head;
  its box's top is wherever the slope meets the bar beside it. So
  carrying by the box moved everything inside up or down whenever that
  bar moved sideways. The rail in a raked sash rode up its leaf and its
  panel changed height, though nothing that bounds the panel had moved.
  Now a region with only one square side along an axis carries its
  contents with that side, and one with none carries them by the box, as
  before.
- **An end that met the region's edge still meets it** (`Polygon.lineIn`).
  An upright dropped from the slope to the sill was carried off the slope
  when the bar beside it moved. A line that stops short divides nothing,
  so the opening came back with no glass and no panel. Its end is now put
  back on the edge along its own line, keeping its angle and its place.
  `SectionBuilder._carryContents` and
  `DesignEdits.moveOpeningToSection` both carry through it, so there is
  still one answer to where the inside of a section goes.
- **A frame reshaped carries its openings' contents the same way**
  (`FrameSides.reshaped`). *Dimensions on an angled design* froze them in
  place, which was right only while the carry was wrong: an overall
  height taking the sill down left the rail behind, and the panel grew by
  the whole difference. Now the sill takes the rail with it, so the panel
  keeps its height, and a slope moved by a jamb's height moves nothing
  the slope did not bound.

`test/domain/openings_inside_an_angled_design_test.dart` holds it, on a
gable:
- two raked openings either side of a fixed light under the apex:
  - Opening 1, a window hinged on its left, divided by a rail into raked
    glass over a white panel;
  - Opening 2, a door hinged on its right, divided by an upright from the
    sill to the slope.
- Every relationship is required, each time:
  - each opening raked and on its own region;
  - its branch of the tree holding exactly its divider and two panes;
  - the divider its own, inside it and meeting its edge at both ends;
  - the glass raked, the panel white, and every fill inside the leaf,
    which follows the slope;
  - hinges on one stile and a handle on the other, all its own, with a
    lock on the door alone;
  - nothing shared between the two, nothing in the fixed light, and no
    validation problem.
- Every edit is checked against them:
  - as drawn;
  - in the solid, inside their regions shut, with only the openings
    moving when swung;
  - with either mullion moved either way, and the rail and the panel
    staying put;
  - with each jamb made taller and shorter;
  - with the overall height and width given;
  - with Opening 1 moved into the five-sided light under the apex;
  - after a save, a load and a fresh reading.
- The carry is unchanged on a rectangle.

Carrying by the box again fails five of its tests, and not putting an end
back on the edge fails four.

### The technical drawing is the canonical geometry

```
standard:  drawing → normalisation → canonical geometry → CAD
angled:    drawing → canonical angled geometry          → CAD
```

`CadPainter` draws the design and `DesignGeometry`, and works no shape
out for itself:
- the frame from `FrameElement.lines` and `innerOutline`;
- every bar from `barBody`;
- every pane's fill from `fillOf`, and the leaf from `leafOuter` and
  `leafInner`;
- the ironmongery from `hardwareOf`;
- the figures from `DimensionChains`.

It never reads the sketch for geometry: the sketch is a layer, off by
default, and shown faded when on. So a rectangle drawn by hand is drawn as
the rectangle the reading corrected it to. An angled design is drawn as
the outline it is: its slope at its angle, its sides at their own
heights, its edges as unparallel as they were drawn. Its figures are the
frame's box, each side of its own (*Dimensions on an angled design*), and
the sections that are there, so none is invented.

**The swing was the last rectangular placeholder.** The dashed triangle
that says how a leaf opens was laid on the leaf's bounding box, in the
technical drawing and the drawing alike. On a raked leaf its lines started
at the box's corners, which lie out past the slope, so the gable from
*Openings inside an angled design* had dashed lines running up off its
frame. `OpeningHardware.swingOf` reads it off the leaf's own edges: the
two ends of the stile or rail it hangs on (`stileOf`, and its own head and
sill), and the middle of the edge opposite. These are the edges its
hinges and handle are placed on. Both painters call it, and on a rectangle
it is exactly the box's.

`test/app/cad_is_the_canonical_geometry_test.dart` holds it, on four
designs:
- a standard rectangle;
- the same rectangle drawn by hand, every corner a little out;
- an angled window, left side 200 cm and right side 150;
- the window under a stair.

Each is painted with its frame and parts alone — no grid, no figures —
and the picture is held to the canonical geometry:
- every line of the outline, the daylight and every bar's body is inked
  where the geometry puts it, except under a piece of ironmongery, which
  stands in front of what is behind it as on any elevation;
- nothing at all is inked outside the outline;
- the hand's own leaning corners are not inked;
- the corrected rectangle is square, and its painter holds the design
  itself;
- the angled shapes are not rectangles;
- a raked leaf's swing runs from the ends of its own stile;
- every figure is the frame, a side or a section that is there, with a
  side's figure on exactly the shapes that have one.

Laying the swing on the box again fails it, and so does drawing the
outline as the box: a rectangular placeholder round an angled frame.

### The solid is the canonical geometry

```
standard:  drawing → normalisation → canonical geometry → 3D
angled:    drawing → canonical angled geometry          → 3D
```

`MeshBuilder` builds from the design and `DesignGeometry`, and works no
shape out for itself:
- the frame is its profile swept round `FrameElement.outline` and
  `innerOutline`, corner to corner, so a slope is a sloped member;
- a leaf is swept between `leafOuter` and `leafInner`;
- every bar is built on `barBody`;
- the glass and the panel fill `fillOf`, so a pane under a slope is
  raked;
- the ironmongery is placed by `OpeningHardware` on the leaf's own stiles.

So a hand-drawn rectangle is built as the rectangle the reading corrected
it to, and an angled design as the outline it is.

**The swing was the last box in the solid.** A leaf turned about the side
of its box: the x of a left or right hung leaf's box, the y of a top or
bottom hung one's. Its hinges are not on the box. They run down the
leaf's own stile (`stileOf`), and on a stile drawn leaning the box's side
is a line the stile only touches at one end. Swung, that leaf's hinge
stile came round in an arc and left its hinges behind.
`MeshBuilder._swingFor` now turns the leaf about the line its hinges are
on: the two ends `OpeningHardware.swingOf` gives, the one answer the
hinges and both drawings already read, at the face it turns about. It is
a turn about that axis (Rodrigues' formula), so every distance within the
leaf is kept as before. On a rectangle the axis is the box's side, so
nothing square turns differently, and the pinned solids did not move.

`test/domain/the_solid_is_the_canonical_geometry_test.dart` holds it on
the four designs: a rectangular door and a standard window, each drawn by
hand a little out of square; an angled window, left side 200 cm and right
side 150; and the window under a stair. Each has an opening divided into
glass over a white panel and furnished.
- Nothing is built outside the outline, and nothing at a corner of its
  box the outline does not reach.
- The frame lies in the ring between the outline and the daylight, has a
  corner at every corner of both, has a member along every edge of the
  outline, slope included, and runs the design's whole depth.
- The sash lies between the leaf's own outer and inner outlines, with a
  corner at each, and is raked where its region is.
- Every bar is on its body, with a corner at each of the body's.
- Every pane's glass or panel is within what it fills and has a corner at
  each of its corners, the slope's included.
- The ironmongery is on its leaf.
- The solid builds exactly the parts the technical drawing draws, with a
  corner at every end of every line it inks for the frame.
- Swung, only the opening moves, and every point of its sash keeps its
  distance from the hinge line.
- On a leaf hung on a stile drawn leaning, that holds at three angles.

Turning about the box's side again fails the leaning leaf. Building the
frame or the glass to its box fails the angled window and the window
under a stair.

### Telling the categories apart

The user's words: *make the distinction understandable without making the
application complicated.* Door, Window, Sliding and Door & window are
standard: a line drawn a little out of square is straightened. **Angled /
Asymmetrical** is for the sloped, the under-stair, the asymmetrical and
the custom, and keeps every slope as it is drawn. Nothing about either was
redesigned; the difference is said in two places, each once.

- **Where the choice is made.** The fifth card keeps its name, its line
  (*Sloped, under-stair & custom shapes*), its pen drawing of a window
  under a stair, and its triangle in the lists (`kindIcon`). Under the
  cards, beneath the note that the choice is where a design starts, one
  sentence says the whole difference (`StartScreen.straighteningNote`):
  *Door, Window, Sliding and Door & window straighten lines drawn a little
  out of square. Angled / Asymmetrical keeps every slope exactly as you
  draw it.*
- **When it happens.** A reading that visibly put a standard design right
  says *Geometry normalized for standard design.* in a small pill at the
  head of the view (`NormalizedNote`). It comes in, stands for about three
  seconds and goes by itself. It takes no tap, nothing waits on it, and it
  is never a dialog.

**Only when something a person could see was put right.**
`NormalizedGeometry.noticeableStrokes` is the strokes a correction moved by
more than the hand can place a line in that drawing: the weld, a hundredth
of its size. A jamb stood up from a few degrees, a corner drawn past and
trimmed, a lean squared all count. The shake taken out of every
hand-drawn line does not, and neither does a slip of the pen left in the
sketch. `Interpretation.noticeablyCorrected` carries them for a standard
design and is empty for an angled one, whose slopes are meant.
`WorkspaceState.correctedStrokes` remembers what has been said, so reading
the same sheet again says nothing more. `normalizedNotice` counts each
reading that had something new to say, and the pill comes up on a new
count.

**Shown on the work, never behind something over it.** A reading usually
brings the sizes up at once, and on a phone they fill the screen. A note
played out behind them was never seen, which is what looking at it in the
browser found. So the note waits while its route is not the one in front
(`ModalRoute.of`) or an alert is up (`WorkspaceState.waitingOnAnAlert`,
which `sizesToAsk` now reads too). If something comes up over it while it
stands, it is put back to wait. It comes in once the user is back at the
drawing it is about.

`test/app/category_behaviour_is_clear_test.dart` holds it:
- each standard category straightening a leaning side and saying which
  stroke;
- a square drawing, and one out by less than a hand places a line, saying
  nothing;
- an angled design keeping the same slope and saying nothing.

On the real app, at a phone, a tablet and a laptop:
- the note held back while the sizes are up, then shown at the head of the
  view once they are put away;
- inside the view, taking no tap, never in a dialog;
- gone by itself, and not said again on a second reading;
- each of the four standard cards saying so, a square drawing and an
  angled design not;
- the five cards, the angled one's line and drawing, five different
  marks, and the sentence under them, fitting at every size.

Saying it again for the same strokes, saying it for the hand's shake, or
playing it out behind the sizes each fails it.

### The category outlasts the design being opened again

A design's category is kept in it (`category` in the file) and goes on
deciding how its geometry behaves after it is opened again. Door, Window,
Sliding and Door & window stay standard; Angled / Asymmetrical stays
angled.

- **Opening a design does nothing to its geometry.** `openDesign` puts the
  kept design into the workspace as it is. Nothing is read, squared,
  rebuilt or measured on the way in, so an angled design is never made a
  rectangle by being opened, and a standard one is not straightened a
  second time.
- **A reading afterwards is the design's own category's.** **Read again**,
  or anything drawn on the sheet, reads with `Design.kind` as kept. A
  standard design comes back as the same square design, since its ink was
  straightened to it the first time. An angled one comes back as the same
  raked design. A new line two degrees out is squared in a standard design
  and kept at its slope in an angled one.
- **Nothing is said about what was straightened before.** `openDesign`
  marks every stroke the kept design was built from as already reported
  (`WorkspaceState.correctedStrokes`), so **Read again** on a reopened
  standard design does not bring up *Geometry normalized for standard
  design.* for lines it straightened the day it was drawn. Only a stroke
  drawn since is news.
- **There is no category conversion, and none was added.** The category
  is shown on the design's information form and is not changeable,
  because everything drawn in the design was drawn in it (*A design's
  information is edited without touching the design*). There is no route
  from Angled to Standard that could square a design, so there is nothing
  to warn about. If conversion is ever added, Angled → Standard must warn
  that the next reading straightens it, and Standard → Angled must keep
  the geometry exactly.

`test/app/reopening_keeps_the_category_test.dart` holds it on six designs:
- a door and a window drawn by hand, each divided and furnished;
- a sliding design and a door & window design;
- an angled window, left side 200 cm and right side 150;
- the window under a stair.

Each is kept and read back with its text identical. Its frame, bars,
sections, openings, ironmongery, figures and solid are the same. It is
opened without being read, read again as its own category to the same
geometry with nothing said, and a new leaning line on its sheet is read by
that category. The angled design is kept, opened and read again three
times over and is never a rectangle. On the real app a standard and an
angled design are each opened from their card, looked at in Draw, CAD and
3D, and found exactly as kept, in the workspace and on the device.

Making opening read the design, making a reading ignore the category, or
not marking the strokes reported on opening each fails it.

### Everything a design is, kept — and every older design still opens

**Kept in full.** A design's file holds everything it is:
- its category (`category`);
- its canonical geometry: the frame with its open sides, every bar,
  section and opening;
- its sizes (`measured`) and the dimensions drawn on it;
- the lines inside each opening, with their parents;
- what every part is made of;
- its handles and hinges, with their finishes and the opening's own
  figures for them;
- the sliding switches;
- whose it is, its id and its name.

Every field of the design and of each of its elements is written by its
`toJson` and read back by `fromJson`. The geometry is kept as built, not
read again from the ink, so an angled design is kept raked and a standard
one square. Nothing about the new category or the corrected geometry
needed a new field or a migration.

**Older designs load, and are not rewritten to load.** A file from any
version since the rebuild opens:
- `kind` where it now says `category`;
- no customer;
- no sizes, shown as they always were;
- no construction;
- an opening that never said what it is;
- ironmongery naming the section it is on, which `openingHolding`
  understands as the opening's.

Opening such a design, listing it or looking at it in any view writes
nothing.

**The two moves that do write are as narrow as they can be:**
- **A design kept before customers existed is given its customer by
  adding `customerId` to its record, and nothing else.** Every other key
  is written back exactly as it was read, including one this version has
  never heard of. It is never parsed into today's model and written out
  again. Doing that dropped whatever the model did not know and wrote in
  whatever loading the file settled: a rewrite of a design nobody touched.
  Once the field is there, nothing writes the record again until the user
  edits it.
- **The oldest list of designs (`proframe.designs.v1`) is moved over
  without losing an entry.** An entry this version cannot read used to be
  skipped, and then the list was removed with it still in it. It is now
  kept, verbatim, under `proframe.designs.v1.unread`, never read by the app
  and there to be recovered.

**The first screen lists the customers older designs belong to.** Reading
the designs is what gives a design kept before customers its customer.
The customers screen used to read the customers first, so after an
upgrade the people the designs were made for were not on it until
something read the list again. It reads the designs first now.

`test/app/persistence_and_old_designs_test.dart` holds it.
- **Create → save → close → reopen**, for Door, Window, Sliding, Door &
  window and Angled / Asymmetrical. Each is begun through the screens for
  Adam, drawn and read, then given:
  - a line inside its opening, with glass above and a white panel below;
  - an anthracite aluminium frame;
  - a silver handle and black hinges, or a pull and a pleated screen on a
    sliding panel;
  - a dimension drawn along the sill;
  - every size.

  It is saved with the Save button, the app closed and opened from
  nothing but the device, and opened from its card. Each listed field
  must come back as it was, then the whole file, then the solid, facet by
  facet.
- **Older records.** Every category loads as itself in the older words.
  Adoption adds `customerId` and nothing else, keeps an unknown key, and
  writes nothing on a second read. An older angled design stays raked.
  The oldest list moves over keeping an unreadable entry and one that is
  not even JSON. On the real app an older design is found under its
  customer, opens as itself, and the device is unchanged by looking at it.

Putting back the rewrite on adoption, dropping an unreadable entry, or
reading the customers before the designs each fails it.

### The geometry, tested end to end

`test/comprehensive_geometry_test.dart` is the brief's eighteen geometry
tests under the brief's own numbers. Each is held on the design, the
technical drawing's figures and the solid. Each is also held through
reading the same sheet again and through a save and a reload
(`expectSound`): the file comes back identical, nothing in the solid
stands outside the outline, every figure measures something, and an
angled design validates.

Standard designs (Door, Window, Sliding and Door & window):

| Test | What is held |
| --- | --- |
| 1. A perfect rectangle | Read with no correction at all; nothing reported. |
| 2. A side tilted 3, 8 or 16 cm | Squared; only that side moves; reported. |
| 3. A head rising 2, 6 or 12 cm | Levelled, the transom too. |
| 4. An inaccurate corner | Ends drawn apart are joined; lines drawn past each other are trimmed to their crossing with no stub left as a bar; a corner off square is squared. |
| 5. Left and right a little apart | One height where it is the hand (2 cm); kept as drawn where it is a slope (40 cm). |
| 6. Two openings | Neither shares a part with the other. A line drawn in one leaves the other identical. Swung, nothing outside them moves. |
| 7. An opening and a divider | The divider is the opening's and inside it, through a second reading; the design's own bars and divisions are unchanged; the solid's bar is inside the leaf. |
| 8. Glass and a panel | Frosted over brown, through a second reading, a wider frame, a moved mullion and a reload; glazing and a brown panel in the solid. |
| 9. A handle and hinges | Door, window and door & window. The opening's and on its leaf: hinges down the hinge stile, the handle on the other. Held as made, read again, made wider, with the mullion moved and reloaded, and turning with the leaf. |

Angled / Asymmetrical:

| Test | What is held |
| --- | --- |
| 10. A sloped top | A 7° head kept exactly, which the same sheet as a window squares. |
| 11. Left 200 cm, right 150 cm | Kept, with each side its own figure. |
| 12. A trapezoid | Kept, with the solid's frame on the four corners drawn. |
| 13. The under-stair shape | Its five corners kept. |
| 14. Angled openings | The gable's two openings raked, each holding its mark. |
| 15. Angled glass | The raked pane's glass at every corner of its fill. |
| 16. An angled panel | A raked panel, panel in the solid and never glass. |
| 17. An angled divider | A line at 15° inside a raked opening keeps its angle and divides it. |
| 18. An angled handle | On the leaf, opposite the hinges, and turning with it: under the gable's slopes, on a leaning stile and under the stair. |

**Test 4 found a fault in the reading, and it is fixed.** A head and a
jamb drawn past each other at a corner, each 4 cm beyond it, came back
square but a centimetre outside the corner. Joining (step 3 of the
normaliser) averaged their two loose ends to a point on neither line. That
left the trim (step 4) no loose ends to take back, and keeping square then
carried both lines off where they were drawn. `_joined` now leaves two
such ends apart for the trim, which takes each back to the crossing, on
both lines. It does so only where it is plainly that:
- judged in the ink, before anything was squared;
- both ends past the crossing by more than a hand's precision;
- no other end at that corner.

So a line that wobbles a few millimetres through a corner is joined as it
always was. A corner the user drew closed, which squaring each leg about
its middle pushes past itself, is joined too. Leaving the guard out fails
test 4; judging it after squaring instead of in the ink fails
`standard_normalization_rules_test`.

### The whole system, end to end

```
Drawing → raw geometry → normalisation / validation → canonical geometry
        → Draw, CAD, 3D → save → reload
```

`test/full_pipeline_regression_test.dart` runs that chain the way the
user does, on the real app, for two designs of Adam's.

- **An imperfect door.** Every corner is a little out, a fanlight
  transom is stopped 15 cm short of the far jamb, and a `>` is drawn in
  the leaf. Then a line is drawn short inside the leaf.
- **A window under a stair, drawn by hand.** Every side is a little out,
  with a `>` under the slope and a line drawn short inside it.

Each is made frosted glass over a brown panel, in an anthracite aluminium
frame with silver handles and black hinges. It is checked as drawn, then
saved, the app closed, opened again from the device and opened from its
card. At each stage it is checked on:

- **geometry:** the door square; the window's five corners where they were
  drawn and its slope within 0.6° of the stair's;
- **frame:** the frame and its material;
- **openings:** one, on the region holding its mark;
- **dividers:** the design's own reach the frame; the line drawn short is
  the leaf's and completed across it;
- **glass and panel:** frosted above and brown below, the glass raked
  under the slope;
- **handles and hinges:** the opening's, hinges down the hinge stile, the
  handle on the leaf, the door's lock, each in its finish;
- **dimensions:** every figure a section that is there, the overall
  figures the frame's own;
- **CAD:** on its pixels, every line of the outline, the daylight and
  every bar inked where the geometry puts it, and none outside the
  outline;
- **3D:** on its facets, nothing outside the outline, the frame on every
  corner of it, the glass glazing, the panel brown and opaque, and every
  piece of ironmongery built;
- **persistence:** the reopened file identical, field by field and as a
  whole, the slope the same;
- **customer and design:** both designs Adam's on the device.

Then the features round them:
- Adam's page shows both designs by name, the most recent first, and
  nothing of Sara's.
- The Door and Angled chips each show their own, and All shows both.
- An edit brings a design to the top.
- Sara's page shows hers alone.

Each item on the brief's regression list is also held by its own tests,
which the full suite runs:

| Feature | Held by |
| --- | --- |
| Customer pages | `a_customer_s_page_test`, `customers_screen_test` |
| Multiple designs | `a_customer_s_designs_as_cards_test`, `designs_are_kept_for_their_customer_test` |
| Design names | `a_design_is_named_test`, `editing_a_design_s_information_test` |
| Recent designs (most recently edited first) | `the_designs_screen_test`, `the_whole_customer_workflow_test` |
| Category filtering | `finding_a_customer_s_designs_test`, `an_angled_design_test` |
| Opening creation | `only_the_marked_section_opens_test`, `the_mark_picks_one_face_test`, `many_openings_in_one_design_test` |
| Line completion | `a_line_stopped_short_is_completed_test`, `a_line_started_in_the_opening_is_completed_to_it_test`, `a_line_outside_the_opening_is_completed_to_the_design_test` |
| Divider behaviour | `lines_inside_an_opening_test`, `the_opening_survives_its_own_lines_test`, `internal_lines_keep_the_opening_test` |
| Panel and glass | `glass_or_panel_test` (domain and app), `materials_on_the_drawing_test` |
| Handles | `a_door_has_door_furniture_test`, `a_window_has_window_furniture_test`, `the_handle_is_on_both_faces_test` |
| Hinges | `hinges_round_the_back_test`, `the_openings_hardware_test` |
| Saving and loading | `persistence_and_old_designs_test`, `reopening_keeps_the_category_test`, `opening_an_existing_design_test` |

Taking line completion out fails this test. Reading every design as
standard does not, because the under-stair slope is about 41°, past
anything any category straightens. The category's own behaviour is held
by `reopening_keeps_the_category_test` and
`comprehensive_geometry_test`, which do fail under that change.

### The final architecture, and where each part of it is

```
                       USER DRAWING                 Sketch, Stroke
                            │
                   RAW DRAWING GEOMETRY             StrokeFitter.fit → DrawnRun
                            │
                  GEOMETRY INTERPRETER              SketchInterpreter.interpret
                            │
              DesignKind.geometryPolicy             GeometryPolicy
                ┌───────────┴───────────┐
       normalize (Door, Window,    preserve (Angled /
       Sliding, Door & window)     Asymmetrical)
                │                       │
       GeometryNormalizer:         GeometryNormalizer, the hand's
       squares the hand's          wobble only; then
       wobble, leans, corners      GeometryValidation checks
                └───────────┬───────────┘
                   CANONICAL GEOMETRY               Design (frame, bars, sections,
                            │                         openings, hardware, sizes),
                            │                         read by DesignGeometry/DesignTree
               ┌────────────┼────────────┐
              2D           CAD           3D        DesignPainter, CadPainter,
                                                     MeshBuilder
```

**A category's whole say over geometry is `DesignKind.geometryPolicy`.**
One engine serves every category. The four standard categories normalise
and Angled / Asymmetrical preserves. The normaliser
(`NormalizationContext.isStandard`) and the reading (what was put right is
said, or what is wrong is checked) both ask the policy and nothing else.
Everything else a category decides is on `DesignKind` too, beside it:
- `leafDefault`, what a leaf follows;
- `asksConstruction`, whether glass or panel is asked;
- `slides`, whether a mark means a sliding panel;
- `seenFrom`, which face is drawn.

A leaf's lever, lock or fastener is the leaf's own kind (`Design.kindOf`),
not the design's. `test/domain/the_category_s_geometry_policy_test.dart`
holds the mapping and that both follow it. It also scans `lib/domain` so
that no geometry code asks *is this angled* for itself.

**Performance.** The reading runs only when it is asked for: **Read**, or
an answer that needs the sheet read again. Drawing a stroke only marks the
drawing changed, and nothing runs on a pointer move. The one fit made
while drawing is the pause to straighten, once, after the pen has rested
a second. A reading takes a few milliseconds, as does building the solid
(see *Every edit reaches every view at once, and looking does no work* for
the rebuilds).

**A category this version does not know is not a window.** A design saved
with one — added by a later version — used to load as a window, and saving
it here kept it as one. It now loads as `DesignKind.unsupported`, keeps the
category it was saved with, and is shown without being changed: see *A
category this version does not know*.

### An edit on the technical drawing is an edit to the drawing

The user's report: a door's head dragged on the technical drawing from
200 cm to 190, then **Read** — and the door was 200 cm again. Every CAD
edit went the same way: a transom dragged, a bar's end moved, a length or
an angle typed on a bar's panel, a jamb pushed out.

**The cause was two authorities.** The frame and every bar of the design
are read from the user's strokes, and **Read** reads them again — rightly,
because the drawing is the source of truth. The CAD edits changed the
design and left the ink where it was, so the next reading rebuilt the
design from the old ink. A size typed in the form never had the fault:
`Measurements.stretch` and `FrameSides.reshaped` already move the ink a
line was read from as the line moves.

**The fix is that rule, for every other edit.** `InkFollows.edit`
(`lib/domain/editing/ink_follows.dart`) takes the design before an edit
and after it, and gives the after with its ink moved exactly as the edit
moved what was read from it:

- **a bar's, a figure's and an arrow's own stroke** carried with that
  element, each sample by the displacement of the point of the element it
  lies against;
- **the frame's ink** — every stroke nothing else was read from — carried
  with the frame's edges, a sample only with an edge within the hand's
  reach of it, so a stroke that is nothing to do with the frame stays put;
- **a dimension resting on a line that moved** carried with it, and a
  figure the user stated reading the new length. Otherwise the next
  reading's pins would hold the old figure and pull the geometry back.

Nothing is written into the ink that was not there: every sample is the
user's own, moved, and the mark of an opening is never touched. It is not
a second geometry: the design is still the only canonical geometry, and
the ink is still what a reading reads. The edit becomes part of the
drawing, so a reading of the moved ink builds the design the edit made.

`WorkspaceController._inked` is where it is applied, on every drag and
typed figure the technical drawing and the panels make:
- `dragSelected`, `dragElement`;
- `moveDividerTo`, `moveDividerAcross`, `moveDividerEnd`,
  `moveDividerWithin`;
- `moveFrameEdge`, `moveFrameMember`;
- `moveDimensionEnd`, `moveArrowEnd`;
- `setDividerLength`, `setDividerAngle`.

The CAD view's grips call these, so the pointer and the panels take one
route. Undo and redo already kept whole designs, ink included, so an undo
puts back the ink with the geometry and a Read after it builds what is
shown.

**Moving the ink exactly found a fault in the reading.** A line ending on
another line, away from its ends — a T-junction — was joined to the
nearest corner within the join's reach, a few per cent of the drawing.
That reach is right for a hand's loose end. A mullion dragged 8 cm along a
head from the corner where the slope meets it lies on the head exactly,
and the join pulled the slope's own corner along to it. `_joined` now
joins such an end only within the weld, the hand's own precision. A hand
never lands exactly on a line, so no hand-drawn reading changed.

**A limit, stated rather than hidden.** A reading of a standard design
still squares a line within its wobble band (see *Telling a wobble from a
slope*). So an edit that turns a bar a degree or two off square is
squared again by the next Read. That is the category's own rule, the same
as for a line drawn that way, and the angle is kept in an angled design.

`test/domain/a_cad_edit_survives_reading_test.dart` holds it:
- the reproduction: the head 200 → 190 cm and a transom dragged, then
  Read;
- in every standard category, the edit checked:
  - on the CAD figure, the 3D solid and the ink;
  - through switching views, Read, a save and a reload;
- each kind of edit: a bar moved by its middle and by one end, a length
  and an angle typed, a jamb, the whole frame;
- an opening's divider, glass, panel, handle and hinges staying its own,
  and every material unchanged, as the frame and the mullion are dragged;
- an angled design, left 200 and right 150, and the window under a stair,
  each staying raked;
- a stated figure and a size given in the form agreeing with the edit;
- undo and redo;
- three edits;
- edit, save, edit, Read, save, reload;
- an edit, then more drawing;
- a drawing made by hand.

`test/app/a_cad_drag_survives_read_again_test.dart` holds it on the real
app: on Adam's Basement Door, the head's grip dragged with the pointer and
**Read again** pressed twice, with a trip to the drawing between.

Taking `InkFollows` out fails all twenty; taking the T-junction rule out
fails the window under a stair.

### What the check finds is shown

The audit's words: *geometry problems in Angled / Asymmetrical designs are
detected after Read, but not shown to the user.* The check
(`GeometryValidation.of`) ran on every reading of an angled design, and
what it found was put away unseen. It is now said under the drawing, and
the validator is still the only thing that decides what is wrong.

- **Each problem has a severity** (`GeometryProblemSeverity`), set by the
  validator where it finds it. There are two levels, because that is what
  the checks can tell apart:
  - **error**: the geometry cannot be built as drawn. A point that is not
    a number, an outline or a section enclosing nothing or crossing itself,
    a section outside the frame, a pane outside its part, an opening that
    has lost its region.
  - **warning**: it can be built, but something may not be what was meant.
    A bar connected to nothing, a line reaching out of its part, a hinge
    off its leaf, a mark outside its region, a dimension measuring nothing,
    a figure the drawing no longer matches.
- **Each is said in words that name the part** (`GeometryFeedback`,
  `lib/domain/recognition/geometry_feedback.dart`), never an id or a class:
  - *A sloped bar is not connected to the frame or to another bar.*
  - *The raking upper right side of the frame crosses the raking lower
    right side.*
  - *The mark of Opening 1 is outside the region it opens.*
  - *A hinge of Opening 1 is not on its leaf.*
  - *The dimension you gave as 150 cm no longer matches the drawing, which
    measures 200 cm.*

  Each problem also lists the parts to show: the two sides that cross, the
  bar, the opening.
- **Worked out from the design, never stored.** `GeometryFeedback.of` runs
  the validator on the design as it now is. The result is kept with that
  design object only, because a design is immutable and an edit makes a
  new one. `WorkspaceState.geometryFeedback` reads it. So a problem put
  right is gone the moment the design that had it is: by drawing and
  reading again, by a drag on the technical drawing, by a delete or by an
  undo. Undo it, and it is back. Nothing is written to the file, so no
  stale problem can be saved.
- **Angled only**, by the category's `GeometryPolicy.preserve`. A standard
  design gets `GeometryFeedback.none` and reads exactly as before.
- **Shown, never mended.** Nothing squares, straightens, equalises, closes
  or deletes anything; the user puts it right on their own drawing.

`GeometryCheckPanel` (`lib/app/inspector/geometry_check_panel.dart`) sits
under the drawing, beside the questions about the sheet and in their
style, under all three views:
- **Folded**, it is one line: *Geometry needs attention* where there is an
  error, *Geometry may need review* where there are only warnings, the
  first problem, and how many of each (*1 error · 2 warnings*).
- **Open**, it adds a sentence saying nothing has been changed, then every
  problem, errors first, each marked **Error** or **Warning**. A long list
  scrolls within a third of the screen.
- **Show me** lights the part on the drawing and the technical drawing
  with the same passing highlight the questions use. It never selects the
  part and never colours the design. From the 3D view it goes to the
  technical drawing to point the part out.

It asks nothing and nothing waits on it. Both painters now repaint when
the highlighted set changes, not only when its size does, so going from
one problem's part to another's is redrawn.

`test/domain/angled_geometry_feedback_test.dart` holds it:
- **no false error** on valid angled designs: a sloped top (200 cm left
  and 150 right), unequal sides, sides that are not parallel, a
  trapezoid, the window under a stair (exact and by hand), and the gable
  with two raked, divided and furnished openings;
- **a loose sloped bar** drawn and read: a warning, in words, with the bar
  to show and the same element the reading reports;
- **an outline drawn crossing itself**: an error naming the two sides that
  cross, and those sides to show — nothing straightened;
- a mark outside its region, a stated figure the drawing disagrees with, a
  dimension measuring nothing, a line and a hinge off their opening, an
  outline enclosing nothing, and a point that is not a number;
- errors first, and a warning never called an error;
- **every standard category** reading the same problems as nothing;
- **put right**: the loose bar rubbed out and read, a figure made true, a
  mark put back. The problem is gone each time, and nothing is written to
  the design;
- every message free of ids and class names.

`test/app/angled_geometry_feedback_on_screen_test.dart` holds it on the
real app:
- a valid design shows nothing;
- a loose line drawn and **Read my drawing** pressed: the panel, its
  heading, its first problem, *Warning* not *Error*, and **Show me**
  lighting the bar on both drawings with the design unchanged and nothing
  selected;
- deleted, the panel is gone and the highlight with it; undone, the panel
  is back;
- the bow tie: an error, and the two crossing sides lit;
- from the 3D view, **Show me** going to the technical drawing;
- a standard window shows nothing;
- the panel fits a phone, a tablet and a laptop, folded and open, under
  half the screen.

Silencing the feedback fails sixteen of them.

### Snapping to the geometry as it is

The audit's words: *CAD snapping is horizontal and vertical only.* The
technical drawing snapped a drag's x and y separately, to values
`DesignEdits.snapCandidates` collected:
- the frame's corners and the daylight's;
- the centres and faces of upright and level bars only;
- each section's bounding box.

On an angled design that failed three ways:
- A raking side was never a snap target, so an end dragged near a slope
  stopped wherever the pointer was, a few millimetres off it, joined to
  nothing.
- A sloped bar was never a candidate at all.
- A raked light's bounding box gave snap values at corners the design does
  not have, so a drag could be pulled to a point that is not geometry.

**`CadSnap` (`lib/domain/editing/cad_snap.dart`) snaps to the canonical
geometry as it is, for an Angled / Asymmetrical design.** It reads the
design's own points and lines each time and holds nothing of its own:
- **Points**: the frame's corners and the daylight's, each bar's ends,
  each light's corners, and where two lines near the pointer cross.
- **Lines**: the frame's outline and daylight, each bar's centre line, each
  light's edges. A point is measured to a line square to that line, at
  whatever angle it runs, and lands on it there. No angle is preferred —
  not 45°, not level, not upright — so a slope of 17° or 73° is snapped to
  as itself.
- **What wins**: a point the geometry has, then a line it has, then a point
  level with or upright from one it has; within each, the nearest; and
  nothing further than the reach the CAD view always used (eleven pixels
  at the drawing's scale). A drag clear of everything lands where it is.
- **Each grip snaps the way it moves.** An end — of a bar, a figure or an
  arrow — snaps as a point (`CadSnap.point`). A bar or a side of the frame
  dragged square to itself snaps its offset along its own normal
  (`CadSnap.across`): through a point the geometry has, or onto a line
  parallel to it. For an upright bar that is exactly the old x snap; for a
  raking side it is a line at the side's own angle. What moves with the
  member is left out. A whole element dragged by its middle snaps by
  alignment (`CadSnap.aligned`).
- **A child snaps inside its parent.** A line inside an opening snaps to
  that opening's region and what is drawn in it, never to the design's
  lines outside, so snapping cannot move a line from one owner to another.

**The standard categories keep the snapping they had.**
`CadSnap.byGeometry` is the category's `GeometryPolicy` and nothing else.
The CAD view takes the new path only for `preserve`; Door, Window, Sliding
and Door & window run the old `snapCandidates` code unchanged.

**A snap is an edit like any other.** The snapped point goes to the same
controller edits a drag always called (`moveDividerEnd`,
`moveDividerAcross`, `moveFrameMember`, …). So it is canonical geometry,
its ink follows it (`InkFollows`), it is undone and redone, and every view
shows it.

**Snapping found a gap in the ink-following.** A bar's stroke seldom ends
exactly at the bar's end. The hand stops short or long, and the reading
closed that gap by joining the end to the corner or the line it met.
`InkFollows` carried the ink with the bar, gap and all. An end dragged
from the corner where the under-stair slope meets the head to half way
down the slope then had nothing to close the gap. **Read** built the bar
from where the hand's ink stopped, off the slope, and the check said it
was connected to nothing. Now, where an edit moves one end of a line
relative to the other (an end dragged or snapped, a length or an angle
typed), the ink's end on that side is carried to the new end exactly, and
the ink between follows in proportion. A line moved whole keeps its ink's
own ends, as before.

`test/domain/angled_cad_snapping_test.dart` holds it:
- **the original fault**: an end near the slope left off it by the axis
  snaps and landed on it now; and a raked light's bounding-box corner,
  which the axis snaps landed on, never offered as a point;
- **slopes of 3°, 17°, 23°, 38°, 52° and 73°**: a point either side of the
  slope lands on it, square to it, and the slope keeps its angle;
- a level sill and an upright jamb snapped as lines too;
- **which candidate wins**: a corner beats its lines, a crossing is a
  corner, the nearer line beats the further, and nothing snaps beyond the
  reach;
- every side of a trapezoid dragged square to itself, landing on the
  nearest corner's offset and, where the frame takes the move, keeping
  its angle and passing through that corner;
- the under-stair slope dragged, keeping its angle and never a rectangle;
- an upright mullion snapping across as the axis snaps did;
- a rail inside a raked opening snapping to the opening's own slope and
  never to the frame's, and staying the opening's;
- **the snapped edit**: the mullion's end snapped onto the slope with the
  200 / 150 sides, the opening, its line and every finish unchanged, then
  through Read, a save, the solid, undo and redo;
- the under-stair mullion drawn by hand, snapped half way down the slope,
  and read again exactly there;
- the four standard categories snapped by the axes.

`test/app/angled_snapping_on_the_drawing_test.dart` holds it on the real
app with the pointer:
- the end grip dragged near the slope landing on it, then **Read again**,
  Draw and 3D all showing that design;
- with Snap off, the end landing where the pointer is;
- a door's lower mullion snapping in line with the upper one by the axis
  snaps, as before.

Taking `CadSnap` out fails the real drag; taking the ink-end rule out fails
the hand-drawn read.

### A category this version does not know

The audit's words: *an unknown or future design category is silently
treated as Window.* `Design.fromJson` and `DesignSummary.fromJson` read
the category with `orElse: () => DesignKind.window`, so a design kept by a
later version as `future_custom_shape` or `circular` came back here as a
window: called a window on its card and in its panel, listed under the
Window filter, read by a window's rules if its sheet was read, and written
back as `window` over what it said the next time it was kept.

- **One more value, never offered.** `DesignKind.unsupported` is what
  `DesignKind.of` gives for anything that is not a category this version
  knows — a later version's name, a number, `null`, nothing at all.
  `DesignKind.categories` is the five that can be chosen; *Choose your
  design* and every new design use only those. Every version since the
  rebuild has written a category into every design, so a missing one is
  not an old design wanting a default: it is one this version cannot name.
- **What it was saved as is kept.** `Design.savedCategory` and
  `DesignSummary.savedCategory` hold the stored value exactly — a string,
  a number, whatever was there — and `toJson` writes it back under
  `category` as it came; a design with none stays with none. The index
  line keeps it too, because the index is written back whole every time
  any design is kept. No new model: the same `Design`, with one field.
- **Shown, never changed.** Its category may change what its geometry
  means, so nothing here may rewrite it by another category's rules, and
  nothing may write it in this version's words.
  - `WorkspaceController`'s state setter is the one place every change
    passes: while the design open is unsupported, a new version of it is
    refused and the design stays the object that was loaded. Looking — the
    view, the camera, picking, a highlight — goes on as for any design.
  - **Read**, Save, keeping, undo, the questions and the sizes do nothing
    for it, and nothing is asked when it is opened.
  - `DesignStore.save` never writes it; duplicate, rename and retitle give
    nothing. Delete is as for any design — the user's choice.
  - On its card neither **Edit information** nor **Duplicate** is offered.
- **The geometry is what was saved.** Opening is `openDesign` on the
  design as kept, as for every design, so the frame, bars, sections,
  openings, the lines and panes inside them, materials, ironmongery and
  figures are the saved ones, and Draw, CAD and 3D draw them. Were it ever
  read, its `geometryPolicy` is `preserve`: never a standard category's
  squaring. No leaf follows it (`leafDefault` is null), it is not asked
  what it is built of, and no mark in it slides.
- **Said in words.** `UnsupportedCategoryNote` stands under the drawing in
  every view: *Unsupported design category* — made by a newer ProFrame or
  with a category this version does not recognise, shown exactly as saved,
  cannot be changed here so nothing is lost, its original category kept.
  Its card, its panel and the filter chip say *Unsupported category*, with
  its own mark (`kindIcon`); the stored value and internal words are never
  shown.

`test/domain/an_unknown_category_test.dart` holds it:
- every known category read as itself, by `category` and by `kind`;
- `future_custom_shape`, `circular`, `Window`, `''`, `12345`, `3.5`,
  `true`, a list, a map, `null` and nothing at all each Unsupported — never
  a window or any other known category;
- the stored value written back exactly through three saves and loads,
  and kept by an edit; none stays none;
- an index line round-tripping with it;
- the brief's sloped fixture, left 200 cm and right 150, loaded as
  `future_custom_shape` with everything but its category identical, its
  frame, opening, divider, glass, white panel, silver handle and black
  hinges as they were, and its solid facet for facet the angled one's;
- a lean a window squares kept;
- on the device: loaded, listed under its customer, counted, filtered and
  searched; never written by save, duplicate, retitle or rename; its line
  and its own unknown field kept when another design rewrites the index;
  a malformed value loading and filtering; and given its customer, when
  kept before customers, by adding that field alone.

`test/app/an_unknown_category_on_screen_test.dart` holds it on the real
app, at a phone and a laptop:
- Adam's two later-version designs called *Unsupported category* and never
  *Window* on their cards;
- the Unsupported, Door and All chips filtering, and a search finding one;
- opened, the notice in Draw, CAD and 3D, each view of the saved design,
  and nothing asked;
- a stroke, Read, a leaf made a door, a colour, a bar moved, a width, a
  depth, a name and a delete each changing nothing, with nothing to undo;
- Save and leaving writing nothing, the device byte for byte as it was;
- a known design opened after it edited as ever;
- the card's sheet without Edit information or Duplicate.

Falling back to a window again fails eleven of them; letting a change
through the state setter fails the on-screen one.

### The price

The brief, twice. First: *a pricing engine for every design category, today's
and later ones, built on the canonical design, that never redraws, guesses
or modifies geometry.* Then, as the workshop actually prices: *measure the
design the way the factory does — normal profile and opening profile in
metres, panel and glass in square metres, hardware by the piece, each at its
own configurable rate, per material and colour — and give each design its
price and each customer the total of theirs.*

```
Design ─ PricingTakeoff ─ CategoryPricing ─ labour ─ installation ─ discount
       (canonical geometry,   (lines: a measurement                 │
        read only, measured    at a rate)                    PriceResult
        once per piece)               ▲                   (lines, groups,
                                  PriceList                measurements,
                        (every rate, kept by PriceListStore)  total)

Customer's designs ─ each priced as above ─ CustomerPricing (sum, worked out)
```

Everything is in `lib/domain/pricing/`, and no widget holds a figure.

- **The takeoff reads the design; nothing else does** (`PricingTakeoff`).
  It measures through the geometry every view draws from — the frame's
  outline, `DesignGeometry.barBody` and `fillOf`, `Infill.partsOf`, each
  opening's own section — and turns millimetres into `Metres` and
  `SquareMetres` (`measurement.dart`) in one place. Nothing is squared,
  boxed, measured afresh or stored: pricing writes nothing, and the design
  that goes in comes out as it was.
- **Each piece is measured once, in one category** (`ProfileUse`):

  | Category | What | Unit |
  | --- | --- | --- |
  | Normal profile | the frame's border (a side left open is no member) and every bar — the design's own and every line inside an opening | m |
  | Opening profile | the perimeter of each opening's own region | m |
  | Other profile | a sliding design's track, the frame's width once | m |
  | Panel, glass | each part as it is cut — its `fillOf`, the polygon's own area | m² |
  | Hardware | each piece | each |

  A line inside an opening is listed against that opening but cut from the
  normal profile, so it is never also in the opening's perimeter. An
  opening's perimeter is its region's outline, so two openings either side
  of a mullion each count their own side and the mullion is counted once,
  as a bar. A bar's length is its body's reach along its own line — what it
  is cut to. An angled design is measured as the polygon it is: left
  200 cm, right 150, 100 wide is 1.75 m², never its box's 2.
- **Metres and square metres never mix.** `MeasurementSummary` keeps
  normal, opening and other profile, panel area, glass area, the pieces and
  the openings apart; `totalProfile` is the profile alone, in metres, and
  the two units are two types, so adding one to the other does not compile.
- **The price list holds every rate** (`PriceList`): per frame material a
  `ProfileRate` — a metre of normal profile and a metre of opening profile,
  each its own figure — and what a colour the catalog does not name adds
  on it; the factory's colour catalog (see *The factory's colour
  catalog*); glass by look —
  a single sheet and a sealed unit each a square metre rate of its own —
  and panel by colour, a square metre each, with a rate for the user's
  own colour; each piece of ironmongery; a sliding track by the metre and
  rollers each; each category's labour — fixed, by area and as a
  percentage (`LabourRate`) — and installation. A figure that is not a
  price — below nothing, not a number — is dropped as it is read, so that
  thing is unpriced and says so, never priced at nonsense.
- **Colour is its own line, by the metre and by a share.** Each colour of
  the catalog (`FactoryColour`) has a `ColourSurcharge` on each material it
  is sold in — so much a metre on every metre of profile in that colour,
  and a percentage of what that profile costs — looked up by material and
  colour together (`PriceList.colourFor`). A colour the catalog does not
  name takes the material's *any other colour* surcharge; the
  application's own house green and cream are on no list. It is its own
  line (*Black uPVC (non-standard colour)*) so the breakdown says why.
- **A category is priced by the strategy registered for it, by name**
  (`PricingEngine.standard`): door, window, door & window and angled by
  `FramedPricing`, sliding by `SlidingPricing` (the track and the rollers
  too). The lines are the measurements at their rates, summed by material,
  colour, glass look and panel colour. A later category is a strategy
  registered and a rate in the list; nothing here changes.
- **A design that cannot be priced says why** (`PriceStatus`): nothing
  drawn; a size it asks for not given — a sketch has no scale, so a price
  off it would be a guess; something else not complete (`incomplete`); a category this version does not know —
  *Unsupported category*, *Price unavailable*, never a window's; a category
  with no strategy or no rate; the list having no price for something the
  design has; or a size of nothing or not a number. No figure is shown
  then, and every amount written is finite and no less than nothing.
- **The result is a breakdown** (`PriceResult`): lines in groups — normal
  profile, opening profile, other profile, colour, glass, panel, hardware,
  labour, installation — each a quantity, a unit, a rate and an amount;
  the measurements; a subtotal, a `Discount` (never below nothing) and the
  total. Every line is whole cents and every sum a sum of cents (see
  *Pricing integrity*). It serialises, so a
  price can be kept as it stood (`PriceSnapshot`); nothing takes one yet.
- **What the user chooses about the price is the design's**
  (`Design.pricing`, `PricingChoices`): installation — never on until they
  switch it on — a discount and a kept snapshot, written only when
  something is chosen. Material, colour, glass, panel and ironmongery were
  already the design's.
- **A customer's total is worked out, never kept** — from each design's
  calculated price, and final only when every one is current. See
  *Calculate price, and the customer's money*.
- **The list is kept on the device, and only the owner changes it**
  (`PriceListStore`, `proframe.pricelist.v2`, a list the first engine kept
  under `proframe.pricelist.v1` read and migrated — see *Pricing
  integrity*; `WorkshopRole`).
  ProFrame has no sign-in, so the device starts each run as staff, who can
  price but not change prices; the owner unlocks the price editor with the
  owner's PIN — see *What a design is made of, and the factory's prices*.
  Until the owner keeps a
  list, the example list (`PriceList.starter`, which is
  `DefaultFactoryPricing.list` — the one place its figures are written —
  in US dollars, uPVC $7 a metre normal and $12 opening) is used and the panel says *Example prices
  — the workshop owner sets the real ones.*
- **On the screen**: the workspace's **Calculate price**, a design card's
  **Price** and the customer's financial summary — see *Calculate price,
  and the customer's money*. A design is priced only once it is complete
  (`PriceReadiness`), every size it asks for given.

`test/domain/pricing_engine_test.dart` holds the brief's tests under its
own numbers, each on a list whose every rate the test sets:
- **the acceptance design**: a 600 cm border, two internal lines of 80 cm
  and a 600 cm opening — 7.60 m × $7 = $53.20 and 6.00 m × $12 = $72.00,
  $125.20 before infill — then a panel priced at its own area;
- the border the outline, every bar once at its cut length, several
  openings each once and never sharing the mullion, panel and glass by
  what each is cut to, metres and square metres apart;
- uPVC against aluminium on one geometry, and a colour's metre and share;
- a door, a window, a sliding set, a door & window set and an angled
  design at its own measurements;
- a later category, a missing strategy, rate, material, glass or piece,
  nothing drawn, no sizes and impossible sizes — each a state, never a
  figure;
- three designs of one customer and their sum; and the choices, a design
  kept before pricing, pricing writing nothing, and the list kept and
  refused to staff.

`test/app/the_price_on_screen_test.dart` holds the panel on the real app,
and `test/app/a_customer_s_total_test.dart` the customer's page: Adam's
three designs each their own price and the total their sum, the profile
in metres and the infill in square metres, nothing written to the device,
a width changed and kept reaching the total, and Sara's total hers alone.

Pricing the opening at the normal rate, counting a line inside an opening
twice, measuring an area by its box, or pricing an unknown category as a
window each fails it.

### Calculate price, and the customer's money

The brief: *a price button in the design workspace and on every design
card, disabled while the design is incomplete and saying exactly what is
missing; never a partial price; a price that changes with the design is
not shown as current once the design has moved on; and on the customer's
page what all their designs come to, what they have paid and what is
still due.*

```
Design ─ PriceReadiness ─ PricingEngine ─ PriceRecord? ─ DesignPriceState
                                                              │
               workspace: Calculate price ◄───────────────────┤
               design card: Price ◄───────────────────────────┤
               customer: CustomerPricing ─ CustomerFinance ◄──┘
                                              ▲
                                       Customer.paid
```

- **Whether a design can be priced is one answer** (`PriceReadiness.of`,
  `lib/domain/pricing/price_readiness.dart`). The engine asks it before it
  prices anything. The workspace's button, a card's button and a
  customer's total are all enabled by it, so no two screens can disagree.
  It decides nothing new: each requirement is a question the application
  already asks, read from where it is kept:

  | Requirement | Read from |
  | --- | --- |
  | A category this version can price | `Design.isUnsupported` |
  | A drawing read since it was last drawn on | `Design.sketchUnread` |
  | An outer frame | `Design.frame` |
  | Geometry that can be measured | `PricingTakeoff.problemWith`; the angled check's errors (`GeometryFeedback`) |
  | What a door is built of | `Design.construction` (not `pending`) |
  | Which parts are glass and which panel | `Design.partsAsked`, where it is both |
  | What each opening is, door or window | `Design.kindOf` (in a door & window or an angled design) |
  | **Every size the design asks for** | `Measurements.of`, against `Design.measured` |
  | The profile's material and colour, chosen | `ProfileSelection.of` |

  The last one is stricter than before: not only the width and height but
  the frame's border, the bars and each light's and pane's own sizes.
  Until a size is given it is the sketch's proportion, and an opening's
  perimeter or a pane's area worked out from a guess is a guessed price. A
  design kept before sizes were asked has nothing outstanding, as
  everywhere else. Each requirement is said in words that name it: *Please
  give the overall height to calculate the price.*, *Please complete the
  dimensions of Opening 1 — Clear glass 1 (its height) to calculate the
  price.*, *Please say whether Opening 1 is a door or a window…*,
  *Please complete the panel/glass selection…*.
- **A calculated price is kept beside the design, never in it**
  (`PriceRecord`, `PriceRecordStore`, under `proframe.price.v1.<id>`).
  `PriceRecord.inputs` (`PriceInputs.of`) says what it was calculated
  from: the design as kept, less its name, customer, dates, ink, notes and
  arrows, plus the price list. `DesignPriceState.of` reads it against the
  design as it is now:

  | State | When | Shown |
  | --- | --- | --- |
  | `current` | the inputs are the same | the price |
  | `notCalculated` | complete, never calculated | *Not calculated yet* |
  | `needsRecalculation` | complete, but the design or the list changed | *Price needs recalculation*, the old figure struck through as *previous* |
  | `incomplete` | `PriceReadiness` says no | *Price unavailable until design is completed*, and why |
  | `unsupported` | a category this version does not know | *Unsupported category. Price unavailable.* |
  | `unavailable` | the list has no price for something in it | the engine's reason |

  So a width, a line, a material, a colour, a glass, a hinge, an option or
  a rate changed makes the kept price stale, and nothing shows a stale
  figure as the price. Calculating writes nothing to the design: not its
  geometry, its materials or when it was edited.
- **Calculate price** (`WorkspacePriceButton`, `PriceButton`) stands on
  the workspace's bar beside Save in every design — its icon alone on a
  phone — and in the design's own **Price** panel. It is never hidden.
  - Where the design cannot be priced it is drawn disabled, and a press on
    it says the exact thing to complete (`PriceButton.explain`).
  - Pressed while enabled, it keeps the design as it is, calculates by the
    one engine, keeps the price, and shows `DesignPriceSheet`: **MATERIAL
    MEASUREMENTS** (profile in metres, panel and glass in m², never added
    together), **COST BREAKDOWN** by group with each line's quantity and
    rate, and **DESIGN TOTAL**.
  - It follows every edit at once (`workspacePriceStateProvider`): a size
    given enables it, a size taken away or a line drawn in a sash disables
    it.
- **A design's card** shows *Complete* or *Incomplete* beside its
  category (`CardPriceStatus`), or *Drawing not read*, then
  *Material:* and *Colour:* in words (`CardProfileLine`). On a row of their
  own under *Last edited* it shows *Price: 189.98 USD*, *not calculated*,
  *recalculate*, *needs update* or *unavailable* (`CardPriceValue`) and
  **Price** (`CardPriceButton`), so the row of buttons below is *Edit
  information* and **Open** alone, each in full.
  All three read `keptDesignPriceProvider`, the same `DesignPriceState`
  of the kept design. Pressed, Price shows the current price, or calculates
  one from the kept design first; disabled, it says why. The card is the
  height it was. A design of an unknown category says nothing more than
  its category already does, and its Price is disabled.
- **The customer's total is the designs' prices, summed, and never kept**
  (`CustomerPricing` in `design_price_state.dart`).
  - It is final only when every design has a current price.
  - Where one is incomplete or cannot be priced, it is *not final* and says
    why: *Customer price is not final. 1 design is incomplete.*
  - Where one is complete but not calculated, or changed since, it says so
    too.
  - In both cases only *Priced so far (not the total)* is shown, never as
    the total.
  - Its measurements are the priced designs', with metres and square metres
    kept apart.
- **What was paid is the one money figure kept on a customer**
  (`Customer.paid`, written only when not nothing, so an older customer
  loads having paid nothing recorded). `CustomerFinance` works out what is
  due — the total less what was paid, never below nothing — and the
  status:

  | Status | When |
  | --- | --- |
  | *Total not final* | some design has no current price |
  | *Not paid* | nothing paid |
  | *Amount due* | some paid |
  | *Paid in full* | all paid |
  | *Paid exceeds total* | the total fell below what was paid, by a design deleted or made cheaper; said, never a debt below nothing |

  **Record payment** (`recordPayment`) asks what has been paid in all.
  Against a final total, more than it is refused: *Paid amount cannot
  exceed the total price.* While the total is not final, a deposit is
  taken, and what is due is not said until the total is. Paying touches no
  design and no price.
- **On the customer's page**, under the cards so it moves none of them:
  - **CUSTOMER FINANCIAL SUMMARY** (`CustomerFinancialSummary`): the
    designs and how many are priced, the total price, paid, *Amount due /
    loan*, the status, and **Record payment**.
  - Unfolded, each design's own price and the **CUSTOMER MATERIAL
    SUMMARY**.
  - On the bar beside the name, the money at a glance
    (`CustomerMoneyGlance`): *Due 1,350.00 USD*, *Paid in full*, *Total
    not final*. It is on the bar because anything added to the
    information card pushed the design cards off a phone's screen.
- **Price rows wrap** (`PriceRow`): a figure is short, but *Price
  unavailable until design is completed* is not, and on a phone it ran off
  the screen.

`test/domain/price_readiness_test.dart` holds it:
- **completeness**: a complete design; nothing drawn; an outline not
  closed; a missing overall size, with no price and no measurement given;
  an opening's sizes missing, named; an opening nobody said is a door or a
  window; construction and the panel/glass selection not said, never
  assumed; a bow tie; a complete angled design priced at its polygon's own
  area; an unknown category; a design kept before sizes; and asking
  writing nothing;
- **the kept price**: current through a save and a load and a rename;
  stale after a geometry change, a material, a colour, a glass, a panel, a
  hinge, an option or a new list; incomplete with the old figure only as
  previous; and a record that cannot be read is no price;
- **the customer**: 800 + 500 + 700 = 2,000, then 500 → 600 and
  calculated = 2,100, with *needs recalculation* in between; an incomplete
  design making the total not final, with 1,300 only as priced so far; a
  design deleted and one added; the measurements summed by unit; an
  unknown category;
- **payment**: 2,100 with 1,000 paid is 1,100 due, *Amount due*; with
  2,100 paid it is 0 and *Paid in full*; nothing paid; more than the total,
  less than nothing and not a number refused; paid exceeding a fallen
  total; `paid` kept on the customer and nothing else; and payment
  touching no design.

`test/app/the_price_button_test.dart` holds it on the real app:
- **in the workspace**: an incomplete design's button there and disabled,
  saying *Please give the overall height…*, no record written; the height
  given, enabled and calculating the engine's price; a calculated price
  going stale on a width change, disabled when a line makes a pane's size
  unknown, enabled again once the sizes are given, with a new price;
- **on the cards**: complete designs enabled and the incomplete one
  disabled, saying why, by the same state as the domain; Price showing
  that design's own price and writing no design;
- **the customer**: not final with priced so far; the total the sum of
  three; one design changed and calculated in the workspace moving the
  total by it alone; payment recorded, refused over the total, *Amount
  due* and *Paid in full*, all through two reloads of the app; the
  incomplete design still disabled after a reload;
- **an unknown category**, disabled on the card and in the workspace with
  the device unchanged;
- **a phone**, with nothing overflowing.

Three older tests moved with it, and say so where they do:
- `the_price_on_screen_test` presses **Calculate price** after each edit,
  and requires *Price needs recalculation* with the old figure struck
  through in between.
- `opening_an_existing_design_test` and `the_whole_customer_workflow_test`
  scroll the customer's page back to the top before looking for a card,
  because the summary under the cards lets the page scroll past the
  first.

The pricing tests' `given` gives every size a design asks for, not only
the width and the height.

### Pricing integrity

The brief: *a price is never of stale geometry, never of a design that is
gone, never off by a rounding, and read from the workshop's list whatever
version kept it.* Each fault is fixed where the fact it depends on lives.

- **Lines drawn and not read are never priced.** Whether the sheet has
  been read since it was last drawn on is the design's own fact,
  `Design.sketchUnread`, kept in its file only while it is true.
  `WorkspaceState.needsReading` reads it. Drawing a structural line sets
  it, a reading clears it, and an undo puts back whatever the design then
  was. A figure, an arrow or a note does not set it: they are not
  geometry.
  - `PriceReadiness` asks it first, after the category. While it is set
    the design is not price-ready, the engine prices nothing
    (`PriceStatus.notRead`), and every price button says *The drawing has
    changes that have not been read. Please Read the drawing before
    calculating the price.*
  - It is in the design, not the workspace, so a card knows too: *Drawing
    not read*, *Price: needs update*, and its Price disabled. A price
    calculated before shows only as the previous one.
  - Reading for the user was not chosen. A reading can raise questions and
    change the design, and doing that unasked to show a price would be the
    application deciding.
- **A price is current only for the design it was calculated from.**
  `PriceInputs` is the fingerprint: the design less its name, customer,
  dates, ink, notes, arrows and `sketchUnread`, plus the price list. Any
  change to geometry, material, colour, glass, ironmongery, option or rate
  makes the kept price *needs recalculation*. Nothing has to remember to
  invalidate it.
- **A deleted design takes its price with it.** `DesignStore.remove`
  removes the design's price record under the same key, and nothing else.
  Undo puts the record back with the design. The customer's total is read
  from the designs that remain, so it never includes one that is gone.
- **An older price list is migrated, never guessed**
  (`PriceListMigration`, `PriceList.schemaVersion` = 3):

  | Schema | Kept as | Carried as |
  | --- | --- | --- |
  | 1 | `proframe.pricelist.v1`: frame, sash and bar a metre, a colour's percentage, a price per leaf and per angled joint | frame → normal profile, sash → opening profile, a colour's percentage → its percentage; a bar rate that differed from the frame's, a leaf's and an angled joint's price named in the notes and left out |
  | 2 | the factory model with no `schemaVersion` | sealed units priced at the glass rates it had, which priced every pane |
  | 3 | `schemaVersion: 3` | as it is |

  Everything with the same name and meaning is carried at the same
  figure, and nothing is made up. Reading writes nothing. The panel says
  *Prices carried over from an older price list* with the notes. The
  owner's first save writes schema 3 under the current key.
- **The example rates are written once**, in `DefaultFactoryPricing`; the
  engine reads only the list it is given, and a scan keeps those figures
  out of every other file.
- **Lengths and money are whole units.** A `Metres` is whole millimetres
  and a `SquareMetres` whole square millimetres, so 20.98 m + 14.23 m is
  35.210 m exactly. A length is written to the millimetre, so the rows
  written add up to the total written. A price line is whole cents
  (`Money.cents`, half a cent rounded up), and every subtotal, total, sum
  over a customer, payment and amount due is a sum of cents.
- **A sealed glazing unit has its own rate** (`sealedGlassPerM2`,
  `customSealedGlassPerM2`), at its actual canonical area. Which panes are
  sealed is read from the solid (`PricingTakeoff.sealedUnitsOf`: a pane
  built with four faces of glass, per `DepthLayout.litesOf`), so pricing
  and the model never disagree. A sheet too thin for a cavity — a sliding
  panel beside a pleated screen — is priced at the glass rate. A sealed
  unit with no rate of its own is unpriced and says so; it never falls
  back to the glass rate.
- **Rollers** are the existing rule, kept: each sliding panel runs on
  `rollersPerSlidingPanel` rollers (the list's, 2 unless the owner says
  otherwise) at `rollerEach`; a fixed panel on none.
- **Discounts** are applied by the engine and kept in the design, but
  nothing on the screen gives one yet; that is a later screen.
- **Payment** is one figure; a history, credit and refunds are later.
  Paying more than a final total is refused.
- **A card's buttons are whole.** The price and **Price** stand on a row
  of their own, so *Edit information* and **Open** are shown in full on
  every laptop width.

`test/domain/pricing_integrity_test.dart` holds it, under the brief's
numbers:

- **30**: an unread design is not priced, and a previous price is not the
  price.
- **31**: a width changed makes the price stale.
- **32**: a delete takes exactly its record, and the total is the rest.
- **33**: migration from both older schemas, on the device and back.
- **The example rates**: written only in `DefaultFactoryPricing`.
- **34**: 20.98 + 14.23 = 35.21, and rows summing as written.
- **35**: cents.
- **36**: sealed and single-sheet glass, and no fallback.
- **37**: rollers 2, 4, then 3 and 6.
- **38**: 800 + 500 + 700 = 2,000 → 2,100, then not final.
- **39**: 2,000 with 500 paid is 1,500 due.

`test/app/pricing_integrity_on_screen_test.dart` holds it on the real app:

- a line drawn after the price, disabling it in the workspace with the
  message, through a figure, an undo and a Read;
- the card of a design kept unread;
- a delete and an Undo;
- *Edit information* in full at five widths, with the app's own typeface
  loaded so the measurement is the screen's.

### What a design is made of, and the factory's prices

The brief: *the final price depends on what the design is made of — uPVC or
aluminium, white or black — so the owner must be able to change those
choices for a design, and the rates for the factory, and every design card
must say its category, its material and its colour in words.*

```
Design ─ ProfileSelection ──┐            (frame's finish: material + colour)
                            ├─ PricingEngine ─ PriceResult (.profile records it)
PriceList ─ RateField ──────┘            (owner-only, kept by PriceListStore)
```

- **A design's material and colour are its frame's finish**
  (`ProfileSelection`, `lib/domain/pricing/profile_selection.dart`). The
  technical drawing and the solid are already built in it, so it is not a
  second copy of anything: choosing aluminium for the price is choosing it
  for the frame, and painting the frame in the inspector is choosing it
  for the price. Choosing it (`ProfileSelection.choose`,
  `WorkspaceController.chooseProfile`) puts the finish on the frame and on
  every bar that was in the frame's finish — one profile system — and
  leaves a bar the user gave a finish of its own. No line, pane, figure or
  piece of ironmongery moves.
- **Not chosen is a real answer.** The reading gives every new frame the
  stock white uPVC, which says nothing about what the customer wants. So a
  design is chosen only when somebody said so (`Design.profileChosen`,
  kept in the file while it is true, set by the price sheet and by the
  frame's own finish control) or when its frame is in any other finish —
  which only a person can have put there. That is how a design kept before
  this phase is read: a frame somebody painted keeps its material and
  colour; one still in the stock finish is *Not selected*. Nothing is
  assumed. Until it is chosen the design is not priced
  (`PriceRequirementKind.profile`, *Please choose the material and colour
  of the profile to calculate the price.*), and its card says *Price:
  choose material*.
- **The engine reads material and colour from the list, and nothing
  else.** It already priced each length of profile at its own material's
  normal or opening rate and each colour by the catalog's rate for that
  material (*The price*; since Phase 29 *The factory's colour catalog*). uPVC and aluminium are one engine with two
  rows of the list; a colour the list does not name takes the material's
  special figure. Nothing in a widget is a rate.
- **The price is worked out, never typed.** There is no field for a final
  price. The price sheet (`DesignPriceSheet`) shows the design's category,
  then **Material** and **Colour** (`ProfileChooser`, offering the list's
  materials and each material's named colours, swatch beside name), then
  what it measures and costs. Choosing either puts it into the design,
  keeps it, and works the price out again at once (`ProfileChoice`, handed
  the sheet's own `WidgetRef` because the card beneath it rebuilds as the
  price is kept). The same chooser stands at the head of the workspace's
  **Price** panel, where a change leaves the kept price *needs
  recalculation*, never shown as the price. A design whose only gap is its
  material has its **Price** button enabled, because the sheet is where it
  is chosen.
- **A price records what it was priced in** (`PriceResult.profile`,
  `PricedProfile`: material, its label, colour and colour name), beside the
  price list's version and every rate on its lines, so a kept price says
  what it was a price of. A quotation snapshot can be built on it later.
- **A card says it in words** (`CardProfileLine`): *Material: Aluminium*,
  *Colour: ● Black*, or *Not selected*, under the category and the status,
  above *Last edited*. The picture is 94 px so the card keeps its height.
  The customer's summary says each design's category, material and colour
  under its price (`CustomerFinancialSummary.profileKey`).
- **Who may change what.** The factory's rates are the owner's
  (`WorkshopRole`, `PriceListStore.save`); a design's material and colour
  are the design's, edited by whoever edits the design — the same as the
  frame's own finish control has always allowed — so offering them only to
  the owner would be a lock with the inspector beside it open.
- **The factory's prices** (`FactoryPricesScreen`, the price-tag icon on
  the customers' header). Every figure of the list is a `RateField`
  (`price_list_fields.dart`): each material's normal and opening profile,
  what a colour the catalog does not name adds on each, a metre and as a
  share (the catalog's own colours are edited as colours since Phase 29 —
  *The factory's colour catalog*), glass,
  sealed units, panels and any other colour of each, every piece of
  ironmongery, the sliding track, rollers and rollers a panel, installation
  and each category's labour. Writing every field back as it reads leaves
  the list identical, so editing drops nothing. Staff see every figure and
  **Unlock as owner**; the owner edits, an empty optional figure is *not
  priced*, a figure below nothing or a part roller is refused, and **Keep
  prices** keeps a new version — every price worked out from the old one
  then needs recalculating. **Lock** returns to staff, and every run starts
  as staff.
- **The owner's PIN** (`OwnerAccessStore`) is set the first time the
  editor is unlocked and asked for after; only a salted SHA-256 of it is
  kept. It is a lock on a screen, not security: anyone who can clear the
  device's storage can set a new one. Accounts would replace it.
- **Areas are written to four places** (`SquareMetres.label`, *1.4296
  m²*), so the area written times its rate is the line's amount to the
  cent for any rate up to 100 a square metre — *1.43 m² × 45.00* read as
  64.35 against a line of 64.33. The amount is always the exact area at
  the rate; nothing is worked out from what is written. Lengths were
  already written to the millimetre.
- **Prices left behind by deletes before *Pricing integrity* are swept**
  (`DesignStore.sweepOrphanPrices`, once a run, from the customers screen
  through `orphanPricesSweptProvider`). Only a design's current price —
  a record under `PriceRecordStore.keyPrefix` — is ever removed, and only
  where its design is known neither by a line of the index nor by a record
  of its own; an index that cannot be read sweeps nothing. A later
  quotation's price, meant to outlast its design, will live under a key of
  its own and is never touched.
- **Deferred, as the brief says**: payment history, credit, refunds, a
  discount screen, quotation and order history, a manual price override,
  and paging the customer's summary. Adding, editing and retiring named
  colours came in Phase 29 (*The factory's colour catalog*).

`test/domain/material_and_colour_pricing_test.dart` holds it under the
brief's numbers: **38** uPVC and aluminium at their own rates, equal rates
equal prices; **39** black adding its figure a metre, equal when set
equal, an unnamed colour at the special figure; the profile chosen and
never assumed, read from a painted frame, choosing moving nothing; **15**
the price recording its profile through a save; **41** 1.4296 m² × 45 =
64.33 and every real line checkable to the cent; **42** the sweep taking
the orphan and nothing else, and keeping a price whose design has only its
record; **43** the owner's rate kept, read back and used, staff refused,
every figure a field, and empty or bad figures; **44** PVC white → aluminium
→ black, stale between and each at its own rates; **32** a customer's total
moving by exactly one design's change; **34** an unknown category unpriced;
**35** an angled design re-priced at its own polygon; and the owner's PIN.

`test/app/material_and_colour_on_screen_test.dart` holds it on the real
app: **40** every card's category, material, colour, status and price in
words, and a long name, colour and category fitting at four widths with the
app's own typeface; **31 & 32** the card's sheet making aluminium uPVC and
black white, each priced afresh, with the card and the summary following;
**37** a design missing only its material priced from its sheet; **44** the
workspace's chooser leaving the price stale, recalculated at aluminium's
rates, and undone; **43** staff reading factory prices, the owner's PIN
set, a rate kept, lasting a reload as staff again, and pricing a design;
and a wrong PIN leaving it locked.

### The factory's colour catalog

The brief: *a professional, persistent, material-aware factory colour
catalog — the owner adds, edits, renames and retires colours, each with a
stable id, the materials it is sold in and a rate on each; the price is
always looked up by material and colour; a price already calculated is
never silently changed by a later edit to a colour.*

```
PriceList.colours ─ FactoryColour (id, name, swatch, grade, rates by material, active, order)
       │                                   ▲
       │ colourFor(material, colour, id?)  │ ColourCatalog.add / update / retire / restore
       ▼                                   │   (owner only, each a new version of the list)
ColourPricing ─ PricingEngine, DesignPriceState, ProfileChooser, cards
       ▲
Design.frame.finish (what every view draws) + Design.profileColourId (which colour it is sold as)
```

- **One catalog, not a list per material** (`PriceList.colours`,
  `FactoryColour` in `price_list.dart`). Phase 28 kept each material's
  colours under it, matched by the colour's value; that structure became
  this one rather than a second one beside it. A colour has an **id that
  is what it is** — `colour-golden-oak`, made from its name once and never
  again (`PriceListMigration.idFor`, unique among every colour, retired or
  not) — its name, its swatch, its grade (standard or not), its **rates**
  keyed by every material it is sold in, whether it is **active**, and its
  **order**. `ProfileRate` keeps the normal and opening rates and *any other
  colour* (`special`), which is only ever for a colour the catalog does not
  name.
- **Always material and colour together** (`PriceList.colourFor`), one
  answer (`ColourPricing`) read by the engine, the price's state, the
  selector and the card:

  | State | When | Said |
  | --- | --- | --- |
  | `named` | a catalog colour sold in the material, with its rate | priced at it |
  | `other` | a colour the catalog does not name | *any other colour* |
  | `notForMaterial` | chosen as a colour not sold in the material | *Please select a colour available for Aluminium.* |
  | `notConfigured` | sold in the material with no rate on it | *Colour pricing is not configured for Aluminium.* |
  | `retiredUnpriced` / `unknown` | retired and no longer priced on it, or an id the list does not have | *Colour pricing unavailable — please select an active colour.* |

  **Nothing falls back** — not to the other material's rate, not to *any
  other colour*, not to nothing, and never to another colour with the same
  swatch. The first and the last are the user's to choose
  (`ColourPricing.needsSelection`, `DesignPriceState.needsColour`, the
  card's *Price: choose colour*, the Price button opening the sheet to
  choose); *not configured* is the owner's, said as the list's problem.
- **The design says which colour it is sold as** (`Design.profileColourId`,
  written only when there is one); its frame's finish is still the colour
  every view draws, so there is no second "pricing colour" and the
  technical drawing and the solid follow the existing finish pipeline
  untouched. A colour chosen on the price sheet or in the Price panel
  carries its id (`ProfileSelection.choose(colourId:)`); a finish painted
  in the inspector clears it and is priced by its value, as before. A
  design kept before the catalog has no id and is matched by value on its
  material — an active colour first — so Phase 28's designs price as they
  did and still say *Material: Not selected* where nobody chose.
- **The selector offers the active colours of the material chosen**
  (`PriceList.offeredFor`), in the factory's order, from the catalog — no
  list of colours is written in a widget. A material chosen keeps the
  colour, with its id: where the new material is not sold in it the field
  says *Please select a colour available for Aluminium* and nothing is
  priced until one is chosen; **nothing is chosen for the user**. A retired
  colour a design is still in is shown as its value, with *Retired: no
  longer offered for new designs.* under the field.
- **The owner edits colours as colours** (`ColourCatalog`,
  `lib/domain/pricing/colour_catalog.dart`), from the **Colours** section of
  Factory prices (`FactoryColoursSection`, `ColourDialog` in
  `lib/app/screens/factory_colours.dart`): **Add colour**, edit (name,
  swatch by palette or code, standard or not, materials, a metre and a
  share on each), retire after a confirmation, and bring back. Staff see
  every row — swatch, name, *uPVC 1.00 USD/m · Aluminium 1.50 USD/m*,
  *Active* or *Retired* — and no button. Every operation is checked first
  and changes nothing on a problem: *Colour name is required.* (trimmed);
  no two active colours sold in one material called the same, whatever the
  case; *Choose at least one material.*; *Aluminium colour rate is
  required for a colour that applies to Aluminium.*; *A rate cannot be
  below nothing.*; *Enter a figure.* A colour's rates are not flat
  `RateField`s any more — they are the colour's — and *any other colour*
  still is.
- **Renaming keeps the id**, so every design in the colour shows the new
  name; **retiring removes nothing** (`ColourCatalog.retire`) — the colour is
  not offered, every design in it keeps it, is named by it, never
  *Unknown*, and is still priced at its rate. Nothing in the catalog can be
  deleted, and nothing cascades into a design.
- **Every change is a version** (`ref.savePriceList` → `PriceListStore.save`),
  so every price calculated before says *Price needs recalculation* and is
  shown only as the previous figure. **A kept price is never changed**: the
  record holds the result as it was, its colour line's rate, the list's
  version, and `PricedProfile.colourId`, `colourName` and `colourRate` as
  they were — a renamed colour's old price still says its old name.
- **What a colour adds is charged once**: all the profile in one material
  and colour together, so much a metre on its metres and its percentage on
  what that profile cost, and nowhere else.
- **Kept and read back** in schema 4 (`PriceList.schemaVersion`). A list
  kept in schema 3 is migrated as it is read (`PriceListMigration._v3ToV4`):
  a colour with the same value, name and grade on two materials becomes one
  colour with a rate on each, at the figures it had; colours that differ
  stay apart; nothing is sold in a material it was not; ids come from the
  names; reading writes nothing. Migrating Phase 28's example list gives
  exactly today's (`DefaultFactoryPricing`). A colour entry that cannot be
  read, or repeats an id, is passed over; a rate kept that is not a price is
  no rate. A price kept before reads as it was.

`test/domain/factory_colour_catalog_test.dart` holds the brief's numbers:
**40** Black on aluminium at 1.00 in version 1 and 2.00 in version 2, the
price kept with 1.00 and version 1, a new one with 2.00 and version 2;
**41** Golden Oak, PVC 2.00 and aluminium 3.00, kept, reloaded, offered for
both and priced at each; **42** Silver aluminium-only, a PVC design in it
asked for a PVC colour; **43** Special Blue with no aluminium rate, *not
configured* and borrowing nothing, the editor refusing it, and *any other
colour* only for unnamed colours; **44** Bronze retired — not offered,
kept, named and priced, its old price untouched, *please select an active
colour* where it is no longer priced, and brought back only while its name
is free; **45** Dark Grey renamed Anthracite Grey with the same id and the
old price saying the old name; **46** nothing deleted and an unknown id
never matched to another colour; **47** colour never geometry; **48**
200.00 of profile and 10% for its colour coming to 220.00, and the same by
the metre; and the checks, persistence, migration and old designs.
`test/app/factory_colours_on_screen_test.dart` holds it on the real app:
staff reading the colours and a wrong PIN; Anthracite Grey added with each
problem said, kept as version 1 through a reload with an unkept figure not
lost; a rate edited and the colour renamed and retired, each a version,
the design still in it, named, priced and its old price a previous one;
the selector's filtering and a material change asking for a colour; the
new colour on the card, the summary and the frame; and the screen and the
dialog at five widths from 320 to 1920.

**One thing to know when upgrading:** a price calculated before Phase 29
says *Price needs recalculation* once, because the list it was calculated
from is now kept in schema 4 and a price is current only for the list as it
is. The figure itself is kept and shown as the previous one.

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

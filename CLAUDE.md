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

## When the drawing is ambiguous, ask

Where the reading cannot tell — a mark that straddles a bar, lines that do
not close, a diagonal that might be a glazing bar or an opening symbol — the
application produces a **question**, not an answer. Every option is offered
and none is chosen. Guessing quietly is worse than asking, because a wrong
guess looks like a decision the user made.

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

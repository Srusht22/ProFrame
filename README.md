# ProFrame

**Draw a door or window by hand. Get the real thing in 3D.**

You sketch a door or a window the way you would on paper — a rough outline with
a finger or a stylus, a line where the mullion goes, two diagonals to show which
way it opens, a dimension with the size written on it. ProFrame reads that
sketch, turns it into a proper parametric product, and generates a clean
technical drawing and a real, dimensioned 3D model of the actual door or window.

```
DRAW  ──▶  UNDERSTAND  ──▶  GENERATE  ──▶  EDIT  ──▶  VISUALISE
```

## The rule everything else follows

> **The user creates the design. The application does not create the design for
> the user.**

The app never redesigns, simplifies, beautifies, normalises or "corrects"
anything. It does not equalise sections, centre openings, square things up,
round sizes to tidy numbers, force symmetry, or improve proportions because they
would look better. A customer who asks for a deliberately lopsided window gets a
deliberately lopsided window.

When something is genuinely a problem to build, the app **says so and offers a
fix** — *Keep my design* / *Modify* / *Show the recommendation* — and the design
only changes if the user picks one.

The order of authority, never reversed:

```
the user's explicit instruction
        ↓  the exact dimensions they gave
        ↓  what they drew
        ↓  geometric constraints (sections must add up)
        ↓  manufacturing validation (reports, never edits)
        ↓  suggestions (offered, never applied)
```

---

## The pipeline

The single most important rule in this codebase: **the 3D model is never made
from the pixels of the drawing.** Every stage produces a structured description
that the next stage consumes.

```
Raw strokes            features/drawing        Stroke, StrokePoint, Sketch
      │                                        (finger / mouse / stylus + pressure)
      ▼
Recognised primitives  features/recognition    LinePrimitive, RectanglePrimitive,
      │                                        ArcPrimitive, ArrowPrimitive,
      │                                        DimensionPrimitive, NotePrimitive
      ▼
Geometric structure    features/recognition    GeometryStructure — outline, bands,
      │                                        mullions, sections, opening marks
      ▼
Parametric model       shared/models           OpeningModel — the one source of truth
      │                                        (free-form sections at exact mm
      │                                         positions, materials, hardware)
      ▼
Solved geometry        RegionSolver            every bar, sash and pane in millimetres
      │
      ├──▶ 2D technical drawing   features/rendering/painters
      ├──▶ 3D assembly            features/rendering/three_d  (SceneBuilder → Scene3D)
      └──▶ Price                  features/pricing
```

Because the drawing, the 3D view and the price are all derived from
`OpeningModel`, they can never disagree with each other. Change the width in the
editor and all three update from the same edit.

### Sections are free-form, not a grid

`OpeningModel` holds a list of `DesignRegion`s — plain rectangles at exact
millimetre positions in the product's own coordinate space, nestable for a leaf
that holds glass over a panel. **It is deliberately not rows and columns.**

That distinction is the whole point. Asked for a 400 × 400 opening in the
top-right corner, a grid would have to push a mullion and a transom right
through the rest of the design. Free-form sections just put a rectangle there:

```
┌────────┬───────────────────┬────────┐
│        │   upper glass     │ 400 ×  │   the corner opening does NOT
│  side  ├───────────────────┴────400─┤   divide the sections below it
│  vent  │        glass              │
│  400   ├───────────────────────────┤
│  full  │        panel              │
└────────┴───────────────────────────┘
   400  +          1600            = 2000 mm exactly
```

Whatever area no section claims becomes structure. `RegionSolver` cuts the
leftover on every section edge, drops the covered parts and merges what remains
into real profile boxes — which is how the L of frame around that corner opening
appears by itself, correct in both the drawing and the 3D model.

Each section's aperture takes the frame's face on an edge that sits on the
outside of the product, and half a bar on an edge shared with a neighbour. That
is why sections specified as 400 + 1600 in a 2000 mm product still add up to
exactly 2000 mm.

### The drawing is read as a planar subdivision, not as a grid

`StructureInterpreter` does not try to match the drawing against a row/column
layout. Every line the user drew is treated as a **cut**, and the outline is
subdivided by those cuts: the cut coordinates make a lattice of candidate
cells, and two neighbouring cells are merged (union-find) unless a drawn line
actually covers the boundary between them. Each merged group is then decomposed
back into maximal rectangles.

That is what makes a partial divider behave the way it was drawn. A line that
stops halfway is a T-junction, and it stays a T-junction:

```
drawn                     a grid interpreter              ProFrame
┌───────────────┐         ┌───────┬───────┐               ┌───────┬───────┐
│               │         │       │       │               │       │       │
├───────┬───────┤   →     ├───────┼───────┤        vs     ├───────┴───────┤
│       │       │         │       │       │               │       │       │
└───────┴───────┘         └───────┴───────┘               └───────┴───────┘
                          invents the upper cut           3 sections, as drawn
```

The same mechanism is what makes a rectangle floating in the middle of the
outline — touching no edge — come out as its own section, with the leftover area
around it filled in as real sections rather than being discarded. Diagonals,
arcs, arrows, dimensions and notes are never cuts, so an opening symbol cannot
accidentally split a leaf.

A section the user drew as a closed shape of its own but did not mark is not
guessed at: it comes back at 0.6 confidence with *"You drew this section on its
own but did not mark how it opens"*, which puts it in **Needs your answer** with
real choices instead of silently becoming fixed glass.

---

## What the app does

**Drawing (the hero screen)**
- Freehand pen with stylus pressure, plus line, rectangle, division, opening
  diagonal, swing arc, sliding arrow, dimension and note tools.
- Infinite sheet: one finger draws, two fingers pan and zoom.
- Intelligent straightening — a line drawn at 88° becomes exactly vertical, a
  deliberate 60° brace is left alone.
- Snapping to endpoints, intersections, frame edges, centres, equal spacing and
  the grid, with an on-canvas guide showing *why* a point moved.
- **Precision mode** turns all of that off and keeps every stroke exactly where
  it was drawn. Freehand and precision live side by side.
- Undo/redo, eraser, select, duplicate, rotate — with the selection actions
  available on every screen size, not just where there is room for a panel.
- **Move and resize what you drew.** With the select tool, drag inside the
  selection to move a stroke and drag a corner grip to resize it; the opposite
  corner stays anchored. Every step of a drag is computed from where the gesture
  started, so dragging back and forth cannot accumulate drift, and the whole
  gesture is a single undo step.
- Tap a dimension with the select tool to set its measurement, or correct one
  already entered; everything derived from the drawing scale follows.

**Understanding**
- Reads the outline, transoms, mullions and each section.
- Reads opening direction from the standard elevation symbols: two diagonals
  meeting at an edge put the hinges on that edge; a horizontal arrow is a
  sliding leaf; a swing arc is a hinged one.
- Keeps structure, opening marks and annotation strictly apart — a dimension
  line can never become a bar of the door.
- The *Understanding your design* screen lists what was read and what it is not
  sure about, with real alternatives to pick from. **Nothing uncertain is
  applied until you choose it.**

**Dimensions**
- Two synchronised routes to the same number: draw a dimension line and type the
  size on it, or type it directly into the editor.
- The first measurement calibrates the whole drawing (600 canvas units = 1200 mm
  → 0.5 units per mm).
- Sizes that were derived rather than measured are labelled as derived, and a
  nearly-round value is *offered* ("Did you mean 1100 mm?"), never applied
  silently.

**The generated product**
- A clean architectural elevation: profiles as double lines, glass hatched,
  opening symbols, dimension chains, section sizes.
- A real 3D assembly: outer frame as four members with true profile depth,
  mullions and transoms, sash stiles and rails, glazing beads, glass with real
  thickness, solid panels, louvres, hinges sized and counted by leaf height,
  handles, locks, thresholds and sills. Sliding leaves sit in separate tracks;
  outward-opening leaves sit further out through the frame depth than inward
  ones.
- Camera presets (front, back, left, right, top, perspective), a Realistic /
  Technical view switch, 3D dimensions and auto-rotate.
- **Tap a part in the 3D view** to select it. The renderer raycasts the actual
  assembly, walks up from an edge overlay to the mesh that owns it, and reports
  the part back to Flutter, which names it in plain words — *left sash stile*,
  *glass*, *transom* — with its size and profile. A drag that orbited the camera
  is not treated as a tap.

**Original vs Result**

- A third view puts **your drawing beside the generated model**, at the same
  scale, so the comparison is visual and immediate.
- Under it, a match checklist states the actual numbers: section count, divider
  count, outline proportion, and the drawn-versus-built position of every
  section. Anything that drifted is named, with the difference, rather than
  being smoothed over. A compact banner carries the same verdict on the smaller
  layouts.

**Editing — every part of it, two ways**

Both routes make the identical edit, because both call the same operation.

- **Drag it.** Tap any section in the technical drawing to select it; drag any
  internal boundary to move it. Every section sharing that boundary moves with
  it, so the totals still add up, and the drag stops at the point where a
  neighbour would become too small to build rather than collapsing it.
- **Type it.** Width, height, distance from the left, distance from the top,
  and a one-tap anchor to any corner or side. Plus opening type, swing, infill,
  glass, panel, handle, handle height above the floor, lock, mesh — and divide
  across, down, or into panes within a leaf.
- **Place an opening.** Give a size and a corner: it lands at exactly that size
  in exactly that place, and the section it lands in keeps the area around it as
  real sections. Nothing else in the design moves.
- **Set the profile itself.** Frame face and depth, sash face and depth, mullion
  and transom face, glazing bead, and the infill thickness of any section. Each
  one follows the chosen material until it is pinned, and a pinned value reaches
  the drawing, the 3D model and the price alike. One tap hands it back to the
  material.

**Say what you want**

Describe a change in plain words and the geometry follows:

| You say | What happens |
| --- | --- |
| `Make the upper half glass and the lower half panel` | splits into two sections |
| `Make the glass 70%` | moves the shared boundary; the panel becomes 30% |
| `Put a 40 by 40 cm opening at the top-right` | exactly 400 × 400 mm, in that corner |
| `On the left side make an opening 40 cm wide and full height` | 400 × the full height |
| `Make the left section 40 cm wide` | the neighbour takes up the difference |
| `Make the left section full height` | takes the space it needs |
| `Make the right panel sliding` / `Keep the centre panel fixed` | changes how it opens |
| `Put the handle 100 cm from the floor` | exact handle height |
| `Make the left section 30 cm wider than the right section` | solved so the total holds |
| `Move this to the top-right` | re-anchors the selected section |

If a sentence is not on that list, the app says it did not understand and
changes nothing. If a phrase could mean two different sections, it says which
ones and asks — it never picks one.

**Everything else**
- Start from scratch or from a template — fixed light, single casement,
  casement + fixed, transom over two sashes, two-panel slider, single door,
  glass-over-panel door, double door, door with transom. A template is only a
  shortcut: it produces an ordinary editable design, and drawing by hand still
  supports geometry no template covers.
- Edit the structure: size, material, finish, glass, panels, divisions, opening
  type, swing, handle, lock, mesh, glass-over-panel leaves.
- Duplicate a saved design to try a variation without losing the original.
- Manufacturing warnings (sections too small, leaves too wide to hang).
- Price derived from the generated geometry — profile metres, glazed area,
  hardware counts — not from a generic catalogue entry. Every rate is editable
  and saved: profile per metre by material, glazing and infill per square
  metre, each piece of hardware, labour, installation, waste, overhead and
  margin.
- Autosave with *Recover unfinished design?*, version history with restore,
  export to PNG, PDF and a project file, OS share sheet.
- Works offline; nothing needs a server.

---

## What is honestly *not* implemented

Per the "do not fake features" rule, these are stated plainly:

- **The instruction parser is not a language model.** It is a deterministic
  parser for the documented phrasings in the table above — it runs offline,
  always does the same thing for the same words, and every phrase it accepts is
  covered by a test. It does not paraphrase, infer or approximate, because a
  wrong guess here silently changes a product somebody is going to build.
  `InstructionParser` is a plain class, so a model-backed implementation can
  replace it without anything downstream changing.
- **Handwriting is not read automatically.** Recognising handwritten digits
  reliably enough to size a manufactured product needs a trained model, and a
  misread `1100` as `1400` is a scrapped frame. So the app asks for the number
  the moment a dimension line is drawn. The seam is real:
  `HandwritingRecognizer` (`features/recognition/handwriting_recognizer.dart`)
  is the interface, `TypedValueRecognizer` is the shipped implementation, and a
  real OCR or cloud recogniser drops in without touching anything downstream.
- **Project files can be exported but not re-opened in the app.** The format
  and its parser are real and tested (`ExportService.importProjectFile`), but
  choosing a file from the device needs a file-picker plugin that is not a
  dependency yet, so there is no Import action. Treat `.proframe` as a backup
  and handoff format for now.
- **No CNC output.** Cutting lists and machining files are not generated. The
  solved geometry (`SolvedOpening`) already contains every profile length and
  pane size those would need, but nothing pretends to produce them.
- **The 3D preview needs a WebView.** It runs on Android, iOS, macOS, Windows
  and the web. On Linux desktop the viewer says so instead of showing an empty
  box; the model itself is still fully generated.
- **Business features are out of scope** by design — no CRM, no quotations, no
  orders, no inventory. Pricing is a secondary read-out of the geometry.

---

## Project layout

```
lib/
  core/
    constants/    app-wide constants (storage keys, canvas, autosave)
    errors/       AppException family
    routing/      go_router configuration — draw → understand → design
    services/     key/value storage seam + Riverpod providers
    theme/        colours (#013E37 / #FFEFB3), typography, spacing, breakpoints
    utilities/    Vec2/Box2 geometry maths, unit conversion, ids
  features/
    drawing/      canvas, painters, DrawingController (ink + history)
    recognition/  stroke → primitive, snapping, structure interpretation,
                  handwriting seam, interpretation service
    dimensions/   scale calibration, dimension resolution, measurement dialogs
    geometry/     free-form region model, solver, editor, validator,
                  selector, drawn-vs-built comparator, instruction parser
    configurator/ session state, interpretation screen, structure editor
    rendering/    2D technical painter, Dart SceneBuilder, three.js bridge/viewer,
                  Original vs Result comparison
    pricing/      rates, geometry-driven pricing engine, breakdown UI
    projects/     design library, repository, home screen
    export/       PNG / PDF / project file, cross-platform save & share
  shared/
    models/       Sketch, primitives, GeometryStructure, DesignRegion,
                  OpeningModel, Scene3D, materials, calibration, DesignDocument
    widgets/      responsive helpers and shared UI
assets/web_3d/    three.js r128 + OrbitControls + opening_engine.js
```

`assets/web_3d/opening_engine.js` contains **no product knowledge**. It receives
an explicit list of parts (role, size, position, rotation, material) built in
Dart and instantiates three.js meshes for them. It cannot invent geometry, which
is why 3D component placement and proportions are unit-testable.

---

## Responsive layout

Each size class is a different arrangement, not a scaled copy:

| Width | Drawing screen | Design screen |
| --- | --- | --- |
| < 600 (phone) | canvas fills the screen, tools on a bottom bar | tabs: View / Edit / Price |
| 600–1440 (tablet) | tool rail + canvas | structure panel + viewer |
| ≥ 1440 (desktop) | tools \| canvas \| properties | structure \| viewer \| price |

The widget tests pump every screen at 390×844, 1024×768 and 1600×1000; Flutter
turns any overflow into a test failure, so they double as a layout regression
suite.

---

## Running it

```bash
flutter pub get
flutter run -d chrome        # or any connected device
```

Verification:

```bash
flutter analyze              # no issues
flutter test                 # 240 tests
flutter build web --release
```

The test suite covers the recogniser (straightening, shapes, roles), structure
interpretation (mullions, transoms, hinge sides, sliding, ambiguity), dimensions
(calibration, measured vs derived, suggestions), the region solver, the editing
operations, the instruction parser, the 3D assembly (part composition,
proportions, hardware placement, updates when the model changes), pricing
(geometry-driven, consistent with the 3D hardware counts, rates editable and
damage-tolerant), every template, export, persistence, the editing interactions,
and the end-to-end pipeline from a hand-drawn sketch to a priced 3D model.

A whole group exists purely to prove the app does not redesign anything:

- the worked example from the brief reproduces exactly — a 400 mm full-height
  side vent, a 400 × 400 corner opening, and the sections between them
- a corner opening does not divide the sections below it
- a deliberately lopsided design is not equalised, and an off-centre opening is
  not moved to the middle
- dragging a boundary conserves the total and stops at the buildable minimum
  rather than collapsing a neighbour
- typing a size and dragging the same boundary produce identical geometry
- the validator reports overlaps, gaps and over-wide leaves without touching the
  design, and its suggested fix only applies when it is asked for
- the spoken instructions from the brief, run in order, produce the same
  geometry as authoring it by hand
- a divider drawn only halfway stays a T-junction and is never completed into a
  full cross
- a rectangle floating inside the outline becomes its own section, and the app
  asks what it is instead of deciding
- moving a stroke on the canvas does not resize it, resizing from a corner keeps
  the opposite corner fixed, and dragging away and back leaves the stroke
  exactly where it was

---

## Brand

Primary `#013E37`, accent `#FFEFB3`. Premium, architectural, clean; no
decorative gradients.

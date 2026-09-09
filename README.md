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
      │                                        (rows × cells, materials, hardware)
      ▼
Solved geometry        OpeningSolver           every bar, sash and pane in millimetres
      │
      ├──▶ 2D technical drawing   features/rendering/painters
      ├──▶ 3D assembly            features/rendering/three_d  (SceneBuilder → Scene3D)
      └──▶ Price                  features/pricing
```

Because the drawing, the 3D view and the price are all derived from
`OpeningModel`, they can never disagree with each other. Change the width in the
editor and all three update from the same edit.

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
- Undo/redo, eraser, select, duplicate, rotate.

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

**Everything else**
- Edit the structure: size, material, finish, glass, panels, divisions, opening
  type, swing, handle, lock, mesh, glass-over-panel leaves.
- Manufacturing warnings (sections too small, leaves too wide to hang).
- Price derived from the generated geometry — profile metres, glazed area,
  hardware counts — not from a generic catalogue entry.
- Autosave with *Recover unfinished design?*, version history with restore,
  export to PNG, PDF and a project file, OS share sheet.
- Works offline; nothing needs a server.

---

## What is honestly *not* implemented

Per the "do not fake features" rule, these are stated plainly:

- **Handwriting is not read automatically.** Recognising handwritten digits
  reliably enough to size a manufactured product needs a trained model, and a
  misread `1100` as `1400` is a scrapped frame. So the app asks for the number
  the moment a dimension line is drawn. The seam is real:
  `HandwritingRecognizer` (`features/recognition/handwriting_recognizer.dart`)
  is the interface, `TypedValueRecognizer` is the shipped implementation, and a
  real OCR or cloud recogniser drops in without touching anything downstream.
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
    geometry/     structure → parametric model, structured model edits
    configurator/ session state, interpretation screen, structure editor
    rendering/    2D technical painter, Dart SceneBuilder, three.js bridge/viewer
    pricing/      rates, geometry-driven pricing engine, breakdown UI
    projects/     design library, repository, home screen
    export/       PNG / PDF / project file, cross-platform save & share
  shared/
    models/       Sketch, primitives, GeometryStructure, OpeningModel, Scene3D,
                  materials, calibration, DesignDocument
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
flutter test                 # 135 tests
flutter build web --release
```

The test suite covers the recogniser (straightening, shapes, roles), structure
interpretation (mullions, transoms, hinge sides, sliding, ambiguity), dimensions
(calibration, measured vs derived, suggestions), the solver (proportions, pinned
sizes, nesting), the 3D assembly (part composition, proportions, hardware
placement, updates when the model changes), pricing (geometry-driven, consistent
with the 3D hardware counts), export, persistence and the end-to-end pipeline
from a hand-drawn sketch to a priced 3D model.

---

## Brand

Primary `#013E37`, accent `#FFEFB3`. Premium, architectural, clean; no
decorative gradients.

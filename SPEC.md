# ProFrame — Specification

The authoritative requirements for this project. Assembled from the
specification supplied by the factory. Phases are checked against this file.

> **Read this entire specification before making implementation decisions.**

Act as a senior Flutter engineer with expertise in computational geometry,
parametric 3D modelling, accessible UX, and software testing.

This must NOT be a "vibe-coded" project. Do not produce attractive screens with
fake functionality, unstructured code, or an unreliable drawing-to-3D pipeline.
Work from a clear architecture, implement in runnable increments, test the
important behaviour, and document limitations honestly.

---

## 1. Product goal and target users

The users are factory workers or salespeople who are comfortable sketching
doors and windows on paper but are not familiar with AI and **do not want to
interact with AI**.

They draw directly inside the application using a finger, stylus or mouse,
similar to drawing on paper. The app interprets that drawing and turns it into
an editable, parametric 3D door or window.

The reference drawing style is: a rough outer frame; vertical and horizontal
internal divisions; fixed and opening sections; sometimes straight sloping tops
or unequal side heights; uneven, non-professional pen strokes.

**Do not build:** an AI chatbot; a prompt-writing interface; a
photo-upload-first application; an image generator that creates a picture
resembling the sketch; a template-only configurator that replaces the user's
layout with the nearest standard design.

Recognition happens in the background. Users interact with ordinary drawing
tools, measurements, buttons and visual choices.

## 2. Non-negotiable accuracy rules

The system must preserve the **user-confirmed design**, not generate a
similar-looking alternative.

Preserve: the intended outer shape; the number and arrangement of sections;
horizontal and vertical divisions; intentional slopes; fixed/opening
assignments; confirmed measurements and opening directions.

A rough sketch provides design **intent**, not exact manufacturing dimensions.
Therefore:

- Use entered or confirmed measurements for exact geometry.
- Treat unmeasured proportions as estimates.
- **Never silently invent missing dimensions.**
- **Never assume sections are equal** unless the user chooses that rule.
- Never silently replace an unsupported shape with a rectangular template.
- Ask for clarification through simple visual controls when necessary.

"Exact" means matching the confirmed geometric specification within documented
modelling tolerances — not copying shaky strokes literally.

A provisional 3D preview is acceptable before all measurements are known, but
it must clearly say that measurements are incomplete. **Do not promise
manufacturing accuracy from an incomplete sketch.**

## 3. Basic user workflow

### A. Create a design

Two large choices: **Door** or **Window**. Then **PVC** or **Aluminium**. Then
product/frame colour, and a factory-approved profile system using a factory
default where possible. Keep advanced technical options out of the beginner's
main workflow.

### B. Draw

A large canvas. Users can draw the outside boundary, draw internal dividers,
add horizontal sections above or below other sections, draw straight sloping
tops, select/move/delete lines, and undo/redo.

Optional rectangle and straight-line tools may be provided, but users must not
be forced to use predefined door/window layouts.

### C. Assign section behaviour

Exact factory labels:

- **CH** = Fixed; does not open.
- **Z** = Opening sash or door leaf.

Tap a section, choose CH or Z with large labelled buttons. **Do not default
every unmarked section to CH without a confirmed factory rule.**

For Z, provide visual opening controls: opening type; hinge side, when
applicable; inward or outward opening, when applicable; sliding direction, when
supported.

Clearly define whether the drawing is viewed from inside or outside. **Do not
infer handing from an ambiguous symbol.**

> Support **fixed and hinged** sections in the first complete implementation.
> Add other opening mechanisms only when their geometry and behaviour are
> actually implemented and tested. **Do not show nonfunctional choices.**

### D. Enter dimensions

Tap dimension labels and use a numeric keypad. Support overall width and
height; divider positions or section measurements; equal-section distribution
as an **explicit command**; left and right heights for straight sloping-top
designs; profile-dependent depth and frame dimensions.

Use **millimetres internally**. Allow display/input units to be configured.

Make the dimension reference explicit: outside frame size; wall opening size;
divider centreline or clear opening, where relevant. **Do not confuse wall
opening dimensions with frame dimensions. Do not apply hidden installation
allowances.**

Detect inconsistent or insufficient dimensions and explain the problem in plain
language.

### E. View 3D

A clear "View 3D" action generating actual interactive 3D geometry: frame
members; internal dividers; fixed glazing/panels; opening sashes or door
leaves; appropriate infill; basic hardware where supported.

Users can rotate, pan and zoom; switch between 2D and 3D; preview supported Z
sections opening; select sections and edit their properties. **CH sections must
remain fixed during opening animations.**

### F. Edit and save

Users can change dimensions, divider positions, CH/Z assignments, opening
settings, material/profile system, product colours, and glass or panel options.

The 2D and 3D views must update from the same underlying design. Saving,
reopening, renaming and duplicating are supported. **A saved design must remain
editable, not just become a screenshot or mesh.**

## 4. Drawing and recognition engine

Capture vector strokes directly from the canvas. Do not introduce handwriting
OCR, photo processing, or an external AI API unless justified — direct drawing
already provides stroke coordinates.

A tested geometry-recognition pipeline: stroke resampling and noise reduction;
identification of approximately straight segments; endpoint snapping;
intersection detection; outer-boundary detection; internal-divider detection;
closed-region construction; validation of the resulting layout.

Important behaviours:

- **Straighten shaky lines without flattening intentional slopes.**
- Support partial dividers and T-junctions.
- Do not interpret every scribble or opening mark as a structural divider.
- Highlight ambiguous geometry rather than silently accepting it.
- Let users correct a line, boundary or section without redrawing everything.
- Preserve the original strokes so users can compare or undo interpretation.

Recognition may be rule-based for the initial supported drawing grammar. A
general-purpose generative AI model is not required.

If genuine curves are outside the first release's scope, say so clearly. **Do
not quietly turn a curved design into a straight-edged one.**

Keep drawing gestures separate from pan/zoom gestures so moving the canvas does
not accidentally create geometry.

## 5. Editable design model and 3D architecture

One versioned, structured design model is the source of truth, containing:
stable project and component IDs; door/window category; PVC/Aluminium
selection; profile-system references and versions; product finishes; outer
boundary; dividers and their relationships; sections and infill; CH/Z
assignments; opening mechanisms and viewing convention; dimensions, units and
geometric constraints; original drawing strokes; unconfirmed or estimated
values; model/schema version.

**Do not store the design only as pixels or an unstructured triangle mesh.**

The 2D editor, 3D generator, validation logic and exports must all consume the
same structured model.

Use reusable frame, sash, divider and infill components. Reusing components is
encouraged; **replacing the user's layout with a nearest-match template is
prohibited.**

Editability means changing dimensions, layout and components — not merely
rotating the camera.

Separate: (1) design semantics and parameters; (2) geometry generation;
(3) rendering; (4) persistence and export.

For an initial visual configurator, a deterministic parametric mesh generator
may be sufficient. If production-grade solids or CAD export are required, use a
suitable CAD engine through a clean interface, such as Open CASCADE or FreeCAD,
after assessing platform and deployment constraints.

**Do not describe a rendering library as a CAD kernel. Do not describe a GLB
file as a complete editable CAD project.** STEP exports can contain CAD
geometry but do not generally preserve the application's parametric editing
history. Always retain the native project data for reliable editing.

## 6. Factory data and manufacturing limitations

PVC and Aluminium are not merely colour labels. The selected system determines
applicable profile geometry and dimensions; frame/sash combinations;
clearances; glazing options; hardware compatibility; size and opening
limitations.

Factory administrators configure approved defaults. Ordinary users should not
need to enter every technical profile setting.

If real manufacturer data is unavailable: use clearly labelled **generic
preview profiles**; document their assumptions; **do not invent manufacturer
specifications**; **do not label the output production-ready**.

Manufacturing outputs require validated profile data, fabrication rules and
factory review. **Do not generate supposedly machine-ready CNC instructions
from generic visual geometry.**

## 7. Visual design — required colours

| Role | Hex | Flutter |
| --- | --- | --- |
| Cream | `#ffefb3` | `Color(0xFFFFEFB3)` |
| Deep green | `#013e37` | `Color(0xFF013E37)` |

Cream for the main background and selected surface treatments. Deep green for
primary buttons, headings, navigation and drawing tools. Cream text/icons on
deep-green buttons where contrast is sufficient; deep-green text/icons on cream
surfaces. Restrained neutral surfaces for forms, canvas areas and panels.

Define central design tokens and a consistent `ThemeData`. **Do not scatter
hardcoded colours throughout widgets.**

Style: professional, calm, clear, appropriate for factory work, easy for
inexperienced users. Avoid excessive gradients, decorative effects, tiny
controls and generic dashboard clutter.

**Brand colours are separate from product/frame colours.** Users must still be
able to choose finishes such as white, black, grey, brown, or factory-approved
finishes for the door/window itself.

Accessibility: check text and control contrast; use at least **48 logical-pixel
touch targets** where practical; support larger system text sizes; **do not
communicate CH/Z, errors or selection through colour alone**; use labels and
simple illustrations; provide tooltips and appropriate accessibility semantics.

Keep primary actions obvious: Draw · Measurements · CH / Z · View 3D · Save.

## 8. Responsive and adaptive layout

Responsiveness is mandatory: small phones, large phones, tablets,
desktop-sized windows, portrait and landscape, and window resizing on supported
platforms.

Agree on actual deployment platforms before selecting platform-dependent
rendering packages. Responsive layout alone does not prove a platform build is
supported.

- **Compact widths** — one main workspace at a time; switch between drawing and
  3D using tabs or a segmented control; bottom sheets for section properties
  and measurements; keep important actions reachable.
- **Medium widths** — larger canvas; collapsible property panel; adaptive
  toolbars.
- **Expanded widths** — drawing tools/navigation on the left; main canvas or 3D
  workspace in the centre; properties on the right; optional side-by-side 2D
  and 3D views.

**Use available layout constraints, not device-name checks.** Choose and
document suitable breakpoints.

Handle safe areas, the on-screen keyboard, scrollable forms, long labels and
localisation, large text, and landscape phones.

**Canvas coordinates and physical model dimensions must be independent of
screen size. Rotating the device or resizing the window must not change the
design geometry.**

Avoid overflow, clipped controls, and unusably small drawing areas. Never
hardcode pixel sizes in feature widgets. The canvas and 3D viewer must
resize/reflow correctly on orientation change **without losing the current
drawing**. Tablet landscape shows canvas and live preview side by side. Touch
targets minimum 48×48dp — users have worker hands, not a stylus.

## 9. Engineering quality — no vibe coding

Current stable Flutter and Dart; sound null safety; clear separation of UI,
application state, domain logic and infrastructure; one consistent
state-management approach; typed models and validated serialisation; testable
geometry services independent of widgets; centralised error handling and design
tokens; clear names and focused files/classes; formatting, static analysis and
automated tests.

**Do not:** put the entire application in `main.dart`; mix geometry
calculations into UI build methods; use arbitrary delays to pretend processing
works; hardcode example 3D results instead of interpreting the current design;
add buttons whose handlers do nothing; hide mocked CAD or recognition behind a
"completed" feature; invent package APIs; **claim tests or builds were run if
they were not**.

Choose maintained dependencies and verify their actual platform support.
Explain important dependency choices and record reproducible versions.

**If the environment does not allow executing the project, state exactly what
was and was not verified.**

Avoid unnecessary microservices or expensive AI dependencies. Do not upload
customer drawings to external services without an explicit product decision and
appropriate disclosure.

If a backend is necessary: keep secrets server-side; validate requests; handle
failures and timeouts; prevent stale geometry responses from overwriting newer
edits.

## 10. Persistence and reliability

Versioned native project format; reliable save/load round trips; autosave or
recoverable drafts; undo/redo for drawing and parameter changes; preservation
of component IDs and assignments where possible; clear handling when splitting
or merging sections changes their identities; **no silent loss of dimensions or
CH/Z settings**.

Keep drawing, editing and saved-project access usable offline where technically
feasible. Clearly identify any feature requiring a server. Do not add mandatory
accounts unless there is a genuine requirement.

## 11. Implementation plan and scope

Build the core workflow before peripheral business features. Start with a real
vertical slice:

1. Draw a rough closed frame and an internal divider.
2. Recognise and display editable regions.
3. Enter measurements.
4. Assign CH/Z.
5. Generate actual 3D geometry.
6. Edit a dimension and update the model.
7. Save, reopen and continue editing.

Then expand to multiple divisions; partial horizontal divisions; straight
sloping tops; supported opening animations; profile/material options;
responsive workspace refinements; more complete validation and recovery.

**Do not spend the first milestone building many polished screens while the
drawing-to-model pipeline remains fake.**

Keep separate unless explicitly commissioned: pricing and quotations;
inventory; full hardware catalogues; CNC integration; advanced CAD exports;
genuine curved profiles; additional opening mechanisms. Document future
extensions without presenting them as implemented.

## 12. Testing and acceptance criteria

Create representative rough-stroke fixtures and expected design models.

**A. Layout recognition** — rectangle with one divider; five-bay window with
unequal widths; four-region layout with an opening lower-left section;
horizontal division spanning only selected bays; straight sloping-top frame
with unequal side heights; imperfect intersections and slightly shaky strokes.

**B. Accuracy and ambiguity** — confirmed layout is preserved; no automatic
substitution with a standard template; missing dimensions remain visibly
unconfirmed; conflicting dimensions are rejected or clearly explained;
intentional slopes are not snapped to horizontal; unsupported shapes are not
silently distorted.

**C. Editability** — changing overall dimensions updates 2D and 3D
consistently; moving a divider updates affected sections; CH/Z changes update
the model; CH stays fixed during opening previews; Z opens around the correct
hinge; undo/redo restores the full design state; save/reopen preserves
geometry, parameters and section assignments.

**D. Responsiveness** — test representative widths such as **360, 600, 900 and
1440** logical pixels; portrait, landscape, keyboard visibility and large text;
verify no overflow or geometry changes caused by resizing.

**E. Engineering** — unit tests for geometry and dimensional constraints;
serialization round-trip tests; widget tests for critical controls; an
integration test covering drawing → dimensions → CH/Z → 3D → save/load; static
analysis without unresolved critical issues.

Document geometric tolerances and test dimensional consistency using the chosen
measurement references and profile allowances.

## 13. Expected deliverables

A concise architecture explanation; documented assumptions and supported scope;
a milestone plan; the actual Flutter project source; any necessary backend
source and setup; dependency configuration; automated tests and representative
fixtures; a sample editable project; instructions to install, run, test and
build; known limitations and unfinished features; a clear distinction between
visual preview and manufacturing capability.

For each milestone report: what genuinely works; what remains incomplete; which
tests/builds were **actually executed**; how to verify the result.

**Do not deliver only pseudocode, mockups, or a collection of disconnected
screens and call the application complete.**

## 14. Questions and starting behaviour

Ask one short batch of genuinely blocking questions. For non-blocking details,
propose sensible defaults and document them.

### Answers given by the factory

| Question | Answer |
| --- | --- |
| Which deployment platforms are required first? | **Android, iOS and web** |
| Must 3D generation work fully offline? | **Yes** (default taken; no server, no external API) |
| Which units and dimension references? | **Millimetres internally**; reference chosen **per project** — outer frame or wall opening |
| Inside/outside viewing convention? | **Per project, default outside** |
| Are real PVC/Aluminium profile catalogues available? | **No** — clearly labelled generic preview profiles |
| Is the first release visual design or validated production output? | **Visual design** (follows from having no real catalogues) |

Other documented defaults: tap sections to assign CH/Z; numeric dimension entry
rather than handwritten-number recognition; local saved projects; text scaling
clamped at 1.6×.

---

## Delivery order

Build and show each phase before continuing. At the end of each phase: list
every file created, explain the architecture decisions, and show how to run the
tests. **Do not merge phases.** Ask before making any assumption not covered by
this specification.

| Phase | Scope |
| --- | --- |
| 1 | Project skeleton, theme, responsive system, domain models + tests |
| 2 | Smart canvas with stroke classification + panel/dimension logic + tests |
| 3 | 2.5D viewer with open/close animation |
| 4 | Persistence, saved designs list |
| 5 | PDF export + cutting list |
| 6 | Localisation (AR/CKB/EN) + numeral setting + polish |

### Phase 2 scope as commissioned

1. Finger-drawing canvas (`GestureDetector` + `CustomPainter`) opened after
   "Start drawing". Canvas background = cream from the theme; snapped strokes =
   deep green from the theme.
2. Deterministic stroke classification in the **domain** layer (pure Dart,
   unit-tested, no Flutter imports):
   - Closed-ish loop with ~4 corners → **frame** (perfect rectangle)
   - Mostly vertical stroke in frame → **vertical divider** (snapped)
   - Mostly horizontal stroke in frame → **horizontal divider** (snapped)
   - Chevron `<` or `>` in a panel → panel becomes **Z**, chevron point = hinge
     side (per the confirmed view convention)
   - Anything else → discard silently
   - Unmarked panels default to **CH**
3. Panels split **proportionally** to where the divider was drawn.
4. Dimension labels as on the paper sketches: total width below the frame,
   total height at the side, each panel width under its panel. Tap any label →
   numeric input in cm. Panel widths must always sum to frame width; adjust the
   neighbour automatically, warn if impossible.
5. Long-press a panel → bottom sheet with type CH/Z and opening settings;
   toggle mesh (توري); toggle empty / no glass (فارغ); and a **panel note** —
   free text attached to that panel, shown as a small note icon on the panel,
   full text on tap, included in exports.
6. **Design note** — free text for the whole design, reachable from the canvas
   app bar and shown on the design summary.
7. Long-press a divider → move (drag) or delete.
8. Undo / redo for every canvas action.
9. Live-update the design summary ("Still to confirm") as the user draws.
10. State survives screen rotation; tablet landscape shows canvas and live
    summary side by side.

**Resolved during Phase 2 planning:**

- *Tilt and slide* were requested in the panel sheet, but their geometry is
  Phase 3 and §3C forbids showing nonfunctional choices. **Phase 2 ships hinged
  only** (CH/Z, hinge side, inward/outward). Tilt and slide arrive in Phase 3
  with their geometry and tests.
- `Section` is renamed **`Panel`**, the word the factory uses.
  `DesignDocument` keeps its name.
- `Divider` is renamed **`PanelDivider`**: the bare name collides with
  Material's `Divider` widget in every UI file.

### Phase 3 scope as commissioned

1. **Renderer architecture.** An abstract `DesignRenderer` at the
   domain/presentation boundary, implemented by the 2.5D isometric renderer. A
   real 3D engine must be able to replace it without any other layer changing.
   The renderer consumes only the design entity, never raw strokes.
2. **2.5D isometric rendering** with real profile depth (PVC thicker,
   aluminium slimmer, from the Phase 1 profile data); surfaces in the user's
   finish with derived shading on the depth faces; glass with a reflection
   gradient; empty panels (فارغ) visually distinct; mesh panels (توري) hatched;
   note markers that open the note; no symbol on CH panels; the standard dashed
   opening glyph on Z panels, with the view convention permanently on screen.
3. **Open/close animation**, 250–400 ms: hinged swings about its hinge edge,
   tilt raises the top inward, sliding travels across its neighbour.
4. **Screen and navigation** — a primary "3D Preview" button from the canvas, a
   lossless "Back to edit", a summary strip (dimensions in cm, material,
   colour, design note), pinch to zoom and drag to pan.
5. **Responsive** — full-screen on a phone, canvas or summary beside the viewer
   on tablet and landscape, state surviving rotation.
6. **Tests** — geometry mapping, hinge resolution per mechanism, and a golden.

**Resolved during Phase 3 planning:**

- *Tilt and slide are now implemented*, so `OpeningMechanism` gains `tilt`,
  `slidingLeft` and `slidingRight` alongside `hinged`, and the panel sheet
  offers them. The slide direction is part of the mechanism, so a sliding sash
  cannot be stored without saying which way it goes.
- *Golden tests:* committed PNGs plus deterministic paint-command assertions.
  The PNG is rasterised on the machine that generated it, so on another
  platform regenerate it with `flutter test --update-goldens` rather than
  assuming a real regression.
- *The tablet split* shows the canvas or the panel list beside the viewer.
- **The projection keeps the elevation true.** A textbook isometric would skew
  the user's rectangle into a rhombus; §2 forbids redrawing the design into
  something else, so depth is an oblique offset and the front face projects to
  exactly what was drawn. The view is therefore called a **2.5D preview**, not
  3D, everywhere the user can see it (§9).

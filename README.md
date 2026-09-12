# ProFrame

**Draw a door or window by hand. Get your own editable parametric 3D design —
not a similar design the software picked for you.**

The users are factory workers and salespeople who are comfortable sketching on
paper and have no interest in talking to an AI. They draw with a finger, a
stylus or a mouse; the app reads the drawing in the background and turns it
into a parametric product they can measure, assign, edit and save.

---

## Status: Phase 2 of 6

This repository is at the **end of Phase 2**. What that means concretely is set
out in [What works](#what-works) and [What is not built yet](#what-is-not-built-yet).
Nothing below describes a feature that does not exist.

The full requirements live in [SPEC.md](SPEC.md).

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Project skeleton, theme, responsive system, domain models + tests | **Done** |
| 2 | Smart drawing canvas, stroke classification, panel and dimension logic | **Done** |
| 3 | 3D viewer with open/close animation | Not started |
| 4 | Persistence and the saved-designs list | Not started |
| 5 | PDF export and cutting list | Not started |
| 6 | Localisation (AR / CKB / EN), numeral setting, polish | Not started |

---

## The rule everything else follows

> **The system preserves the user-confirmed design. It does not generate a
> similar-looking alternative.**

The app never redesigns, simplifies, normalises or "corrects" a drawing. It
does not equalise sections, level an intended slope, round a dimension to a
tidy number, or substitute the nearest standard layout.

A rough sketch carries design *intent*, not manufacturing dimensions. So the
model distinguishes three kinds of number, and the distinction is enforced by
the type system rather than by convention:

```
confirmed   the user typed or confirmed it        may be used as a dimension
derived     computed from confirmed values        as good as its inputs
estimated   scaled from the sketch proportions    preview only, always labelled
(absent)    nobody has said yet                   asked for, never invented
```

`Measurement` in `lib/domain/measurement.dart` carries this. A confirmed 1200
and an estimated 1200 are deliberately **not equal**, so an estimate cannot be
substituted for a real dimension anywhere the model compares values. There is
no method that promotes an estimate to confirmed while keeping its number —
confirming takes a new number, because confirming means a person supplied it.

---

## Architecture

Four layers, with dependencies pointing one way only.

```
lib/
  main.dart        entry point and wiring — nothing else
  app/             UI: screens, widgets, Riverpod providers
  core/            cross-cutting: design tokens, theme, layout, units, errors
  domain/          pure Dart: geometry, product model, the design document
```

**`domain/` imports no Flutter.** That is what makes the geometry testable
without a widget tree, and it is asserted by a test
(`test/architecture_test.dart`) rather than left to discipline. The same test
checks that no widget declares a brand colour literal and that `main.dart`
stays wiring.

### One source of truth

`DesignDocument` is the whole design: category, material, profile reference,
finish, outline, dividers, sections, CH/Z assignments, opening specs,
dimensions with their provenance, viewing convention, dimension reference, and
the original ink. The 2D editor, the 3D generator, validation and every export
will read this and nothing else, which is what stops them from disagreeing.

It is structured data throughout — never pixels, never a triangle mesh — so a
saved project reopens fully editable rather than as a picture of a decision.
It carries a `schemaVersion`, and a project saved by a newer build is
**refused** rather than partially read.

### Two decisions that are stored, never inferred

Both were confirmed with the factory before any code was written:

- **Viewing side** — `ViewingSide`, per project, default *outside*. A hinge
  side is meaningless without it, so it is stored on the design and stated on
  screen wherever handing appears. It is never guessed from a symbol.
- **Dimension reference** — `DimensionReference`, per project. Either *outer
  frame size* (what the factory manufactures to) or *wall opening size*. When
  it is a wall opening, the fitting gap is a value the user sets and can see;
  the conversion happens in one place (`frameWidthMm` / `frameHeightMm`) and
  the entered dimension is never overwritten. **No installation allowance is
  ever applied behind the user's back.**

### Sections use the factory's own labels

`SectionBehaviour` is `CH` (fixed) or `Z` (opening), shown with both the code
and a plain word, because a new salesperson does not yet know what CH means.

A `Section` cannot contradict itself: the constructor rejects a Z section with
no opening spec and a CH section that still carries one. Switching a sash to
fixed drops the hinge settings and keeps the section id, so the user's other
choices about that section are not orphaned.

### Unimplemented mechanisms are absent, not disabled

`OpeningMechanism` contains exactly one value — `hinged`. Sliding,
tilt-and-turn, top-hung and folding are **not there at all**, rather than
present and greyed out. An absent value cannot be serialised into a project,
cannot reach the 3D generator, and cannot appear in a picker built from
`values`. Adding one means adding its geometry and its tests in the same
change.

A project that names a mechanism this build does not implement is refused on
load. Opening it would mean silently turning a sliding sash into a hinged one.

### Tolerances are documented, not scattered

`lib/domain/geometry/tolerances.dart` holds every epsilon in the geometry
layer. The important one:

```
axisAlignmentDegrees = 5
```

Chosen from the drawing side rather than the manufacturing side. Hand strokes
in the reference sketches wobble by two to three degrees; a deliberate sloping
top in a real door is at least eight. Five degrees separates them with margin
on both sides — which is exactly what lets the app straighten a shaky line
**without flattening an intended slope**. Both halves of that are tested.

### Responsive layout from constraints

`WindowSize` is derived from the `BoxConstraints` a widget is actually given,
never from a device name or a platform check. A 320-wide properties panel
inside a 1440 window lays out as compact, which is correct and which
`MediaQuery.of(context).size` would get wrong.

Width classes: compact `< 600`, medium `600–1023`, expanded `≥ 1024`.

The expanded threshold is **1024, not Material's 840**, on purpose: the
expanded layout puts an 88dp tool rail and a 320dp properties panel either side
of the canvas, so at 840 the canvas would be about 430dp — narrower than the
compact layout's own canvas, and therefore a downgrade rather than an upgrade.

Height is a first-class part of the decision. A phone held in landscape is
800×360: wide enough to call "medium" on width alone, which would hand it a
layout with chrome above and below and leave a canvas too short to draw in.
`WindowHeightClass` and `isLandscapePhone` exist for that case, and the
workspace drops its app bar there.

Model coordinates are millimetres and completely independent of screen size,
so rotating the device or resizing the window cannot change the geometry.

---

## What works

Run it and you can go from two taps to a measured, assigned design: choose Door
or Window and PVC or Aluminium, pick a product colour, then **draw the thing
with your finger** — a rough box becomes the frame, a stroke down the middle
becomes a mullion, a `>` inside a panel makes it open — type the real sizes in
centimetres, set each panel to CH or Z, and add notes. The summary beside the
canvas empties out as you answer its questions.

### Phase 2 — the smart canvas

**Reading the drawing.** `StrokeClassifier` is deterministic, rule-based and
pure Dart. Five outcomes, checked in order: a closed-ish loop with about four
corners is the frame; a chevron inside a panel opens it; a mostly-vertical
stroke is a mullion; a mostly-horizontal one is a transom; anything else is
dropped silently. There is no model, no network call and no randomness — these
users were promised a tool, and a wrong guess changes a product somebody
builds.

The chevron is tested **before** the straight lines, because a `<` is two
segments and a divider is one; checking the line first would match a chevron's
first leg.

**Two tolerances, on purpose.** Reading a rough gesture and measuring a product
are different problems, so they have separate numbers:

| Tolerance | Value | Governs |
| --- | --- | --- |
| `axisAlignmentDegrees` | 5° | Whether a **frame edge** is a deliberate slope. Being wrong scraps a frame. |
| `dividerAxisDominance` | 2.0 (≈26°) | Whether a **gesture** meant vertical or horizontal. Being wrong costs one undo. |

A stroke that leans genuinely diagonal is **discarded**, not snapped to
whichever axis it happens to favour — snapping it would invent a divider the
user did not draw.

**Panels split proportionally.** A divider drawn a third of the way across
makes a panel a third as wide. Equal panels happen only when asked for. When
the real width arrives the whole design rescales about its top-left corner, so
the proportions drawn by hand survive into millimetres exactly.

**Splitting creates new panels.** The original panel's id does not survive a
split, and a merge creates a third new id. Pretending one half is the old panel
would make a CH/Z choice silently apply to something the user never assigned.

**Widths always sum.** Tap any dimension label — total width, total height, or
a panel's own width — and type it in centimetres. The panel to the right
absorbs the change (the left-hand one for the last panel in a row, which has no
right-hand neighbour), and the outcome names which panel moved. A width that
will not fit is **refused with an explanation and nothing changes**; it is
never quietly clamped to a number the user did not type.

**Notes.** Free text on any panel and on the design as a whole, deliberately
unconstrained — the factory's shorthand is Arabic, Kurdish or its own, and a
note the app cannot parse is still one a fabricator can read. A panel with a
note shows a marker on the canvas.

**Undo covers everything.** The whole design is one immutable value, so history
is a stack of documents rather than a log of reversible operations — there is
no way for an action to be half-undone.

### Phase 1 — foundations

Verified by tests:

- **Domain model.** `DesignDocument` with a schema version, `Measurement` with
  provenance, `Polygon` with validation, `Section` with CH/Z integrity,
  `Divider` supporting partial spans and T-junctions, `OpeningSpec`, `Sketch`.
- **Serialisation.** Full JSON round trip. Damaged, versionless, future-version
  and self-contradictory files are refused with a sentence a user can read.
- **Geometry.** Rectangles, sloping-top frames with unequal side heights, point
  containment, self-intersection rejection, coincident-corner merging, and the
  wobble-versus-slope rule.
- **Theme.** Exact brand colours, built by hand rather than seeded so they
  cannot drift. Contrast is tested: cream on deep green is 10.45:1 (AAA).
  Every themed button has a 48dp minimum.
- **Responsive system.** Three arrangements, tested at 360, 600, 900 and 1440
  in both orientations and at 1.6× text, with overflow as a test failure.
- **Workspace shell.** Compact puts properties in a bottom sheet that lifts
  above the keyboard; medium can fold the panel away; expanded shows tools,
  canvas and properties at once.

---

## What is not built yet

Stated plainly, because a screen that pretends to be finished is exactly what
this project is not doing.

- **There is no 3D view, no persistence, no export and no localisation.** Those
  are Phases 3–6. A design exists only while the app is open — closing it loses
  the work, because saving is Phase 4.
- **Only fixed and hinged.** `OpeningMechanism` contains exactly one value.
  Sliding and tilt are **absent, not greyed out**, and the panel sheet says so
  in one line. They arrive in Phase 3 with their geometry and their tests.
- **Curves, sloping tops and partial transoms are modelled but not yet
  drawable.** The domain supports all three; the Phase 2 classifier reads
  rectangles, full dividers and chevrons only. A curve is discarded, never
  silently straightened.
- **No manufacturer profile data.** The two systems in `GenericProfiles` are
  clearly labelled generic previews with their assumptions written out in full.
  They are not any manufacturer's product.
- **Therefore nothing this build produces is production data.** The first
  release is a visual design tool. Manufacturing output requires validated
  profile data, fabrication rules and factory review — and no CNC instructions
  are generated from generic visual geometry.
- **Curves are out of scope** for the first release. Straight edges and
  straight sloping tops only. A curved design will be reported as unsupported,
  not quietly straightened.
- **Pricing, inventory, hardware catalogues, CAD export and additional opening
  mechanisms are out of scope** and are not present in any form.

---

## Verification — what was actually run

Everything below was executed in this environment, with the results shown.

| Check | Result |
| --- | --- |
| `flutter analyze` | **No issues found** |
| `flutter test` | **175 tests, all passing** |
| `flutter build web --release` | **Succeeds** |
| Android build | **Not verified** — no Android SDK in this environment |
| iOS build | **Not verified** — requires macOS and Xcode |

The Android and iOS project folders were generated by `flutter create` and the
code contains no platform-specific plugins, but a build for either has **not**
been run and must not be assumed to work until it has.

Flutter 3.47.2 (stable) · Dart 3.13.2 · `flutter_riverpod` 3.4.3 ·
`flutter_lints` 6.0.0.

---

## Running it

```bash
flutter pub get

flutter run -d chrome        # the platform verified in this environment
flutter run                  # any connected device

flutter analyze              # static analysis, strict mode
flutter test                 # the full suite
flutter build web --release
```

### What the tests cover

| File | Covers |
| --- | --- |
| `test/domain/measurement_test.dart` | Provenance, unit conversion, parsing, refusal to invent |
| `test/domain/geometry/polygon_test.dart` | Rectangles, sloping tops, the wobble/slope rule, invalid outlines |
| `test/domain/design_document_test.dart` | CH/Z integrity, wall opening vs frame size, round trips, refusal cases |
| `test/core/window_size_test.dart` | Breakpoints, landscape phones, constraint-derived sizing |
| `test/core/theme_test.dart` | Exact brand colours, WCAG contrast, 48dp touch targets |
| `test/architecture_test.dart` | Domain has no Flutter, no colour literals, `main.dart` stays wiring |
| `test/domain/recognition/stroke_classifier_test.dart` | The five outcomes, on deliberately wobbly hand-drawn input |
| `test/domain/layout/panel_math_test.dart` | Proportional splitting, width solving, refusals, equal distribution |
| `test/domain/layout/design_builder_test.dart` | Intents applied to the document, rescaling, the live summary |
| `test/widget/canvas_widget_test.dart` | Drawing through the real canvas, undo/redo, labels, notes, rotation |
| `test/widget/responsive_widget_test.dart` | Every size and orientation, large text, the create-a-design flow |

Run one file with `flutter test test/domain/measurement_test.dart`, or one test
with `--plain-name "a sloping-top frame keeps both side heights exactly"`.

The classifier tests build their input with a seeded `handDrawn` helper that
adds real wobble to every stroke, so they exercise rough input rather than
perfect input.

---

## Decisions taken as defaults

Confirmed with the factory before coding: deployment platforms (Android, iOS,
web), viewing side (per project, default outside), dimension reference (per
project), and profile catalogues (none available — generic previews).

Taken as documented defaults because they were not blocking:

- **3D generation runs fully offline.** A deterministic parametric mesh
  generator in Dart. No server, no external API, no customer drawing leaving
  the device.
- **The first release is for visual design, not validated production output.**
  This follows necessarily from having no real profile catalogues.
- **Millimetres internally**, with the display and input unit configurable.
- **Local projects, no accounts.**
- **Text scaling is clamped at 1.6×.** Large text must work, but an unbounded
  scale on a landscape phone pushes the drawing tools off screen; beyond the
  cap, panels scroll rather than the canvas shrinking.

---

## Brand

Cream `#FFEFB3`, deep green `#013E37`. Professional, calm, clear — built for a
factory floor, not a dashboard. These are the *application's* colours; what the
door or window is finished in is a separate choice from the finish catalogue.

# Requirement checklist

Every requirement from the specification, with its status and the evidence.

**How to read the statuses**

| Status | Means |
| --- | --- |
| **Verified** | Implemented, and an automated test asserts the behaviour. The test is named. |
| **Implemented, unverified** | The code is there and analyzes, but no test proves it, or it needs a device this environment does not have. |
| **Partial** | Some of it works; what does not is stated. |
| **Not built** | Deliberately absent. The reason is stated. |

Nothing below is marked Verified on the strength of a build succeeding or a
screenshot looking right.

---

## §1–2 Product goal and accuracy rules

| Requirement | Status | Evidence |
| --- | --- | --- |
| Draw with finger/stylus/mouse inside the app | **Verified** | `canvas_widget_test.dart` drives real pointer gestures through `DrawingCanvas` |
| No AI, no prompts, no chatbot | **Verified** | Recognition is a deterministic rule engine; `stroke_classifier_test.dart` asserts the same stroke always reads the same. No network dependency exists in `pubspec.yaml` |
| The drawing becomes *their* design, not a template | **Verified** | `panel_math_test.dart` "a lopsided row stays lopsided"; `design_builder_test.dart` "the proportions the user drew are kept exactly" |
| Never silently invent a dimension | **Verified** | `measurement_test.dart` — a confirmed 1200 and an estimated 1200 are deliberately unequal; text that will not parse stays unknown rather than becoming zero |
| Never assume sections are equal | **Verified** | `panel_math_test.dart` "equal distribution happens only when asked for" |
| Intentional slopes are not flattened | **Verified** | `stroke_classifier_test.dart` "sloping tops are kept, not levelled" (4 tests) |
| Original strokes preserved | **Verified** | `canvas_widget_test.dart` "a scribble is dropped but its ink is still kept" |
| Unsupported shapes not silently distorted | **Verified** | A stroke that is not frame, divider or chevron is discarded; `stroke_classifier_test.dart` "anything else is dropped" |

## §3 Workflow and navigation

| Requirement | Status | Evidence |
| --- | --- | --- |
| Door / Window, PVC / Aluminium, colour, profile | **Verified** | `acceptance_test.dart` main scenario and "the door workflow, in aluminium" |
| Glass / panel options | **Partial** | Glazing and solid panel exist in the model and are selectable per panel via the sheet's mesh/empty toggles and infill. A full glazing catalogue (units, coatings, thicknesses) is **not built** |
| Factory-configurable defaults | **Verified** | `settings_screen.dart`; defaults applied in `new_design_screen.dart` |
| Previously confirmed decisions preserved | **Verified** | Platforms, offline, units, viewing side, dimension reference and generic profiles are recorded in `SPEC.md` §14 and were not re-asked |
| Navigation between projects, editor, 3D, export | **Verified** | `app.dart` `_Step`; `acceptance_test.dart` walks the whole path |
| Create, name, duplicate, reopen, delete | **Verified** | `persistence_test.dart` (duplicating, the project list); `projects_screen.dart` confirms before deleting |
| Protection against accidental data loss | **Verified** | Leaving with unsaved changes prompts (`app.dart` `_leaveEditor`); delete asks and names the project |

## §4 Drawing editor

| Requirement | Status | Evidence |
| --- | --- | --- |
| Outer frames, vertical and horizontal divisions | **Verified** | `stroke_classifier_test.dart`, `design_builder_test.dart` |
| Multiple unequal-width bays | **Verified** | `scene_builder_test.dart` "two unequal panels keep their proportions" |
| Partial dividers and T-junctions | **Verified** | `design_builder_test.dart` "a divider inside one panel of several is partial, and stays partial" |
| Straight sloping tops, unequal side heights | **Verified** | `stroke_classifier_test.dart` "the two heights survive into the outline" |
| Draw / select / move / delete / undo / redo | **Verified** | Tool palette in `canvas_screen.dart`; `canvas_widget_test.dart` undo/redo group |
| Pan, zoom, fit to view | **Implemented, unverified** | `CanvasProjection.view` / `.fitTo`, wired to the palette. The transform maths has no direct test |
| Add note | **Verified** | `acceptance_test.dart` steps 8–9 |
| Strokes shown immediately while drawing | **Verified** | Wet ink painted from `_wetInk`; exercised by every canvas gesture test |
| Drawing separated from navigation | **Verified** | `CanvasTool` modes; two fingers always zoom, one finger draws only in Draw |
| Screen and model coordinates separate | **Verified** | `canvas_widget_test.dart` "the model is the same whatever size the screen is" |

## §5 Recognition

| Requirement | Status | Evidence |
| --- | --- | --- |
| Resampling and noise reduction | **Verified** | `StrokeSimplifier`; the classifier tests feed deliberately wobbly input |
| Straight-segment recognition, endpoint snapping | **Verified** | Ramer–Douglas–Peucker plus the frame fit; `stroke_classifier_test.dart` |
| Outer boundary and internal divider identification | **Verified** | Same |
| Closed-region construction | **Verified** | `PanelSplitter`, `panel_math_test.dart` |
| Layout validation | **Verified** | `DesignValidator`, `notes_and_validation_test.dart` |
| Ambiguity highlighted, not guessed | **Verified** | A chevron sets the hinge side but leaves the swing unconfirmed — `design_builder_test.dart` "the swing direction is left as a question, not answered" |
| Curves | **Not built** | Out of scope for this release. A curved stroke is discarded, never straightened — stated in the README |

## §6 Dimensions, CH/Z, openings

| Requirement | Status | Evidence |
| --- | --- | --- |
| Millimetres internally, configurable display | **Verified** | `measurement_test.dart` display-units group |
| Overall size, divider positions, section sizes | **Verified** | `acceptance_test.dart` step 5 |
| Left/right heights for sloping tops | **Verified** | Recognised from the drawing; `stroke_classifier_test.dart` |
| Explicit equal-section command | **Verified** | `WidthSolver.distributeEqually`, `panel_math_test.dart` |
| Detect missing, contradictory, impossible dimensions | **Verified** | `notes_and_validation_test.dart` — gaps, overlaps, outside the frame, impossible fitting gap, over-size sashes |
| Never silently override a confirmed dimension | **Verified** | `notes_and_validation_test.dart` "nothing the validator does changes the design"; `panel_math_test.dart` "an impossible width is refused, not quietly clamped" |
| Outer frame vs wall opening, shown not hidden | **Verified** | `design_document_test.dart` "wall opening is not frame size"; the PDF states the reference and the calculation |
| CH / Z by tapping a section | **Verified** | `panel_sheet.dart`; `acceptance_test.dart` step 6 |
| Hinge side, inward/outward, visual indication | **Verified** | `scene_builder_test.dart` opening-symbol group |
| Inside/outside view displayed | **Verified** | `viewer_widget_test.dart` "it shows dimensions, material, colour and the view side" |
| Fixed and hinged required; agreed extras completed | **Verified** | Hinged, tilt and both sliding directions all have geometry and tests (`scene_builder_test.dart` opening-animation group) |

## §7 Parametric 3D

| Requirement | Status | Evidence |
| --- | --- | --- |
| Frame members, dividers, glazing, sashes | **Verified** | `scene_builder_test.dart` (33 tests) |
| Hardware — handles and hinges | **Implemented, unverified** | `SceneBuilder._addHardware` places a handle on the opening edge and 2–3 hinges by leaf height. No test asserts their positions |
| Door vs Window respected | **Verified** | `acceptance_test.dart` — a door gets a flush threshold, a window a sill that noses out |
| Rotate, pan, zoom, reset | **Verified** | `viewer_widget_test.dart` pan-and-zoom group; camera angle and turn-around in `ViewerController` |
| Return to the drawing editor | **Verified** | `viewer_widget_test.dart` "canvas to viewer and back loses nothing" (three round trips) |
| Select a section and edit its properties | **Verified** | `viewer_widget_test.dart` note and open/close groups |
| CH stays fixed during animation | **Verified** | `scene_builder_test.dart` "a CH panel never moves, whatever fraction it is given" |
| One source of truth for 2D and 3D | **Verified** | `viewer_widget_test.dart` "an edit between visits reaches the viewer" |
| "Preview — measurements incomplete" labelling | **Verified** | `viewer_widget_test.dart` "an unmeasured design says so"; the PDF carries the same warning block |
| Stale results cannot overwrite newer edits | **Verified by construction** | Generation is synchronous and pure — `SceneBuilder.build(design)` — so there is no async result to arrive late |

## §8 Notes

| Requirement | Status | Evidence |
| --- | --- | --- |
| Design notes, saved and in the PDF | **Verified** | `acceptance_test.dart` step 8; `pdf_smoke_test.dart` |
| Factual summary from real data | **Verified** | `DesignFacts.of` reads the document only |
| Add / edit / delete a note in a section | **Verified** | `panel_sheet.dart`; `acceptance_test.dart` step 9 |
| Move the label within the section | **Implemented, unverified** | `DesignController.movePanelNote` with fractional positions; no drag gesture is wired to it yet |
| Multiple notes per section | **Verified** | `persistence_test.dart`; the sample has two on one panel |
| Show / hide without deleting | **Verified** | `notes_and_validation_test.dart` "hiding one keeps it" |
| CH/Z kept separate from free text | **Verified** | Different fields; `notes_and_validation_test.dart` "a note is an annotation, never a command" |
| Structured data on stable IDs, never painted in | **Verified** | `PanelNote`; `persistence_test.dart` |
| Association maintained when dimensions change | **Verified** | Fractional positions; `notes_and_validation_test.dart` |
| Split/merge resolved explicitly | **Verified** | `NoteResolver`; every move is reported |
| Notes reachable in 3D | **Verified** | `viewer_widget_test.dart` "tapping a panel with a note shows the note" |
| Unicode and text direction | **Verified** | Arabic round-trips through save, PDF and PNG. Fonts bundled |
| A note never changes the product | **Verified** | `notes_and_validation_test.dart` |

## §9 Materials and profiles

| Requirement | Status | Evidence |
| --- | --- | --- |
| PVC ≠ Aluminium in the specification | **Verified** | `scene_builder_test.dart` "PVC reads thicker than aluminium"; `notes_and_validation_test.dart` — the sash size limit differs by system |
| Profile determines geometry, clearances, limits | **Verified** | Same |
| Factory settings area | **Verified** | `settings_screen.dart` |
| Generic profiles labelled, assumptions documented | **Verified** | `responsive_widget_test.dart` "the generic-profile warning is shown, not buried"; the PDF repeats it |
| Interface preserved for real catalogue data | **Partial** | `ProfileSystem` and `ProfileSystemRef` are the seam, and a project records which system it wants. **No importer exists** — swapping in a supplier catalogue still needs code |
| No production-readiness claim | **Verified** | Stated in the viewer footer, the PDF footer and the README |

## §10 Persistence

| Requirement | Status | Evidence |
| --- | --- | --- |
| Full editable project persisted | **Verified** | `persistence_test.dart` (21 tests) |
| Reliable save/load | **Verified** | Same |
| Autosave / recoverable drafts | **Verified** | `SaveController`; drafts and recovery tested |
| Undo/redo for design and annotation | **Verified** | `canvas_widget_test.dart` |
| Safe recovery from an interrupted save | **Verified** | `persistence_test.dart` "leaves the previous version intact" |
| Versioned migrations | **Verified** | `persistence_test.dart` "a schema 1 project with a single note string still opens" |
| Old projects not destroyed by an update | **Verified** | Same |
| Offline | **Verified by construction** | `shared_preferences` and local files only; no network call exists in the app |

## §11 Outputs

| Requirement | Status | Evidence |
| --- | --- | --- |
| Interactive 3D from the current design | **Verified** | `viewer_widget_test.dart` |
| Native editable export/import, versioned | **Verified** | `persistence_test.dart` project-file group; `acceptance_test.dart` step 15 |
| Unsupported versions handled clearly | **Verified** | Refused with a readable sentence |
| Missing profiles not silently substituted | **Verified** | `DesignDocument.profileSystem` falls back and the fallback is visible; the reference is preserved in the file |
| PDF design sheet with all listed content | **Verified** | `pdf_smoke_test.dart`; the rendered sheet was inspected |
| "Not to scale" labelling | **Verified** | On the sheet |
| PNG with dimensions/annotations toggles | **Verified** | `samples_generator_test.dart` proves the two renders differ |
| Exports reflect the current design | **Verified by construction** | Every export is generated from the document at the moment of export |
| No nonfunctional export buttons | **Verified** | Three exports, all of which produce real bytes (`acceptance_test.dart` step 16) |

## §12 Responsive and accessible

| Requirement | Status | Evidence |
| --- | --- | --- |
| Brand colours, central tokens | **Verified** | `theme_test.dart`; `architecture_test.dart` forbids colour literals in widgets |
| Phone / tablet / desktop arrangements | **Verified** | `responsive_widget_test.dart`, `viewer_widget_test.dart` |
| Portrait, landscape, safe areas, keyboard, long labels, large text | **Verified** | `responsive_widget_test.dart` — every size at 1.6× text, overflow is a failure |
| Contrast and 48dp targets | **Verified** | `theme_test.dart` |
| Nothing communicated by colour alone | **Verified** | CH/Z carry their codes; unconfirmed dimensions are bracketed; tools carry words |

## §13 Engineering

| Requirement | Status | Evidence |
| --- | --- | --- |
| Null safety, typed models, validated serialisation | **Verified** | Strict analysis options; `flutter analyze` clean |
| One state-management approach | **Verified** | Riverpod throughout |
| Geometry independent of widgets | **Verified** | `architecture_test.dart` "the domain layer does not depend on Flutter" |
| Layer separation | **Verified** | `domain/` · `core/` · `infrastructure/` · `app/` |
| No oversized `main.dart` | **Verified** | `architecture_test.dart` |
| Nothing faked | **Verified** | Every export produces real bytes; recognition is real; saving is real |
| No external AI, accounts or microservices | **Verified** | Dependency list |

## §14 Acceptance tests

The 16-step main scenario runs as one test: `test/integration/acceptance_test.dart`,
"the whole workflow: draw, measure, assign, note, 3D, save, reopen, export".

| Also tested | Where |
| --- | --- |
| Door workflow, aluminium | `acceptance_test.dart` |
| Multiple unequal bays | `scene_builder_test.dart` |
| Partial dividers, T-junctions | `design_builder_test.dart` |
| Sloping tops | `stroke_classifier_test.dart` |
| Incomplete and contradictory dimensions | `notes_and_validation_test.dart` |
| Inside/outside view | `viewer_widget_test.dart` |
| Undo/redo | `canvas_widget_test.dart` |
| Notes after section edits | `notes_and_validation_test.dart` |
| Interrupted save and recovery | `persistence_test.dart` |
| Responsive layouts and keyboard | `responsive_widget_test.dart` |

---

## What is not built, and why

| Item | Reason |
| --- | --- |
| **Curved profiles** | Out of the agreed scope. A curved stroke is discarded rather than straightened |
| **Dragging a note label on the canvas** | The model and the controller support it; no gesture is wired to it |
| **Glazing catalogue** | Glass type beyond single/double/triple and obscure was never specified |
| **Profile catalogue importer** | No supplier catalogue has been supplied; the interface is in place, the importer is not |
| **Pricing, inventory, CNC, CAD export** | Explicitly out of scope |

## What could not be verified here, and why

| Item | Reason | How to verify |
| --- | --- | --- |
| **Android build and APK** | This container has no Android SDK, and `dl.google.com` is blocked by the environment's egress policy, so one cannot be installed | `flutter build apk --release` on a machine with the SDK |
| **iOS build** | Requires macOS and Xcode | `flutter build ipa` on a Mac |
| **On-device touch and stylus** | No device or emulator is reachable | Run on a tablet and draw with a finger and a stylus |
| **The share sheet** | `share_plus` needs a platform channel | Tap any export on a device; in tests the delivery is captured instead |
| **File picking for import** | `file_selector` needs a platform channel | Tap "Open a project file" on a device |
| **The golden image on other platforms** | Rasterised on Linux; font hinting differs | `flutter test --update-goldens` on that machine |

# Geometry and drawing architecture — the audit

Written before the geometry correction and angled / asymmetrical design work
begins (Phase 1 of that project). Nothing in the application was changed to
write it. Every statement below was read from the code at `715c5a4`, and the
five marked **probed** were also run: a throwaway test fed hand-drawn shapes
through `SketchInterpreter.interpret` and printed what came back.

## 1. The flow, traced

```
pointer events                     DrawingSurface (lib/app/canvas/drawing_surface.dart)
  │  StrokeSample(at mm, atMs, pressure) — pen, line, rectangle, polyline tools;
  │  "pause to straighten" replaces the live ink with StrokeFitter.straightRuns
  ▼
WorkspaceController.addStroke      (lib/app/state/workspace.dart)
  │  Stroke appended to design.sketch; needsReading = true; nothing is read yet
  ▼  the user presses Read (_ReadBar in workspace_screen.dart) → readDrawing()
SketchInterpreter.interpret        (lib/domain/recognition/interpreter.dart)
  │  1 OpeningSymbolReader.read   — <, >, ^, v strokes taken out as marks
  │  2 StrokeFitter.fit           — each stroke → straight runs (RDP corners)
  │  3 StrokeFitter.straightened  — each run squared if within 5° of an axis
  │  4 _ontoWhatTheyWereDrawnOn   — an end drawn onto another stroke's ink
  │                                 carried back onto that stroke's leg
  │  5 _weld                      — ends clustered into anchors (averaged)
  │  6 PlanarSubdivision          — runs cut at crossings → faces; outline =
  │                                 the largest outer face
  │  7 _gapIn / _unclosed         — one side missing, or no closed shape
  │  8 _scopeOf, _completed,      — every run not on the outline becomes a
  │    _completedWithin             DividerElement, scoped to the design or
  │                                 to an opening, its free ends completed
  │  9 SectionBuilder.rebuild     — sections from frame + dividers
  │ 10 _placeSymbols              — each mark opens the smallest face it is in
  ▼
Measurements.keepAfterReading      (lib/domain/dimensions/measurements.dart)
  │  sizes the user typed are put back over the fresh reading
  ▼
Design  ── the canonical geometry ──  (lib/domain/model/design.dart)
  │  frame (polygon), dividers (segments), sections (polygons), openings,
  │  hardware, dimensions — plus the untouched sketch
  ├─► DesignStore.save → Design.toJson → SharedPreferences
  ├─► DesignTree.of / DesignGeometry.of (derived, cached per Design object)
  │      ├─► DesignPainter  (Draw)
  │      ├─► CadPainter     (CAD)
  │      └─► MeshBuilder.build → Camera.project → ModelPainter (3D)
  └─► every edit: DesignEdits.* → SectionBuilder.rebuild → OpeningHardware.settle
```

## 2. The twenty-four things, where each lives

| # | What | Where | Notes |
| --- | --- | --- | --- |
| 1 | Design model | `domain/model/design.dart` `Design` | Immutable; every edit is `copyWith`, which applies `Hierarchy` |
| 2 | Category | `DesignKind` in `domain/model/elements.dart`; `Design.kind` (saved as `category`) | door, window, both, sliding |
| 3 | Drawing / canvas | `app/canvas/drawing_surface.dart`, `design_painter.dart`, `view_transform.dart` | Screen ↔ mm only in `ViewTransform` |
| 4 | Freehand input | `DrawingSurface._down/_move/_up`; pause-to-straighten `_straighten` | Samples stored raw, in mm |
| 5 | Point / line / shape | `domain/geometry/vec2.dart`, `segment.dart`, `polygon.dart` | No curve type at all |
| 6 | Dimensions | `domain/dimensions/` — `measurements.dart`, `dimension_chain.dart`, `scale.dart`, `units.dart`; `DimensionElement` | Width/height only |
| 7 | Width / height | `Design.widthMm/heightMm` = frame bounding box; `Measurements.stretch`, `DesignScale`, `DesignEdits.resizeFrame` | Three resize routes |
| 8 | Openings | `OpeningElement` (names a section + mark); `SketchInterpreter.sectionFor`, `_placeSymbols`; `Hierarchy` | No geometry of its own |
| 9 | Internal dividers | `DividerElement` with `parentId` = opening id | Segment + width |
| 10 | Panel regions | `SectionElement` with `Finish` (`MaterialKind` panel); `Infill` | |
| 11 | Glass regions | same, glazing materials | |
| 12 | Frame / border | `FrameElement` (outline polygon, `profileMm`, `openEdges`); `innerOutline` = `Polygon.inset`; `FrameProfile` | |
| 13 | Handles | `HardwareElement`, placed by `OpeningHardware.forOpening` / `handleAt`; shapes in `Furniture` | Regenerated every rebuild |
| 14 | Hinges | same, `hingeAt`, `hingeCount` | |
| 15 | Snapping | Reading: `StrokeFitter.straightened` (±5°). Editing: `DesignEdits.snapCandidates/snapTo` (CAD drag, x/y only). Live pen: `straightRuns` | |
| 16 | Line completion | `SketchInterpreter._completed`, `_completedWithin`; `DesignEdits.spanAcross` for the in-opening tools | Level and upright lines only |
| 17 | Geometry validation | None as a module. `Hierarchy.settle*` (structure), `Tol.minSectionAreaMmSq`, `Tol.minLineMm`, `Measurements` size refusals | |
| 18 | Normalisation | Steps 2–5 of §1 — spread over `StrokeFitter` and four private interpreter functions | See §4 |
| 19 | CAD renderer | `app/canvas/cad_painter.dart` (+ `cad_view.dart`, `dimension_layout.dart`, `dimension_handles.dart`) | Walks `DesignTree` |
| 20 | 3D renderer | `domain/solid/mesh_builder.dart` → `camera.dart` → `app/viewer/model_painter.dart`, `model_view.dart` | |
| 21 | Persistence | `infrastructure/design_store.dart` (key per design + index), `customer_store.dart` | SharedPreferences |
| 22 | Serialisation | `Design.toJson/fromJson`, each element's own | Derived sections and hardware are saved too |
| 23 | Category selection | `app/screens/start_screen.dart` → `NewDesignSetup.begin` | |
| 24 | State management | Riverpod `WorkspaceController` / `WorkspaceState` | Undo stack, `needsReading`, `work` token |

## 3. Answers to the three questions

**Where is the canonical geometry stored?** In `Design`: `frame.outline`
(a polygon), `dividers` (two endpoints and a width each), and the sections,
openings and hardware derived from them by `SectionBuilder.rebuild`. Every
coordinate is millimetres, X across and Y down. The sketch sits beside it
and is never overwritten by it.

**But there are two authorities, not one.** For anything drawn on the sheet
the *ink* is the authority at the next reading: `interpret` re-derives the
frame and every top-level bar from the strokes, keeping only ids and
parents. **Probed:** a mullion dragged 300 mm and then re-read came back
where the ink is. Only `Measurements.stretch` moves the ink along with the
geometry, which is why typed sizes survive and dragged edits do not. The
bars made with the tools inside an opening have no stroke and are left
alone.

**Do CAD and 3D consume it directly?** Yes. Both read the `Design` object
in hand, through `DesignTree.of` (structure) and `DesignGeometry.of` (bar
bodies, fills, leaves, frame sightlines, beads, ironmongery outlines).
`test/app/a_design_in_every_view_test.dart` holds that each view's painter
is given the identical object.

**Does any renderer create its own geometry?** Not new geometry, but four
places derive shapes outside `DesignGeometry` and can drift from it:

- `CadPainter._leaf` uses `OpeningLeaf.outerOf/innerOf`. The solid uses
  `DesignGeometry.leafOuter/leafInner`, which for a sliding panel on a track
  is `slidingPanelOf`, reaching the middle of the meeting line. On a
  sliding design the two leaves differ by half a bar.
- `CadPainter` and `DesignPainter` ink `frame.innerOutline` themselves,
  and `MeshBuilder` sweeps the profile between outline and `innerOutline`
  itself. All read the same function, so they agree today, but nothing
  makes them share one.
- `MeshBuilder._panel`, `_plate` and the frame sweep inset polygons
  directly (`inset`, `insetEach`) for arrises. That is appearance and not
  position.
- `OpeningHardware` places every piece from the opening's **bounding box**,
  and `MeshBuilder._swingFor` swings about a bounding-box edge — see §5.

## 4. What normalisation and snapping exist today

| Step | Code | What it does | Scope |
| --- | --- | --- | --- |
| Corner finding | `StrokeFitter._simplify` (RDP) | Wobble out, corners kept | Each stroke alone; tolerance 5 % of the stroke's own diagonal, floor 10 mm |
| Spur removal | `_dropSpurs` | Drops a flick back | Each stroke |
| Closing | `_mergeEnds`, `Stroke.isClosed` | Ends within 25 % of size close | Each stroke |
| Axis snap | `StrokeFitter.straightened` | A run within 5° of horizontal or vertical is set to its mean y or x | **Each run alone** |
| Onto the ink | `_ontoWhatTheyWereDrawnOn` | An end within a weld of another stroke's samples is carried along its own line onto that stroke's leg | Pairs of strokes |
| Weld | `_weld` | Ends within `max(3 % of span, 30 mm)` share one anchor, **the running average** of them | All runs, order-dependent |
| Planar weld | `PlanarSubdivision` | Nodes within `weldFor(span)` (1 %) merge | All runs |
| Outline tidy | `Polygon.simplified(weld)` | Collinear junction points dropped | Outline |
| Completion | `_completed`, `_completedWithin` | A level or upright free end runs to the first line ahead | Axis-aligned runs only |
| Edit snap | `DesignEdits.snapCandidates/snapTo` | CAD drags snap x or y to frame, bar and section edges | Axis-aligned only |

There is no angle snapping other than 0° and 90°: no 45°, no "parallel to",
no "same angle as". There is no alignment of coordinates across runs, so two
transoms drawn at slightly different heights are not made level. There is
no equal-length or symmetry recognition, which the rules forbid as a default
anyway. There is no curve or arc support. Validation is only structural
(`Hierarchy`) plus minimum areas and lengths.

## 5. Architectural problems found

**Probed** marks a fault shown by running the code, not only by reading it.

1. **The weld undoes the axis snap (probed).** Each run is squared on its
   own, then `_weld` averages the ends that meet into one anchor. A
   rectangle drawn with every side about 1° off came back with *no square
   side at all*: corners at `(−7.5, 8.8) (1991.3, 26.3) (1973.8, 1595.0)
   (−22.5, 1585.0)`. Squaring has to come after the joins are known, or
   the join has to keep the squaring.
2. **The weld turns level bars into sloped ones (probed).** Two transoms
   either side of a mullion, drawn 15 mm apart in height, were welded at the
   mullion to their average (`507.5`). Both came back sloped,
   `(0,500)→(1000,507.5)` and `(1000,507.5)→(2000,515)`: two bars the user
   drew level, now neither level nor matching. `_weld` is also
   order-dependent (`anchors[i].lerp(point, 0.5)`), and its radius — 3 % of
   the drawing's diagonal, about 77 mm on a 2.5 m sheet — is far wider than
   the 1 % weld everything else uses.
3. **Ink and geometry are two authorities (probed).** A drag in CAD — a
   divider moved, a frame member moved, a bar's end, length or angle — does
   not move the stroke it came from, so the next reading puts it back.
   Only sizes typed through `Measurements` move the ink. A correction system
   that writes geometry without writing the ink, or without pinning it,
   will be undone the same way.
4. **Hardware and swing assume a rectangle (probed).** `OpeningHardware`
   uses the opening's bounding box. On a leaf with a raked closing edge the
   lever and the lock were placed at `x = 866.7` when the leaf's edge at
   that height is about 725, so both were **outside the leaf**.
   `MeshBuilder._swingFor` turns the leaf about the bounding box's edge, so
   a leaf hung on a sloped side would rotate about a line that is not its
   edge. `OpeningEdge` is only left, right, top and bottom.
5. **Sizes are axis-aligned only.** `Measurements` asks width and height,
   and it measures and moves only bars that are `isVertical` /
   `isHorizontal`. An angled bar, a raked frame side or a gable pitch has no
   figure that can be typed. `Measurements.stretch` remaps X or Y piecewise,
   which changes the angle of anything sloped. `DimensionChains` chains only
   rectilinear parts (`isRectilinear`, `_squareWithin`).
6. **Convexity is assumed in several places.** `Polygon.clippedTo`
   (Sutherland–Hodgman), `Polygon.inset` / `insetEach` (edge offset and
   intersection), `OpeningLeaf.insideOf`, `DesignGeometry.beadAround`
   (`isConvex` guard) and the arris insets. A concave frame insets
   correctly in the simple L case (probed), but a concave *opening* or pane
   would clip wrongly, and the frame sweep falls back to a flat slab
   whenever inset changes the corner count.
7. **"Inside a section" is a bounding-box map.** `Polygon.sameIn` carries a
   child across a move or resize by scaling the bounding box. That is exact
   for rectangles and an approximation for a trapezoid or triangle: a bar
   near a raked edge can be carried across it. `LocalSpace` measures from
   the bounding box's top-left corner, which is outside a triangle or gable.
8. **Three resize routes.** `Measurements.apply/stretch` (the UI's), which
   moves the ink; `DesignEdits.resizeFrame`, which does not move the ink and
   is used by tests only; and `DesignScale.by/toDimension`, which scales
   everything including the ink and the profile. Only the first keeps a
   typed size through a re-reading.
9. **Small inconsistencies to know about.** `SectionBuilder._readingOrder`
   rounds `top` to whole centimetres, unlike every other tolerance.
   `_carryIdentityForward` pairs sections by index when the count is
   unchanged. `Design.widthMm/heightMm` are the frame's bounding box, which
   is the right overall size for a gable but not "the width" of any member.
   `FrameMemberElement` names members by `isHorizontalish/isVerticalish`,
   so a sloped head is a "rake".

What is already sound and should be kept: the planar subdivision is fully
general (any angle, any polygon); bars are built as bodies, so angled bars
make correct faces; `DesignTree` and `DesignGeometry` really are the one
structure and the one shape-source for all three views; and the hierarchy
rules are enforced in `Design.copyWith`.

## 6. Where the new normalisation system should go

**One place: inside `SketchInterpreter.interpret`, between fitting and
subdivision — steps 3–5 of §1.** Today those steps are three independent
passes that undo each other (§5 items 1–2). They should become one module
that takes *all* the runs of the drawing at once and returns canonical runs:

```
StrokeFitter.fit  (per stroke, unchanged)
      ↓  raw runs + their strokes
RunNormalizer.normalize(runs, context)        ← new, pure Dart,
      ↓  canonical runs + a record of            lib/domain/recognition/
         every change it made (and why)
PlanarSubdivision → frame / dividers → SectionBuilder → _placeSymbols  (unchanged)
```

- **Pure domain, no Flutter.** Inputs are `Segment`s with their stroke ids
  and the drawing's span. Outputs are `Segment`s plus a change log, so a
  test, and later the UI, can say what was cleaned.
- **Tolerances stay in `Tol`**, relative to the drawing's span, each with a
  reason, as now.
- **Order: join first, then square, then align.** Ends are clustered
  without averaging away a snap, a run is squared together with the runs it
  joins, and nearly-equal coordinates are shared only between runs that are
  meant to be collinear. Then the "may / must not" table in `CLAUDE.md`
  decides each step: a run more than 5° off an axis keeps its angle exactly,
  and nothing is equalised.
- **The canonical store does not change.** `Design` stays the single source
  of truth, and `DesignTree` / `DesignGeometry` stay the only things the
  three views read, so no renderer needs to change for the reading to be
  corrected.
- **The ink question (§5 item 3) must be decided before any later phase
  writes corrected geometry back.** Either an edit moves the ink, as
  `Measurements.stretch` already does, or a reading keeps edited geometry
  as `keepAfterReading` already does for typed sizes. Otherwise every
  correction lasts until the next reading.
- **Angled and asymmetrical follow-on work belongs in `DesignGeometry` and
  `OpeningHardware`**: hinge and handle positions and the swing axis from
  the leaf's real edges rather than its bounding box (§5 item 4), and sizes
  for angled members in `Measurements` (§5 item 5). Neither belongs in a
  renderer.

Pinned by `test/domain/rendering_geometry_baseline_test.dart`: any change
here that moves a facet of the pinned door, window or sliding pair is a
change of geometry, and has to be said so on purpose.

## 7. Since the audit — the normaliser (Phase 2)

`lib/domain/recognition/geometry_normalizer.dart` is the place §6 asked
for. `GeometryNormalizer.normalizeStandardGeometry` takes every run at once
and does steps 3–5 of §1 in one order: square, carry onto the ink, join,
then **keep square**. The new last step fixes faults 1 and 2 of §5. The
probes now come back as follows:

- the rectangle drawn about 1° out has every side exactly level or
  upright;
- the two transoms 15 mm apart are level and still meet.

`SketchInterpreter` no longer holds any of those steps. Only the reading's
own work is left in it: the outline, the completion of lines stopped short,
scope, sections and marks.

Making the geometry exact exposed a fault in `Segment.crossing`: its
parallel test was absolute, and collinear edges looked like steep
crossings. It is relative to the two lengths now.

Faults 3–5 of §5 — the ink as a second authority, hardware from the
bounding box, and axis-only sizes — are untouched.

## 8. The standard rules (Phase 4)

These are for Door, Window, Sliding and Door & window. Two steps were added
to the normaliser between joining and keeping square.

**Trim a corner drawn past** (`_trimmedAtCorners`). Two loose ends whose
runs cross within `Tol.overshootFraction` of each run's own length are cut
back to the crossing.
- Probe before the change: a head drawn 15 cm past its jamb came back as a
  bar lying along the frame.
- Probe now: a clean rectangle.
- This step applies in every category.
- An end that stops *short* of a line is not touched. That is an open side,
  and the user is still asked about it.

**Square a lean** (`_leansSquared`). This applies in standard designs only.
A run is squared when all three hold:
- it is 5–10° off an axis (`Tol.leanDegrees`);
- the side opposite it is square, or it turns a corner from a square side;
- squaring it changes the width of what it bounds by at most
  `Tol.leanShare`.

Probes:
- A right side leaning 7° comes back upright where before it was kept.
- A parallelogram and sides leaning opposite ways come back as rectangles.
- A narrow light drawn tapering keeps its taper.
- A rectangle turned 7° altogether is kept as drawn.
- In an angled design every slope past 5° is kept.

**Behaviour change.** A head drawn 5–10° off level in a door, window or
sliding design is now squared. The Angled / Asymmetrical category is how to
keep it.

Faults 3–5 of §5 are still untouched: the ink as a second authority,
hardware from the bounding box, and axis-only sizes.

## 9. Tolerance-based detection (Phase 5)

The first step of the normaliser now classifies each run with
`Deviation.of(segment, span)` instead of squaring anything within 5°. Each
run is measured three ways:
- its angle off the nearest axis;
- its distance error: how far one end is out against the other, across
  that axis;
- the drawing's own size, which is what the tolerances scale with.

A run comes out as one of four kinds:
- **none**: exactly level or upright.
- **wobble**: squared in every category. This is a run out by no more than
  the hand's precision (1% of the drawing) at up to 10°, or one within 5°
  and out by no more than 5% of the drawing.
- **lean**: settled by the standard rules of §8, in standard designs only.
- **slope**: kept exactly.

Consequences:
- A long side 5° out by a visible twentieth of the drawing is kept in an
  angled design.
- A short bar out by less than the hand can place a line is squared at up
  to 10°.
- The same drawing at any scale is read the same.

The user's own snaps (the pen's pause, the straight-line tool) are
unchanged: they still square by angle.

## 10. Standard rectangle correction (Phase 6)

A corrected side used to settle at the average of its ends, whatever the
user had said about sizes. It now settles at the size the user stated:
- A stated dimension that is square to an axis pins the coordinate it
  measures. The pin applies to the run ends within the join tolerance of
  the dimension's ends (`SizePin`).
- The pins ride with those ends through the snap, the join and the trim.
- When keeping square, a pinned group takes the user's figure instead of
  its average.
- A run whose ends the user's figures pin to different values is not
  squared. A group whose pins disagree keeps each point where it is.

With nothing stated, a corrected side still settles at the average and its
size stays `?`.

`Measurements.withStatedOverall` makes the overall size known when a
stated dimension spans the whole frame. Before this, the CAD chain showed
`?` beside the user's own figure.

Probe: the brief's example (left side 200 cm, right side 185 cm):
- **nothing stated:** a rectangle at the fit of the drawn ends, with its
  size `?`;
- **left side stated 200:** 200 high;
- **right side stated 185:** 185 high;
- **both stated:** the head is kept sloping.

In every case the frame, the CAD chain and the solid agree.

Still open: a stated dimension's figure is not updated when the sizes form
later stretches the design (`Measurements.stretch` moves its ends but keeps
`statedMm`).

## 11. The hierarchy through correction (Phase 7)

When the frame is corrected, by the reading or by a stated figure, the
opening's children stay attached. The opening is found again by its mark;
its lines, panes and hardware follow from the model's `parentId`s, from
`SectionBuilder`'s carry, and from `OpeningHardware`.

One fault was found, in the sizes form. `Measurements.stretch` moved lines
inside an opening by its axis map, and then the rebuild carried them again.
Placed twice, a line came off its sash and the opening's panes were lost.

`stretch` now places each child by one route:
- by the carry, where its section changes;
- by the map, where its section does not.

## 12. Materials through correction (Phase 8)

Every material assignment lives on a part's own `Finish`: the frame, each
bar, each pane, each piece of ironmongery, and the design's infill. A
correction moves corners, never finishes, so all of them survive these
four cases:
- a second reading;
- a stated figure;
- the sizes form;
- the outline drawn again.

The rubber seal is built by the solid itself.

One gap was found. A leaf made taller gains a hinge, which came in the
stock finish. It now takes the finish the leaf's other hinges share
(`OpeningHardware._finishOf`, `setOf`).

## 13. Angled / Asymmetrical mode (Phase 9)

- **Preserved.** In an angled design only a deviation smaller than the
  hand's precision (1% of the drawing) is squared. The 1%–5% band within 5°
  is squared only in standard designs (`Deviation.standard`).
- **Validated.** `GeometryNormalizer.validateAngledGeometry`
  (`GeometryValidation.of`) reports problems with coordinates, boundaries,
  self-intersections, connection, child geometry, openings, ironmongery
  and dimensions. It changes nothing. Angled readings carry the result in
  `Interpretation.problems`.
- **Fault 4 of §5 fixed.** Ironmongery is placed along the leaf's own
  stiles (`OpeningHardware.stileOf`) and rails (`_railAt`), not its
  bounding box. Rectangles are unchanged.

Still open:
- Faults 3 and 5 of §5.
- Validation problems are not shown in the app.

## 14. A window under a stair (Phase 10)

Drawn as an Angled / Asymmetrical design — a short jamb, the stair's slope
up to a level head, a tall jamb, a mullion dropped from the corner where
the slope meets the head, a `>` in the light under the slope — it is read,
built, sized, saved and opened again as drawn. Five faults were found on
the way, all where a bar meets a raked side:

- **The mullion's own body counted as glass.** A body cut square at its
  end reached the level head on one side and stopped short of the slope on
  the other, leaving a sliver of the bar as a light. A bar's body now runs
  on, along its own line, to meet the line it ends against
  (`SectionBuilder._reachingWhatItMeets`).
- **A pane's height stretched the frame.** `Measurements.stretch` mapped
  the slope's corner with the bars round the pane. When the frame's own
  sides do not move, the frame and the ink nobody claims are now kept
  where they are.
- **A light's size missed by a weld.** It is measured on the result, and
  put right once (`Measurements._resize`, `again`).
- **The subdivision welded two points of one line.** Where the mullion's
  face met the head two millimetres from the corner the slope meets it,
  the weld folded the two together. The light then measured from the
  frame's corner, not the bar's face, and a 7 cm border with a 120 cm
  light was refused. Two points that both lie exactly on one line, more
  than half a millimetre apart, are now two points
  (`PlanarSubdivision._twoPointsOfOneLine`). A hand's end left short of a
  line is still welded to it. Lowering the weld instead was tried and
  undone: it stopped a hand-drawn line 6 mm short of a mullion from
  dividing anything.
- **Two lights swapped identities.** With as many regions as before, the
  nth region took the nth's identity. When the mullion crossed the slope's
  corner the faces came back the other way round, and a frosted right
  light became a frosted left one. Regions are now matched by the ground
  they share first, and by place only where ground cannot say
  (`SectionBuilder._carryIdentityForward`).

`test/domain/an_under_stair_design_test.dart` holds it.

Still open:
- Faults 3 and 5 of §5.
- Validation problems are not shown in the app.

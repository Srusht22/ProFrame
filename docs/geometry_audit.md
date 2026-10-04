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
   will be undone the same way. **Fixed in Phase 21** (§25).
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

## 15. Dimensions on an angled design (Phase 11)

Before: an angled frame had an overall width and height and nothing else,
the bounding box. A sloped head with a left side of 200 cm and a right of
150 had no figure for the 150. Typing the overall height stretched the
whole sheet, so the 150 became 165.

Now (`lib/domain/dimensions/frame_sides.dart`):
- **Each side has its own figure.** On a frame that is not a rectangle,
  every upright side shorter than the frame and every level side narrower
  than it is a `FrameSide`. It is asked for in the sizes form, written on
  the technical drawing (`ChainRunOf.side`), tappable there, and typed on
  the frame member's own panel. A slope is not a side: its length, angle,
  rise and run are read on its panel.
- **Typing a side moves its free corner**, and only that
  (`FrameSides.sized`). The slope that joins it follows and stays a
  straight slope.
- **Typing the overall size of an angled frame moves its far side**, with
  every side standing on it (`FrameSides.overall`). Each side keeps its own
  figure.
- **Everything that met the frame still meets it**
  (`FrameSides.reshaped`). A bar's end goes to where its own line meets the
  new outline. A line inside an opening is not carried in proportion. The
  ink moves with what was read from it, so a fresh reading gives the same
  design. A stated figure on a side that moved reads its new length.
- **Sides that add up to another are not both asked.** On a stepped frame,
  `FrameSides.askedOf` asks only one of them.

Still open:
- Faults 3 and 5 of §5. Fault 5's sizes now exist for a frame's own upright
  and level sides, but not for a bar at a slope.
- No aligned figure is drawn along a slope.
- Validation problems are not shown in the app.

## 16. Openings inside an angled design (Phase 12)

An opening marked under a slope is the shape the frame gives it, raked and
never squared. Read and built, it already held its divider, its glass, its
panel and its ironmongery, all inside it. What broke was editing it. An
opening's contents were carried by its bounding box (`Polygon.sameIn`), and
on a raked light the box's top is wherever the slope meets the bar beside
it. So moving that bar sideways stretched the opening vertically:
- a rail inside it rode up or down, and its panel's height changed;
- an upright dropped to the slope came off the slope and divided nothing,
  so the opening lost its glass and its panel.

- **The carry is measured from the sides that bound a region square**
  (`Polygon.sameIn`): between a level head and a level sill, between two
  upright sides. A rectangle carries exactly as before. A raked light,
  with only a sill level, carries its contents with the sill.
- **An end that met the region's edge still meets it**
  (`Polygon.lineIn`), along its own line. `SectionBuilder._carryContents`
  and `DesignEdits.moveOpeningToSection` both use it.
- **A frame reshape lets the rebuild carry the opening's contents**
  (`FrameSides.reshaped`). Phase 11 froze them in place, which was only
  right while the carry was wrong. The sill taken down by an overall
  height now takes the rail with it, so the panel keeps its height.

`test/domain/openings_inside_an_angled_design_test.dart` holds it.

## 17. The technical drawing is the canonical geometry (Phase 13)

`CadPainter` draws from the design and `DesignGeometry` and nothing else:
- the frame from `FrameElement.lines` and `innerOutline`;
- every bar from `DesignGeometry.barBody`;
- every fill from `fillOf`, the leaf from `leafOuter` and `leafInner`;
- the ironmongery from `hardwareOf`;
- the figures from `DimensionChains`, each a section, a side or the frame
  that is there.

Nothing is rebuilt from the sketch, so a hand-drawn rectangle is drawn as
the rectangle the reading corrected it to. An angled frame is drawn as
the outline it is.

**One rectangular placeholder was left: the swing.** The dashed triangle
that says how a leaf opens was laid on the leaf's bounding box in both
drawings. On a raked leaf it started at the box's corners, out past the
slope and off the frame. It is now `OpeningHardware.swingOf`: the two ends
of the stile or rail the leaf hangs on, by `stileOf` and the leaf's own
head and sill, and the middle of the edge opposite. These are the same
edges the hinges and the handle are placed on. A rectangle's swing is
exactly what it was.

`test/app/cad_is_the_canonical_geometry_test.dart` holds it on a standard
rectangle, the same drawn by hand, an angled window and a window under a
stair:
- every line of the outline, the daylight and every bar body is inked
  where the geometry puts it (except under a piece of ironmongery, which
  stands in front);
- nothing is inked outside the outline;
- the hand's own leaning corners are not drawn;
- every figure is a measure of something the design has.

Laying the swing on the box again, or drawing the outline as the box,
fails it.

## 18. The solid is the canonical geometry (Phase 14)

`MeshBuilder` was audited for anything built from a bounding box rather
than the design's own shapes. Everything it builds already read the shared
geometry:
- the frame is the profile swept round `outline` and `innerOutline`;
- the sash is swept between `leafOuter` and `leafInner`;
- the bars are on `barBody`;
- the glass, the panel and the bead are on `fillOf` and `beadAround`;
- the ironmongery is placed by `OpeningHardware` on the leaf's stiles.

The floor's shadow blocks and the sliding tracks' spans use boxes for
extents only, never for a face.

**One box remained: the swing axis.** `_swingFor` turned a leaf about the
side of its box, while its hinges run down its own stile. On a stile
drawn leaning, the two are different lines. Swung, the hinge stile left
its hinges. The leaf now turns about the line `OpeningHardware.swingOf`
gives, the one its hinges and both drawings read. On a rectangle that is
the box's side, so the pinned solids did not move.

`test/domain/the_solid_is_the_canonical_geometry_test.dart` holds the
solid to the canonical geometry, face by face, on four designs:
- a rectangular door;
- a standard window;
- an angled window;
- the window under a stair.

It also holds the leaning leaf's swing. Three mutations fail it:
- the box swing;
- a box frame;
- box glass.

## 19. Telling the categories apart (Phase 15)

The category, its name, its line and its marks were already in place. Two
things were added, and nothing else on any screen was changed.

- **One sentence on *Choose your design*.** It sits under the cards: the
  four standard categories straighten a line drawn a little out of square,
  and Angled / Asymmetrical keeps every slope
  (`StartScreen.straighteningNote`).
- **A quiet note when it happens.** *Geometry normalized for standard
  design.* is shown when a reading visibly put a standard design right
  (`NormalizedNote`). A correction counts when it moved a line by more
  than the weld, which is what `NormalizedGeometry.noticeableStrokes` and
  `Interpretation.noticeablyCorrected` say. The note is said once per
  stroke. It is never shown for an angled design and never in a dialog.

The browser found one fault, and it is fixed. A first reading brings up
the sizes, and on a phone they fill the screen, so the note played out
unseen behind them. It now waits until the workspace route is in front
and no alert is up (`WorkspaceState.waitingOnAnAlert`, shared with
`sizesToAsk`).

`test/app/category_behaviour_is_clear_test.dart` holds it.

## 20. The category outlasts the design being opened again (Phase 16)

Audited: nothing that opens a design touches its geometry.
- `Design.fromJson` reads the category back as it was kept.
- `DesignStore.load` hands the design over as stored.
- `WorkspaceController.openDesign` puts it into the workspace without
  reading it.

A later reading reads with the kept category, so an angled design stays
raked and a standard one stays the same square design.

Category conversion does not exist: the information form shows the
category and does not let it be changed. None was added.

One small fault was fixed. **Read again** on a reopened standard design
brought up *Geometry normalized for standard design.* for lines it had
straightened when it was first drawn. `openDesign` now marks those strokes
as already reported.

`test/app/reopening_keeps_the_category_test.dart` holds it. Six designs,
four standard and two angled, are each kept, reopened, read again and
drawn on.

## 21. Persistence and backward compatibility (Phase 17)

Audited field by field: every field of `Design` and of each of its
elements is written and read back. The category and the canonical
geometry are kept as built, so no new field or migration was needed.

Three faults in what already existed were fixed.

- **Adoption rewrote untouched designs.** A design kept before customers
  was parsed into today's model and written back whole. Now only
  `customerId` is added to the stored record, and every other key is kept
  exactly.
- **The oldest list could lose a design.** An unreadable entry was skipped
  and then deleted along with the list. It is now kept verbatim under
  `proframe.designs.v1.unread`.
- **The first screen missed the customers of older designs.** It read the
  customers before the designs, and reading the designs is what makes
  those customers. It reads the designs first now.

`test/app/persistence_and_old_designs_test.dart` holds it: create, save,
close and reopen for all five categories, and older records loading
unchanged.

## 22. Comprehensive geometry testing (Phase 18)

`test/comprehensive_geometry_test.dart` holds the eighteen standard and
angled cases on the design, the figures and the solid, through a second
reading and a save and reload.

**It found one fault, in the join, and it is fixed.** Lines drawn past
each other at a corner had their loose ends averaged to a point on
neither line. The trim was then skipped, and keeping square moved both
lines about a centimetre. `_joined` now leaves such ends for the trim.
"Such ends" is judged in the ink: both ends past the crossing by more than
the weld, and no other end at the corner. Everything else joins as before.

## 23. The whole system, end to end (Phase 19)

`test/full_pipeline_regression_test.dart` runs the whole chain on the real
app: drawing, reading, canonical geometry, CAD on its pixels, 3D on its
facets, save, close, reopen. It does this for an imperfect door and a
hand-drawn under-stair window. It then checks the customer page, several
designs, names, most recent first, category filtering, and another
customer.

The full suite is the regression run: 2194 tests, all passing, with
`flutter analyze` clean. Nothing in the application changed in this
phase; nothing it found needed fixing.

## 24. Final review (Phase 20)

The review found two things worth changing, and both were changed. No
behaviour changed.

- **The category's say over geometry was asked in three places**: the
  normaliser and twice in the reading, each as `kind == angled`. It is now
  one property, `DesignKind.geometryPolicy` (`GeometryPolicy.normalize`
  or `preserve`), and all three ask it. A test scans `lib/domain` so that
  the question cannot be asked directly again.
- **One tolerance was written twice as a bare 0.05.** Where a bar's end
  is carried on to a line, and where a frame side is followed along a bar,
  the same "lying along it, not ending on it" angle was a literal in each
  file. It is `Tol.alongSine` now, with its reason.

Checked and found right:
- **One source of truth:** `Design`, read by `DesignGeometry` and
  `DesignTree`, drawn by all three views.
- **The reading runs on Read, never on a pointer event.** It takes 1–6 ms
  and the solid 1–9 ms on the debug VM, even for a 12-light design with
  six leaves.
- **Serialization:** every field round-trips, and older files load
  unchanged.

The open faults from the first audit are now settled:
- a drag in CAD undone by the next reading: still open here, fixed in
  Phase 21 (§25);
- sizes and snaps only for horizontal and vertical members: sizes are
  fixed for angled frames by the side figures (§15); the CAD snaps were
  unchanged here, and are fixed for angled designs in Phase 23 (§27).

## 25. CAD edits persist through Read (Phase 21)

Fault 3 of §2 was open until this phase, and it was what the user met: a
door's head dragged on the technical drawing from 200 cm to 190 came back
at 200 cm after **Read**.

**Reproduced first.** `moveFrameMember` took the head to 1900 mm, and
`readDrawing` returned 2000. A transom dragged from 500 to 600 came back
at 500. The frame and the bars are read from the strokes. The drag
changed the design and not the strokes, so a reading put them back.

**The fix is the rule sizes already followed.** `Measurements.stretch`
and `FrameSides.reshaped` move the ink as they move the geometry.
`InkFollows.edit` does the same for every edit the technical drawing and
the panels make, applied by `WorkspaceController._inked`:
- each bar's, figure's and arrow's own stroke follows that element;
- the frame's ink follows the frame's edges, within the hand's reach;
- a dimension resting on what moved goes with it, and a stated figure
  reads the new length.

The ink is still what a reading reads, and the design is still the only
canonical geometry. Undo already kept whole designs, ink included.

**One reading fault found on the way.** `GeometryNormalizer._joined`
joined an end lying exactly on another line (a T-junction) to that line's
nearest end within the join's reach, about 3 % of the drawing. A mullion
moved 80 mm along the under-stair head then pulled the slope's corner
60 mm along with it. Such an end is now joined only within the weld. No
hand-drawn reading changed: the full suite is unchanged.

**Limit.** In a standard design, an edit leaving a line inside the wobble
band (within the snap angle and a twentieth of the drawing) is squared by
the next Read. That is the category's policy, as for a line drawn that
way.

`test/domain/a_cad_edit_survives_reading_test.dart` (19 tests) and
`test/app/a_cad_drag_survives_read_again_test.dart` (the real grip and
the real button) hold it. Disabling `InkFollows` fails all 20, and
disabling the T-junction rule fails the under-stair test.

## 26. Angled validation shown to the user (Phase 22)

`GeometryValidation.of` (§12) already reported structured problems: a
kind, the element and a detail. Every reading of an angled design carried
them as `Interpretation.problems`, and nothing showed them. Three things
changed, and the validator's checks did not.

- **Severity**, the minimum the checks can tell apart.
  `GeometryProblemSeverity.error` is geometry nothing can be built from: a
  non-number, an empty or self-crossing outline or section, a section
  outside the frame, a pane outside its part, an opening without a region.
  `GeometryProblemSeverity.warning` is geometry that can be built but may
  not be meant: a bar connected to nothing, a line outside its part,
  ironmongery off its leaf, a mark outside its region, and every
  dimension problem. There is no info level, because nothing the validator
  finds is merely informative.
- **Words** (`GeometryFeedback`). Each problem is named by the part it is
  about, read from the design: *the raking upper left side of the frame*,
  *a sloped bar*, *Opening 1*, *the dimension you gave as 150 cm*. It
  never shows an id. It also lists the parts to highlight: for a crossing
  outline, the two sides that actually cross.
- **Shown** (`GeometryCheckPanel`) under the drawing in every view, with a
  passing highlight on both drawings.

The feedback is worked out from the design on the screen, kept only with
that design object, and never saved, so a problem put right cannot
outlive the geometry it was found in. It is gated by
`GeometryPolicy.preserve`, so standard designs are untouched.

Verified in the browser on a phone: a valid hand-drawn under-stair window
showed nothing; a loose sloped line read as one warning; **Show me** lit
it; Undo cleared both. The tests are
`test/domain/angled_geometry_feedback_test.dart` (24) and
`test/app/angled_geometry_feedback_on_screen_test.dart` (7). Silencing the
feedback fails 16 of them.

## 27. Angled CAD snapping (Phase 23)

**What was there.** `CadView._move` snapped a drag's x and y separately,
when the Snap layer was on (`DesignEdits.snapTo` over
`DesignEdits.snapCandidates`). Then it handed the point to the grip's edit:
`moveDividerAcross`, `moveFrameMember` through `frameMemberOffset`,
`moveDividerEnd`, `moveDimensionEnd`, `moveArrowEnd`, `dragElement`. The
candidates were the x and y values of the frame's and the daylight's
corners, the centres and faces of upright and level bars, and every
section's bounding box.

**Why angled snapping failed.**
- No line was ever a target, so an end dragged near a raking side stayed
  off it.
- Sloped bars were skipped.
- A raked light's bounding box gave values at corners no geometry has, for
  example the daylight's right x with the slope's height at the mullion.

**What was done.** `CadSnap` snaps to the design's own points, to its lines
at their own angles (perpendicular projection), then to alignments, in that
order, nearest first, within the CAD view's existing eleven-pixel reach.
- Boundary grips snap their offset along their own normal.
- End grips snap as points.
- Move grips snap by alignment.
- A child bar's candidates are its opening's region and contents.

It applies only where `GeometryPolicy.preserve`; the standard path is the
old code, untouched.

**Found and fixed on the way.** `InkFollows` kept the gap between a bar's
ink end and its end. An end moved from a corner to mid-slope was read back
at the ink's end, off the slope; in the browser, about 18 cm off. Where an
edit moves one end relative to the other, the ink's end now goes to the
new end exactly.

**Verified** with `test/domain/angled_cad_snapping_test.dart` (22) and
`test/app/angled_snapping_on_the_drawing_test.dart` (3), the full suite,
and in the browser on a phone: the under-stair mullion's end dragged down
the slope landed on it, the 3D followed, **Read again** kept it with no
warning, and it was the same after Save, a page reload and reopening from
the card.

**Not done**: there is no corner (vertex) grip on the frame, so a
frame corner cannot be dragged on its own; a side is moved square to
itself.

## 28. A category this version does not know (Phase 24)

**The fault.** `Design.fromJson` and `DesignSummary.fromJson` read the
category with `orElse: () => DesignKind.window`. A design kept by a later
version under a category this one does not know — `future_custom_shape`,
`circular` — loaded as a window:
- labelled Window on its card, in its panel and under the Window filter;
- read with a window's rules, so a reading squared what a window squares;
- written back as `window` over the category it was saved with the next
  time it was kept, losing it for the version that made it.

A malformed value (`12345`) or a missing one did the same.

**What was done.**
- `DesignKind.unsupported`, given by `DesignKind.of` for anything that is
  not a known category, and never offered (`DesignKind.categories`).
- `Design.savedCategory` / `DesignSummary.savedCategory` keep the stored
  value and `toJson` writes it back as it came.
- The design is shown and never changed:
  - the controller's state setter refuses a new version of it;
  - Read, Save, keeping, undo, questions and sizes do nothing for it;
  - the store never writes it, and duplicate, rename and retitle refuse
    it;
  - its card offers neither Edit information nor Duplicate.
- Its geometry policy is `preserve`; no leaf follows it.
- `UnsupportedCategoryNote` says so, in words, under every view.

**Verified** with `test/domain/an_unknown_category_test.dart` (11) and
`test/app/an_unknown_category_on_screen_test.dart` (5), the full suite
(2290), and in the browser on a phone. A design seeded into the browser's
storage as `future_custom_shape` was:
- listed as *Unsupported category*, with its own chip;
- drawn in Draw, CAD and 3D with the notice;
- left alone by a stroke and by Save.

The device's storage was identical before, after and after a reload.

**Not done.**
- An opening's own leaf kind still falls back to a window when its stored
  value is unknown (`OpeningElement.fromJson`); that is a leaf's kind, not
  the design's category.
- The tools stay on the bar for an unsupported design and do nothing; the
  notice says why.
- The Sizes icon keeps its dot where sizes were never given.

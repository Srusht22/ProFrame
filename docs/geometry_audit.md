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

## 29. A pricing engine on the canonical design (Phase 25)

**What was there.** No pricing at all, and no roles: CLAUDE.md says the
application has no administrator.

**What was done.** `lib/domain/pricing/`:
- `PricingTakeoff` reads quantities from the canonical design through
  `DesignGeometry` and `Infill`, in metres and square metres. Polygon areas
  are used as they are, so an angled design is priced at its own area.
- `PriceList` holds every figure, and `PriceListStore` keeps it on the
  device. Only `WorkshopRole.owner` may change it; the device starts as
  staff.
- `PricingEngine` uses a strategy for each category, by name:
  - `FramedPricing` for door, window and door & window, each leaf by its
    own kind;
  - `SlidingPricing`, which adds the track and rollers;
  - `AngledPricing`, which adds the angled joints.

  A category with no strategy or rate is not priced, and Phase 24's
  unknown categories give *Price unavailable*.
- `PriceResult` is a breakdown with a subtotal, a discount and a total.
  `PriceSnapshot` keeps a price as it stood.
- `Design.pricing` holds installation, a discount and a snapshot. It is
  written only when set.
- `PricePanel` in the design's own panel shows the total, the breakdown and
  **Include installation**.

**Verified** with `test/domain/pricing_engine_test.dart` (28) and
`test/app/the_price_on_screen_test.dart` (5), the full suite (2323), and in
the browser at a laptop's width:
- a 100 × 200 cm door priced at 427,461 IQD on the example list;
- 472,461 with installation;
- 507,736 at 120 cm wide;
- the breakdown open;
- a `future_custom_shape` design showing *Price unavailable*.

Mutations caught: an unknown category priced as a window, the frame's
material ignored, the colour dropped.

**Not done.**
- No price editor and no sign-in: the owner cannot yet change prices from
  the app.
- No quotation flow takes a snapshot.
- Discounts have a model but no control.
- Rollers are counted from the sliding panels, because the design does not
  model them as pieces.
- Glass is priced by its look; the sealed unit every pane is built as has
  no separate rate.

## 30. Factory measurement and a customer's total (Phase 25, reworked)

**What was there.** §29's engine priced a frame, sash and bar by the metre
and charged each leaf by what it is, with an angled joint as its own line.
That is not how the workshop prices: it measures profile in two kinds, at
two rates, and fills by area.

**What was done.**
- **`measurement.dart`**: `Metres`, `SquareMetres` and `MeasurementSummary`.
  The two units are two types, and `totalProfile` is metres alone.
- **`PricingTakeoff`, rewritten.** Every run of profile is measured once, in
  one `ProfileUse`:
  - **border**: the outline's members;
  - **divider**: each bar, the design's or an opening's, at its body's cut
    length;
  - **opening**: each opening's own region's perimeter;
  - **track**: a sliding design's track.

  Panel and glass are each part's `fillOf` area, the polygon's own. A line
  inside an opening is the opening's on the list, but its metres are normal
  profile, never added to the perimeter again.
- **`PriceList`, rewritten.** `ProfileRate` has a normal and an opening rate
  per metre, and `ColourRate` / `ColourSurcharge` add so much a metre and a
  percentage. `LeafRate` and the angled joint are gone. The starter list is
  in US dollars; the store key moved to `proframe.pricelist.v2`.
- **The engine.** `FramedPricing` (door, window, both, angled) and
  `SlidingPricing` give lines by material and use, colour, glass look, panel
  colour and piece. `PriceResult` carries the measurements, and
  `CustomerPricing` sums a customer's designs.
- **On the screen.**
  - The design panel's **Price** shows the measurement rows.
  - `CustomerPriceCard` stands under the cards on a customer's page.

  It was put above the cards first, and that moved every card down. Five
  older tests that tap a card's ⋮ or picture failed, so it went under them.

**Verified.**
- `test/domain/pricing_engine_test.dart` (28): the acceptance design gives
  7.60 m × $7 = $53.20 and 6.00 m × $12 = $72.00, which is $125.20.
- `test/app/the_price_on_screen_test.dart` (5) and
  `test/app/a_customer_s_total_test.dart` (3).
- The full suite: 2326 passed.
- In the browser at 1440 × 900:
  - Adam's three designs were 155.99 + 240.41 + 189.98 = 586.38 USD, with
    35.22 m of profile.
  - Sara's one design was 162.98 USD.
  - The door's own panel read 6.00 m normal, 5.52 m opening and 11.52 m
    total profile, 1.43 m² of glass, and 189.98 USD — the same figure as
    its line on Adam's card.

**Mutations caught.**
- The opening priced at the normal rate fails 8 tests.
- Inside lines counted twice fails 5.
- Areas by the box fails 1.
- An unknown category priced as a window fails 4.

**Not done.**
- No price editor and no sign-in.
- No quotation takes a snapshot.
- The discount has no control.
- Rollers are counted from the panels.
- The sealed unit has no rate of its own.
- Shown figures are rounded each on its own, so two rows can differ by a
  hundredth from the total under them (20.98 + 14.23 shown against
  35.22 m).
- The customer card loads every design of that customer to price it. That
  is fine for a workshop's customer, but it is not paged.

## 31. Calculate price, completeness and the customer's money (Phase 26)

**What was there.** The design panel showed a live price. It was worked out
whenever the width and height were given, even where other sizes were
still `?`, or an opening's kind or the panel/glass parts were not said. A
customer's total summed whatever priced. Nothing recorded a payment.

**What was done.**
- **`PriceReadiness`** is the one answer to whether a design can be priced.
  It reads the requirements the application already asks: category, frame,
  measurable geometry and the angled check's errors, construction, the
  panel/glass parts, each opening's kind, and every asked size. The engine
  refuses anything it rejects, with a new `PriceStatus.incomplete` for the
  questions not answered.
- **`PriceRecord`** (`design_price_state.dart`) is a calculated price with
  a fingerprint of its inputs (`PriceInputs`). It is kept by
  `PriceRecordStore` beside the design, never in it.
- **`DesignPriceState`** is current, not calculated, needs recalculation,
  incomplete, unsupported or unavailable. The workspace, the cards and the
  customer total all read it.
- **`CustomerPricing`** (moved and rebuilt) is final only when every
  design is current. **`CustomerFinance`** gives the total, paid, due and
  status from `Customer.paid`, the one new kept field.
- **The screens:**
  - **Calculate price** on the workspace bar and in the Price panel.
  - **Price**, the status and the price on each card.
  - **CUSTOMER FINANCIAL SUMMARY** with **Record payment** under the cards.
  - The money at a glance on the customer page's bar.
- `PriceRow` wraps a long value.

**Layout found by the tests.**
- A taller card pushed **Open** off a 900-px screen, so the card keeps its
  height: the price goes at the end of *Last edited*, and **Price** joins
  the bottom row.
- A line added to the information card, or beside the name, pushed the
  cards off a phone, so the glance went to the bar.
- The summary under the cards lets the page scroll past the first card.
  Two older tests' helpers now scroll to the top first.

**Verified.**
- `test/domain/price_readiness_test.dart` (29), including 800 + 500 + 700 =
  2,000 → 2,100, and 2,100 with 1,000 paid = 1,100 due.
- `test/app/the_price_button_test.dart` (9).
- The pricing tests updated; the full suite passes (2361).
- In the browser at 1440 × 900, on Adam's three designs:
  - Basement Door is *Incomplete*. Its Price is disabled and, pressed,
    says *Please give the overall height to calculate the price.*
  - Kitchen Window calculated at 240.41 USD, and Front Entrance Door at
    189.98 USD.
  - The summary showed *Not final* with 430.39 priced so far.
  - A 100 USD deposit was recorded.
  - In the workspace, Basement Door's **Calculate price** was disabled
    until the height was typed into the sizes form. It then calculated
    189.98 USD.
- At 390 × 844 the page, the cards and the summary fit.

**Not done.**
- A payment is one figure, not a history: there are no dates, methods or
  receipts.
- Overpayment is refused against a final total but is not recorded as
  credit.
- A deleted design's kept price stays on the device, unread.
- The customer summary reads every design of that customer, not a page.
- A sheet drawn but not yet read is priced as the design last read.

## 32. Pricing integrity (Phase 27)

**Found.**
- A sheet drawn on and not read was priced as the design last read. A card
  could not know: the flag lived in the workspace, not in the design.
- A deleted design's price record stayed on the device.
- The first engine's price list (`proframe.pricelist.v1`) was ignored, so
  a workshop that had kept one was priced by the example list.
- The example rates were written inside `PriceList`.
- Lengths and money were doubles. Profile rows written to the centimetre
  did not always add up to the total written, and money was summed as
  doubles of rounded cents.
- A sealed glazing unit was priced at the single-sheet glass rate.

**Changed.**
- `Design.sketchUnread` is kept in the design while the sheet has unread
  structural lines. `WorkspaceState.needsReading` reads it.
  `PriceReadiness` refuses to price it (`PriceRequirementKind.notRead`,
  `PriceStatus.notRead`). A card says *Drawing not read* and *Price: needs
  update*, and its Price is disabled. Reading for the user was not chosen:
  a reading can raise questions and change the design.
- `DesignStore.remove` also removes the design's price record. Undo
  restores both.
- `PriceListMigration` brings schema 1 and schema 2 lists to schema 3.
  Only equivalent rates are carried; anything without a place is named in
  `PriceList.migrationNotes`. `PriceListStore.load` reads the old key when
  no current list is kept, and writes nothing. The owner's save writes
  schema 3.
- `DefaultFactoryPricing.list` is the one place the example rates are
  written; `PriceList.starter` is it.
- `Metres` and `SquareMetres` are whole millimetres and square
  millimetres. A price line is whole cents (`Money.cents`). Totals, a
  customer's sum, payments and amounts due are sums of cents.
- `sealedGlassPerM2` and `customSealedGlassPerM2` price a sealed unit.
  Which panes are sealed is read from the solid's facets (four faces of
  glass), so pricing and the model agree. There is no fallback to the
  glass rate.
- The card's price and **Price** moved to their own row. *Edit
  information* and **Open** share the bottom row in full, and the
  picture is 116 px so the card keeps its height.

**Kept.**
- The roller rule: sliding panels × `rollersPerSlidingPanel` ×
  `rollerEach`.
- Discounts: in the engine, with no screen yet.
- Payment: one figure per customer, with overpayment refused against a
  final total.
- The customer summary reads every design of that customer.

**Verified.**
- `test/domain/pricing_integrity_test.dart` (25).
- `test/app/pricing_integrity_on_screen_test.dart` (8).
- The full suite passes (2394), and `flutter analyze` is clean.
- In the browser at 1440 × 900:
  - Adam's cards show *Edit information* in full.
  - Front Entrance Door, kept unread, says *Drawing not read* and *Price:
    needs update*, with Price disabled.
  - In the workspace, Calculate price is disabled and says to Read first.
  - After **Read my drawing** it calculated 218.57 USD:
    42.00 + 66.24 + 64.33 (*Sealed unit — Clear glass*, 45.00 a m²) +
    46.00. The profile is 6.000 m + 5.520 m = 11.520 m.

**Not done.**
- Price records left by deletes before this phase are not swept.
- Glass and panel areas are written to the hundredth of a square metre,
  so the quantity × rate written can differ from the amount by a few
  cents. The amount is the exact area × rate, and the rows still sum
  exactly.
- No payment history, credit, refunds or discount screen.
- The customer summary is not paged.

## 33. Material, colour and the factory's prices (Phase 28)

**Found.**
- The engine already priced each profile by its own material's rates and
  each colour by the list. But nothing said whether anybody had *chosen*
  the material: every new frame is read in the stock white uPVC, so every
  design was priced as white uPVC whether or not anyone had said so.
- A card said its category but not what it was made of, so two doors of
  one shape at different prices had nothing on them to say why.
- There was no price editor, and no way at all to become the owner.
- Areas were written to two decimals, so a line could read
  `1.43 m² × 45.00` beside an amount of 64.33.
- Price records left behind by deletes before Phase 27 were never swept.
- A card's sheet, once able to change the design, used the card's `ref`
  after the card had rebuilt beneath it (the first app test found it).

**Changed.**
- `ProfileSelection` is the design's material and colour: its frame's own
  finish, chosen when `Design.profileChosen` says so or when the frame is
  in any finish but the stock one. Unchosen designs are not priced
  (`PriceRequirementKind.profile`), and nothing is assumed.
- `ProfileSelection.choose` sets the frame and the bars in the frame's
  finish, and moves nothing.
- `ProfileChooser` is on the price sheet and in the workspace's Price
  panel. The sheet recalculates on a change and is handed its own `ref`.
- `PriceResult.profile` records what the design was priced in.
- `CardProfileLine` shows *Material:* and *Colour:* on every card, and the
  summary shows each design's category, material and colour.
- `FactoryPricesScreen` edits every `RateField` of the list for the owner
  only, behind `OwnerAccessStore`'s salted PIN.
- `SquareMetres.label` writes four places.
- `DesignStore.sweepOrphanPrices` runs once a run and removes only design
  price records whose design is not kept.

**Kept.**
- One engine for every material. Payments, credit, refunds, discounts and
  quotations are deferred; the customer summary is still not paged.

**Verified.**
- `test/domain/material_and_colour_pricing_test.dart` (23).
- `test/app/material_and_colour_on_screen_test.dart` (10).
- The full suite passes and `flutter analyze` is clean.
- In the browser at 1440 × 900 and 390 × 844:
  - Adam's cards say *Material: Aluminium · Colour: Anthracite* and *Not
    selected*.
  - Front Entrance Door, whose only gap was its material, opened its sheet
    from Price. Aluminium priced it at 275.69 USD (11.00 and 18.00 a metre,
    glass 1.4296 m² × 45.00 = 64.33). Black added 11.520 m × 1.00, for
    287.21, and the card followed.
  - Factory prices: read-only as staff. The PIN was set and uPVC's normal
    rate kept as 9.50, with **Lock** on the bar.
  - The Lock button was invisible on the green bar until given the bar's
    lettering colour.

**Not done.**
- The owner's PIN is device-local: anyone who clears the device's storage
  can set a new one.
- Adding a new named colour to the list has no editor yet; existing
  colours' rates are edited.
- A design's material and colour can be chosen by anyone who can edit the
  design, as the frame's finish always could; only the factory's rates are
  the owner's.

## 34. The factory's colour catalog (Phase 29)

**Found.**
- Phase 28's colours lived under each material (`ProfileRate.colours`) and
  were matched by the finish value alone. Nothing had an id, so a colour
  could not be renamed without becoming another colour, and could not be
  retired at all — only deleted by editing the list by hand.
- A colour sold in uPVC and aluminium was two unrelated entries.
- A colour named on one material and not the other quietly took the
  *special* rate on the other, and a named colour with no rate could not
  be expressed at all.
- The owner could change a colour's rates but could not add one.

**Changed.**
- `PriceList.colours` is one catalog of `FactoryColour`s — id, name,
  swatch, grade, rates by material (null where sold but not priced),
  active, order — in schema 4. `ProfileRate` keeps only the normal and
  opening rates and *any other colour*.
- `PriceListMigration._v3ToV4` merges schema 3's per-material colours by
  value, name and grade, at their figures, ids from names.
- `PriceList.colourFor` gives `ColourPricing`; the engine, the price's
  state, the selector and the card all read it, and nothing falls back.
- `Design.profileColourId` says which catalog colour the frame was chosen
  as; the finish stays what every view draws.
- `ColourCatalog` adds, updates, retires and restores, with its checks;
  `FactoryColoursSection` and `ColourDialog` are its screen; each change is
  saved as a new version through `PriceListStore`.
- `PricedProfile` keeps the colour's id and the rate it was priced at.
- The per-colour `RateField`s are gone; *any other colour* stays a field.

**Kept.**
- One engine, one finish pipeline, the existing versioning and records,
  the owner's PIN, `$`/m plus percent.

**Verified.**
- `test/domain/factory_colour_catalog_test.dart` (25) and
  `test/app/factory_colours_on_screen_test.dart` (10).
- The full suite passes and `flutter analyze` is clean.
- In the browser at 1440 × 900 and 390 × 844:
  - **A.** Anthracite Grey added (PVC 2.00, aluminium 1.50, `#383E42`),
    kept as version 1, and there after a reload.
  - **B.** Chosen on Front Entrance Door from its card: the aluminium
    selector listed only aluminium colours with it among them; the card,
    the Price panel, the drawing, the technical drawing and the solid all
    showed the anthracite aluminium frame.
  - **C.** Its line: *Anthracite Grey Aluminium (non-standard colour) ·
    11.520 m × 1.50 = 17.28 USD*, once; total 292.97 USD.
  - **D.** Aluminium raised to 2.00: version 2, the card *Price:
    recalculate*, the old 292.97 kept as previous; recalculated 298.73
    (11.520 × 2.00 = 23.04).
  - **E.** Retired: *Retired* on its row, the door still in it with
    *Retired: no longer offered for new designs.* under the field, and
    still priced at its rate.
- Looking found: the percent field's label cut short (widened), the retire
  confirmation as wide as the window (bounded), *(retired)* cut off the
  colour's name in the selector (moved under the field), and the card's
  colour cut short beside the material (the material now takes only its
  word's width; where the colour still does not fit, its tooltip holds the
  whole name — a second line overflowed the card's fixed height).

**Not done.**
- Colours cannot be reordered from the screen: a new colour is listed
  last, and `order` is kept for a later control.
- Messages use the application's spelling — *colour*, *Aluminium* — where
  the brief wrote *color*, *Aluminum*.
- A price calculated before Phase 29 says it needs recalculation once,
  because its list is now kept in schema 4.
- On the narrowest card a long colour name is cut, with the whole name in
  its tooltip, on the sheet and in the summary.

## 35. A customer's payments, refunds and credit (Phase 30)

**Found.**
- A customer's money was one figure, `Customer.paid`, typed as the total
  paid so far. Each new payment overwrote it, so there was no record of
  when or how money came in, and nothing to refund against.
- Paying more than a final total was refused, so a customer who overpaid,
  or whose total fell after a design was deleted, could not be recorded as
  they stood.
- The summary said *Amount due / loan*.

**Changed.**
- `lib/domain/model/payment.dart`: `PaymentTransaction` (id, customer,
  payment or refund, amount in whole cents always more than nothing, date,
  method, note, recorded, currency) and `PaymentLedger` (newest first,
  gross payments, refunds, net paid, ids, amount and date checks, refund no
  more than the net paid).
- `Customer.payments` replaces `paid`. `Customer.fromJson` reads an old
  `paid` figure as one `PAY-LEGACY` payment of exactly that, to the cent;
  reading writes nothing, and the next save writes the ledger without
  `paid`.
- `CustomerStore.record` appends a transaction with the device's own copy
  of the customer in one step, and `_keepNow` merges the kept ledger into
  any customer saved, so a stale copy never drops a transaction.
- `CustomerFinance.of(pricing, ledger)`: balance, due (never below
  nothing), credit, and `PaymentStatus` — pricing incomplete, outstanding,
  paid in full, credit, nothing to pay. Overpayment is credit.
- `CustomerFinancialSummary`: total payments, refunds, net paid, amount
  due, credit, status, **Add payment**, **Refund**, the history newest
  first (latest five, then **Show all**), and `TransactionDialog`.
  `CustomerMoneyGlance` says *Credit …* too. *Loan* is gone.
- Five older tests moved with it: two domain tests give the paid figure as
  a ledger; the price button test pays through the new dialog; two page
  tests return to the top before looking for a card, because the history
  makes the page longer than the list keeps built.

**Kept.**
- The total is still the designs' current prices (`CustomerPricing`);
  money never touches a design, a price record or the price list; one
  currency, the price list's; no customer can be deleted, so no
  transaction is ever orphaned.

**Verified.**
- `test/domain/payment_history_test.dart` (33) and
  `test/app/payment_history_on_screen_test.dart` (11).
- The full suite passes (2506) and `flutter analyze` is clean.
- In the browser at 1440 × 900, Adam's two designs priced from their cards
  at 1,000.00 USD (the seed's door labour set so the total is the brief's):
  1. $500 Cash, *First installment*: paid 500.00, due 500.00,
     *Outstanding*, one history row.
  2. $300 Bank transfer: net paid 800.00, due 200.00.
  3. $500 more: payments 1,300.00, due 0.00, credit 300.00, *Credit*, the
     line saying it is the customer's, and *Credit 300.00 USD* on the bar.
  4. Refund $100 *Part of the credit returned*: refunds 100.00, net paid
     1,200.00, credit 200.00, a *REFUND −100.00 USD* row at the top.
  5. Reloaded: Adam's page with all four rows, newest first, and the same
     figures; Sara's page showing none of them.
- At 390 × 844, a ledger kept on the device over four days: the summary,
  status, both buttons and every history row on the screen, *Other —
  Company cheque* in full; the refund dialog fitting, and 1,300.01 refused
  with *A refund cannot be more than the net paid, 1,200.00 USD.*

**Not done.**
- No editing or deleting of a transaction, by design; a mistake is put
  right with a refund.
- No receipts, discounts, quotations or paging of the history, as the
  brief says.
- No permission beyond being able to open the customer: ProFrame has no
  accounts, and the owner's pricing PIN is not reused for money.
- One currency. A transaction recorded in another is not added and is
  said.


## 36. Financial records, receipts, discounts, quotations, currencies and permissions (Phase 31)

**Audited first.** Phase 30 left a customer's money as a ledger of
payments and refunds on the customer (`Customer.payments`,
`PaymentLedger`), one currency, `CustomerFinance` working out what is due,
and one permission anywhere — `WorkshopRole` with the owner's PIN guarding
the price list, checked by the price editor's screen and by
`PriceListStore.save`. The pricing engine priced designs; nothing priced a
customer's discount, kept a quotation or issued a receipt. Everything
below extends those pieces: the ledger gained a currency conversion and
paging, `CustomerFinance` a discount, `WorkshopRole` became one
`Authority` among several, and the engine is untouched.

**Built.**
- `Capability`, `Authority`, `AccessDenied` (`pricing_access.dart`); the
  owner, `StaffMember` (`staff.dart`, kept by `StaffStore` with a salted,
  hashed PIN) and `NobodySignedIn`. Every store that writes money takes
  `by:` and requires the capability: `PriceListStore.save`
  (`pricing.edit`), `CustomerStore.record` (`payments.create` /
  `payments.refund`), `.issueReceipt` (`receipts.create`), `.applyDiscount`
  (`discounts.apply`), `QuotationStore.create` / `.setStatus`
  (`quotations.create` / `.edit`), `StaffStore` (`users.manage`,
  `permissions.manage`). `actorProvider` says who is at the device; the
  account button on the customers' header signs in and out; **Staff &
  permissions** ticks capabilities.
- `CustomerDiscount` and its log on the customer; `CustomerFinance`'s
  subtotal, discount and final total; the **Discount** dialog.
- `Quotation` with the whole `PriceResult` of each design as a snapshot,
  `QuotationStore` with its sequence and index; **New quotation**, the
  quotation's sheet and its statuses.
- `Receipt` on the customer, from a workspace-wide sequence; issued with a
  payment or from its row; the receipt's sheet.
- `Conversion` on a transaction; `CurrencyTotals` and the summary's box of
  currencies not counted; `PaymentLedger.page` and **Load more**.

**Found and settled on the way.**
- A customer record saved from a copy read before a discount or a receipt
  would have dropped it, exactly as Phase 30 found for payments.
  `CustomerStore._keepNow` now merges discounts by id and receipts by
  number as well as payments.
- A receipt's number had to be unique across customers, and a device
  whose sequence key was cleared would have started again at 1. The
  sequence now starts past the highest number any customer holds when its
  key is missing.
- A fixed discount given while some design was unpriced had no subtotal to
  be checked against. It is refused until the total is final; a percentage
  can be given at any time.
- The account menu said *Nobody signed in* on a device with no staff
  accounts, which works as staff. It now says *No accounts yet — working
  as staff*; *Nobody signed in* is kept for the view-only case.
- The add-staff dialog did not submit on Enter from its last field; it
  does now, as the owner's PIN dialog does.

**Verified.**
- `test/domain/financial_records_test.dart` (38) and
  `test/app/financial_records_on_screen_test.dart` (9).
- The full suite passes (2553) and `flutter analyze` is clean.
- In the browser at 1440 × 900, Adam's two designs priced at 1,000.00 USD:
  1. Signed in as owner; a 10% discount: Subtotal 1,000.00, Discount (10%)
     −100.00, Final total 900.00, *Due 900.00 USD* on the bar.
  2. $300 Cash with **Issue a receipt**: due 600.00, `RCP-000001` on the
     row, its sheet saying 300.00 received, balance after 600.00 due,
     issued by Owner for `PAY-20261005-0001`.
  3. **New quotation** of both designs: `Q-000001`, 252.95 + 747.05 =
     1,000.00, −100.00, 900.00, *Draft*; **Issue** making it *Issued*,
     with both statuses in its history.
  4. 100 EUR with no rate: kept as 100.00 EUR in *Other currencies — not
     included in the USD total* with the reason, the USD figures
     unchanged, `RCP-000002` issued.
  5. **Staff & permissions**: Rawa added, starting at looking; *Record
     payments* ticked. Signed out: Add payment and Refund disabled, no
     Discount. Signed in as Rawa: Add payment enabled, Refund disabled, no
     Discount, and no receipt box in the dialog.
- At 390 × 844, the same customer: the summary, the box of currencies,
  the history with both receipts and the quotation list on the screen,
  nothing overflowing.

**Not done.**
- Customers and designs are not behind capabilities; anybody at the
  device may still add and edit them.
- No print or PDF of a receipt or a quotation; their sheets are the
  documents.
- No editing or deleting of a transaction, receipt, discount or
  quotation, by design.
- Exchange rates are typed when a payment is recorded; there is no rate
  feed, and a rate is never changed afterwards.
- A discount is the customer's; the engine's per-design discount still has
  nothing on the screen.
- The customer's ledger is read with the customer record, so paging is in
  memory, not in storage.
- A PIN is a lock on a device, not security: anyone who can clear its
  storage can remove it.

## 37. Flexible factory pricing, optional glass, extra charges and permissions (Phase 32)

**Audited first.** Phase 31 left the engine charging each material only
for what the canonical design has (`PricingTakeoff.regions`,
`hardwareCounts`), so glass was already optional in the arithmetic, but the
breakdown said nothing where there was none. `PricingChoices.discount`
existed in the engine with nothing on the screen. A design's price was its
geometry's cost alone: nothing priced silicone, labour, a trip or an
accessory nobody had a field for. The customer's discount came off the sum
of their designs. Capabilities guarded money, the price list and staff;
customers and designs were open to anybody at the device. Everything below
extends those pieces; the engine's own arithmetic is untouched.

**Built.**
- `ExtraCharge` (`extra_charge.dart`): name, category (labels only), a
  quantity in thousandths, a unit, a unit price in cents, a currency, a
  note, a scope and who wrote it when; its total is quantity × unit price,
  half a cent up, in integers. `ExtraUnit` offers ten units and takes any
  typed one.
- Design extras in `PricingChoices.extras`, handed through by the engine to
  `PriceResult.extras` beside `designCostCents`, `extrasCents` and
  `subtotalCents`; another currency stops the price. `DesignPricing` puts,
  removes and discounts, each behind its capability.
- Customer extras on `Customer.extras`, changed only through
  `CustomerStore.saveExtra` and `takeExtraOff`, merged by `_keepNow` like
  every other record a stale copy could drop. `CustomerFinance` adds them
  before the customer's discount.
- The breakdown (`PriceBreakdown`): automatic costs with **Glass** and
  **Panel** always listed and *Not used* where absent, the extras with
  edit and remove (asked first), the extras' cost, the subtotal, the
  design's discount with **Give** / **Change** and **Remove discount**, and
  the final total. The customer's summary has *Extra charges — whole job*.
- `ExtraCharge.alreadyCalculated`: an extra that looks like a cost the
  price already works out is refused unless **This is an additional
  charge** is ticked; the form says what is already charged and how much.
- Quotations keep each design's extras and discount in its `PriceResult`
  and the customer's extras in `Quotation.extras`.
- New capabilities: `customers.view` / `create` / `edit`, `designs.view` /
  `create` / `edit` / `delete`, `extras.create` / `edit` / `delete`,
  checked by `CustomerStore` and `DesignStore` themselves (every write takes
  `by:`), by `WorkspaceController`'s one state gate (*View only* under the
  drawing) and offered or not by the screens.

**Found and settled on the way.**
- A customer saved from a copy read before an extra was added would have
  dropped it, as Phase 30 and 31 found for payments and receipts. `_keepNow`
  keeps the device's extras unless the save is an extra's own.
- Saving a design's new price asks for `designs.edit` as well as the
  extras' capability, so a member of staff allowed only extras could not
  keep one. A save that changes nothing but pricing (`_onlyPricing`) skips
  `designs.edit`; anything else riding along is still refused.
- While the staff list is still being read, every control was briefly
  disabled and seventy screen tests failed on a button that was not yet
  offered. `ref.offers` offers a control until the staff are known; the
  stores decide either way.
- The customers-are-never-deleted scan reads any `Future<…> remove(` in a
  store as a deletion. The customer store's method is `takeExtraOff`, which
  deletes no customer.
- The customer's page now goes on below the cards, so a test that collected
  card ids and looked them up after scrolling found the first ones no longer
  built; it reads each name as the card passes.
- A member of staff without `customers.view` now sees no customer page, so
  the test of a price hidden from somebody without `prices.view` gives them
  `customers.view` and `designs.view`.
- The browser showed the summary with two rows called *Designs* — the count
  and the money. The money row is now *Designs total*.

**Verified.**
- `test/domain/flexible_factory_pricing_test.dart` (28) and
  `test/app/flexible_pricing_on_screen_test.dart` (8), including acceptance
  48 (330 + 15 + 50 = 395, −45, 350) and 49 (500 + 400 + 30 = 930, −30,
  900).
- The full suite passes (2589) and `flutter analyze` is clean.
- In the browser at 1440 × 900, Adam's Front Entrance Door (all panel) and
  Back Door (all glass):
  1. The door's sheet: normal profile 152.00, opening profile 48.00,
     **Glass Not used**, panel 100.00, hardware 30.00, design cost 330.00.
  2. Silicone 5 bottles × 3.00 = 15.00 and labour 5 hours × 10.00 = 50.00
     added through the form, the line under it showing the product as it
     was typed; extras 65.00, subtotal 395.00; the card's price following.
  3. Signed in as owner, **Give**: fixed 45 → −45.00, final total 350.00;
     **Change** opening with 45.00 and **Remove discount**; the trash can
     asking *Remove "Silicone" (15.00 USD) from this design?*.
  4. The Back Door priced at 217.75; the summary 567.75; a whole-job
     *Delivery trip*, Transport, 1 trip × 30.00, making designs 567.75 +
     extras 30.00 = 597.75 and *Due 597.75 USD* on the bar.
- At 390 × 844: the Back Door's breakdown with **Panel Not used** and glass
  28.59; the extra form with a long custom name; an extra called *Glass*
  stopped with *Glass (28.59 USD) is already calculated from the design* and
  the additional-charge box.

**Not done.**
- No catalog of the factory's usual extras with default prices; every
  extra is typed. `ExtraCharge` holds what a catalog entry would.
- No exchange-rate feed, and an extra in another currency is refused rather
  than converted.
- No print or PDF of a quotation or a receipt.
- There is no `customers.delete`, because no customer can be deleted.
- The stores' read methods are not gated; reading is gated where the
  screens read.
- While the staff list is loading a control is offered and the store
  decides.
- A PIN is a lock on a device, not authentication.

## 38. Aluminium profiles, optional glass, separate measurements and completing a design (Phase 33)

**Audited first.**
- Aluminium was one material with one `normalPerMetre`. The frame and
  every bar of the design were one normal-profile figure, so the border
  and the lines inside it could be neither seen nor priced apart.
- Glass was charged whenever a pane was glass. Phase 32 had made it
  optional only in the sense that a design with no glass was charged for
  none.
- Nothing said a design was finished. The cards' *Complete* / *Incomplete*
  was whether it could be priced. A new design for the same customer meant
  going back to their page.
- Phase 32's remaining limitations, all from its final report:
  - reads were not gated in the stores;
  - a control was offered while the staff list was loading;
  - there was no `customers.delete`;
  - there was no catalog of extras, rate feed or PDF.

  The discount form had Percentage and Fixed amount but no way to choose
  none in the form itself.

**Built.**
- `ProfileCategory` (System Aluminium, Bend Shoulder Aluminium).
  - Each has its own normal rate in `ProfileRate.categories`, edited in
    Factory prices. The example list has 8 and 11.
  - `ProfileAllocation` names every frame member and bar and gives each
    its category: the design's, or the part's own.
  - `PriceReadiness` refuses an aluminium design with an unallocated part,
    naming it.
- The takeoff measures one run a frame member.
  - `MeasurementSummary` keeps `borderLength` and `lineLength`.
  - The engine keys every normal run by material, category and part, and
    prices it at that category's rate.
  - The breakdown shows a line a cell and the **Combined profile cost**.
  - The measurements show **Border length**, **Internal line length** and
    **Combined profile length**.
- `PricingChoices.glassPriced` is off by default and not written while off.
  - The engine charges no glass while it is off.
  - `GlassState` says what the Glass row means.
  - **Include glass in price** sits on the sheet and in the Price panel.
- Price list schema 5. `_v4ToV5` carries the old aluminium normal rate to
  neither category and says so in a note.
- `DesignCompletion`: `completedAs` is a fingerprint of what is built.
  - `WorkspaceController.complete` reads, checks, marks, saves, and reverts
    on failure.
  - `CompleteBar` / `NotCompleteDialog` / `CompletedDialog`, with **New
    Design**, **View Completed Design** and **Back to Customer**.
  - Each choice is guarded against a second press.
- Store reads. `CustomerStore`, `DesignStore` and `QuotationStore` take
  `readsAs` and check `.view` before every public read. The providers pass
  `ref.actorNow`.
- `Offering.offers` is false until `permissionsKnown`, and
  `PermissionsLoading` shows a thin bar meanwhile.
- `customers.delete`.
  - `CustomerStore.deleteCustomer` checks it and refuses any customer with
    a design, payment, receipt, discount, quotation or extra charge.
  - The customer's page has **Delete customer**, confirmed, with Undo.
- **None** in the discount form.
- `test/flutter_test_config.dart` gives every test file in-memory storage.

**Found and settled on the way.**
- Pressing Complete! twice opened two dialogs. The busy flag was cleared
  before the first dialog was drawn, so it is now held until the dialog
  closes.
  - That left the spinner turning under the dialog for ever, so tests
    never settled. The spinner now has a flag of its own, cleared once the
    save is done.
- Forty-three test files had never mocked storage. Once nothing was
  offered before the staff were known, they waited forever on the host's
  disk, whose answer never comes inside a widget test's clock.
  `flutter_test_config.dart` settles it for every file.
- **Undo** after deleting a customer used the page's `ref` after the page
  had gone. The revision notifier is now taken before the page is left.
- The price list editor (`price_list_fields.dart`, `_withProfile` and
  `_withSpecial`) rebuilt a rate field by field and dropped the
  categories, so editing any other aluminium figure lost them. Both now
  use `ProfileRate.copyWith`, and writing every field back as it reads
  leaves the list identical again.

**Verified.**
- `aluminium_categories_and_optional_glass_test` (22).
- `complete_and_new_design_test` (6).
- `store_permissions_test` (8).
- `permissions_on_screen_test` (4).
- The full suite passes and `flutter analyze` is clean.
- In the browser at 1440 × 900:
  1. Acceptance A, the shop front's sheet: Aluminium profile *System
     Aluminium*. Border 20.000 m, internal lines 8.000 m, combined 28.000
     m; 160 + 64 = 224; glass *Not included — 0.00 USD* with 23.6 m²
     measured.
  2. **Set each part**, with both jambs and Line 2 set to Bend Shoulder:
     - System border 12 m × 8 = 96
     - System lines 4 m × 8 = 32
     - Bend Shoulder border 8 m × 11 = 88
     - Bend Shoulder lines 4 m × 11 = 44
     - Combined profile cost 260.00, final total 260.00, and the card's
       price following.
  3. Acceptance B, the Kitchen Window: 3.0000 m² of glass, *Not included —
     0.00* and design cost 140. Switched on: *Sealed unit — Clear glass ·
     3.0000 m² × 20.00 = 60.00* and 200. Switched off: 140 again.
  4. Acceptance C: Front Entrance Door, **Complete!**, *Design completed
     and saved successfully.*, **New Design**. The name step shows Adam's
     chip; then Window and **Start drawing**. Back on Adam's page there
     are four designs:
     - Front Entrance Door, *Completed*
     - Kitchen Window, *Draft*
     - the new Kitchen Window 2, *Incomplete*
- At 390 × 844: the price sheet with the glass switch and the separate
  lengths, and the workspace with *Draft* and **Complete!** above the tools.

**Not done.**
- A line's amount is rounded to the cent once, and the cents are summed —
  the rule since Phase 27. Nothing is rounded twice.
- The opening profile of aluminium is still the material's one rate. The
  brief divided the normal profile, and nothing says which category a
  sash is.
- A price list kept before schema 5 has no aluminium normal rate until the
  owner sets the two. Every kept price says *needs recalculation* once.
- A part's category is keyed by its frame member's or bar's id. A
  re-reading that gives a member a new id loses that one part's override,
  and the part then asks for its category again. Nothing is guessed.
- While permissions are unknown, the workspace still lets edits happen in
  memory. Nothing is kept without the store's own check.
- A store made without `readsAs` (tests, the device's own housekeeping)
  reads unchecked.
- A customer with anything kept cannot be deleted. There is no cascade,
  because it would delete financial records.
- There is no catalog of extras, no exchange-rate feed, and no print or PDF.
- A PIN is a lock on a device, not authentication.

## 39. English and Central Kurdish (Sorani), right to left (Phase 34)

**Audited first** (`docs/localization/phase_34_audit.md`).
- Every word the user read was a literal in Dart: about 1,800 candidates
  across `lib/app` and the domain's messages. There was no localization
  layer and no Settings screen. The architecture test refused any
  translation file under `lib/`, because of the one left behind before.
- The domain made its own English messages — readiness, issues, checks,
  questions, the names of openings — and some of them were kept in records:
  a price line's label, a quotation line's category, material and colour.
- Positions written with `left:` and `right:` would not follow a
  right-to-left screen. Flutter has no Central Kurdish localizations at
  all, so without some the app would have no Material words in Kurdish and
  would run left to right.

**Built.**
- `flutter gen-l10n` from `lib/app/l10n/app_en.arb` and `app_ckb.arb`:
  1,219 messages each, the generated files tracked. English is the
  default and the fallback.
- `Words`, generated from the `[domain]` entries by
  `tool/generate_domain_words.dart`, so the domain stays pure Dart and
  says everything through one interface. `EnglishWords` is what its tests
  read; `ArbWords` adapts the ARB.
- `labelIn` for every enum the screens show (`names.dart`). `LineName`
  beside each price line's English label, so kept prices read in either
  language. `keptCategoryIn` and its kin for quotation lines kept in
  English.
- `KurdishFramework`: Material, Widgets and Cupertino delegates for `ckb`,
  right to left, with the framework's words from the same ARB.
- **Settings** with the two languages named in themselves. The choice is
  kept as `proframe.language`, read before the first frame, and set on
  `MaterialApp` outright.
- Directional layout throughout: paddings, alignments, overlays, and the
  moving indicators (`AnimatedPositionedDirectional`). The drawing, the
  technical drawing and the solid are not mirrored; their words are passed
  in (`CadPainter.words`, `DimensionLayout.of(words:)`).
- Figures are kept left to right inside right-to-left lines. In Kurdish
  messages, figure placeholders are marked with U+200E. On screen,
  `context.figure`, `context.figures` and `directionOf` do the same, and
  `PriceRow` sets a pure figure left to right.
- `docs/localization/central_kurdish_translation_review.md`: every
  message, with its context, a confidence and why, and a column for the
  approved wording. `tool/apply_approved_translations.dart` writes the
  approved wording into the ARB, and refuses a wrong key or a lost
  placeholder.
- `docs/localization/hardcoded_text_audit.md` classifies every literal
  still in the code.

**Found by looking at it in the browser, and fixed.**
- At 390 × 844 in Kurdish, the price sheet wrote `m 7.000` and
  `USD 140.00`, and split `7.000 m × 20.00` around the words beside it.
  This is the bidirectional algorithm reordering a figure inside a
  right-to-left line. Figures are now one left-to-right run.
- The radio rows in Settings sat on a coloured box, so their ink was
  hidden; the first widget test caught it. Each section is now a
  `Material`.
- Each language's name pushed itself to the far side of its row. It is
  now aligned at the start, as the screen reads.
- A design card's category tag, the small preview's IN, and Perspective |
  Orthographic were still English. They are now in the chosen language.
- U+2066/U+2069 isolates were tried first. The analyzer rightly refuses
  bidi controls in source, and the generated Dart carries the ARB's
  characters literally, so U+200E is used instead.

**Tests.**
- `the_words_are_one_set_test.dart` (15): keys, placeholders, no empty
  or key-named message, generated files current, the domain's English the
  screen's, a glyph for every Kurdish letter, and figures marked.
- `the_app_in_central_kurdish_test.dart` (14): English and LTR by
  default; Kurdish at once, RTL, kept, reopened; an unknown code English;
  storage unchanged by switching but for the choice; the same price figure
  in both; no key ever shown; no overflow in Kurdish at 390, 820 and 1440
  wide through the customers, Settings, a customer's page and Draw, CAD
  and 3D; CAD's lines the same pixels in both; a design's name never
  translated.
- `the_translation_review_test.dart` (5).
- Two older tests moved, each saying why:
  - the architecture test now allows translation files in `lib/app/l10n/`
    only, and requires every one of them to be tracked by git;
  - `the_bars_move_test` finds the indicators as
    `AnimatedPositionedDirectional`.

**Not done.**
- **No Sorani has been checked by a native speaker.** 140 messages are
  low confidence: the trade terms, the framework's month and weekday names
  and their initials. 512 are medium.
- *Bend Shoulder Aluminium* is left in English inside its Sorani name
  until the factory says what it calls it.
- Digits stay Latin in both languages. Eastern Arabic digits were not
  asked for, and would make figures differ between the two languages.
- Flutter words the app's screens never show (some screen-reader hints)
  fall back to English in Kurdish.
- Guard messages the screens pre-empt (store-level `ArgumentError`s) stay
  English.
- A name the user typed in English, shown in a right-to-left title, takes
  its ellipsis on the left.

# CAD and 3D rendering — audit

The state of the technical drawing and the 3D model before the visual work
begins. Nothing here changes behaviour; it says where things are, how they
flow, what limits the look, and where the look can be improved without
touching the geometry.

## 1. The pipeline

```
USER DRAWING        Sketch — strokes of StrokeSample points (domain/sketch)
      │  SketchInterpreter.interpret (domain/recognition)
      ▼
CANONICAL DESIGN    Design (domain/model/design.dart) — one document
      │  DesignTree.of(design): the hierarchy read once, no geometry of its own
      ├── 2D DRAWING   DesignPainter      (app/canvas/design_painter.dart)
      ├── CAD VIEW     CadPainter         (app/canvas/cad_painter.dart)
      └── 3D MODEL     MeshBuilder.build → Mesh of Facets (domain/solid)
                          Camera.project → ProjectedFacet (domain/solid/camera.dart)
                          ModelPainter paints them (app/viewer/model_painter.dart)
```

**The user's geometry is the source of truth, and both views read it.**
`CadPainter` and `MeshBuilder` are each handed the same `Design`, walk the
same `DesignTree`, and take the frame from `FrameElement.outline` /
`innerOutline`, each bar's body from its `DividerElement`, and each leaf's
edge and each pane's fill from `OpeningLeaf` (`outerOf`, `innerOf`,
`fillOf`). Neither keeps geometry between frames. `test/app/one_design_two_views_test.dart`,
`test/domain/the_solid_is_the_cad_hierarchy_test.dart` and
`test/app/a_design_in_every_view_test.dart` hold this.

**There is no 3D package.** `pubspec.yaml` has Flutter, `flutter_riverpod`
and `shared_preferences` and nothing else: no WebView, no three.js, no
SceneKit-style engine, no model files (`test/no_stock_content_test.dart`
forbids them). The 3D view is Dart geometry projected by our own camera and
drawn with `CustomPainter` — a painter's-algorithm polygon renderer.

## 2. Where each thing lives (the sixteen questions)

| # | Question | Answer |
| --- | --- | --- |
| 1 | Design geometry | `Design` (`domain/model/design.dart`): `frame`, `dividers`, `sections`, `openings`, `hardware`, `dimensions`, `texts`, `arrows`, `depthMm`, `measured`. Kept by `DesignStore` as JSON. |
| 2 | 2D drawing geometry | `Design.sketch` — `Sketch` of `Stroke`s, each a list of `StrokeSample` points in mm, with the pen's colour and width (`domain/sketch/stroke.dart`). Kept forever; the design is read from it. |
| 3 | Openings | `OpeningElement` (`elements.dart`): `sectionId` (the region it opens), `mechanism`, `direction`, `markAt`/`markGlyph`, `kind`, hinge/handle figures. Stores no outline — `Design.outlineOf` gives its section's. |
| 4 | Internal lines / dividers | `DividerElement`: a `Segment` (`a`,`b`), `widthMm` (50 default), `finish`, `parentId` (null = divides the design; set = inside that opening). |
| 5 | Panel regions | `SectionElement` with a `finish` whose `material` is `MaterialKind.panel` (or any non-glazing kind). Outline from planar subdivision (`SectionBuilder`). |
| 6 | Glass regions | The same `SectionElement`, `finish.material.isGlazing` (`clearGlass`, `frostedGlass`, `tintedGlass`); look from `GlassLook`. The filled shape is `OpeningLeaf.fillOf` (stops at the sash). |
| 7 | Frame / border | `FrameElement`: `outline` (polygon), `profileMm` (face width, 60 default), `finish`, `openEdges`; `innerOutline` is the outline inset by the profile. Members as `FrameMemberElement` for picking. |
| 8 | Dimensions | Three kinds: sizes the user gave (`Design.measured` keys, applied by `Measurements`), chains worked out from the geometry (`DimensionChains`, `ChainRun` in `domain/dimensions/dimension_chain.dart`, placed by `dimension_handles.dart`), and measurements drawn on the sheet (`DimensionElement`: `a`, `b`, `offsetMm`, `statedMm`). All mm inside, cm on screen (`Units`). |
| 9 | CAD rendering | `CadPainter.paint`: sheet and grid, sketch (optional), infill (glass pale fill + glazing mark; panel = its colour at 32% + hatch), frame (two outlines + profile hatch), bars (body clipped to their parent, hatched), openings (leaf edge, dashed swing triangle, IN/OUT, the user's mark), hardware (symbol sized from the design), chains, sizes, user dimensions, annotations, selection, grips, snap. Line weights and ink sets in `cad_style.dart` (`Cad.paper`, `Cad.night`). Layers in `CadLayers`. |
| 10 | 3D rendering | `MeshBuilder.build` makes flat `Facet`s (corners in mm, `elementId`, `colour`, `transparency`, `gloss`, `role`, `part`). `Camera.project` turns, projects (perspective or parallel), lights (Lambert, one fixed light) and sorts far to near, with ironmongery settled by planes. `ModelPainter` fills each face: colour × light, opacity from transparency, a fixed gradient on glass, a white wash on glossy lit faces, then edges and selection. Sky gradient and a blurred ground shadow behind. |
| 11 | Packages | None for rendering: `dart:ui` `Canvas`, `Path`, `Paint`, `ui.Gradient`, `MaskFilter`. |
| 12 | 3D technology | Flutter `CustomPainter` with its own `Camera` — not a 3D package, WebView or three.js. |
| 13 | Same geometry source? | Yes for the frame, bars, sections, leaves and panes (see §1). **One exception: ironmongery size** — see §4.4. |
| 14 | Material / colour | `Finish` (`colour` 0xAARRGGBB + `MaterialKind`) on the frame, every divider, every section and every hardware piece. `MaterialKind.transparency` and `.gloss` give the renderer's numbers. Defaults: frame and every bar white uPVC `0xFFF3F4F2` (`Finish.frameDefault`), glass `0xFFD8E6EA`, hardware grey steel `0xFF8A8F8C`. Palettes: `GlassLook`, `PanelColour`, `HardwareColour`. |
| 15 | Depth / thickness | `Design.depthMm` (frame depth, 70 default, editable in 3D). Everything else in depth is derived from it in `MeshBuilder`: leaf front `-0.08·depth`, leaf depth `0.66·depth`, glass `min(28, 0.4·depth)` (in a leaf `min(26, 0.4·leafDepth)`), panel `min(40, 0.55·depth)`; leaf face width `OpeningLeaf.profileFor` = `max(18, 0.7·profileMm)`. |
| 16 | Hardcoded figures | See §3. |

## 3. Fixed figures in the rendering

These are rules of proportion, each derived from a design figure, not
offsets patching a position — but they are the knobs a visual phase will
reach for, so they are listed:

- **Frame and leaf** — `FrameElement.profileMm` 60, `Design.depthMm` 70,
  `DividerElement.widthMm` 50; leaf profile `0.7 ×` frame profile, at least
  18 mm (`OpeningLeaf`); leaf depth and position as in §2 #15.
- **Glass and panel thickness** — as in §2 #15, centred in the depth.
- **Ironmongery (3D)** — every size is `constant × scale`, where
  `scale = clamp(min(leaf w, h) / 900, 0.55, 1.6)` (`MeshBuilder`, line ~845):
  backplate 235 × 48, rose, neck and lever radii, knuckle 34, etc.
- **Ironmongery (CAD)** — a fraction of the *whole design's* larger side:
  lever `0.07`, handle `0.09`, letterplate `0.22`, others `0.035`, clamped
  24–420 px (`CadPainter._hardware`).
- **Shading baked into facets** — `MeshBuilder._quad(shade:)` darkens the
  facet's own colour: back faces `0.55`/`0.6`, slab sides `0.8`, frame outer
  edge `0.75`, reveal `0.85`, cut ends `0.7`, hardware `0.6–0.8`.
- **Lighting** — one light from `(-0.45, -0.7, 1)`, ambient `0.32`,
  diffuse `0.68` (`Camera.project`).
- **Painter** — glass gradient `#EAF3F8 → #BFD4DE → #E8F1F4` at fixed
  alphas; gloss wash when `gloss > 0.4` and `light > 0.72`, alpha
  `(gloss − 0.4) × 0.3`; opacity floor `0.12`; edges at 0.9 px.
- **Materials** — `MaterialKind.transparency` (clear 0.82, tinted 0.55,
  frosted 0.35, mesh 0.25) and `.gloss` (aluminium 0.55, steel 0.6, uPVC
  0.32, wood 0.18, clear/tinted glass 0.9, frosted 0.4, other 0.2).

## 4. Why it does not look professional yet

1. **Every surface is one flat colour × one number.** A face is filled with
   its finish times a Lambert factor. There is no specular highlight in the
   right place, no metallic response, no roughness, no bevel or edge
   catch-light, no ambient occlusion in corners. Metal, uPVC and panel differ
   only in hue and a faint white wash.
2. **Shading is applied twice.** `MeshBuilder` darkens the colour it stores
   (`shade:`), then the painter multiplies by the light again. The stored
   colour is no longer the user's finish, and the result reads muddy and
   flat at once. Lighting belongs to the renderer alone.
3. **Glass is a translucent box.** Six faces of one slab are each painted
   translucent with the same fixed gradient, so glass stacks into grey,
   shows its own back face, and has no edge tint, reflection or depth cue
   that says *glass*. Frosted and clear differ only in alpha.
4. **Ironmongery size has two sources.** CAD sizes a handle from the whole
   design; 3D from the leaf. The same handle is a different size in the two
   views — the one place CAD and 3D do not share their numbers.
5. **No gaskets, seals or glazing beads exist** — not as geometry, not as a
   `MaterialKind` (there is no rubber/EPDM), not as a `FacetRole`. Nothing can
   look like rubber because nothing is rubber.
6. **The renderer cannot tell parts apart.** `FacetRole` is `frame, bar,
   sash, glazing, panel, hardware`; a hinge, a lever, a lock and a sensor
   are all `hardware`, and the painter has only the facet's colour,
   transparency and gloss.
7. **Appearance is decided in four places.** `MaterialKind` (domain),
   `MeshBuilder._quad`/`_darken` (domain), `Camera.project` light (domain),
   `ModelPainter` gradients and washes (app). There is no single description
   of how a material looks.
8. **CAD is correct but plain.** Glass is a pale fill with a mark, panel a
   translucent colour with hatching, the frame two outlines with hatching.
   Line weights and ink are sound (`Cad`); what is missing is a finished
   drafting look — section shading of the profile, a distinct treatment for
   glass edges, beads and gaskets, and a title block.
9. **Cost.** `ModelView.build` rebuilds the whole mesh on every rebuild,
   including every orbit frame; fine now, a limit once facets multiply.

## 5. Safest places to improve

Improve **appearance** where appearance is decided, and leave geometry where
it is:

- **One appearance description** (domain or app/viewer), keyed on
  `MaterialKind` and `FacetRole`, giving base colour treatment, opacity,
  roughness, metalness and edge treatment — read by `ModelPainter` (and by
  `CadPainter` for fills). Replaces the numbers now spread over
  `MaterialKind`, `_darken` and `ModelPainter`.
- **Move shading out of `MeshBuilder`**: facets carry the finish as the
  user set it; `Camera.project` / `ModelPainter` do all the lighting. The
  facet corners do not change, so every geometry test still holds.
- **Richer painting in `ModelPainter`**: per-material fills (a metallic
  gradient along the light, glass tinted at its edges and faint across its
  face, a matt panel), with glass slabs showing their near face only.
- **Finer part identity**: extend `FacetRole` (or add a component tag on
  `Facet`) so hinges, handles, locks and seals can each be painted as what
  they are. Additive — nothing reads the role but the painter and tests.
- **New physical parts (seals, beads) as geometry from existing geometry** —
  a gasket follows the glass's own edge from `OpeningLeaf.fillOf`, never a
  position of its own; built in `MeshBuilder` and drawn by `CadPainter` from
  the same description, so the two views keep one source.
- **One ironmongery size rule** shared by `CadPainter._hardware` and
  `MeshBuilder` (§4.4), derived from the leaf.
- **CAD finish** in `CadPainter` and `cad_style.dart` only.

What must not move: `SketchInterpreter`, `SectionBuilder`, `DesignTree`,
`OpeningLeaf`, `OpeningHardware` positions, `Measurements`, the customer and
design layers. Every visual phase should end with the geometry tests green —
`the_rule_test`, `one_design_two_views_test`, `the_solid_is_the_cad_hierarchy_test`,
`only_the_opening_moves_test` — and a browser check of all three views.

## 6. Since the audit — one geometry source (Phase 2)

`DesignGeometry` (`lib/domain/model/design_geometry.dart`) is now the one
source the three views read: bar bodies, pane fills, leaves (including a
sliding panel's reach to the meeting line) and ironmongery shapes, the last
from `Furniture` (`lib/domain/hardware/furniture.dart`) with the round parts'
rings in `lib/domain/solid/turned.dart`. §4.4 is closed: the drawings draw
ironmongery at the solid's leaf-derived size, as the shapes it is built as.
Top-level bars stop at the frame's inner face on both sheets, as in the
solid. The pinned mesh fingerprints are unchanged. Held by
`test/app/one_geometry_for_every_view_test.dart`.

## 7. Since the audit — a real material system (Phase 3)

`Surface` (`lib/domain/model/surface.dart`) describes every material
physically, and `Shading.of` (`lib/domain/solid/shading.dart`) lights every
face from it. Of §4: **1** closed — faces are lit from roughness, metallic,
reflectivity and transmission rather than colour × one number; **2** closed
— nothing is baked into the stored colour; **3** closed — glass filters,
scatters and reflects, with a green side; **6** eased — every facet carries
its material, and handle and hinge metal are their own; **7** closed — one
description of how a material looks, read by both views. **5** in part:
rubber exists as a material, but nothing is built of it yet. Held by
`test/domain/materials_are_physical_test.dart` and
`test/app/materials_can_be_told_apart_test.dart`; the pinned geometry
fingerprints are unchanged.

## 8. Since the audit — the frame as a physical profile (Phase 4)

The frame and the sash are `FrameProfile` sections swept round their rings
(`lib/domain/model/frame_profile.dart`), shaped by material — sculptured
uPVC, extruded aluminium and steel, moulded timber — from the profile width
and the design's depth only, inside the outline, daylight and depth the
plain ring had. Bars have eased long edges. CAD adds only the sightline, as
a hairline from the same profile. The pinned solid fingerprints moved once,
on purpose; the designs' fingerprints did not. `Camera.project` orders
ironmongery against faces it actually meets on screen, with soft
constraints for planes that only nick a piece. Held by
`test/domain/the_frame_is_a_real_profile_test.dart` and
`test/app/cad_draws_the_frame_as_a_drawing_test.dart`.

## 9. Since the audit — glass (Phase 5)

Panes are shaded point by point across their faces (`ModelPainter._pane`,
`drawVertices` over a 10 × 10 grid) along the eye's own ray to each point,
in a studio environment — a sky with a horizon, a sky brighter than what it
lights, and strip lights either side of the camera — so a sheen lies across
the glass where it truly falls and moves with the view. The glass filters
what is behind it, frosting scatters, reflection is added; the thin side is
green. CAD: tinted glass shaded, frosted stippled, lines unchanged. Glass
choices never change geometry. Held by
`test/app/glass_looks_like_glass_test.dart`.

## 10. Since the audit — panels (Phase 6)

A panel is a slab with eased edges: its front and back are its fill inset by
`panelArrisOf` (never more than 2 mm, never more than a small share of its
thickness), with an arris and a side round every edge, all inside the fill
and the thickness. Each face records how high what surrounds it stands
proud of it (`Facet.recesses`, from the sash's or frame's front); the
painter shades such a face on a grid dense at its edges
(`ModelPainter._recessed`), darkening it by the light the step shuts out
and, on the side the key light comes from, by the shadow the step casts
(`recess` and the `occlusion`/`shadowed` terms of `Shading.of`). The colour
on every facet is the user's exactly; nothing is textured. CAD unchanged.
Colour changes never change geometry; the door's pinned solid fingerprints
moved once, on purpose, for the arris. Held by
`test/app/panels_look_like_panels_test.dart`.

## 11. Since the audit — ironmongery (Phase 7)

Round parts carry the way their surface faces at every corner
(`Facet.normals`, turned by `Camera.project` into `cornerNormals`), and
`ModelPainter._smooth` lights each facet point by point from them, so a
lever is round to the light and a highlight runs along it. Metals mirror
the studio in their own colour — the sky at its own brightness, the strip
lights blurred by roughness, a dimmer studio on the camera's side — and a
metal's colour is what it reflects rather than a colour under a
reflection. The lever is one bent tube closed in a dome; the rose, boss and
knuckle are turned; plates are pressed with a rounded rim (`_plate`); a
hinge's leaf lies on its face. `tubeRings` now carries each ring's turn on
from the last, which removed a twist at every bend. Every piece records the
face it is fixed to (`Facet.mountAt`/`mountNormal`); the camera casts its
shadow along the key light onto that face and the painter lays it down
softened by distance, clipped to what can take a shadow — never glass.
Pieces are painted plate first, then what stands on it. CAD fills a
keyhole solid (`Furniture.bores`). Only ironmongery moved; the pinned
solids moved on purpose. Held by `test/app/ironmongery_is_metal_test.dart`.

## 12. Since the audit — consistent depth (Phase 8)

The solid is built in one coordinate system — X across and Y down the
elevation, exactly the drawing's own, and Z out of the face the drawing is
of, the frame's face at Z = 0 and the design running back to Z = -depth —
and `DepthLayout` (`lib/domain/solid/depth_layout.dart`) is the one
description of where along Z each part stands, every figure a share of what
holds it: the frame, the design's bars, a leaf in whatever holds it, the
bars and panes inside a leaf in that leaf, glass and panels centred in their
holder, a glazing bead on the room side, the faces ironmongery is fixed to,
and a sliding panel's track. MeshBuilder passes a band down the tree rather
than a frame depth, which fixed a glazing bar standing proud of its sash and
the panes of a divided sash sitting off its middle, and replaced the sliding
tracks' borrowed depth. Glass is a sealed unit — two 4 mm sheets, a cavity,
an edge seal — whose four faces share what the glass lets through and
reflects (`Facet.glassFaces`), so it is the same glass as a sheet. A glazing
bead (`FrameProfile.bead`, `FacetRole.bead`) holds each unit from the room;
the elevation draws its line where that face is the one drawn
(`DesignGeometry.beadLineOf`). Depth never moves a point on the face. Held by
`test/domain/depth_is_consistent_test.dart`.

## 13. Since the audit — the camera (Phase 9)

`Camera.presentation` is the first view and the one Reset returns to: turned
28°, 10° above, through a long lens (five model sizes away) so a door does
not lean. `Camera.framing` fits the model to the viewport's own shape,
centred between the controls over the top and the foot of the view, changing
only the target and the zoom; the model view does it when it opens, when it
is resized and when the design's size changes, and never over a view the
user set (`WorkspaceState.framedFor`). Pan follows the pointer at every zoom
(it had been converted without the zoom), with two fingers, Shift or the
middle button; the wheel zooms towards the pointer (`Camera.zoomedToward`);
Fit and Reset sit with zoom in and out along the foot; Perspective |
Orthographic is named and always shown. The camera is the workspace's and
never the design's. Held by `test/app/the_camera_test.dart`.

## 14. Since the audit — the studio lights (Phase 10)

`Environment` is a product studio lit to be read: a soft key light over the
left shoulder lighting only what faces it (it had lit both sides alike, which
flattened every reveal), a weaker fill from the other side and below, light
from all round a little stronger from above, and two pairs of soft strip
lights seen only in reflections — the nearer placed for the presentation
view, the further so the sheen stays as the model turns — with a narrow core
and long soft edges so a pane shows a gradient and never burns out.
`Environment.lightOn` is the one answer for how much light reaches a face;
the key light's size (`keySize`) bounds how tight a highlight can be and how
sharp a cast shadow is. All white; a white face square on is exposed as
before. Held by `test/app/the_studio_lights_test.dart`.

## 15. Since the audit — the studio and the floor (Phase 11)

`Studio` is what the model is shown in and is neutral throughout; the
application's palette no longer supplies the backdrop, ground line, model
edge or clay. `Floor` stands at the model's foot with a ten-centimetre grid
laid from the model's own side and face, and a shadow worked out by rays
against the model's opaque members — the room's light from above and the key
light's, glass letting it through — lit by `Environment.lightOn`. Two faults
the new floor exposed were fixed at their source: the pitch was applied the
wrong way round (the first view was from below the floor), and glass could
be painted over the stile in front of it (`ProjectedFacet.hiders`). Held by
`test/app/the_studio_test.dart`.

## 16. Since the audit — the drawing's own language (Phase 12)

`cad_style.dart` gives the elevation a draughtsman's weight scale (2.4, 1.4,
1.0, 0.7, 0.6, 0.4 px), graphite inks and one slate annotation ink, and
`Cad.write` letters with tabular figures and a paper mask instead of boxes.
Chain figures stand just off their lines at `CadDimensions.figureAt`, which
the tap targets share; dimension lines run past their witness lines and end
in a heavier 45° slash; the opening mark is a drafting tag. No geometry and
no figure changed. Held by `test/app/the_cad_is_a_drawing_test.dart`.

## 17. Since the audit — materials on the drawing (Phase 13)

Structure (frame, sashes, bars) is one flat light grey band; glass the
sheet's pale tint with its corner strokes, stippled when frosted and shaded
when tinted; a panel fine hatching on the paper. The panel's colour is
named (`PANEL · BROWN`) and no longer flooded: `CadIndication` lost
`ownColour` and `tint`. Rings are drawn as one even-odd path and the 3D
glass clip as one even-odd clip per face in front, because the web's
renderer did not take a path difference as the others do. Held by
`test/app/materials_on_the_drawing_test.dart`.

## 18. Since the audit — the dimensions (Phase 14)

`DimensionChains` now places each kind of figure on its side — divisions
and overall along the foot and down the left, divisions inside parts and
openings along the head and down the right — each read off a section that
is there, and each measurement once. `DimensionLayout` is the one placement
the painter and the tap targets share: most wanted rows first, nothing
overlapping or on the drawing, figures past or staggered off runs too
short for them, and a row left off at a zoom where it cannot be legible.
Every figure on the drawing is written to the millimetre. Held by
`test/app/the_dimensions_test.dart`.

## 19. Since the audit — openings and sections in the solid (Phase 15)

The hierarchy — frame, openings, the panes and dividers inside each — was
already the solid's by `DesignTree`, and is now held on complex designs: a
door and two windows each divided glass over panel, independent in the
model and in motion, each divider inside its own leaf, and one pane's
material changing that pane alone. The floor's shadow blocks each member
square to itself (`Block.axes`), so a leaf standing open shades the floor
under it and not the whole box its swing spans. Held by
`test/app/openings_and_sections_in_3d_test.dart`.

## 20. Since the audit — one design in every view (Phase 16)

The three views are now measured against each other on complex designs:
width, height, each opening, each divider, glass or panel, and every piece
of ironmongery, the solid by its facets and each drawing by its pixels.
Three gaps were closed: `ModelPainter.shouldRepaint` compares the picture
face by face instead of the first face, so a change of material or of
ironmongery repaints the model; the solid builds a section's bars whether
or not they divide it; and the drawing's frame is an even-odd ring, since
the web filled a path difference over every pane. Held by
`test/app/cad_and_3d_are_one_design_test.dart`.

## 21. Since the audit — live updates (Phase 17)

Every view is built from the one design, so every edit reaches all three at
once. Around that: a pane split by a line keeps its finish in both halves
(`SectionBuilder._carryIdentityForward`); a way of looking at the model is
not work (`WorkspaceState.work`, `WidgetRef.watchWork`), so turning the
model or playing its swing rebuilds only the model view; `ModelView` keeps
the solid and its floor while the design and the swing are the same; and a
frame of the model records in about a third of the time — curved facets
shaded as finely as they are large on the screen, and the ironmongery's
shadows masked rather than clipped by path booleans. Held by
`test/app/live_updates_test.dart`.

## 22. Since the audit — view modes (Phase 18)

The 3D view's display styles became four view modes, all painting the same
projected faces (`ViewMode`, `ModelPainter`): **Technical** — a hidden-line
drawing on the technical drawing's paper and inks, edges only where the
form turns, ranked by part (`penOf`), with the overall width, height and
depth written on it from the design's own figures (`overallSizesOn`);
**Shaded** — one colour, lit, edged; **Material** — every material as it
is made, edged, no cast shadows; **Realistic** — materials, the
ironmongery's shadows and the floor's, no lines, and the default. The
wireframe stays under More. The selector (`ViewModeSwitch`) sits in the
band along the top of the view the model is framed clear of, spread or
collapsed to a list by measured width; a tap on the chosen option no
longer falls through to the model. Held by `test/app/view_modes_test.dart`.

## 23. Since the audit — the polish (Phase 19)

One set of view controls (`ViewControls`) in the same corner of the drawing,
the technical drawing and the model, laid over each view rather than inside
its pointer handling — on the technical drawing a press on zoom had put down
the picked part. The technical drawing's room for its figures is worked out
inside the layout, so its first refit no longer waits for, and undoes, the
user's first zoom; the drawing and the technical drawing refit when their
room changes unless moved. The model outlines a pick along its outside and
silhouette only, untinted (`ModelPainter._outsideOf`), and the technical
mode's outline pen follows the same silhouette. The materials were measured
on one window of every kind and left as they were. Held by
`test/app/materials_read_as_materials_test.dart` and
`test/app/controls_and_selection_test.dart`.

## 24. Since the audit — the final quality assurance (Phase 20)

One complex design drawn stroke by stroke — clear and tinted glass, panels,
a divider in each of two openings, a door's lever and lock, a window's
espagnolette, hinges, an aluminium frame with uPVC mullions and a drawn
dimension — measured against every claim of the CAD and 3D work, beside a
material board of glass, panel, frame, metal and rubber in one shape, the
first four in one colour, told apart by what each does with the light.
The one fault it found: a flat face of metal was lit once, as a flat colour;
it is now shaded point by point as glass is (`ModelPainter._mirrors`).
Held by `test/final_cad_and_3d_quality_test.dart`.

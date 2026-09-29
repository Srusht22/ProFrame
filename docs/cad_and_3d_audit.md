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

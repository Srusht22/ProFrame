import 'elements.dart';
import 'materials.dart';

// What a part is made of, as a physical material — how it behaves in light —
// kept apart from what shape it is and from the colour the user chose.
//
//     Finish (the user's colour + MaterialKind)  →  Surface  →  3D shading
//                                                            →  CAD indication
//
// A Surface never touches geometry. It is read only by the renderers, after
// every corner of the solid and every line of the drawing has been placed,
// so choosing a different glass or recolouring a panel cannot move anything.

/// The kinds of material a viewer tells apart without being told: glass
/// from panel from frame from metal from rubber.
enum MaterialClass {
  glass('Glass'),
  panel('Panel'),
  pvc('PVC'),
  aluminium('Aluminium'),
  wood('Wood'),
  rubber('Rubber gasket'),
  metal('Metal'),
  handleMetal('Handle metal'),
  hingeMetal('Hinge metal'),
  mesh('Mesh');

  const MaterialClass(this.label);
  final String label;
}

/// A surface's texture, where the material has one. The renderer reads it;
/// a surface with [none] is uniform.
enum SurfaceTexture {
  none,

  /// Light passing through is diffused: frosted or obscured glass.
  frosted,

  /// Fine parallel lines along the piece: brushed or satin metal.
  brushed,

  /// Wood's grain.
  grain,

  /// An open weave: insect mesh.
  woven,
}

/// How an elevation indicates a material — the drafting conventions, not a
/// picture of it.
enum CadHatch {
  /// Nothing drawn inside.
  none,

  /// The two short strokes across a corner that mean glass.
  glazing,

  /// Forty-five degree hatching: anything solid.
  diagonal,

  /// Filled solid: a gasket, too thin to hatch.
  solid,
}

/// How a material is shown on the technical drawing.
class CadIndication {
  final CadHatch hatch;

  /// Whether the part is tinted with its own colour on the sheet — a panel
  /// in the colour it is ordered in — or with the sheet's glass tint.
  final bool ownColour;

  /// How strongly that tint is laid on, 0 to 1.
  final double tint;

  /// For glass shown in the sheet's glass tint: how much of its own colour
  /// that tint takes, 0 to 1 — a controlled shade, so tinted glass reads
  /// darker than clear on the drawing without hiding the lines over it.
  final double shade;

  /// Whether it is stippled: the fine dots a drawing marks obscured —
  /// frosted — glass with, over the glazing mark.
  final bool stipple;

  const CadIndication({
    required this.hatch,
    this.ownColour = true,
    this.tint = 0.32,
    this.shade = 0,
    this.stipple = false,
  });
}

/// How the edges of a material read: the arris where two faces meet, and
/// the thin side of a sheet.
class EdgeLook {
  /// How dark an edge line is drawn against the material's own colour,
  /// 0 not at all to 1 black. A crisp extrusion has a hard dark edge; glass
  /// has almost none, because it is seen through.
  final double darkness;

  /// The colour the thin side of a sheet takes, 0xAARRGGBB, or null to use
  /// the material's own. Float glass seen edge on is green: the iron in it.
  final int? sideTint;

  const EdgeLook({required this.darkness, this.sideTint});
}

/// One material, physically: how it looks in light, whatever its colour.
///
/// Every figure is 0 to 1 and describes the stuff itself. The colour is not
/// here: it is the user's, on the part's [Finish], and a material is shown
/// in whatever colour the part was given.
class Surface {
  /// Stable name, for anything that needs to refer to it.
  final String id;

  final MaterialClass kind;

  /// How much light passes through the material, taking its colour: 0 for
  /// anything solid. Glass is mostly this.
  final double transmission;

  /// How much of what passes is scattered on the way, 0 a clear view to 1
  /// milky: frosting.
  final double scatter;

  /// How rough the surface is, 0 polished to 1 chalky. Rough surfaces
  /// spread a highlight out and blur what they reflect.
  final double roughness;

  /// 0 for a dielectric — plastic, paint, glass, rubber — which reflects in
  /// white; 1 for a metal, which reflects in its own colour and has little
  /// diffuse colour at all.
  final double metallic;

  /// How much a surface reflects when looked at square on. Everything
  /// reflects more at a glancing angle (Fresnel); this is where it starts.
  final double reflectivity;

  final EdgeLook edge;

  final SurfaceTexture texture;

  final CadIndication cad;

  const Surface({
    required this.id,
    required this.kind,
    this.transmission = 0,
    this.scatter = 0,
    required this.roughness,
    this.metallic = 0,
    required this.reflectivity,
    required this.edge,
    this.texture = SurfaceTexture.none,
    required this.cad,
  });

  /// How much light the material stops, 0 to 1: the complement of what it
  /// lets through.
  double get opacity => 1 - transmission;

  bool get isTransparent => transmission > 0;

  @override
  String toString() => 'Surface($id)';
}

/// The materials the application knows, and which one each part is.
///
/// **Adding a material is adding one here.** The renderers ask a surface for
/// its properties and never for its name, so a new material — laminated
/// glass, a painted steel sheet — is a new constant and an entry in [all],
/// and is drawn and built correctly without either view learning of it.
abstract final class Surfaces {
  static const _solid = CadIndication(hatch: CadHatch.diagonal);

  /// Float glass. Mostly what it lets through and what it reflects, and
  /// green along its edge.
  static const clearGlass = Surface(
    id: 'glass.clear',
    kind: MaterialClass.glass,
    transmission: 0.82,
    roughness: 0.02,
    reflectivity: 0.06,
    edge: EdgeLook(darkness: 0.15, sideTint: 0xFF7FA79A),
    cad: CadIndication(hatch: CadHatch.glazing, ownColour: false),
  );

  /// Body-tinted glass: less through, the tint deeper.
  static const tintedGlass = Surface(
    id: 'glass.tinted',
    kind: MaterialClass.glass,
    transmission: 0.55,
    roughness: 0.02,
    reflectivity: 0.07,
    edge: EdgeLook(darkness: 0.2, sideTint: 0xFF566E66),
    cad: CadIndication(
      hatch: CadHatch.glazing,
      ownColour: false,
      shade: 0.3,
    ),
  );

  /// Acid-etched or sandblasted glass: light comes through, a view does
  /// not, and the surface is satin rather than mirror.
  static const frostedGlass = Surface(
    id: 'glass.frosted',
    kind: MaterialClass.glass,
    transmission: 0.35,
    scatter: 0.85,
    roughness: 0.45,
    reflectivity: 0.05,
    edge: EdgeLook(darkness: 0.15, sideTint: 0xFF9DB8AE),
    texture: SurfaceTexture.frosted,
    cad: CadIndication(
      hatch: CadHatch.glazing,
      ownColour: false,
      stipple: true,
    ),
  );

  /// An infill panel: opaque, matte, painted or foiled.
  static const panel = Surface(
    id: 'panel',
    kind: MaterialClass.panel,
    roughness: 0.72,
    reflectivity: 0.035,
    edge: EdgeLook(darkness: 0.35),
    cad: _solid,
  );

  /// uPVC profile: opaque, a soft satin sheen, rounded arrises.
  static const pvc = Surface(
    id: 'pvc',
    kind: MaterialClass.pvc,
    roughness: 0.42,
    reflectivity: 0.045,
    edge: EdgeLook(darkness: 0.3),
    cad: _solid,
  );

  /// Powder-coated or anodised aluminium profile: crisper, with a metallic
  /// part to its sheen.
  static const aluminium = Surface(
    id: 'aluminium',
    kind: MaterialClass.aluminium,
    roughness: 0.34,
    metallic: 0.45,
    reflectivity: 0.12,
    edge: EdgeLook(darkness: 0.5),
    cad: _solid,
  );

  static const wood = Surface(
    id: 'wood',
    kind: MaterialClass.wood,
    roughness: 0.66,
    reflectivity: 0.035,
    edge: EdgeLook(darkness: 0.4),
    texture: SurfaceTexture.grain,
    cad: _solid,
  );

  /// EPDM gasket rubber: dark, rough, reflecting almost nothing.
  static const rubber = Surface(
    id: 'rubber',
    kind: MaterialClass.rubber,
    roughness: 0.92,
    reflectivity: 0.02,
    edge: EdgeLook(darkness: 0.2),
    cad: CadIndication(hatch: CadHatch.solid),
  );

  /// Plain sheet steel: a metal, not polished.
  static const metal = Surface(
    id: 'metal',
    kind: MaterialClass.metal,
    roughness: 0.38,
    metallic: 1,
    reflectivity: 0.55,
    edge: EdgeLook(darkness: 0.55),
    texture: SurfaceTexture.brushed,
    cad: _solid,
  );

  /// What handles are cast and plated in: a metal finished to be held, the
  /// smoothest surface on the door.
  static const handleMetal = Surface(
    id: 'metal.handle',
    kind: MaterialClass.handleMetal,
    roughness: 0.18,
    metallic: 1,
    reflectivity: 0.7,
    edge: EdgeLook(darkness: 0.45),
    cad: _solid,
  );

  /// What hinges are pressed from: plated steel, satin rather than
  /// polished.
  static const hingeMetal = Surface(
    id: 'metal.hinge',
    kind: MaterialClass.hingeMetal,
    roughness: 0.4,
    metallic: 1,
    reflectivity: 0.5,
    edge: EdgeLook(darkness: 0.55),
    texture: SurfaceTexture.brushed,
    cad: _solid,
  );

  /// Insect mesh: a woven screen, mostly open.
  static const mesh = Surface(
    id: 'mesh',
    kind: MaterialClass.mesh,
    transmission: 0.25,
    roughness: 0.8,
    reflectivity: 0.03,
    edge: EdgeLook(darkness: 0.3),
    texture: SurfaceTexture.woven,
    cad: _solid,
  );

  static const all = <Surface>[
    clearGlass,
    tintedGlass,
    frostedGlass,
    panel,
    pvc,
    aluminium,
    wood,
    rubber,
    metal,
    handleMetal,
    hingeMetal,
    mesh,
  ];

  /// The surface a part with [material] is.
  static Surface of(MaterialKind material) => switch (material) {
    MaterialKind.clearGlass => clearGlass,
    MaterialKind.tintedGlass => tintedGlass,
    MaterialKind.frostedGlass => frostedGlass,
    MaterialKind.panel => panel,
    MaterialKind.upvc => pvc,
    MaterialKind.aluminium => aluminium,
    MaterialKind.wood => wood,
    MaterialKind.steel => metal,
    MaterialKind.rubber => rubber,
    MaterialKind.louvre => panel,
    MaterialKind.mesh => mesh,
  };

  /// The surface a piece of ironmongery of [kind] is, in [material].
  ///
  /// A metal piece is the metal that piece is made of — a handle is cast
  /// and plated to be held, a hinge pressed from satin steel — whichever
  /// metal the user picked; a piece they say is plastic or wood is that.
  static Surface ofHardware(HardwareKind kind, MaterialKind material) {
    final metallic =
        material == MaterialKind.aluminium || material == MaterialKind.steel;
    if (!metallic) return of(material);
    if (kind == HardwareKind.hinge) return hingeMetal;
    if (kind.isHandle ||
        kind == HardwareKind.lock ||
        kind == HardwareKind.letterplate) {
      return handleMetal;
    }
    return of(material);
  }
}

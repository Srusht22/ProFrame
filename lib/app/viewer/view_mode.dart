/// How the model is shown: the four ways a professional looks at a design,
/// and the wireframe under **More**.
///
/// **The same geometry every time.** A mode is a way of looking, like the
/// camera: it chooses how the faces the solid built are painted and nothing
/// else. It is never written into the design, saved with it or undone with
/// it, and the solid is built from the design alone — so every mode shows
/// the same faces at the same places, and changing mode changes no figure,
/// no line and no part.
enum ViewMode {
  /// A drawing of the solid: the faces the sheet's own paper, glass its
  /// tint and the frame its structural tone, every edge where the form
  /// turns drawn in the technical drawing's graphite — the outline heaviest
  /// — and the overall width, height and depth written on it.
  technical('Technical', 'A line drawing with the overall sizes.'),

  /// Faces in one colour, lit, with their edges: the form and its depth,
  /// without the finishes or the studio's shadows getting in the way.
  shaded('Shaded', 'One colour, lit, so the form reads on its own.'),

  /// Every part in what it is made of — glass seen through with its sheen,
  /// the panel matte, the frame its profile, the metal bright — with its
  /// edges drawn, and no shadow cast over any of it, so each material is
  /// seen as itself.
  material('Material', 'Glass, panel, frame and metal as they are made.'),

  /// The most realistic the renderer goes: the materials, the cast shadows
  /// of the ironmongery, the floor's shadow, and no drawn lines.
  realistic('Realistic', 'Materials, light and shadow, as it will look.'),

  /// Edges only, and every edge, including the ones behind. Good for
  /// checking that a bar really does run all the way through.
  wireframe('Wireframe', 'Every edge, including the ones behind.');

  const ViewMode(this.label, this.hint);
  final String label;
  final String hint;

  /// The four always on the view; [wireframe] joins them under **More**.
  static const shown = [technical, shaded, material, realistic];

  bool get drawsFaces => this != wireframe;

  /// Whether each face's own edges are drawn over it, as the mesh has them.
  /// [technical] draws its own edges — only where the form turns.
  bool get drawsEdges => this == shaded || this == material;

  /// Whether the design's finishes and materials are shown.
  bool get usesFinishes => this == material || this == realistic;

  /// Whether the ironmongery casts its shadow and the model its shadow on
  /// the floor.
  bool get castsShadows => this == realistic;

  /// Whether the model stands on the studio's floor. A drawing does not.
  bool get drawsFloor => this != technical;

  bool get isTechnical => this == technical;
}

/// How the model is drawn.
///
/// The same geometry every time. These change nothing about the model — they
/// change how much of it you are being shown at once.
enum DisplayStyle {
  /// Faces lit, no lines. What the thing looks like.
  shaded('Shaded', 'Surfaces only.'),

  /// Faces lit with every edge drawn over them. The usual way to work,
  /// because it shows the surfaces and the construction at the same time.
  shadedWithEdges('Shaded + edges', 'Surfaces with every edge drawn.'),

  /// Edges only, and every edge, including the ones behind. Good for
  /// checking that a bar really does run all the way through.
  wireframe('Wireframe', 'Every edge, including the ones behind.'),

  /// Faces in one colour, lit. Shows the form without the finishes getting
  /// in the way.
  monochrome('Monochrome', 'One colour, so the shape reads on its own.');

  const DisplayStyle(this.label, this.hint);
  final String label;
  final String hint;

  bool get drawsFaces => this != wireframe;
  bool get drawsEdges => this != shaded;
  bool get usesFinishes => this != monochrome;
}

import 'point3.dart';

/// What a face is, so the renderer knows how to shade it without knowing
/// anything about doors and windows.
///
/// The scene is deliberately this abstract: a replacement renderer — a real 3D
/// engine — consumes the same roles and makes its own decisions about
/// materials and lighting (spec Phase 3, item 1).
enum PartRole {
  /// The outer frame.
  frame,

  /// A mullion or transom.
  divider,

  /// The moving part of an opening panel.
  sash,

  /// Glazing.
  glass,

  /// A solid infill board.
  panel,

  /// An insect screen over the glass (توري).
  mesh,

  /// An opening symbol drawn on the glass.
  openingGlyph,

  /// The marker showing a panel carries a note.
  noteMarker,
}

/// Which surface of a box a face belongs to. The renderer uses this to shade
/// the depth faces differently from the front, which is what makes the
/// drawing read as solid.
enum FaceKind {
  /// The face towards the viewer.
  front,

  /// A face running back into the wall along the top or bottom.
  horizontalSide,

  /// A face running back into the wall along the left or right.
  verticalSide,
}

/// One flat face, as a closed polygon in model space.
class SceneFace {
  final PartRole role;
  final FaceKind kind;

  /// The corners, in order. Three or more.
  final List<Point3> corners;

  /// Which panel this belongs to, where it belongs to one. Lets the renderer
  /// hit-test a tap back to a panel without a second geometry pass.
  final String? panelId;

  /// Painter's-algorithm key: larger is drawn later, so nearer.
  ///
  /// Computed by the builder rather than the renderer, because the builder is
  /// the only thing that knows a sash swung towards the viewer should cover
  /// the frame it sits in.
  final double sortDepth;

  const SceneFace({
    required this.role,
    required this.kind,
    required this.corners,
    required this.sortDepth,
    this.panelId,
  });

  @override
  String toString() => 'SceneFace(${role.name}/${kind.name}, '
      '${corners.length} corners, panel=$panelId)';
}

/// A line drawn on top of the faces — an opening symbol, a mesh hatch.
class SceneLine {
  final PartRole role;
  final Point3 from;
  final Point3 to;

  /// Drawn as a dashed line. The standard fenestration opening glyph is
  /// dashed, which is how it stays distinguishable from a real bar.
  final bool dashed;

  final String? panelId;
  final double sortDepth;

  const SceneLine({
    required this.role,
    required this.from,
    required this.to,
    required this.sortDepth,
    this.dashed = false,
    this.panelId,
  });
}

/// Everything to draw, already ordered back to front.
///
/// Pure data with no Flutter in it, so the geometry can be asserted in plain
/// unit tests and a different renderer can consume it unchanged.
class RenderScene {
  final List<SceneFace> faces;
  final List<SceneLine> lines;

  /// Every corner in the scene, for fitting it into a viewport.
  final List<Point3> extent;

  const RenderScene({
    required this.faces,
    required this.lines,
    required this.extent,
  });

  static const RenderScene empty =
      RenderScene(faces: [], lines: [], extent: []);

  bool get isEmpty => faces.isEmpty && lines.isEmpty;

  /// The faces belonging to [panelId], nearest first — the order a hit test
  /// wants.
  List<SceneFace> facesOf(String panelId) =>
      faces.where((face) => face.panelId == panelId).toList().reversed.toList();
}

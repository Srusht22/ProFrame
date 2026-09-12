import 'dart:math' as math;

import '../design_document.dart';
import '../panel.dart';
import '../product/infill.dart';
import '../product/opening.dart';
import '../product/profile_system.dart';
import 'point3.dart';
import 'scene.dart';

/// How far open each panel is, 0 closed to 1 fully open.
typedef OpenFractions = Map<String, double>;

/// Turns a design into a scene of flat faces.
///
/// **It reads the [DesignDocument] and nothing else** — never the strokes,
/// never the canvas (spec Phase 3, item 1). Every edit to the document
/// produces a different scene, which is what keeps the drawing, the viewer and
/// the price from ever disagreeing.
///
/// Pure Dart with no Flutter, so every position below is asserted in ordinary
/// unit tests rather than by looking at a picture.
abstract final class SceneBuilder {
  /// How far a sash swings when fully open, in degrees. Short of 90 so the
  /// leaf stays foreshortened and the viewer can still read the opening it
  /// came out of.
  static const double maxSwingDegrees = 55;

  /// How far a bottom-hung sash tilts when fully open.
  static const double maxTiltDegrees = 14;

  /// How far a sliding sash travels, as a fraction of its own width.
  static const double maxSlideFraction = 0.92;

  /// Builds the scene for [design].
  ///
  /// [openFractions] animates panels; anything absent is closed. [profile]
  /// supplies the real face widths and depths chosen in Phase 1, which is what
  /// makes a PVC frame read thicker than an aluminium one.
  static RenderScene build(
    DesignDocument design, {
    OpenFractions openFractions = const {},
    ProfileSystem? profile,
  }) {
    final outline = design.outline;
    if (outline == null) return RenderScene.empty;

    final system = profile ?? GenericProfiles.defaultFor(design.material);
    final faces = <SceneFace>[];
    final lines = <SceneLine>[];
    final extent = <Point3>[];

    final frameDepth = system.frameDepthMm;
    final frameFace = system.frameFaceMm;

    // -- the outer frame, as four members with real depth ------------------
    final left = outline.left;
    final top = outline.top;
    final right = outline.right;
    final bottom = outline.bottom;

    void addBox({
      required PartRole role,
      required double x0,
      required double y0,
      required double x1,
      required double y1,
      required double z0,
      required double z1,
      String? panelId,
      double sortBias = 0,
    }) {
      // Front face.
      faces.add(SceneFace(
        role: role,
        kind: FaceKind.front,
        corners: [
          Point3(x0, y0, z0),
          Point3(x1, y0, z0),
          Point3(x1, y1, z0),
          Point3(x0, y1, z0),
        ],
        sortDepth: -z0 + sortBias,
        panelId: panelId,
      ));
      // The two depth faces that can be seen: depth recedes up and to the
      // right, so the right-hand and top faces are the visible ones.
      faces.add(SceneFace(
        role: role,
        kind: FaceKind.verticalSide,
        corners: [
          Point3(x1, y0, z0),
          Point3(x1, y0, z1),
          Point3(x1, y1, z1),
          Point3(x1, y1, z0),
        ],
        sortDepth: -z0 + sortBias - 0.01,
        panelId: panelId,
      ));
      faces.add(SceneFace(
        role: role,
        kind: FaceKind.horizontalSide,
        corners: [
          Point3(x0, y0, z0),
          Point3(x1, y0, z0),
          Point3(x1, y0, z1),
          Point3(x0, y0, z1),
        ],
        sortDepth: -z0 + sortBias - 0.02,
        panelId: panelId,
      ));
      extent.addAll([
        Point3(x0, y0, z0),
        Point3(x1, y1, z0),
        Point3(x1, y0, z1),
        Point3(x0, y1, z1),
      ]);
    }

    // Frame members: head, sill, two jambs.
    addBox(role: PartRole.frame, x0: left, y0: top, x1: right, y1: top + frameFace, z0: 0, z1: frameDepth);
    addBox(role: PartRole.frame, x0: left, y0: bottom - frameFace, x1: right, y1: bottom, z0: 0, z1: frameDepth);
    addBox(role: PartRole.frame, x0: left, y0: top, x1: left + frameFace, y1: bottom, z0: 0, z1: frameDepth);
    addBox(role: PartRole.frame, x0: right - frameFace, y0: top, x1: right, y1: bottom, z0: 0, z1: frameDepth);

    // -- dividers -----------------------------------------------------------
    final half = system.dividerFaceMm / 2;
    for (final divider in design.dividers) {
      if (divider.isVertical) {
        addBox(
          role: PartRole.divider,
          x0: divider.start.x - half,
          y0: math.min(divider.start.y, divider.end.y),
          x1: divider.start.x + half,
          y1: math.max(divider.start.y, divider.end.y),
          z0: 0,
          z1: frameDepth,
        );
      } else {
        addBox(
          role: PartRole.divider,
          x0: math.min(divider.start.x, divider.end.x),
          y0: divider.start.y - half,
          x1: math.max(divider.start.x, divider.end.x),
          y1: divider.start.y + half,
          z0: 0,
          z1: frameDepth,
        );
      }
    }

    // -- panels -------------------------------------------------------------
    for (final panel in design.panels) {
      _addPanel(
        panel: panel,
        design: design,
        system: system,
        openFraction: (openFractions[panel.id] ?? 0).clamp(0.0, 1.0),
        faces: faces,
        lines: lines,
        extent: extent,
      );
    }

    faces.sort((a, b) => a.sortDepth.compareTo(b.sortDepth));
    lines.sort((a, b) => a.sortDepth.compareTo(b.sortDepth));

    return RenderScene(faces: faces, lines: lines, extent: extent);
  }

  static void _addPanel({
    required Panel panel,
    required DesignDocument design,
    required ProfileSystem system,
    required double openFraction,
    required List<SceneFace> faces,
    required List<SceneLine> lines,
    required List<Point3> extent,
  }) {
    final box = panel.boundary;
    // The glass sits inside the profile faces around the opening.
    final inset = system.frameFaceMm / 2;
    final glassLeft = box.left + inset;
    final glassTop = box.top + inset;
    final glassRight = box.right - inset;
    final glassBottom = box.bottom - inset;
    if (glassRight <= glassLeft || glassBottom <= glassTop) return;

    // Glazing sits at the back of the rebate; the sash stands proud of it.
    final glassZ = system.frameDepthMm / 2;
    final sashZ = system.sashDepthMm / 4;

    final corners = _panelCorners(
      panel: panel,
      left: glassLeft,
      top: glassTop,
      right: glassRight,
      bottom: glassBottom,
      baseZ: panel.behaviour.isOpening ? sashZ : glassZ,
      openFraction: openFraction,
      system: system,
    );
    extent.addAll(corners);

    // An empty panel (فارغ) is a hole: no glass, no board, nothing to draw but
    // the opening itself. That is the whole visual difference the user asked
    // for (spec Phase 2, item 5).
    if (!panel.isEmpty) {
      faces.add(SceneFace(
        role: panel.infill is SolidPanel ? PartRole.panel : PartRole.glass,
        kind: FaceKind.front,
        corners: corners,
        // Ahead of the frame it sits in, behind anything swung towards us.
        sortDepth: -corners.first.z + openFraction * 100,
        panelId: panel.id,
      ));
    }

    if (panel.hasMesh && !panel.isEmpty) {
      _addMeshHatch(corners, panel.id, openFraction, lines);
    }

    // A CH panel gets no opening symbol at all (spec Phase 3, item 2).
    final opening = panel.opening;
    if (opening != null) {
      _addOpeningGlyph(corners, opening, panel.id, openFraction, lines);
    }

    if (panel.hasNote) {
      faces.add(SceneFace(
        role: PartRole.noteMarker,
        kind: FaceKind.front,
        corners: _noteMarkerAt(corners),
        sortDepth: -corners.first.z + openFraction * 100 + 1,
        panelId: panel.id,
      ));
    }
  }

  /// The four corners of a panel's face, after its opening motion is applied.
  ///
  /// This is the heart of the animation, and it is plain trigonometry on the
  /// model rather than a canvas transform — so each motion can be asserted in
  /// millimetres by a unit test.
  static List<Point3> _panelCorners({
    required Panel panel,
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double baseZ,
    required double openFraction,
    required ProfileSystem system,
  }) {
    final opening = panel.opening;
    if (opening == null || openFraction <= 0) {
      return [
        Point3(left, top, baseZ),
        Point3(right, top, baseZ),
        Point3(right, bottom, baseZ),
        Point3(left, bottom, baseZ),
      ];
    }

    final width = right - left;
    final height = bottom - top;

    // Inward opening swings towards the room, which is +z and away from the
    // viewer; outward comes towards the viewer, which is -z.
    final towards =
        opening.direction == OpeningDirection.inward ? 1.0 : -1.0;

    switch (opening.mechanism) {
      case OpeningMechanism.hinged:
        final angle = maxSwingDegrees * openFraction * math.pi / 180;
        final reach = width * math.cos(angle);
        final depth = width * math.sin(angle) * towards;
        // The hinged edge stays exactly where it was; the free edge swings.
        if (opening.hingeSide == HingeSide.left) {
          return [
            Point3(left, top, baseZ),
            Point3(left + reach, top, baseZ + depth),
            Point3(left + reach, bottom, baseZ + depth),
            Point3(left, bottom, baseZ),
          ];
        }
        if (opening.hingeSide == HingeSide.right) {
          return [
            Point3(right - reach, top, baseZ + depth),
            Point3(right, top, baseZ),
            Point3(right, bottom, baseZ),
            Point3(right - reach, bottom, baseZ + depth),
          ];
        }
        // Top- or bottom-hung swing: the horizontal edge stays put.
        final vReach = height * math.cos(angle);
        final vDepth = height * math.sin(angle) * towards;
        if (opening.hingeSide == HingeSide.top) {
          return [
            Point3(left, top, baseZ),
            Point3(right, top, baseZ),
            Point3(right, top + vReach, baseZ + vDepth),
            Point3(left, top + vReach, baseZ + vDepth),
          ];
        }
        return [
          Point3(left, bottom - vReach, baseZ + vDepth),
          Point3(right, bottom - vReach, baseZ + vDepth),
          Point3(right, bottom, baseZ),
          Point3(left, bottom, baseZ),
        ];

      case OpeningMechanism.tilt:
        // Bottom-hung: the bottom edge stays, the top tilts inward.
        final angle = maxTiltDegrees * openFraction * math.pi / 180;
        final reach = height * math.cos(angle);
        final depth = height * math.sin(angle);
        return [
          Point3(left, bottom - reach, baseZ + depth),
          Point3(right, bottom - reach, baseZ + depth),
          Point3(right, bottom, baseZ),
          Point3(left, bottom, baseZ),
        ];

      case OpeningMechanism.slidingLeft:
      case OpeningMechanism.slidingRight:
        // The sash keeps its size and slides across its neighbour, standing
        // proud of it in its own track.
        final travel = width *
            maxSlideFraction *
            openFraction *
            (opening.mechanism == OpeningMechanism.slidingLeft ? -1 : 1);
        final z = baseZ - system.sashDepthMm / 3;
        return [
          Point3(left + travel, top, z),
          Point3(right + travel, top, z),
          Point3(right + travel, bottom, z),
          Point3(left + travel, bottom, z),
        ];
    }
  }

  /// The standard fenestration opening symbol: dashed lines running from the
  /// free edge to the hinge edge, so the point of the triangle marks the
  /// hinges.
  ///
  /// Read in the elevation as drawn; the project's viewing side says whether
  /// that elevation is the outside or the inside, and the viewer states which
  /// on screen (spec section 3C).
  static void _addOpeningGlyph(
    List<Point3> corners,
    OpeningSpec opening,
    String panelId,
    double openFraction,
    List<SceneLine> lines,
  ) {
    final sort = -corners.first.z + openFraction * 100 + 0.5;
    void dash(Point3 from, Point3 to) => lines.add(SceneLine(
          role: PartRole.openingGlyph,
          from: from,
          to: to,
          dashed: true,
          panelId: panelId,
          sortDepth: sort,
        ));

    final topLeft = corners[0];
    final topRight = corners[1];
    final bottomRight = corners[2];
    final bottomLeft = corners[3];

    Point3 midOf(Point3 a, Point3 b) => Point3(
          (a.x + b.x) / 2,
          (a.y + b.y) / 2,
          (a.z + b.z) / 2,
        );

    switch (opening.mechanism) {
      case OpeningMechanism.hinged:
        switch (opening.hingeSide) {
          case HingeSide.left:
            final apex = midOf(topLeft, bottomLeft);
            dash(topRight, apex);
            dash(bottomRight, apex);
          case HingeSide.right:
            final apex = midOf(topRight, bottomRight);
            dash(topLeft, apex);
            dash(bottomLeft, apex);
          case HingeSide.top:
            final apex = midOf(topLeft, topRight);
            dash(bottomLeft, apex);
            dash(bottomRight, apex);
          case HingeSide.bottom:
            final apex = midOf(bottomLeft, bottomRight);
            dash(topLeft, apex);
            dash(topRight, apex);
        }
      case OpeningMechanism.tilt:
        // Bottom-hung, so the apex is on the bottom edge.
        final apex = midOf(bottomLeft, bottomRight);
        dash(topLeft, apex);
        dash(topRight, apex);
      case OpeningMechanism.slidingLeft:
      case OpeningMechanism.slidingRight:
        // An arrow along the middle, pointing the way it travels.
        final left = midOf(topLeft, bottomLeft);
        final right = midOf(topRight, bottomRight);
        dash(left, right);
        final towardsLeft =
            opening.mechanism == OpeningMechanism.slidingLeft;
        final tip = towardsLeft ? left : right;
        final back = towardsLeft ? right : left;
        final dx = (back.x - tip.x) * 0.18;
        final dy = (topLeft.y - bottomLeft.y).abs() * 0.12;
        dash(tip, Point3(tip.x + dx, tip.y - dy, tip.z));
        dash(tip, Point3(tip.x + dx, tip.y + dy, tip.z));
    }
  }

  /// A fine grid over the glass, for an insect screen (توري).
  static void _addMeshHatch(
    List<Point3> corners,
    String panelId,
    double openFraction,
    List<SceneLine> lines,
  ) {
    const steps = 7;
    final sort = -corners.first.z + openFraction * 100 + 0.25;
    final topLeft = corners[0];
    final topRight = corners[1];
    final bottomRight = corners[2];
    final bottomLeft = corners[3];

    Point3 lerp(Point3 a, Point3 b, double t) => Point3(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t,
        );

    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      lines.add(SceneLine(
        role: PartRole.mesh,
        from: lerp(topLeft, topRight, t),
        to: lerp(bottomLeft, bottomRight, t),
        panelId: panelId,
        sortDepth: sort,
      ));
      lines.add(SceneLine(
        role: PartRole.mesh,
        from: lerp(topLeft, bottomLeft, t),
        to: lerp(topRight, bottomRight, t),
        panelId: panelId,
        sortDepth: sort,
      ));
    }
  }

  /// A small square in the panel's top-right corner.
  static List<Point3> _noteMarkerAt(List<Point3> corners) {
    final topRight = corners[1];
    final topLeft = corners[0];
    final bottomRight = corners[2];
    final size = math.min(
      (topRight.x - topLeft.x).abs(),
      (bottomRight.y - topRight.y).abs(),
    ) *
        0.16;
    final inset = size * 0.5;
    return [
      Point3(topRight.x - inset - size, topRight.y + inset, topRight.z),
      Point3(topRight.x - inset, topRight.y + inset, topRight.z),
      Point3(topRight.x - inset, topRight.y + inset + size, topRight.z),
      Point3(topRight.x - inset - size, topRight.y + inset + size, topRight.z),
    ];
  }
}

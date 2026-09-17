import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../model/materials.dart';
import '../model/opening_leaf.dart';
import 'mesh.dart';

/// Builds the 3D model out of the design itself.
///
/// Every face here comes from a line the user drew. There is no stock model
/// being stretched to fit and no shape assumed about what a door or a window
/// looks like: the frame follows the outline, the bars follow the bars, the
/// panes fill whatever the bars enclose, and hardware appears only where the
/// user put it. Draw a five-sided window with one diagonal bar and that is
/// exactly what comes out.
abstract final class MeshBuilder {
  /// The model of [design].
  ///
  /// [openFraction] swings any opening leaf, 0 shut and 1 fully open. It is
  /// a way of looking at the model, not a property of the design.
  static Mesh build(Design design, {double openFraction = 0}) {
    final frame = design.frame;
    if (frame == null) return Mesh.empty;

    final depth = design.depthMm;
    final facets = <Facet>[];

    _addFrame(facets, frame, depth);

    // Only the bars that divide the design itself. A bar drawn inside a
    // section is built with that section, so that it swings with the leaf it
    // is part of instead of staying behind on the frame.
    for (final divider in design.topLevelDividers) {
      _addBar(facets, divider, frame, depth);
    }

    // Only the main divisions are built here. What is inside a section is
    // built with it, so that a leaf and everything drawn in it are one thing
    // that swings together.
    for (final section in design.topLevelSections) {
      final opening = design.openingOf(section.id);
      if (opening == null) {
        _addSection(facets, design, section, depth);
      } else {
        _addLeaf(
          facets,
          design,
          section,
          opening,
          frame,
          depth,
          openFraction,
        );
      }
    }

    // Hardware the user placed themselves sits on the design where they put
    // it. An opening's own hinges and handle are built with the leaf, so
    // they swing with it rather than staying behind on the frame.
    for (final piece in design.hardware) {
      if (piece.isOpeningHardware) continue;
      _addHardware(facets, piece, design, depth);
    }

    return Mesh(facets);
  }

  /// The frame: a ring following the outline, through the full depth.
  static void _addFrame(List<Facet> out, FrameElement frame, double depth) {
    final outer = frame.outline;
    final inner = frame.innerOutline;
    if (inner.isEmpty || outer.corners.length != inner.corners.length) {
      // A profile too thick for the opening leaves no daylight. Show it as
      // the solid thing it would be rather than failing quietly.
      _addSlab(out, outer, 0, depth, frame.id, frame.finish, FacetRole.frame);
      return;
    }

    final n = outer.corners.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final o1 = outer.corners[i], o2 = outer.corners[j];
      final i1 = inner.corners[i], i2 = inner.corners[j];

      // The face you see from the front, and its twin at the back.
      _quad(out, [
        _at(o1, 0),
        _at(o2, 0),
        _at(i2, 0),
        _at(i1, 0),
      ], frame.id, frame.finish, FacetRole.frame);
      _quad(out, [
        _at(i1, -depth),
        _at(i2, -depth),
        _at(o2, -depth),
        _at(o1, -depth),
      ], frame.id, frame.finish, FacetRole.frame, shade: 0.55);

      // The outside edge, and the reveal facing into the opening.
      _quad(out, [
        _at(o1, -depth),
        _at(o2, -depth),
        _at(o2, 0),
        _at(o1, 0),
      ], frame.id, frame.finish, FacetRole.frame, shade: 0.75);
      _quad(out, [
        _at(i1, 0),
        _at(i2, 0),
        _at(i2, -depth),
        _at(i1, -depth),
      ], frame.id, frame.finish, FacetRole.frame, shade: 0.85);
    }
  }

  /// A bar, as wide as the user set it and running exactly where they drew
  /// it — including at an angle, if that is how it was drawn.
  static void _addBar(
    List<Facet> out,
    DividerElement divider,
    FrameElement frame,
    double depth,
  ) {
    final run = _clip(divider.segment, frame.innerOutline);
    if (run == null) return;

    final half = divider.widthMm / 2;
    final side = run.unit.perpendicular * half;
    final face = Polygon([
      run.a + side,
      run.b + side,
      run.b - side,
      run.a - side,
    ]);

    // Bars sit a little back from the face of the frame, as they do in the
    // real thing.
    const setback = 0.1;
    _addSlab(
      out,
      face,
      -depth * setback,
      depth * (1 - setback * 2),
      divider.id,
      divider.finish,
      FacetRole.bar,
    );
  }

  /// A section that does not open: either the pane that fills it, or — when
  /// the user drew lines inside it — the bars they drew and the panes those
  /// bars make.
  static void _addSection(
    List<Facet> out,
    Design design,
    SectionElement section,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    final children = design.childSectionsOf(section.id);
    if (children.isEmpty) {
      _addFixedInfill(out, design, section, depth, place: place);
      return;
    }

    // The bars drawn inside it, then whatever they enclose — which may in
    // turn have lines inside it. Each bar stops where the fill of this
    // section stops, so a bar inside a sash runs between the sash's faces
    // rather than across them.
    final bounds = OpeningLeaf.fillOf(design, section);
    for (final bar in design.childDividersOf(section.id)) {
      _addInternalBar(out, bar, bounds, depth, place: place);
    }
    for (final child in children) {
      _addSection(out, design, child, depth, place: place);
    }
  }

  /// A bar the user drew inside a section, trimmed to that section.
  static void _addInternalBar(
    List<Facet> out,
    DividerElement divider,
    Polygon bounds,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    final run = _clip(divider.segment, bounds);
    if (run == null) return;

    final half = divider.widthMm / 2;
    final side = run.unit.perpendicular * half;
    final face = Polygon([
      run.a + side,
      run.b + side,
      run.b - side,
      run.a - side,
    ]);

    const setback = 0.1;
    _slabBetween(
      out,
      face,
      -depth * setback,
      depth * (1 - setback * 2),
      divider.id,
      divider.finish,
      FacetRole.bar,
      place ?? (p) => p,
    );
  }

  /// The pane or panel filling a section that does not open.
  ///
  /// It fills what [OpeningLeaf.fillOf] says it fills — its own region, or,
  /// when it is a pane of a sash the user divided, the part of that region
  /// within the sash. The glass stops at the sash in the solid because it
  /// stops at the sash on the drawing, from the same description.
  static void _addFixedInfill(
    List<Facet> out,
    Design design,
    SectionElement section,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    final fill = OpeningLeaf.fillOf(design, section);
    if (fill.isEmpty) return;
    final thickness = section.finish.material.isGlazing
        ? math.min(28.0, depth * 0.4)
        : math.min(depth * 0.55, 40.0);
    _slabBetween(
      out,
      fill,
      -(depth - thickness) / 2,
      thickness,
      section.id,
      section.finish,
      section.finish.material.isGlazing ? FacetRole.glazing : FacetRole.panel,
      place ?? (p) => p,
    );
  }

  /// A leaf that opens: a sash ring inside the section with its own infill,
  /// swung about the edge the mechanism hinges on.
  static void _addLeaf(
    List<Facet> out,
    Design design,
    SectionElement section,
    OpeningElement opening,
    FrameElement frame,
    double depth,
    double openFraction,
  ) {
    // The same leaf the drawing shows, described in one place so the
    // elevation and the solid cannot disagree about where it is.
    final sashOuter = OpeningLeaf.outerOf(section);
    final sashInner =
        OpeningLeaf.innerOf(section, frame) ?? const Polygon([]);

    final place = _swingFor(opening, section, openFraction);
    Vec3 at(Vec2 point, double z) => place(_at(point, z));
    _addLeafHardware(out, design, section, depth, place);

    final leafFront = -depth * 0.08;
    final leafDepth = depth * 0.66;

    if (!sashInner.isEmpty &&
        sashInner.corners.length == sashOuter.corners.length) {
      final n = sashOuter.corners.length;
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n;
        final o1 = sashOuter.corners[i], o2 = sashOuter.corners[j];
        final i1 = sashInner.corners[i], i2 = sashInner.corners[j];
        _quad(out, [
          at(o1, leafFront),
          at(o2, leafFront),
          at(i2, leafFront),
          at(i1, leafFront),
        ], section.id, frame.finish, FacetRole.sash);
        _quad(out, [
          at(i1, leafFront - leafDepth),
          at(i2, leafFront - leafDepth),
          at(o2, leafFront - leafDepth),
          at(o1, leafFront - leafDepth),
        ], section.id, frame.finish, FacetRole.sash, shade: 0.55);
        _quad(out, [
          at(i1, leafFront),
          at(i2, leafFront),
          at(i2, leafFront - leafDepth),
          at(i1, leafFront - leafDepth),
        ], section.id, frame.finish, FacetRole.sash, shade: 0.85);
        _quad(out, [
          at(o1, leafFront - leafDepth),
          at(o2, leafFront - leafDepth),
          at(o2, leafFront),
          at(o1, leafFront),
        ], section.id, frame.finish, FacetRole.sash, shade: 0.75);
      }
    }

    // What fills the leaf, swinging with it. Where the user drew lines
    // inside the opening, those lines and the panes they make are what fills
    // it — and they swing with it too, because they are part of it.
    final glazed = sashInner.isEmpty ? sashOuter : sashInner;
    final children = design.childSectionsOf(section.id);

    if (children.isEmpty) {
      final thickness = section.finish.material.isGlazing
          ? math.min(26.0, leafDepth * 0.4)
          : math.min(leafDepth * 0.6, 38.0);
      final front = leafFront - (leafDepth - thickness) / 2;
      _slabBetween(
        out,
        glazed,
        front,
        thickness,
        section.id,
        section.finish,
        section.finish.material.isGlazing
            ? FacetRole.glazing
            : FacetRole.panel,
        place,
      );
      return;
    }

    for (final bar in design.childDividersOf(section.id)) {
      _addInternalBar(out, bar, glazed, leafDepth, place: place);
    }
    for (final child in children) {
      _addSection(out, design, child, leafDepth, place: place);
    }
  }

  /// The hinges and handle of a leaf, swinging with it.
  static void _addLeafHardware(
    List<Facet> out,
    Design design,
    SectionElement section,
    double depth,
    Vec3 Function(Vec3) place,
  ) {
    for (final piece in design.hardware) {
      if (piece.parentId != section.id) continue;
      _addHardware(out, piece, design, depth, place: place);
    }
  }

  /// Swings a point about the hinge edge of [opening].
  static Vec3 Function(Vec3) _swingFor(
    OpeningElement opening,
    SectionElement section,
    double openFraction,
  ) {
    final edge = opening.mechanism.hingeEdge;
    if (edge == null || openFraction <= 0) return (p) => p;

    // Ninety degrees is as far as anything swings here; a leaf drawn further
    // than that in a preview reads as broken rather than as open.
    final angle = (openFraction.clamp(0.0, 1.0)) * math.pi / 2;
    final towards =
        opening.direction == OpeningDirection.outward ? -1.0 : 1.0;
    final cos = math.cos(angle);
    final sin = math.sin(angle) * towards;
    final box = section.outline;

    return switch (edge) {
      OpeningEdge.left => (p) {
          final d = p.x - box.left;
          return Vec3(box.left + d * cos, p.y, p.z + d * sin);
        },
      OpeningEdge.right => (p) {
          final d = p.x - box.right;
          return Vec3(box.right + d * cos, p.y, p.z - d * sin);
        },
      OpeningEdge.top => (p) {
          final d = p.y - box.top;
          return Vec3(p.x, box.top + d * cos, p.z + d * sin);
        },
      OpeningEdge.bottom => (p) {
          final d = p.y - box.bottom;
          return Vec3(p.x, box.bottom + d * cos, p.z - d * sin);
        },
    };
  }

  /// A piece of ironmongery, at the point the user put it — or at the point
  /// its opening puts it, carried through the leaf's swing by [place].
  static void _addHardware(
    List<Facet> out,
    HardwareElement piece,
    Design design,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    final scale = math.max(design.widthMm, design.heightMm);
    final length = switch (piece.kind) {
      HardwareKind.lever => scale * 0.07,
      HardwareKind.handle => scale * 0.09,
      HardwareKind.letterplate => scale * 0.22,
      HardwareKind.closer => scale * 0.12,
      _ => scale * 0.035,
    }
        .clamp(24.0, 420.0);
    final width = (length * 0.26).clamp(14.0, 90.0);
    final stand = (depth * 0.5).clamp(12.0, 60.0);

    final along = Vec2(math.cos(piece.rotation * math.pi / 180),
        math.sin(piece.rotation * math.pi / 180));
    final across = along.perpendicular;
    final centre = piece.at;

    final face = Polygon([
      centre + along * (length / 2) + across * (width / 2),
      centre + along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) + across * (width / 2),
    ]);
    _addSlab(out, face, stand, stand, piece.id, piece.finish,
        FacetRole.hardware, place);
  }

  /// A flat shape given thickness: front, back and a side for every edge.
  static void _addSlab(
    List<Facet> out,
    Polygon shape,
    double frontZ,
    double thickness,
    String elementId,
    Finish finish,
    FacetRole role, [
    Vec3 Function(Vec3)? place,
  ]) =>
      _slabBetween(
        out,
        shape,
        frontZ,
        thickness,
        elementId,
        finish,
        role,
        place ?? (p) => p,
      );

  static void _slabBetween(
    List<Facet> out,
    Polygon shape,
    double frontZ,
    double thickness,
    String elementId,
    Finish finish,
    FacetRole role,
    Vec3 Function(Vec3) place,
  ) {
    if (shape.isEmpty) return;
    final backZ = frontZ - thickness;

    _quad(
      out,
      [for (final c in shape.corners) place(_at(c, frontZ))],
      elementId,
      finish,
      role,
    );
    _quad(
      out,
      [for (final c in shape.corners.reversed) place(_at(c, backZ))],
      elementId,
      finish,
      role,
      shade: 0.6,
    );

    final n = shape.corners.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      _quad(out, [
        place(_at(shape.corners[i], backZ)),
        place(_at(shape.corners[j], backZ)),
        place(_at(shape.corners[j], frontZ)),
        place(_at(shape.corners[i], frontZ)),
      ], elementId, finish, role, shade: 0.8);
    }
  }

  static void _quad(
    List<Facet> out,
    List<Vec3> corners,
    String elementId,
    Finish finish,
    FacetRole role, {
    double shade = 1,
  }) {
    if (corners.length < 3) return;
    out.add(Facet(
      corners: corners,
      elementId: elementId,
      colour: shade == 1 ? finish.colour : _darken(finish.colour, shade),
      transparency: finish.material.transparency,
      gloss: finish.material.gloss,
      role: role,
    ));
  }

  static int _darken(int colour, double by) {
    final a = (colour >> 24) & 0xFF;
    final r = ((colour >> 16) & 0xFF) * by;
    final g = ((colour >> 8) & 0xFF) * by;
    final b = (colour & 0xFF) * by;
    return (a << 24) |
        (r.round().clamp(0, 255) << 16) |
        (g.round().clamp(0, 255) << 8) |
        b.round().clamp(0, 255);
  }

  static Vec3 _at(Vec2 point, double z) => Vec3(point.x, point.y, z);

  /// The part of a bar that is actually inside the opening.
  static Segment? _clip(Segment line, Polygon bounds) {
    if (bounds.isEmpty) return line;
    final aIn = bounds.contains(line.a);
    final bIn = bounds.contains(line.b);
    if (aIn && bIn) return line;

    final hits = <double>[];
    for (final edge in bounds.edges) {
      final crossing = line.crossing(edge);
      if (crossing != null) hits.add(crossing.onA);
    }
    if (hits.isEmpty) return aIn || bIn ? line : null;
    hits.sort();

    final from = aIn ? 0.0 : hits.first;
    final to = bIn ? 1.0 : hits.last;
    if (to - from < 1e-6) return null;
    return Segment(line.pointAt(from), line.pointAt(to));
  }
}

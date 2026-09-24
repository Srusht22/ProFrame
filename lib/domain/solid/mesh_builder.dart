import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/design_tree.dart';
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

    // The design's own hierarchy, read once. The elevation walks this same
    // tree, so the two views cannot disagree about what is inside what.
    final tree = DesignTree.of(design);

    _addFrame(facets, frame, depth);

    // Only the bars that divide the design itself. A bar drawn inside a
    // section is built with that section, so that it swings with the leaf it
    // is part of instead of staying behind on the frame.
    for (final id in tree.barIds) {
      final divider = design.dividerById(id);
      if (divider != null) _addBar(facets, divider, frame, depth);
    }

    // Only the main divisions are built here. What is inside a section is
    // built with it, so that a leaf and everything drawn in it are one thing
    // that swings together.
    for (final branch in tree.sections) {
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;
      _addSection(facets, design, branch, section, frame, depth, openFraction);
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

      // A side the user left open has no member to build. The members
      // either side of it stop there, so each is given its cut end — the
      // face that stands on the floor at the foot of a door with no sill.
      if (!frame.hasMember(i)) {
        if (o1.distanceTo(i1) > 0) {
          _quad(out, [
            _at(o1, 0),
            _at(i1, 0),
            _at(i1, -depth),
            _at(o1, -depth),
          ], frame.id, frame.finish, FacetRole.frame, shade: 0.7);
        }
        if (o2.distanceTo(i2) > 0) {
          _quad(out, [
            _at(i2, 0),
            _at(o2, 0),
            _at(o2, -depth),
            _at(i2, -depth),
          ], frame.id, frame.finish, FacetRole.frame, shade: 0.7);
        }
        continue;
      }

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
    TreeSection branch,
    SectionElement section,
    FrameElement frame,
    double depth,
    double openFraction, {
    Vec3 Function(Vec3)? place,
  }) {
    // The one place that decides what a section is built as, at every level
    // of the tree. A section the user marked is a leaf, wherever it sits: a
    // pane of a sash they marked as well is a leaf inside a leaf, and it
    // swings within its parent because [place] is the parent's own movement
    // and this one's is applied inside it. Deciding this here rather than at
    // the top is what stops the model from showing a swing the drawing does
    // not, or missing one it does.
    final opening =
        branch.opens ? design.openingById(branch.openingId!) : null;
    if (opening != null) {
      _addLeaf(
        out,
        design,
        branch,
        section,
        opening,
        frame,
        depth,
        openFraction,
        place: place,
      );
      return;
    }

    if (branch.isLeaf) {
      _addFixedInfill(out, design, section, depth, place: place);
      return;
    }

    // The bars drawn inside it, then whatever they enclose — which may in
    // turn have lines inside it. Each bar stops where the fill of this
    // section stops, so a bar inside a sash runs between the sash's faces
    // rather than across them.
    final bounds = OpeningLeaf.fillOf(design, section);
    _addBarsInside(out, design, branch, bounds, depth, place: place);
    for (final pane in branch.panes) {
      final child = design.sectionById(pane.sectionId);
      if (child != null) {
        _addSection(
          out,
          design,
          pane,
          child,
          frame,
          depth,
          openFraction,
          place: place,
        );
      }
    }
  }

  /// The bars the user drew inside one section, trimmed to what fills it.
  static void _addBarsInside(
    List<Facet> out,
    Design design,
    TreeSection branch,
    Polygon bounds,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    for (final id in branch.barIds) {
      final bar = design.dividerById(id);
      if (bar != null) {
        _addInternalBar(out, bar, bounds, depth, place: place);
      }
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
    TreeSection branch,
    SectionElement section,
    OpeningElement opening,
    FrameElement frame,
    double depth,
    double openFraction, {
    Vec3 Function(Vec3)? place,
  }) {
    // The same leaf the drawing shows, described in one place so the
    // elevation and the solid cannot disagree about where it is.
    final sashOuter = OpeningLeaf.outerOf(section);
    final sashInner =
        OpeningLeaf.innerOf(section, frame) ?? const Polygon([]);

    // Its own swing, then whatever its parent is doing. A leaf inside a leaf
    // swings within the one it hangs in; a leaf hanging in the frame has no
    // parent movement and this is its swing alone.
    final swing = _swingFor(design, opening, section, depth, openFraction);
    final outer = place;
    Vec3 move(Vec3 point) =>
        outer == null ? swing(point) : outer(swing(point));

    Vec3 at(Vec2 point, double z) => move(_at(point, z));
    _addLeafHardware(out, design, section, depth, move);

    final leafFront = MeshBuilder.leafFront(depth);
    final leafDepth = _leafDepth(depth);

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

    if (branch.isLeaf) {
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
        move,
      );
      return;
    }

    _addBarsInside(out, design, branch, glazed, leafDepth, place: move);
    for (final pane in branch.panes) {
      final child = design.sectionById(pane.sectionId);
      if (child != null) {
        _addSection(
          out,
          design,
          pane,
          child,
          frame,
          leafDepth,
          openFraction,
          place: move,
        );
      }
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
    // Asked of the model rather than compared by hand: a parent may name the
    // section or the opening on it, and `sectionHolding` is the one place the
    // two forms become one answer. The comparison used to be direct, which
    // worked only because hardware happens to be stored against the section —
    // the day it is not, a leaf would swing in the solid with its hinges and
    // its handle left behind on the frame.
    for (final piece in design.hardware) {
      if (design.sectionHolding(piece.parentId) != section.id) continue;
      _addHardware(out, piece, design, depth, place: place);
    }
  }

  /// Where a leaf's near face stands: a little back from the frame's own
  /// face, which is at zero, with the frame running back from there.
  ///
  /// Public because the ironmongery is measured from it, and a test asking
  /// whether a handle stands off the leaf has to ask of the leaf's face and
  /// not of a figure it believes the leaf is at.
  static double leafFront(double depth) => -depth * 0.08;

  /// Where a leaf's far face stands — the one a door's hinges are on.
  static double leafBack(double depth) => leafFront(depth) - _leafDepth(depth);

  /// How thick a leaf is, within the frame's depth.
  static double _leafDepth(double depth) => depth * 0.66;

  /// Swings a point about the hinge edge of [opening].
  /// Whether [opening] swings towards the viewer — out of the face the
  /// drawing is of — rather than away from it.
  ///
  /// **Inward is into the building, and which way that is on the screen
  /// depends on which side of the wall the drawing is of.** A window is
  /// drawn from inside, so an inward sash swings towards you. A design with
  /// a door in it is drawn from outside, so an inward door swings *away*,
  /// into the room behind it — which is what the user expects of a door they
  /// walk up to and push. Swinging every inward leaf towards the viewer, as
  /// it used to, opened a front door out into the street.
  /// `Design.seenFrom` is the one answer for the whole assembly.
  static bool swingsTowardViewer(Design design, OpeningElement opening) {
    final inward = opening.direction != OpeningDirection.outward;
    final seenFromInside = design.seenFrom == Face.inside;
    return inward == seenFromInside;
  }

  static Vec3 Function(Vec3) _swingFor(
    Design design,
    OpeningElement opening,
    SectionElement section,
    double depth,
    double openFraction,
  ) {
    final edge = opening.mechanism.hingeEdge;
    if (edge == null || openFraction <= 0) return (p) => p;

    // Ninety degrees is as far as anything swings here; a leaf drawn further
    // than that in a preview reads as broken rather than as open.
    final angle = (openFraction.clamp(0.0, 1.0)) * math.pi / 2;
    final toward = swingsTowardViewer(design, opening);
    final towards = toward ? 1.0 : -1.0;
    final cos = math.cos(angle);
    final sin = math.sin(angle) * towards;
    final box = section.outline;

    // It turns about the face it swings towards — the face its hinges are
    // screwed to — so it comes out of the frame rather than through it.
    final pivot = toward ? leafFront(depth) : leafBack(depth);

    // A turn about the hinge, not a squash towards it. The leaf has depth,
    // so its far face has to come round with its near face: rotating the
    // distance from the hinge while leaving the depth where it was left the
    // leaf thinner the further it opened, and at ninety degrees flattened it
    // into the plane of the frame with its thickness pointing the way it had
    // swung. A door turns. Every distance within the leaf is the same
    // afterwards as before, which is what makes the glass, the panel, the
    // bars and the hardware inside it one thing that moves together.
    return switch (edge) {
      OpeningEdge.left => (p) {
          final d = p.x - box.left;
          final q = p.z - pivot;
          return Vec3(
            box.left + d * cos - q * sin,
            p.y,
            pivot + q * cos + d * sin,
          );
        },
      OpeningEdge.right => (p) {
          final d = p.x - box.right;
          final q = p.z - pivot;
          return Vec3(
            box.right + d * cos + q * sin,
            p.y,
            pivot + q * cos - d * sin,
          );
        },
      OpeningEdge.top => (p) {
          final d = p.y - box.top;
          final q = p.z - pivot;
          return Vec3(
            p.x,
            box.top + d * cos - q * sin,
            pivot + q * cos + d * sin,
          );
        },
      OpeningEdge.bottom => (p) {
          final d = p.y - box.bottom;
          final q = p.z - pivot;
          return Vec3(
            p.x,
            box.bottom + d * cos + q * sin,
            pivot + q * cos - d * sin,
          );
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

    // **Ironmongery is built as ironmongery.** A lever on a backplate, an
    // espagnolette with a curved arm, an escutcheon with a keyhole through
    // it and a butt hinge with a knuckle are all real pieces with a shape,
    // and a flat tab standing on the leaf is a placeholder for one rather
    // than one of them.
    if (design.openingHolding(piece.parentId) case final opening?) {
      final hinge = opening.mechanism.hingeEdge;
      if (_addFurniture(out, piece, design, opening, hinge, depth, place)) {
        return;
      }
    }

    final face = Polygon([
      centre + along * (length / 2) + across * (width / 2),
      centre + along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) - across * (width / 2),
      centre - along * (length / 2) + across * (width / 2),
    ]);
    // **A hinge hangs on the inside face, and which face that is comes from
    // the kind.** A window is met from inside, so its hinges are on the face
    // you are looking at; a door is met from outside, so its hinges are
    // round the back and the leaf itself stands in front of them. Nothing is
    // hidden by the renderer here — the hinge is simply *behind* the leaf,
    // and a solid built the right way round does not need telling twice.
    //
    // Everything else goes through the leaf and is worked from either side,
    // so it stands proud of the face you are at whichever kind it is.
    final from = design.isConcealed(piece) ? -stand * 2 : stand;
    _addSlab(out, face, from, stand, piece.id, piece.finish,
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

  // ---------------------------------------------------------- door hardware

  /// A leaf's ironmongery, built as the piece it is.
  ///
  /// Everything here is geometry: a backplate with radiused ends, a rose
  /// standing off it, a lever that comes out of the door and turns across
  /// it, an escutcheon with a keyhole through it, a hinge with a knuckle.
  /// There is no picture of a handle anywhere in this repository and there
  /// is not to be one — a photograph standing in for a part is a lie about
  /// what was built.
  ///
  /// Returns false for a piece there is no built form of, which is then
  /// built the plain way.
  static bool _addFurniture(
    List<Facet> out,
    HardwareElement piece,
    Design design,
    OpeningElement opening,
    OpeningEdge? hinge,
    double depth,
    Vec3 Function(Vec3)? place,
  ) {
    final put = place ?? (Vec3 p) => p;
    final section = design.sectionById(opening.sectionId);
    if (section == null || hinge == null) return false;
    final leaf = section.outline;

    // Everything is sized from the leaf, so a garden gate and a front door
    // each get ironmongery in proportion to themselves, and nothing is a
    // number chosen to look right on one drawing.
    final scale = (math.min(leaf.width, leaf.height) / 900).clamp(0.55, 1.6);

    // The face this piece is fixed to, and the way out of the leaf from it.
    // A door's hinges are on the inside face, so theirs is the far one and
    // they stand away from the viewer; the lever and the escutcheon are on
    // the face the drawing is of. `Design.isConcealed` is the one answer.
    //
    // **Both are the leaf's own faces**, the ones the sash is built between,
    // and not figures of their own. The frame's face is at zero and the
    // design runs back from it, but these were measured as though the leaf
    // ran forward from zero to the frame's depth: every handle floated
    // three inches in front of its door, and a door's hinges, meant to be
    // round the back, were built into the front of the leaf — which is
    // where the user saw them, on a design seen from outside.
    final concealed = design.isConcealed(piece);
    final face = concealed ? leafBack(depth) : leafFront(depth);
    final outward = concealed ? -1.0 : 1.0;

    // Back across the leaf, from the stile the handle is on towards the
    // stile it hangs on. A lever points that way because that is the way a
    // hand closes on it; pointing it the other way runs it off the edge of
    // the door into the frame.
    final inward = switch (hinge) {
      OpeningEdge.left => const Vec3(-1, 0, 0),
      OpeningEdge.right => const Vec3(1, 0, 0),
      OpeningEdge.top => const Vec3(0, -1, 0),
      OpeningEdge.bottom => const Vec3(0, 1, 0),
    };

    // **The form is the piece's own, not the leaf's.** Which form a leaf
    // gets by default comes from what it is — a door's lever, a window's
    // espagnolette — but once the user has chosen one, that is what is
    // built, on either kind of leaf. A door with a window handle on it is a
    // door the user put a window handle on.
    //
    // **A piece that goes through the leaf is on both of its faces.** A
    // lever, a window's handle, a knob and a lock are worked from either
    // side — you open a door from the room as well as from the street — so
    // each is built on the face the drawing is of and again on the other,
    // the same piece turned through the leaf's middle. A hinge is screwed
    // to one face only, and stays there.
    final bothFaces = !piece.kind.onTheInsideFace;
    final through = MeshBuilder.leafFront(depth) + MeshBuilder.leafBack(depth);
    Vec3 otherFace(Vec3 p) => put(Vec3(p.x, p.y, through - p.z));

    bool build(Vec3 Function(Vec3) put) {
      switch (piece.kind) {
        case HardwareKind.hinge:
          _addButtHinge(out, piece, hinge, face, outward, scale, put);
          return true;
        case HardwareKind.lock:
          _addEscutcheon(out, piece, face, scale, put);
          return true;
        case HardwareKind.lever:
          _addLeverOnBackplate(
              out, piece, opening, hinge, inward, face, scale, put);
          return true;
        case HardwareKind.handle:
          _addWindowHandle(out, piece, hinge, inward, face, scale, put);
          return true;
        case HardwareKind.knob:
          _addKnob(out, piece, face, scale, put);
          return true;
        default:
          return false;
      }
    }

    final built = build(put);
    if (built && bothFaces) {
      final from = out.length;
      build(otherFace);
      for (var i = from; i < out.length; i++) {
        out[i] = out[i].inPart('the other face');
      }
    }
    return built;
  }

  /// A lever on a long backplate: plate, rose, neck, lever, return.
  ///
  /// The lever comes *out of* the leaf and then turns across it, which is
  /// what a lever does and what a flat tab cannot show. It points away from
  /// the stile it is on — towards the hinges — because that is the way a
  /// hand closes on it.
  static void _addLeverOnBackplate(
    List<Facet> out,
    HardwareElement piece,
    OpeningElement opening,
    OpeningEdge hinge,
    Vec3 inward,
    double face,
    double scale,
    Vec3 Function(Vec3) put,
  ) {
    final finish = piece.finish;
    final id = piece.id;
    final sideHung = hinge == OpeningEdge.left || hinge == OpeningEdge.right;

    // The plate runs up the leaf on a side-hung door and across it on a top
    // or bottom hung one: along the stile it is fixed to, either way.
    final plateAlong = sideHung ? const Vec2(0, 1) : const Vec2(1, 0);
    final plate = _stadium(piece.at, plateAlong, 235 * scale, 48 * scale);
    _slabBetween(out, plate, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The rose the lever turns in, standing off the plate.
    final roseAt = Vec3(piece.at.x, piece.at.y, face + 4 * scale);
    final rose = _ring(roseAt, const Vec3(1, 0, 0), const Vec3(0, 1, 0),
        27 * scale);
    _sweep(out, rose, Vec3(0, 0, 14 * scale), id, finish, put,
        capStart: false);

    // Out of the door, then across it, then a short return towards it —
    // the three runs a lever is made of.
    final neckFrom = Vec3(piece.at.x, piece.at.y, face + 18 * scale);
    final thickness = 11 * scale;
    final acrossPlane = _ring(neckFrom, const Vec3(1, 0, 0),
        const Vec3(0, 1, 0), thickness);
    _sweep(out, acrossPlane, Vec3(0, 0, 26 * scale), id, finish, put,
        capStart: false);

    final elbow = Vec3(neckFrom.x, neckFrom.y, neckFrom.z + 26 * scale);
    final armLength = 108 * scale;
    // The lever's own cross-section stands square to the way it runs.
    final armRing = _ring(elbow, const Vec3(0, 0, 1),
        Vec3(-inward.y, inward.x, 0), thickness);
    _sweep(
      out,
      armRing,
      Vec3(inward.x * armLength, inward.y * armLength, 0),
      id,
      finish,
      put,
      capEnd: false,
    );

    final tip = Vec3(elbow.x + inward.x * armLength,
        elbow.y + inward.y * armLength, elbow.z);
    final tipRing = _ring(tip, const Vec3(1, 0, 0), const Vec3(0, 1, 0),
        thickness);
    _sweep(out, tipRing, Vec3(0, 0, -20 * scale), id, finish, put,
        capStart: false);
  }

  /// A window's espagnolette handle: base, boss, and an arm that sweeps
  /// down the sash.
  ///
  /// **This is not the door lever made smaller.** A window handle is a
  /// different manufactured object: a short base on the stile rather than a
  /// long backplate, a boss the spindle turns in, and a cast arm that
  /// curves away from the face and hangs down, swelling towards its end
  /// where a hand takes it. It rests down because that is where the handle
  /// of a shut window sits.
  static void _addWindowHandle(
    List<Facet> out,
    HardwareElement piece,
    OpeningEdge hinge,
    Vec3 inward,
    double face,
    double scale,
    Vec3 Function(Vec3) put,
  ) {
    final finish = piece.finish;
    final id = piece.id;
    final sideHung = hinge == OpeningEdge.left || hinge == OpeningEdge.right;

    // A short base along the stile it is screwed to — nothing like the long
    // plate a mortice lock needs.
    final baseAlong = sideHung ? const Vec2(0, 1) : const Vec2(1, 0);
    final base = _stadium(piece.at, baseAlong, 104 * scale, 30 * scale);
    _slabBetween(out, base, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The boss the spindle turns in, standing off the base.
    final bossAt = Vec3(piece.at.x, piece.at.y, face + 4 * scale);
    _sweep(
      out,
      _ring(bossAt, const Vec3(1, 0, 0), const Vec3(0, 1, 0), 15 * scale),
      Vec3(0, 0, 11 * scale),
      id,
      finish,
      put,
      capStart: false,
    );

    // The arm. Out of the sash, then round and down, as a cast lever does.
    // Down the leaf for a side-hung sash; for a top or bottom hung one it
    // still hangs, because hanging is what a shut handle does.
    final sweepAway = sideHung ? const Vec2(0, 1) : Vec2(-inward.x, -inward.y);
    final reach = 86 * scale;
    final stand = 26 * scale;

    final path = <Vec3>[];
    final radii = <double>[];
    const steps = 7;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      // A quarter turn: out of the face first, then over and along the
      // leaf, so the arm leaves the boss square and finishes lying down it.
      final outOf = math.sin(t * math.pi / 2);
      final along = 1 - math.cos(t * math.pi / 2);
      path.add(Vec3(
        piece.at.x + sweepAway.x * reach * along,
        piece.at.y + sweepAway.y * reach * along,
        face + 11 * scale + stand * outOf,
      ));
      // Slim at the boss, swelling towards the end a hand takes.
      radii.add((7.5 + 2.6 * t) * scale);
    }
    _tube(out, path, radii, id, finish, put);
  }

  /// A knob on its rose: a stem out of the leaf and a ball on the end.
  static void _addKnob(
    List<Facet> out,
    HardwareElement piece,
    double face,
    double scale,
    Vec3 Function(Vec3) put,
  ) {
    final id = piece.id;
    final finish = piece.finish;

    final rose = _stadium(piece.at, const Vec2(0, 1), 58 * scale, 52 * scale);
    _slabBetween(out, rose, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The stem, and then the knob itself: rings swelling and closing again,
    // which is a turned ball rather than a cylinder with a lid.
    final path = <Vec3>[];
    final radii = <double>[];
    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      path.add(Vec3(piece.at.x, piece.at.y, face + 4 * scale + 52 * scale * t));
      radii.add(t < 0.45
          ? 9 * scale
          : (9 + 17 * math.sin((t - 0.45) / 0.55 * math.pi)) * scale);
    }
    _tube(out, path, radii, id, finish, put);
  }

  /// The escutcheon below the lever: a plate with the keyhole through it.
  static void _addEscutcheon(
    List<Facet> out,
    HardwareElement piece,
    double face,
    double scale,
    Vec3 Function(Vec3) put,
  ) {
    final plate = _stadium(piece.at, const Vec2(0, 1), 62 * scale,
        48 * scale);
    _slabBetween(out, plate, face + 4 * scale, 4 * scale, piece.id,
        piece.finish, FacetRole.hardware, put);

    // The keyhole is a hole, so it is built as one: a short bore sunk into
    // the plate, dark because nothing in it catches the light.
    final dark = Finish(
      colour: _darken(piece.finish.colour, 0.28),
      material: piece.finish.material,
    );
    final mouth = Vec3(piece.at.x, piece.at.y - 6 * scale, face + 4 * scale);
    _sweep(
      out,
      _ring(mouth, const Vec3(1, 0, 0), const Vec3(0, 1, 0), 7 * scale),
      Vec3(0, 0, -5 * scale),
      piece.id,
      dark,
      put,
      capStart: false,
    );
    final ward = _stadium(Vec2(piece.at.x, piece.at.y + 5 * scale),
        const Vec2(0, 1), 20 * scale, 7 * scale);
    _slabBetween(out, ward, face + 4 * scale, 2 * scale, piece.id, dark,
        FacetRole.hardware, put);
  }

  /// A butt hinge: the leaf screwed to the stile, and the knuckle it turns
  /// on standing proud of the edge.
  ///
  /// The knuckle is the part you see on a closed door from the hinge side,
  /// and on a door drawn from outside it is the only part you see at all.
  static void _addButtHinge(
    List<Facet> out,
    HardwareElement piece,
    OpeningEdge hinge,
    double face,
    double outward,
    double scale,
    Vec3 Function(Vec3) put,
  ) {
    final sideHung = hinge == OpeningEdge.left || hinge == OpeningEdge.right;
    final along = sideHung ? const Vec2(0, 1) : const Vec2(1, 0);
    final knuckleLength = 88 * scale;

    final leaf = _stadium(piece.at, along, knuckleLength, 34 * scale);
    _slabBetween(out, leaf, face + outward * 6 * scale, 3 * scale, piece.id,
        piece.finish, FacetRole.hardware, put);

    // The barrel, lying along the hinge line.
    final axis = sideHung ? const Vec3(0, 1, 0) : const Vec3(1, 0, 0);
    final u = sideHung ? const Vec3(1, 0, 0) : const Vec3(0, 1, 0);
    final start = Vec3(
      piece.at.x - axis.x * knuckleLength / 2,
      piece.at.y - axis.y * knuckleLength / 2,
      face + outward * 6 * scale,
    );
    _sweep(
      out,
      _ring(start, u, const Vec3(0, 0, 1), 9 * scale),
      Vec3(axis.x * knuckleLength, axis.y * knuckleLength, 0),
      piece.id,
      piece.finish,
      put,
    );
  }

  // ------------------------------------------------------- solid primitives

  /// A ring of [sides] points around [centre], in the plane [u] and [v] span.
  ///
  /// The cross-section of anything round. A lever is not a box and a hinge
  /// knuckle is not a box, so neither is built as one; twelve sides is the
  /// point where another one stops showing at the size ironmongery is drawn.
  static List<Vec3> _ring(
    Vec3 centre,
    Vec3 u,
    Vec3 v,
    double radius, {
    int sides = 12,
  }) =>
      [
        for (var i = 0; i < sides; i++)
          () {
            final angle = i / sides * math.pi * 2;
            final c = math.cos(angle) * radius;
            final d = math.sin(angle) * radius;
            return Vec3(
              centre.x + u.x * c + v.x * d,
              centre.y + u.y * c + v.y * d,
              centre.z + u.z * c + v.z * d,
            );
          }(),
      ];

  /// [ring] swept along [along]: the ends capped, the sides walled.
  ///
  /// The general form of a slab, free of the z axis, so a part can run out of
  /// the door and turn across it rather than only lying flat on it.
  static void _sweep(
    List<Facet> out,
    List<Vec3> ring,
    Vec3 along,
    String elementId,
    Finish finish,
    Vec3 Function(Vec3) place, {
    bool capStart = true,
    bool capEnd = true,
  }) {
    if (ring.length < 3) return;
    final far = [
      for (final p in ring) Vec3(p.x + along.x, p.y + along.y, p.z + along.z),
    ];

    if (capStart) {
      _quad(out, [for (final p in ring.reversed) place(p)], elementId, finish,
          FacetRole.hardware, shade: 0.72);
    }
    if (capEnd) {
      _quad(out, [for (final p in far) place(p)], elementId, finish,
          FacetRole.hardware);
    }
    for (var i = 0; i < ring.length; i++) {
      final j = (i + 1) % ring.length;
      // Along the round, each facet catches the light a little differently,
      // which is what makes a cylinder read as a cylinder rather than as a
      // faceted stick.
      final lit = 0.72 + 0.28 * (0.5 + 0.5 * math.cos(i / ring.length * math.pi * 2));
      _quad(out, [
        place(ring[i]),
        place(ring[j]),
        place(far[j]),
        place(far[i]),
      ], elementId, finish, FacetRole.hardware, shade: lit);
    }
  }

  /// A round bar following [path], with its own radius at each point.
  ///
  /// A real window handle's arm is a curve, not a straight stick with a
  /// bend in it, so it is built as one: a ring at every point along the
  /// path, each standing square to the way the path is going there, and the
  /// wall run between consecutive rings. Tapering the radius along it is
  /// what gives a cast lever its swelling grip.
  static void _tube(
    List<Facet> out,
    List<Vec3> path,
    List<double> radii,
    String elementId,
    Finish finish,
    Vec3 Function(Vec3) put, {
    int sides = 10,
  }) {
    if (path.length < 2 || radii.length != path.length) return;

    Vec3 minus(Vec3 a, Vec3 b) => Vec3(a.x - b.x, a.y - b.y, a.z - b.z);
    Vec3 unit(Vec3 v) {
      final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
      return len < 1e-9 ? const Vec3(0, 0, 1) : Vec3(v.x / len, v.y / len, v.z / len);
    }

    Vec3 cross(Vec3 a, Vec3 b) => Vec3(
          a.y * b.z - a.z * b.y,
          a.z * b.x - a.x * b.z,
          a.x * b.y - a.y * b.x,
        );

    final rings = <List<Vec3>>[];
    for (var i = 0; i < path.length; i++) {
      // The way the path is going here: between its neighbours where it has
      // two, and along the one leg it has at each end.
      final before = i == 0 ? path[0] : path[i - 1];
      final after = i == path.length - 1 ? path[i] : path[i + 1];
      final along = unit(minus(after, before));
      // Any steady reference that is not along the path gives a frame that
      // does not spin as the curve turns.
      final reference =
          along.z.abs() > 0.9 ? const Vec3(0, 1, 0) : const Vec3(0, 0, 1);
      final u = unit(cross(along, reference));
      final v = cross(along, u);
      rings.add(_ring(path[i], u, v, radii[i], sides: sides));
    }

    _quad(out, [for (final p in rings.first.reversed) put(p)], elementId,
        finish, FacetRole.hardware, shade: 0.7);
    _quad(out, [for (final p in rings.last) put(p)], elementId, finish,
        FacetRole.hardware);

    for (var i = 0; i + 1 < rings.length; i++) {
      for (var j = 0; j < sides; j++) {
        final k = (j + 1) % sides;
        final lit = 0.7 + 0.3 * (0.5 + 0.5 * math.cos(j / sides * math.pi * 2));
        _quad(out, [
          put(rings[i][j]),
          put(rings[i][k]),
          put(rings[i + 1][k]),
          put(rings[i + 1][j]),
        ], elementId, finish, FacetRole.hardware, shade: lit);
      }
    }
  }

  /// A rounded-cornered plate lying on the leaf, as a backplate does.
  ///
  /// Real ironmongery has no sharp corners — a pressed plate is radiused all
  /// round — and a box with four right angles reads as a sticker rather than
  /// as a piece of metal.
  static Polygon _stadium(
    Vec2 centre,
    Vec2 along,
    double length,
    double width, {
    int corner = 5,
  }) {
    final u = along.length < 1e-9 ? const Vec2(1, 0) : along.normalised;
    final v = u.perpendicular;
    final radius = width / 2;
    final straight = math.max(0.0, length / 2 - radius);

    final corners = <Vec2>[];
    for (final end in [1.0, -1.0]) {
      final hub = centre + u * (straight * end);
      for (var i = 0; i <= corner; i++) {
        final angle = (i / corner - 0.5) * math.pi * end;
        final c = math.cos(angle) * end;
        final d = math.sin(angle);
        corners.add(Vec2(
          hub.x + u.x * radius * c + v.x * radius * d,
          hub.y + u.y * radius * c + v.y * radius * d,
        ));
      }
    }
    return Polygon(corners);
  }

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

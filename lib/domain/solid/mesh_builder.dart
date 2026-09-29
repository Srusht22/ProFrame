import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import '../hardware/furniture.dart';
import '../hardware/opening_hardware.dart';
import '../model/design.dart';
import '../model/design_geometry.dart';
import '../model/design_tree.dart';
import '../model/elements.dart';
import '../model/frame_profile.dart';
import '../model/materials.dart';
import '../model/opening_leaf.dart';
import '../model/surface.dart';
import 'mesh.dart';
import 'turned.dart';

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

    _addFrame(facets, frame, DesignGeometry.of(design).frameProfile!, depth);

    // A sliding design is panels standing on tracks in the frame, and the
    // lines between them are where the panels meet — see [_Tracks].
    final tracks = design.kind.slides
        ? _Tracks.of(design, tree, frame, depth)
        : null;

    // Only the bars that divide the design itself. A bar drawn inside a
    // section is built with that section, so that it swings with the leaf it
    // is part of instead of staying behind on the frame.
    for (final id in tree.barIds) {
      final divider = design.dividerById(id);
      // In a sliding design a line between two panels is where they meet:
      // its material is the two panels' own stiles, which reach to its
      // middle, and not a post standing in the frame for one of them to run
      // into.
      if (divider != null && tracks == null) {
        _addBar(facets, design, divider, depth);
      }
    }

    // Only the main divisions are built here. What is inside a section is
    // built with it, so that a leaf and everything drawn in it are one thing
    // that swings together.
    for (final branch in tree.sections) {
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;
      if (tracks != null) {
        tracks.addPanel(facets, branch, section, openFraction);
        continue;
      }
      _addSection(facets, design, branch, section, frame, depth, openFraction);
    }

    // Hardware the user placed themselves sits on the design where they put
    // it. An opening's own hinges and handle are built with the leaf, so
    // they swing with it rather than staying behind on the frame.
    for (final piece in design.hardware) {
      if (piece.isOpeningHardware) continue;
      _addHardware(facets, piece, design, depth);
    }

    // What an opening has fixed to the frame — a screen's cassette at its
    // jamb, a sensor on the head — stays where it is while the leaf moves.
    for (final piece in design.hardware) {
      if (!piece.isOpeningHardware || !piece.kind.staysOnFrame) continue;
      switch (piece.kind) {
        case HardwareKind.screen:
          _addScreen(facets, design, piece, depth, openFraction, tracks);
        case HardwareKind.sensor:
          _addSensor(facets, design, piece, depth);
        default:
          break;
      }
    }

    return Mesh(facets);
  }

  /// The frame, as the profile it is made of, swept round the outline.
  ///
  /// Its section is [FrameProfile] — the frame's own width and the design's
  /// depth, shaped by what it is made of — so the frame has a front face,
  /// the arrises and sightline its material is made with, a reveal facing
  /// into the opening and an outside, and it stands exactly on the outline
  /// and the daylight the drawing has: nothing is wider, narrower, deeper or
  /// shallower than the plain ring it replaces.
  static void _addFrame(
    List<Facet> out,
    FrameElement frame,
    FrameProfile profile,
    double depth,
  ) {
    final outer = frame.outline;
    final inner = frame.innerOutline;
    if (inner.isEmpty ||
        outer.corners.length != inner.corners.length ||
        profile.isEmpty) {
      // A profile too thick for the opening leaves no daylight. Show it as
      // the solid thing it would be rather than failing quietly.
      _addSlab(out, outer, 0, depth, frame.id, frame.finish, FacetRole.frame);
      return;
    }
    _sweepProfile(
      out,
      outer,
      inner,
      profile,
      0,
      frame.id,
      frame.finish,
      FacetRole.frame,
      (p) => p,
      hasMember: frame.hasMember,
    );
  }

  /// [profile]'s section swept round the ring between [outer] and [inner],
  /// its front face at [frontZ].
  ///
  /// A point of the section [across] of the way in is at that share of the
  /// way from each outer corner to its inner one — the mitre — so every
  /// member meets the next on its mitre, as a joiner cuts them, and the
  /// outermost and innermost points of the section lie exactly on [outer]
  /// and [inner].
  ///
  /// A side with no member ([hasMember] false) is not built; the members
  /// either side stop there, each with its cut end — the section itself,
  /// standing on the floor at the foot of a door with no sill.
  static void _sweepProfile(
    List<Facet> out,
    Polygon outer,
    Polygon inner,
    FrameProfile profile,
    double frontZ,
    String elementId,
    Finish finish,
    FacetRole role,
    Vec3 Function(Vec3) place, {
    bool Function(int edge)? hasMember,
  }) {
    final n = outer.corners.length;
    final section = profile.section;
    final m = section.length;
    Vec3 at(int corner, ProfilePoint p) {
      final o = outer.corners[corner % n], i = inner.corners[corner % n];
      final t = p.across / profile.width;
      return place(Vec3(
        o.x + (i.x - o.x) * t,
        o.y + (i.y - o.y) * t,
        frontZ - p.back,
      ));
    }

    void end(int corner) {
      final o = outer.corners[corner % n], i = inner.corners[corner % n];
      if (o.distanceTo(i) <= 0) return;
      _quad(out, [for (final p in section) at(corner, p)], elementId, finish,
          role, side: true);
    }

    for (var e = 0; e < n; e++) {
      if (hasMember != null && !hasMember(e)) {
        end(e);
        end(e + 1);
        continue;
      }
      for (var k = 0; k < m; k++) {
        final p = section[k], q = section[(k + 1) % m];
        _quad(out, [
          at(e, p),
          at(e + 1, p),
          at(e + 1, q),
          at(e, q),
        ], elementId, finish, role);
      }
    }
  }


  /// A bar, as wide as the user set it and running exactly where they drew
  /// it — including at an angle, if that is how it was drawn. Its face is
  /// [DesignGeometry.barBody], the one the drawings draw.
  static void _addBar(
    List<Facet> out,
    Design design,
    DividerElement divider,
    double depth,
  ) {
    final face = DesignGeometry.of(design).barBody(divider);
    if (face.isEmpty) return;

    // Bars sit a little back from the face of the frame, as they do in the
    // real thing.
    const setback = 0.1;
    _barSlab(
      out,
      face,
      -depth * setback,
      depth * (1 - setback * 2),
      barArrisOf(divider.finish.material, divider.widthMm),
      divider.id,
      divider.finish,
      (p) => p,
    );
  }

  /// A bar's body given thickness, with the long edges of its front eased
  /// by [arris] — the rounded or cut arris its material is made with — and
  /// its ends left square, because they butt against the frame or the bar
  /// they run to. Everything stays inside the bar's own body: the front is
  /// narrowed by the arris, never the bar.
  ///
  /// A body that is not a plain four-sided bar — one cut to a slope at both
  /// ends by the frame — is built as it is, square.
  static void _barSlab(
    List<Facet> out,
    Polygon face,
    double frontZ,
    double thickness,
    double arris,
    String elementId,
    Finish finish,
    Vec3 Function(Vec3) place,
  ) {
    final front = face.corners.length == 4 && arris > 0 && arris < thickness
        ? face.insetEach([arris, 0, arris, 0])
        : const Polygon([]);
    if (front.corners.length != 4 || front.area >= face.area) {
      _slabBetween(out, face, frontZ, thickness, elementId, finish,
          FacetRole.bar, place);
      return;
    }

    final eased = frontZ - arris;
    final back = frontZ - thickness;
    Vec3 at(Vec2 p, double z) => place(_at(p, z));
    final c = face.corners, f = front.corners;

    _quad(out, [for (final p in f) at(p, frontZ)], elementId, finish,
        FacetRole.bar);
    _quad(out, [for (final p in c.reversed) at(p, back)], elementId, finish,
        FacetRole.bar);
    for (var i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      if (i.isEven) {
        // A long edge: the arris, then the side.
        _quad(out, [at(f[i], frontZ), at(f[j], frontZ), at(c[j], eased),
            at(c[i], eased)], elementId, finish, FacetRole.bar);
        _quad(out, [at(c[i], eased), at(c[j], eased), at(c[j], back),
            at(c[i], back)], elementId, finish, FacetRole.bar, side: true);
      } else {
        // An end, square, showing the section of the arrises either side.
        _quad(out, [
          at(f[i], frontZ),
          at(c[i], eased),
          at(c[i], back),
          at(c[j], back),
          at(c[j], eased),
          at(f[j], frontZ),
        ], elementId, finish, FacetRole.bar, side: true);
      }
    }
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
    _addBarsInside(out, design, branch, depth, place: place);
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

  /// The bars the user drew inside one section, trimmed to what fills it —
  /// so a bar inside a sash runs between the sash's faces rather than
  /// across them.
  static void _addBarsInside(
    List<Facet> out,
    Design design,
    TreeSection branch,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    for (final id in branch.barIds) {
      final bar = design.dividerById(id);
      if (bar != null) {
        _addInternalBar(out, design, bar, depth, place: place);
      }
    }
  }

  /// A bar the user drew inside a section, trimmed to that section:
  /// [DesignGeometry.barBody], the one the drawings draw.
  static void _addInternalBar(
    List<Facet> out,
    Design design,
    DividerElement divider,
    double depth, {
    Vec3 Function(Vec3)? place,
  }) {
    final face = DesignGeometry.of(design).barBody(divider);
    if (face.isEmpty) return;

    const setback = 0.1;
    _barSlab(
      out,
      face,
      -depth * setback,
      depth * (1 - setback * 2),
      barArrisOf(divider.finish.material, divider.widthMm),
      divider.id,
      divider.finish,
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
    // elevation and the solid cannot disagree about where it is — a panel
    // on a track reaching the middle of the line it meets its neighbour at.
    final geometry = DesignGeometry.of(design);
    final sashOuter = geometry.leafOuter(section);
    final sashInner = geometry.leafInner(section) ?? const Polygon([]);

    // Its own swing, then whatever its parent is doing. A leaf inside a leaf
    // swings within the one it hangs in; a leaf hanging in the frame has no
    // parent movement and this is its swing alone.
    final swing = _swingFor(design, opening, section, depth, openFraction);
    final outer = place;
    Vec3 move(Vec3 point) =>
        outer == null ? swing(point) : outer(swing(point));

    _addLeafHardware(out, design, section, depth, move);
    _addSash(out, design, branch, section, frame, depth, openFraction,
        sashOuter, sashInner, move);
  }

  /// A sash — its ring of material between [sashOuter] and [sashInner], and
  /// whatever fills it — placed by [move].
  static void _addSash(
    List<Facet> out,
    Design design,
    TreeSection branch,
    SectionElement section,
    FrameElement frame,
    double depth,
    double openFraction,
    Polygon sashOuter,
    Polygon sashInner,
    Vec3 Function(Vec3) move,
  ) {
    final leafFront = MeshBuilder.leafFront(depth);
    final leafDepth = _leafDepth(depth);

    // The sash is a frame of its own, in the frame's material: the same
    // profile at the sash's width and the leaf's depth, swung with it.
    final profile = FrameProfile.of(
      frame.finish.material,
      width: OpeningLeaf.profileFor(frame),
      depth: leafDepth,
    );
    if (!sashInner.isEmpty &&
        sashInner.corners.length == sashOuter.corners.length &&
        !profile.isEmpty) {
      _sweepProfile(
        out,
        sashOuter,
        sashInner,
        profile,
        leafFront,
        section.id,
        frame.finish,
        FacetRole.sash,
        move,
      );
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

    _addBarsInside(out, design, branch, leafDepth, place: move);
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
      if (piece.kind.staysOnFrame) continue;
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
    if (opening.mechanism.slideEdge case final leads?) {
      return _slideFor(design, opening, section, leads, depth, openFraction);
    }
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

  /// Slides a point of a sliding panel, [openFraction] of the way open.
  ///
  /// **A sliding panel runs along its own track, and does nothing else.** It
  /// already stands on that track in the frame — [_Tracks] puts it there —
  /// so opening it is a translation along the track and nothing more: no
  /// turn, no step out of the frame, as a real sliding door glides past the
  /// panel beside it.
  ///
  /// **How far is the panel's own width, and never past the frame.** That
  /// is what opening a slider means: it clears its own light. Where the
  /// jamb is nearer than that, it stops at the jamb. Nothing here is a
  /// distance chosen to look right.
  static Vec3 Function(Vec3) _slideFor(
    Design design,
    OpeningElement opening,
    SectionElement section,
    OpeningEdge leads,
    double depth,
    double openFraction,
  ) {
    if (openFraction <= 0) return (p) => p;
    final along =
        _travelOf(design, section, leads) * openFraction.clamp(0.0, 1.0);
    return (p) => Vec3(p.x + along, p.y, p.z);
  }

  /// How far a panel in [section] slides when fully open, towards [leads]:
  /// negative to the left.
  static double _travelOf(
    Design design,
    SectionElement section,
    OpeningEdge leads,
  ) {
    final box = section.outline;
    final room = design.frame?.innerOutline;
    return switch (leads) {
      OpeningEdge.left => -math.min(
          box.width, math.max(0.0, box.left - (room?.left ?? box.left))),
      OpeningEdge.right => math.min(
          box.width, math.max(0.0, (room?.right ?? box.right) - box.right)),
      _ => 0.0,
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
    // **Ironmongery is built as ironmongery.** A lever on a backplate, an
    // espagnolette with a curved arm, an escutcheon with a keyhole through
    // it and a butt hinge with a knuckle are all real pieces with a shape,
    // and a flat tab standing on the leaf is a placeholder for one rather
    // than one of them.
    //
    // Where each part of it is, and how big, is [Furniture] — the one
    // description the drawings read as well — and a sliding panel, which
    // has no hinges, has the edge it leads with standing where they would,
    // opposite its handle.
    final from = out.length;
    if (Furniture.of(design, piece) case final furniture?) {
      _addFurniture(out, furniture, design, depth, place);
    } else {
      _addPlainPiece(out, piece, design, depth, place);
    }

    // **What a piece is made of is what that piece is made of.** A handle is
    // cast and plated to be held and a hinge pressed from satin steel, in
    // whichever metal and colour the user chose for it; a piece they say is
    // plastic or wood is that.
    final surface = Surfaces.ofHardware(piece.kind, piece.finish.material);
    for (var i = from; i < out.length; i++) {
      out[i] = out[i].madeOf(surface);
    }
  }

  static void _addPlainPiece(
    List<Facet> out,
    HardwareElement piece,
    Design design,
    double depth,
    Vec3 Function(Vec3)? place,
  ) {
    final stand = (depth * 0.5).clamp(12.0, 60.0);

    final face = Furniture.plainPlate(design, piece);
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
    );

    final n = shape.corners.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      _quad(out, [
        place(_at(shape.corners[i], backZ)),
        place(_at(shape.corners[j], backZ)),
        place(_at(shape.corners[j], frontZ)),
        place(_at(shape.corners[i], frontZ)),
      ], elementId, finish, role, side: true);
    }
  }

  static void _quad(
    List<Facet> out,
    List<Vec3> corners,
    String elementId,
    Finish finish,
    FacetRole role, {
    bool side = false,
  }) {
    if (corners.length < 3) return;
    // The user's colour and the material it is, as they are: how the face
    // is lit is worked out by the renderer from the material, once.
    out.add(Facet(
      corners: corners,
      elementId: elementId,
      colour: finish.colour,
      surface: finish.material.surface,
      isSide: side,
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
  static void _addFurniture(
    List<Facet> out,
    Furniture f,
    Design design,
    double depth,
    Vec3 Function(Vec3)? place,
  ) {
    final put = place ?? (Vec3 p) => p;
    final piece = f.piece;
    final opening = design.openingHolding(piece.parentId)!;

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
    final inward = Vec3(f.inward.x, f.inward.y, 0);

    // **The form is the piece's own, not the leaf's.** Which form a leaf
    // gets by default comes from what it is — a door's lever, a window's
    // espagnolette — but once the user has chosen one, that is what is
    // built, on either kind of leaf. A door with a window handle on it is a
    // door the user put a window handle on.
    //
    // **A door's handle is on both of its faces.** You open a door from the
    // room as well as from the street, so its lever and its lock are built
    // on the face the drawing is of and again on the other, the same piece
    // turned through the leaf's middle. A window is opened from inside
    // only, so its handle is on the one face — the one you are standing
    // at. A hinge is screwed to one face of either, and stays there. Which
    // the leaf is comes from `Design.kindOf`, the user's own answer.
    final bothFaces = !piece.kind.onTheInsideFace &&
        design.kindOf(opening) == DesignKind.door;
    final through = MeshBuilder.leafFront(depth) + MeshBuilder.leafBack(depth);
    Vec3 otherFace(Vec3 p) => put(Vec3(p.x, p.y, through - p.z));

    void build(Vec3 Function(Vec3) put) {
      switch (piece.kind) {
        case HardwareKind.hinge:
          _addButtHinge(out, f, face, outward, put);
        case HardwareKind.lock:
          _addEscutcheon(out, f, face, put);
        case HardwareKind.lever:
          _addLeverOnBackplate(out, f, inward, face, put);
        case HardwareKind.handle:
          _addWindowHandle(out, f, inward, face, put);
        case HardwareKind.knob:
          _addKnob(out, f, face, put);
        case HardwareKind.pull:
          _addPull(out, f, face, put);
        default:
          break;
      }
    }

    build(put);
    if (bothFaces) {
      final from = out.length;
      build(otherFace);
      for (var i = from; i < out.length; i++) {
        out[i] = out[i].inPart('the other face');
      }
    }
  }

  /// A lever on a long backplate: plate, rose, neck, lever, return.
  ///
  /// The lever comes *out of* the leaf and then turns across it, which is
  /// what a lever does and what a flat tab cannot show. It points away from
  /// the stile it is on — towards the hinges — because that is the way a
  /// hand closes on it.
  static void _addLeverOnBackplate(
    List<Facet> out,
    Furniture f,
    Vec3 inward,
    double face,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final finish = piece.finish;
    final id = piece.id;

    // The plate runs up the leaf on a side-hung door and across it on a top
    // or bottom hung one: along the stile it is fixed to, either way.
    final plate = f.leverPlate;
    _slabBetween(out, plate, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The rose the lever turns in, standing off the plate.
    final roseAt = Vec3(piece.at.x, piece.at.y, face + 4 * scale);
    final rose = _ring(roseAt, const Vec3(1, 0, 0), const Vec3(0, 1, 0),
        f.leverRose);
    _sweep(out, rose, Vec3(0, 0, 14 * scale), id, finish, put,
        capStart: false);

    // Out of the door, then across it, then a short return towards it —
    // the three runs a lever is made of.
    final neckFrom = Vec3(piece.at.x, piece.at.y, face + 18 * scale);
    final thickness = f.leverRadius;
    final acrossPlane = _ring(neckFrom, const Vec3(1, 0, 0),
        const Vec3(0, 1, 0), thickness);
    _sweep(out, acrossPlane, Vec3(0, 0, 26 * scale), id, finish, put,
        capStart: false);

    final elbow = Vec3(neckFrom.x, neckFrom.y, neckFrom.z + 26 * scale);
    final armLength = f.leverReach;
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
    Furniture f,
    Vec3 inward,
    double face,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final finish = piece.finish;
    final id = piece.id;

    // A short base along the stile it is screwed to — nothing like the long
    // plate a mortice lock needs.
    final base = f.handleBase;
    _slabBetween(out, base, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The boss the spindle turns in, standing off the base.
    final bossAt = Vec3(piece.at.x, piece.at.y, face + 4 * scale);
    _sweep(
      out,
      _ring(bossAt, const Vec3(1, 0, 0), const Vec3(0, 1, 0), f.handleBoss),
      Vec3(0, 0, 11 * scale),
      id,
      finish,
      put,
      capStart: false,
    );

    // The arm. Out of the sash, then round and down, as a cast lever does.
    // Down the leaf for a side-hung sash; for a top or bottom hung one it
    // still hangs, because hanging is what a shut handle does.
    final (path, radii) = f.handleArm(face);
    _tube(out, path, radii, id, finish, put);
  }

  /// A sliding panel's pull: an upright bar held off the stile on two
  /// posts, which a hand closes round and draws along.
  ///
  /// Nothing on it turns, because nothing on a sliding panel does — a lever
  /// or a turned fastener would be the handle of a leaf that swings. It is
  /// centred on the stile rather than on the stile's outer edge, so it is on
  /// the panel's own material and not over the frame it closes against.
  static void _addPull(
    List<Facet> out,
    Furniture f,
    double face,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final id = piece.id;
    final finish = piece.finish;
    final length = f.pullLength;
    final x = f.pullAt.x;
    final y = f.pullAt.y;
    final stand = 34 * scale;

    // The two posts, out of the face.
    for (final end in [-1.0, 1.0]) {
      final at = Vec3(x, y + end * f.postFromMiddle, face);
      _sweep(
        out,
        _ring(at, const Vec3(1, 0, 0), const Vec3(0, 1, 0), f.postRadius),
        Vec3(0, 0, stand),
        id,
        finish,
        put,
        capStart: false,
      );
    }

    // The bar, upright between them, standing off the face by the posts.
    final foot = Vec3(x, y + length / 2, face + stand);
    _sweep(
      out,
      _ring(foot, const Vec3(1, 0, 0), const Vec3(0, 0, 1), f.pullRadius),
      Vec3(0, -length, 0),
      id,
      finish,
      put,
    );
  }

  /// How near flat a fold of a screen lies when the screen is fully out:
  /// never quite, because mesh pulled flat is a sheet and not a pleat.
  static const _flattest = 0.94;

  /// A pleated screen: its cassette at the jamb, and the mesh fanned out of
  /// it as far as its panel has opened.
  ///
  /// A pleated screen is one length of mesh folded to and fro. Drawn across
  /// the passage it opens flatter; gathered back it folds deeper — every
  /// face of every fold stays the same size throughout, which is what makes
  /// it pleat rather than stretch.
  static void _addScreen(
    List<Facet> out,
    Design design,
    HardwareElement piece,
    double depth,
    double openFraction,
    _Tracks? tracks,
  ) {
    final frame = design.frame;
    final housing = OpeningHardware.footprintOf(design, piece);
    final opening = design.openingHolding(piece.parentId);
    final section =
        opening == null ? null : design.sectionById(opening.sectionId);
    final leads = opening?.mechanism.slideEdge;
    if (frame == null || housing == null || section == null || leads == null) {
      return;
    }

    // Its own track, behind the panels; without tracks, the back of the
    // frame's depth, which is the same place in a frame with one.
    final band = tracks?.screenBand ?? (front: -depth * 0.8, depth: depth * 0.2);
    final front = band.front - band.depth * 0.1;
    final thick = band.depth * 0.8;

    // The cassette, in the frame's finish: it is part of the frame's line.
    _addSlab(out, housing, front, thick, piece.id, frame.finish,
        FacetRole.hardware);

    final into = leads == OpeningEdge.left ? -1.0 : 1.0;
    final travel = _travelOf(design, section, leads).abs();
    final pitch = housing.width;
    final full = travel - pitch;
    if (full <= 0 || thick <= 0) return;
    final span = (travel * openFraction.clamp(0.0, 1.0) - pitch)
        .clamp(0.0, full);
    if (span <= 0) return;

    // Each face of a fold is as long as the screen's track is deep, so the
    // gathered screen fits its track exactly; and there are enough folds
    // that fully out they still stand a little proud of flat.
    final fold = thick;
    final folds = math.max(1, (full / (2 * fold * _flattest)).ceil());
    final half = span / (2 * folds);
    final deep = math.sqrt(math.max(0.0, fold * fold - half * half));
    final middle = front - thick / 2;
    final from = piece.at.x + into * pitch;
    final box = section.outline;

    for (var i = 0; i < 2 * folds; i++) {
      final x0 = from + into * i * half, x1 = from + into * (i + 1) * half;
      final z0 = middle + (i.isEven ? deep / 2 : -deep / 2);
      final z1 = middle + (i.isEven ? -deep / 2 : deep / 2);
      out.add(Facet(
        corners: [
          Vec3(x0, box.top, z0),
          Vec3(x1, box.top, z1),
          Vec3(x1, box.bottom, z1),
          Vec3(x0, box.bottom, z0),
        ],
        elementId: piece.id,
        // Each fold faces its own way and is lit as it faces: nothing is
        // darkened here to make it look folded.
        colour: piece.finish.colour,
        surface: piece.finish.material.surface,
        transparency: piece.finish.material.transparency,
        gloss: piece.finish.material.gloss,
        role: FacetRole.glazing,
      ).inPart('pleats'));
    }
  }

  /// An automatic entrance's sensor, on the outside face of the head: the
  /// face somebody walks up to it from.
  static void _addSensor(
    List<Facet> out,
    Design design,
    HardwareElement piece,
    double depth,
  ) {
    final housing = OpeningHardware.footprintOf(design, piece);
    if (housing == null) return;
    final stand = housing.height * 0.8;
    final outside = design.seenFrom == Face.outside;
    _addSlab(out, housing, outside ? stand : -depth, stand, piece.id,
        piece.finish, FacetRole.hardware);
  }

  /// A knob on its rose: a stem out of the leaf and a ball on the end.
  static void _addKnob(
    List<Facet> out,
    Furniture f,
    double face,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final id = piece.id;
    final finish = piece.finish;

    final rose = f.knobRose;
    _slabBetween(out, rose, face + 4 * scale, 4 * scale, id, finish,
        FacetRole.hardware, put);

    // The stem, and then the knob itself: rings swelling and closing again,
    // which is a turned ball rather than a cylinder with a lid.
    final path = <Vec3>[];
    final radii = <double>[];
    const steps = Furniture.knobSteps;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      path.add(Vec3(piece.at.x, piece.at.y, face + 4 * scale + 52 * scale * t));
      radii.add(f.knobRadius(t));
    }
    _tube(out, path, radii, id, finish, put);
  }

  /// The escutcheon below the lever: a plate with the keyhole through it.
  static void _addEscutcheon(
    List<Facet> out,
    Furniture f,
    double face,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final plate = f.escutcheon;
    _slabBetween(out, plate, face + 4 * scale, 4 * scale, piece.id,
        piece.finish, FacetRole.hardware, put);

    // The keyhole is a hole, so it is built as one: a short bore sunk into
    // the plate, dark because nothing in it catches the light.
    final dark = Finish(
      colour: _darken(piece.finish.colour, 0.28),
      material: piece.finish.material,
    );
    final mouth = Vec3(f.keyholeAt.x, f.keyholeAt.y, face + 4 * scale);
    _sweep(
      out,
      _ring(mouth, const Vec3(1, 0, 0), const Vec3(0, 1, 0), f.keyholeRadius),
      Vec3(0, 0, -5 * scale),
      piece.id,
      dark,
      put,
      capStart: false,
    );
    final ward = f.keyWard;
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
    Furniture f,
    double face,
    double outward,
    Vec3 Function(Vec3) put,
  ) {
    final piece = f.piece;
    final scale = f.scale;
    final sideHung = f.sideHung;
    final knuckleLength = f.knuckleLength;

    final leaf = f.hingeLeaf;
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
      _ring(start, u, const Vec3(0, 0, 1), f.knuckleRadius),
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
      ringAround(centre, u, v, radius, sides: sides);

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
          FacetRole.hardware);
    }
    if (capEnd) {
      _quad(out, [for (final p in far) place(p)], elementId, finish,
          FacetRole.hardware);
    }
    for (var i = 0; i < ring.length; i++) {
      final j = (i + 1) % ring.length;
      // Each facet round it faces a different way, so the renderer lights
      // each differently: that is what makes it read as a cylinder.
      _quad(out, [
        place(ring[i]),
        place(ring[j]),
        place(far[j]),
        place(far[i]),
      ], elementId, finish, FacetRole.hardware);
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

    final rings = tubeRings(path, radii, sides: sides);

    _quad(out, [for (final p in rings.first.reversed) put(p)], elementId,
        finish, FacetRole.hardware);
    _quad(out, [for (final p in rings.last) put(p)], elementId, finish,
        FacetRole.hardware);

    for (var i = 0; i + 1 < rings.length; i++) {
      for (var j = 0; j < sides; j++) {
        final k = (j + 1) % sides;
        _quad(out, [
          put(rings[i][j]),
          put(rings[i][k]),
          put(rings[i + 1][k]),
          put(rings[i + 1][j]),
        ], elementId, finish, FacetRole.hardware);
      }
    }
  }
}

/// A sliding design as the thing it is: panels standing on tracks in the
/// depth of the frame.
///
/// **Every panel stands in the frame, on a track of its own.** The fixed
/// panels share the outermost track; each sliding panel stands on the first
/// track behind that where it will not run into anything on its way — so a
/// slider beside a fixed light runs behind it, two sliders that pass each
/// other are on two tracks, and two that part in the middle of a four-panel
/// door share one, because they never meet. Which track that is follows from
/// where the panels are and which way they go, nothing else.
///
/// **A panel reaches to the middle of the line it meets its neighbour at.**
/// The line the user drew between two panels is where they meet, and that
/// meeting is the two panels' own stiles, one on each track, rather than a
/// post in the frame. A post there would stand in the very track the slider
/// runs along.
class _Tracks {
  final Design design;
  final FrameElement frame;
  final double depth;
  final Map<String, int> _track;

  /// How many tracks the frame holds.
  final int count;

  _Tracks._(
    this.design,
    this.frame,
    this.depth,
    this._track,
    this.count, {
    this.screened = false,
  });

  /// How much of its track a panel fills: the rest is the clearance that
  /// keeps two panels on neighbouring tracks from touching.
  static const _fills = 0.86;

  static _Tracks of(
    Design design,
    DesignTree tree,
    FrameElement frame,
    double depth,
  ) {
    // The ground each panel covers: its own, and for a slider everything it
    // passes over on its way open.
    final spans = <String, (double, double)>{};
    final sliders = <String>[];
    for (final branch in tree.sections) {
      final section = design.sectionById(branch.sectionId);
      if (section == null) continue;
      final box = section.outline;
      final opening =
          branch.opens ? design.openingById(branch.openingId!) : null;
      final leads = opening?.mechanism.slideEdge;
      if (leads == null) {
        spans[section.id] = (box.left, box.right);
        continue;
      }
      final travel = MeshBuilder._travelOf(design, section, leads);
      spans[section.id] = (
        math.min(box.left, box.left + travel),
        math.max(box.right, box.right + travel),
      );
      sliders.add(section.id);
    }

    final track = <String, int>{
      for (final id in spans.keys)
        if (!sliders.contains(id)) id: 0,
    };
    bool clash(String a, String b) =>
        spans[a]!.$1 < spans[b]!.$2 - 1 && spans[b]!.$1 < spans[a]!.$2 - 1;
    for (final id in sliders) {
      var t = 1;
      while (track.entries.any((e) => e.value == t && clash(e.key, id))) {
        t++;
      }
      track[id] = t;
    }

    // Numbered from the outermost track anything actually stands on.
    final lowest = track.values.fold(1 << 30, math.min);
    final numbered = {
      for (final e in track.entries) e.key: e.value - lowest,
    };
    final panels = numbered.values.fold(0, math.max) + 1;

    // A pleated screen runs in a track of its own behind every panel, so
    // it can fan out across the passage without meeting any of them.
    final screened = design.openings.any(
      (o) => o.pleatedScreen && o.mechanism.slideEdge != null,
    );
    return _Tracks._(design, frame, depth, numbered,
        panels + (screened ? 1 : 0),
        screened: screened);
  }

  /// Whether the innermost track is a screen's.
  final bool screened;

  /// The screen's track: where its face is, and how deep it is.
  ({double front, double depth})? get screenBand => screened
      ? (front: _frontOf(count - 1), depth: depth / count)
      : null;

  /// The track [sectionId] stands on, 0 the outermost.
  int trackOf(String sectionId) => _track[sectionId] ?? 0;

  /// Where the face of track [k] is: the outermost at the face of the
  /// frame that is outside.
  double _frontOf(int k) {
    final each = depth / count;
    return design.seenFrom == Face.outside
        ? -k * each
        : -(count - 1 - k) * each;
  }

  /// The panel in [section], on its track: a sliding panel runs along it,
  /// and a fixed one is a sash standing on it.
  void addPanel(
    List<Facet> out,
    TreeSection branch,
    SectionElement section,
    double openFraction,
  ) {
    final each = depth / count;
    // The depth the leaf builders are given so that the leaf they build is
    // as thick as its share of the track, and the shift that stands it
    // there.
    final asBuilt = each * _fills / MeshBuilder._leafDepth(1);
    final shift = _frontOf(trackOf(section.id)) -
        each * (1 - _fills) / 2 -
        MeshBuilder.leafFront(asBuilt);
    Vec3 onTrack(Vec3 p) => Vec3(p.x, p.y, p.z + shift);

    final outline = DesignGeometry.of(design).leafOuter(section);
    final opening =
        branch.opens ? design.openingById(branch.openingId!) : null;
    if (opening != null) {
      MeshBuilder._addLeaf(
        out,
        design,
        branch,
        section,
        opening,
        frame,
        asBuilt,
        openFraction,
        place: onTrack,
      );
      return;
    }
    MeshBuilder._addSash(
      out,
      design,
      branch,
      section,
      frame,
      asBuilt,
      openFraction,
      outline,
      DesignGeometry.of(design).leafInner(section) ?? const Polygon([]),
      onTrack,
    );
  }
}

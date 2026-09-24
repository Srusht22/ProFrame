import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../model/materials.dart';
import '../model/opening_leaf.dart';

/// The hinges and handle an opening carries.
///
/// An opening exists only because the user marked a section with `<`, `>`,
/// `^` or `v`. Having said that a section opens, they have said it hangs on
/// something and is worked by something, so the hinges and the handle are
/// part of what they asked for rather than parts added on the application's
/// own initiative. A section with no mark on it gets none of this, however
/// door-shaped it is.
///
/// The pieces are worked out from the opening every time rather than placed
/// once and remembered. That is what makes them the opening's: change the
/// direction and the hinges change sides, resize the leaf and they stay on
/// its edges, move the leaf and they move with it. Nothing drifts, because
/// there is nothing to drift — the positions are a function of the opening.
///
/// Where the user has said where a piece goes, their figure is used exactly.
/// The defaults below only fill in what they have not said.
abstract final class OpeningHardware {
  /// How far the outer hinges stand in from the ends of the hinged edge,
  /// until the user says otherwise.
  static const double defaultEndInsetMm = 200;

  /// How far the keyhole sits below the lever, until the user says.
  ///
  /// A mortice lock's keyway is below its follower by the lock's own case,
  /// and on the stock sizes a joiner buys that is about this far.
  static const double lockBelowHandleMm = 72;

  /// A hinged edge this long or shorter carries the fewest hinges.
  static const double hingePerMm = 1000;

  /// [design] with the hardware of its openings worked out afresh.
  ///
  /// Run after anything that changes an opening or the section under it.
  /// What the user placed by hand is theirs and is left exactly where it is;
  /// everything belonging to an opening is replaced, so a piece can never
  /// outlive the opening it hangs on or be left behind by one that moved.
  static Design settle(Design design) => design.copyWith(
        hardware: [...placedByHand(design), ...of(design)],
      );

  /// The hardware the user put there themselves.
  static List<HardwareElement> placedByHand(Design design) => [
        for (final piece in design.hardware)
          if (!piece.isOpeningHardware) piece,
      ];

  /// Every piece of hardware the openings on [design] carry.
  ///
  /// In the design's own order, so the list is stable and an edit that
  /// changes nothing produces the same list byte for byte.
  static List<HardwareElement> of(Design design) {
    final pieces = <HardwareElement>[];
    for (final opening in design.openings) {
      pieces.addAll(forOpening(design, opening));
    }
    return pieces;
  }

  /// The hinges and handle of one opening, or nothing when the opening has
  /// no hinged edge — a sliding or pivoting leaf hangs on neither side, and
  /// guessing an edge for it would be inventing the design.
  static List<HardwareElement> forOpening(
    Design design,
    OpeningElement opening,
  ) {
    final section = design.sectionById(opening.sectionId);
    if (section == null) return const [];
    final outline = section.outline;
    if (outline.width <= 0 || outline.height <= 0) return const [];

    // **A sliding panel hangs on no hinge and is pulled, not turned.** It
    // carries one thing: a pull on the stile it closes with — the edge
    // *away from* the way it slides, which meets the jamb or its partner
    // when it is shut. That is where a hand takes it to draw it open, and
    // where the user's own photographs of sliding doors have it; a pull on
    // the leading stile would run into the panel it slides behind. So the
    // edge it leads with stands where a hinged leaf's hinges would, and the
    // handle is opposite it, half way up, by the same rule as every handle.
    final leads = opening.mechanism.slideEdge;
    if (leads != null) {
      final id = '${opening.id}-handle';
      final pull = handleAt(opening, outline.left, outline.right, outline.top,
          outline.bottom, leads);
      return [
        HardwareElement(
          id: id,
          kind: opening.handleKind ?? HardwareKind.pull,
          parentId: opening.id,
          at: pull,
          rotation: 90,
          finish: _finishOf(design, id),
        ),
        // The screen's cassette stands at the jamb the panel closes against
        // — the stile its pull is on — so the screen fans out across exactly
        // the passage the panel uncovers, and nowhere else.
        if (opening.pleatedScreen)
          HardwareElement(
            id: '${opening.id}-screen',
            kind: HardwareKind.screen,
            parentId: opening.id,
            at: Vec2(pull.x, (outline.top + outline.bottom) / 2),
            rotation: 90,
            finish: _finishOf(design, '${opening.id}-screen',
                fresh: screenFinish),
          ),
        ?_sensorFor(design, opening),
      ];
    }

    final edge = opening.mechanism.hingeEdge;
    if (edge == null) return const [];

    // The hinged edge, and the one opposite it that the handle is on.
    final sideHung = edge == OpeningEdge.left || edge == OpeningEdge.right;
    final along = sideHung ? outline.height : outline.width;
    final from = sideHung ? outline.top : outline.left;

    final hingeX = switch (edge) {
      OpeningEdge.left => outline.left,
      OpeningEdge.right => outline.right,
      _ => 0.0,
    };
    final hingeY = switch (edge) {
      OpeningEdge.top => outline.top,
      OpeningEdge.bottom => outline.bottom,
      _ => 0.0,
    };

    final pieces = <HardwareElement>[];

    final count = hingeCount(opening, along);
    final insets = _insets(opening, along, count);
    for (var i = 0; i < count; i++) {
      final at = from + insets[i];
      final id = '${opening.id}-hinge-$i';
      pieces.add(HardwareElement(
        id: id,
        kind: HardwareKind.hinge,
        parentId: opening.id,
        at: sideHung ? Vec2(hingeX, at) : Vec2(at, hingeY),
        rotation: sideHung ? 90 : 0,
        finish: _finishOf(design, id),
      ));
    }

    final kind = design.kindOf(opening);
    final handleAtPoint = handleAt(opening, outline.left, outline.right,
        outline.top, outline.bottom, edge);

    // **A leaf nobody has named yet carries no handle**, and that is not an
    // omission. The mark says this section opens, so it hangs on the hinges
    // above whatever else is true of it; which handle it is worked by is the
    // question still outstanding, and a door's lever and a window's fastener
    // are different manufactured objects. Putting one of them on to have
    // something there would be the application answering its own question,
    // and the user would find a decision they never made already built. It
    // appears the moment they say, which in a door-and-window design is the
    // moment they answer the dialog the opening raised.
    final form = opening.handleKind ??
        switch (kind) {
          // A lever is what a door has until they say otherwise, and a
          // window's fastener keeps the plain form it had.
          DesignKind.door => HardwareKind.lever,
          DesignKind.window => HardwareKind.handle,
          DesignKind.both || DesignKind.sliding || null => null,
        };
    if (form != null) {
      pieces.add(HardwareElement(
        id: '${opening.id}-handle',
        kind: form,
        parentId: opening.id,
        at: handleAtPoint,
        rotation: sideHung ? 90 : 0,
        finish: _finishOf(design, '${opening.id}-handle'),
      ));
    }

    // **A door locks; a window fastens.** So a door carries an escutcheon
    // under its lever and a window carries none — which is the user's
    // answer about this leaf deciding what is built on it, not a shape the
    // application picked. A door with a top or bottom hung leaf is a hatch
    // and has nowhere sensible for a keyhole, so it gets none either.
    if (kind == DesignKind.door && sideHung) {
      pieces.add(HardwareElement(
        id: '${opening.id}-lock',
        kind: HardwareKind.lock,
        parentId: opening.id,
        at: Vec2(
          handleAtPoint.x,
          math.min(handleAtPoint.y + lockBelowHandleMm, outline.bottom - 40),
        ),
        rotation: 90,
        finish: _finishOf(design, '${opening.id}-lock'),
      ));
    }

    return pieces;
  }

  /// The finish the piece with this id is already wearing.
  ///
  /// **The ironmongery is worked out again on every rebuild, so anything the
  /// user said about it has to be carried across or it is thrown away.** A
  /// handle set to silver went back to the stock grey at the next edit —
  /// the panel appeared to work and then quietly undid itself, which is
  /// worse than not offering the control at all. The pieces have settled
  /// ids, so the one being replaced is found by id, exactly as an opening's
  /// own answers are carried in `DesignEdits.setOpening`.
  ///
  /// Only the finish is carried. Where a piece *is* is worked out from the
  /// leaf every time and must stay that way, or a resize would leave the
  /// handle where the old leaf had it.
  static Finish _finishOf(Design design, String id, {Finish? fresh}) {
    for (final piece in design.hardware) {
      if (piece.id == id) return piece.finish;
    }
    if (fresh != null) return fresh;
    return const HardwareElement(
      id: '',
      kind: HardwareKind.handle,
      at: Vec2.zero,
    ).finish;
  }

  /// How much of its leaf's height a sliding panel's pull bar runs.
  ///
  /// A pull is gripped by a whole hand drawing a heavy panel along, so it is
  /// a long bar rather than a lever — the user's own references show one
  /// running a good part of the stile — and it is sized from the leaf, so a
  /// tall door gets a long one and a low window a short one.
  static const double pullOfLeafHeight = 0.35;

  /// How long [piece]'s pull bar is, from the leaf it is on.
  static double pullLengthOf(Design design, HardwareElement piece) {
    final opening = design.openingHolding(piece.parentId);
    final box = opening == null
        ? null
        : design.sectionById(opening.sectionId)?.outline;
    return (box?.height ?? 0) * pullOfLeafHeight;
  }

  /// Where a piece that stays on the frame stands on the drawing, or null
  /// for every other piece.
  ///
  /// A screen's cassette is as wide as a sash stile — the stile of the shut
  /// panel stands in front of it — and runs the leaf's height, from the
  /// jamb into the passage the panel uncovers. A sensor sits on the head:
  /// as tall as a little over half the head, and a few times as long as it
  /// is tall, as a sensor housing is. Both drawings and the solid read this,
  /// so the three cannot put either somewhere different.
  static Polygon? footprintOf(Design design, HardwareElement piece) {
    final frame = design.frame;
    if (frame == null) return null;
    final opening = design.openingHolding(piece.parentId);
    switch (piece.kind) {
      case HardwareKind.screen:
        final box = opening == null
            ? null
            : design.sectionById(opening.sectionId)?.outline;
        final leads = opening?.mechanism.slideEdge;
        if (box == null || leads == null) return null;
        final into = leads == OpeningEdge.left ? -1.0 : 1.0;
        final wide = OpeningLeaf.profileFor(frame);
        final x0 = piece.at.x, x1 = piece.at.x + into * wide;
        return Polygon.rect(
            math.min(x0, x1), box.top, math.max(x0, x1), box.bottom);
      case HardwareKind.sensor:
        final head = frame.innerOutline.top - frame.outline.top;
        final tall = head * 0.6;
        final long = tall * 4;
        return Polygon.rect(piece.at.x - long / 2, piece.at.y - tall / 2,
            piece.at.x + long / 2, piece.at.y + tall / 2);
      default:
        return null;
    }
  }

  /// What a pleated screen is made of until the user says otherwise: pale
  /// insect mesh, which is what one is.
  static const screenFinish =
      Finish(colour: 0xFFE9E6DC, material: MaterialKind.mesh);

  /// The sensor over the automatic leaves [opening] is one of, carried by
  /// the first of them in reading order — or null when [opening] is not
  /// automatic or is not that first one.
  ///
  /// **One sensor for the entrance, not one per leaf.** The two leaves of a
  /// centre-opening door open together because one sensor sees somebody
  /// coming, so it stands on the head over the middle of all the automatic
  /// leaves together — which for a pair parting in the middle is the line
  /// they meet at, as in the user's reference.
  static HardwareElement? _sensorFor(Design design, OpeningElement opening) {
    if (!opening.automatic) return null;
    final frame = design.frame;
    if (frame == null) return null;
    final automatic = [
      for (final o in design.openingsInOrder)
        if (o.automatic && o.mechanism.slideEdge != null) o,
    ];
    if (automatic.isEmpty || automatic.first.id != opening.id) return null;

    var left = double.infinity, right = double.negativeInfinity;
    for (final o in automatic) {
      final box = design.sectionById(o.sectionId)?.outline;
      if (box == null) continue;
      left = math.min(left, box.left);
      right = math.max(right, box.right);
    }
    if (!left.isFinite) return null;
    // On the head, half way through its own depth of material.
    final head = (frame.outline.top + frame.innerOutline.top) / 2;
    final id = '${opening.id}-sensor';
    return HardwareElement(
      id: id,
      kind: HardwareKind.sensor,
      parentId: opening.id,
      at: Vec2((left + right) / 2, head),
      finish: _finishOf(design, id),
    );
  }

  /// How many hinges an opening carries.
  ///
  /// Two holds a leaf; a long one wants a third in the middle so it does not
  /// bow. That is the whole rule, and the user can say otherwise.
  static int hingeCount(OpeningElement opening, double alongMm) {
    final said = opening.hingeCount;
    if (said != null) return said.clamp(0, 8);
    return (2 + (alongMm / hingePerMm).floor()).clamp(2, 4);
  }

  /// Where the handle sits on a leaf of this extent, hung on [edge].
  ///
  /// **The middle of the edge it is on, on every leaf.** A handle is worked
  /// from the opening edge, so which edge that is comes from how the leaf is
  /// hung; how far along it is the middle of that edge, and the user's own
  /// figure overrides it wherever they want it.
  ///
  /// It used to depend on what the leaf was: a window's fastener at the
  /// middle of the stile and a door's lever a fixed metre up. Two rules meant
  /// the handle jumped when the answer to *door or window* changed, on a leaf
  /// whose geometry had not moved at all, and the fixed metre was a figure
  /// with nothing in the drawing behind it — right on a leaf of one height
  /// and wrong on every other. The middle is derived from the leaf, as every
  /// other position in this repository is, and it is the same rule the top
  /// and bottom hung cases already used.
  static Vec2 handleAt(
    OpeningElement opening,
    double left,
    double right,
    double top,
    double bottom,
    OpeningEdge edge,
  ) {
    final sideHung = edge == OpeningEdge.left || edge == OpeningEdge.right;
    if (sideHung) {
      // On the stile opposite the hinges, at a height up from the sill.
      final height = bottom - top;
      final up = (opening.handleAlongMm ?? height / 2)
          .clamp(0.0, math.max(0.0, height));
      final x = edge == OpeningEdge.left ? right : left;
      return Vec2(x, bottom - up);
    }
    // On the rail opposite the hinges, along from the left.
    final width = right - left;
    final across = (opening.handleAlongMm ?? width / 2)
        .clamp(0.0, math.max(0.0, width));
    final y = edge == OpeningEdge.top ? bottom : top;
    return Vec2(left + across, y);
  }


  /// Where each hinge sits along the hinged edge, measured from its start.
  ///
  /// The outer two stand in from the ends by the user's figures, or by the
  /// default stand-off; any others are spaced evenly between them, because
  /// evenly is the only spacing that is not a choice about where they look
  /// best.
  static List<double> _insets(
    OpeningElement opening,
    double alongMm,
    int count,
  ) {
    if (count <= 0) return const [];
    final room = math.max(alongMm, 1.0);
    final start =
        (opening.hingeFromStartMm ?? defaultEndInsetMm).clamp(0.0, room / 2);
    final end =
        (opening.hingeFromEndMm ?? defaultEndInsetMm).clamp(0.0, room / 2);
    if (count == 1) return [room / 2];

    final first = start;
    final last = room - end;
    return [
      for (var i = 0; i < count; i++)
        first + (last - first) * (i / (count - 1)),
    ];
  }
}

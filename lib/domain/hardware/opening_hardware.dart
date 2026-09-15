import 'dart:math' as math;

import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';

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

  /// How high the handle sits above the bottom of a side-hung leaf, until
  /// the user says otherwise. A metre is where a hand falls on a door.
  static const double defaultHandleHeightMm = 1000;

  /// How much stile must be left above the handle for a metre to be the
  /// sensible height. A sash shorter than this has its fastener in the
  /// middle of the stile instead, which is where a window's is.
  static const double handleHeadroomMm = 150;

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
    final edge = opening.mechanism.hingeEdge;
    if (edge == null) return const [];

    final outline = section.outline;
    if (outline.width <= 0 || outline.height <= 0) return const [];

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
      pieces.add(HardwareElement(
        id: '${opening.id}-hinge-$i',
        kind: HardwareKind.hinge,
        parentId: opening.sectionId,
        at: sideHung ? Vec2(hingeX, at) : Vec2(at, hingeY),
        rotation: sideHung ? 90 : 0,
      ));
    }

    pieces.add(HardwareElement(
      id: '${opening.id}-handle',
      kind: HardwareKind.handle,
      parentId: opening.sectionId,
      at: handleAt(opening, outline.left, outline.right, outline.top,
          outline.bottom, edge),
      rotation: sideHung ? 90 : 0,
    ));

    return pieces;
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

  /// Where the handle sits, given the opening and the leaf's extent.
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
      final up = (opening.handleAlongMm ?? defaultHeightIn(height))
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

  /// How high the handle goes on a side-hung leaf [heightMm] tall, when the
  /// user has not said.
  ///
  /// A metre up, which is where a hand falls on a door — unless the leaf is
  /// too short for that to leave any stile above it, in which case the
  /// middle, which is where a window's fastener goes.
  static double defaultHeightIn(double heightMm) =>
      heightMm - defaultHandleHeightMm >= handleHeadroomMm
          ? defaultHandleHeightMm
          : heightMm / 2;

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

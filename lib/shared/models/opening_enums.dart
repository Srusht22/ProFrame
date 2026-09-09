/// Is this a door or a window? It changes defaults (threshold vs sill, handle
/// height, minimum sizes) but not the underlying geometry engine.
enum OpeningKind { door, window }

extension OpeningKindInfo on OpeningKind {
  String get label => this == OpeningKind.door ? 'Door' : 'Window';
}

/// Which way the hinges are and how the leaf moves. This is the single value
/// the recogniser has to get right from the diagonals on the paper.
enum CellOperation {
  fixed,
  casementLeft,
  casementRight,
  awning,
  hopper,
  slidingLeft,
  slidingRight,
  tiltTurnLeft,
  tiltTurnRight,
  doorLeafLeft,
  doorLeafRight,
}

enum HingeSide { left, right, top, bottom, none }

extension CellOperationInfo on CellOperation {
  String get label => switch (this) {
        CellOperation.fixed => 'Fixed',
        CellOperation.casementLeft => 'Casement, hinged left',
        CellOperation.casementRight => 'Casement, hinged right',
        CellOperation.awning => 'Awning (top hung)',
        CellOperation.hopper => 'Hopper (bottom hung)',
        CellOperation.slidingLeft => 'Sliding to the left',
        CellOperation.slidingRight => 'Sliding to the right',
        CellOperation.tiltTurnLeft => 'Tilt & turn, hinged left',
        CellOperation.tiltTurnRight => 'Tilt & turn, hinged right',
        CellOperation.doorLeafLeft => 'Door leaf, hinged left',
        CellOperation.doorLeafRight => 'Door leaf, hinged right',
      };

  /// A moving leaf needs its own sash profile, hinges and a handle.
  bool get isOperable => this != CellOperation.fixed;

  bool get isSliding =>
      this == CellOperation.slidingLeft || this == CellOperation.slidingRight;

  bool get isDoorLeaf =>
      this == CellOperation.doorLeafLeft || this == CellOperation.doorLeafRight;

  HingeSide get hingeSide => switch (this) {
        CellOperation.casementLeft ||
        CellOperation.tiltTurnLeft ||
        CellOperation.doorLeafLeft =>
          HingeSide.left,
        CellOperation.casementRight ||
        CellOperation.tiltTurnRight ||
        CellOperation.doorLeafRight =>
          HingeSide.right,
        CellOperation.awning => HingeSide.top,
        CellOperation.hopper => HingeSide.bottom,
        _ => HingeSide.none,
      };

  /// Mirrors the operation left↔right, used by the "flip hinge side" action.
  CellOperation get mirrored => switch (this) {
        CellOperation.casementLeft => CellOperation.casementRight,
        CellOperation.casementRight => CellOperation.casementLeft,
        CellOperation.slidingLeft => CellOperation.slidingRight,
        CellOperation.slidingRight => CellOperation.slidingLeft,
        CellOperation.tiltTurnLeft => CellOperation.tiltTurnRight,
        CellOperation.tiltTurnRight => CellOperation.tiltTurnLeft,
        CellOperation.doorLeafLeft => CellOperation.doorLeafRight,
        CellOperation.doorLeafRight => CellOperation.doorLeafLeft,
        _ => this,
      };
}

/// Which way an operable leaf swings relative to the building.
enum SwingDirection { inward, outward, none }

extension SwingDirectionInfo on SwingDirection {
  String get label => switch (this) {
        SwingDirection.inward => 'Opens inward',
        SwingDirection.outward => 'Opens outward',
        SwingDirection.none => 'No swing',
      };
}

/// What fills the aperture.
enum CellInfill { glass, panel, louvre, mesh, open }

extension CellInfillInfo on CellInfill {
  String get label => switch (this) {
        CellInfill.glass => 'Glass',
        CellInfill.panel => 'Solid panel',
        CellInfill.louvre => 'Louvre',
        CellInfill.mesh => 'Insect mesh',
        CellInfill.open => 'Open',
      };
}

/// Looks an enum up by its stored name, falling back rather than throwing so a
/// design saved by an older build still loads.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

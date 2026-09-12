/// What is being designed.
enum ProductCategory {
  door('Door'),
  window('Window');

  final String label;

  const ProductCategory(this.label);
}

/// The frame material family.
///
/// This is not a colour label: the choice determines profile geometry,
/// clearances, glazing options and size limits (spec section 6). The actual
/// numbers live on [ProfileSystem].
enum FrameMaterial {
  pvc('PVC'),
  aluminium('Aluminium');

  final String label;

  const FrameMaterial(this.label);
}

/// Whether the drawing is seen from the outside or the inside.
///
/// Handing is meaningless without this, so it is a stored property of the
/// project and is stated on screen wherever a hinge side is shown. It is never
/// inferred from a symbol (spec section 3C).
enum ViewingSide {
  outside('Viewed from outside'),
  inside('Viewed from inside');

  final String label;

  const ViewingSide(this.label);

  ViewingSide get opposite =>
      this == ViewingSide.outside ? ViewingSide.inside : ViewingSide.outside;
}

/// What the entered width and height refer to.
///
/// A wall opening is not a frame size. Mixing them up scraps a frame, so the
/// reference is explicit on every project and no allowance is ever applied
/// behind the user's back (spec section 3D).
enum DimensionReference {
  /// The outside of the frame — what the factory manufactures to.
  outerFrame(
    'Outer frame size',
    'The size of the frame itself, outside edge to outside edge.',
  ),

  /// The hole in the wall. Reaching a frame size from this needs a fitting
  /// allowance, which the user sets and can see.
  wallOpening(
    'Wall opening size',
    'The size of the hole in the wall. A fitting gap is subtracted to get the '
        'frame size, and you choose that gap.',
  );

  final String label;
  final String description;

  const DimensionReference(this.label, this.description);
}

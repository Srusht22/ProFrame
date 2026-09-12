import 'product_basics.dart';

/// What a panel does, using the factory's own labels (spec section 3C).
enum PanelBehaviour {
  /// CH — fixed. Does not open.
  fixed('CH', 'Fixed', 'Does not open.'),

  /// Z — an opening sash or door leaf.
  opening('Z', 'Opening', 'An opening sash or door leaf.');

  /// The label the factory uses. Shown alongside [name] rather than instead of
  /// it, because a new salesperson does not yet know what CH means.
  final String code;
  final String label;
  final String description;

  const PanelBehaviour(this.code, this.label, this.description);

  bool get isFixed => this == PanelBehaviour.fixed;
  bool get isOpening => this == PanelBehaviour.opening;
}

/// How an opening panel moves.
///
/// Every value here has geometry behind it and an animation that shows it.
/// Nothing is listed that the renderer cannot draw: the specification forbids
/// showing nonfunctional choices (spec section 3C), so a mechanism appears in
/// this enum only once its motion is implemented and tested.
///
/// Phase 2 shipped [hinged] alone. Phase 3 adds the other three with their
/// geometry in `domain/rendering/scene_builder.dart` and their tests.
///
/// The slide direction is part of the mechanism rather than a separate field,
/// so each value is a complete description of one motion and there is no way
/// to store a sliding sash that does not say which way it goes.
enum OpeningMechanism {
  hinged('Hinged', 'Swings on hinges at one edge.'),
  tilt('Tilt', 'Bottom-hung: the top tilts inward.'),
  slidingLeft('Slides left', 'Slides across the panel to its left.'),
  slidingRight('Slides right', 'Slides across the panel to its right.');

  final String label;
  final String description;

  const OpeningMechanism(this.label, this.description);

  /// Whether a hinge side has to be chosen for this mechanism.
  ///
  /// Only a swinging sash has one. A tilt is always bottom-hung and a sliding
  /// sash has a direction instead, so asking for a hinge side on either would
  /// be asking a question with no answer.
  bool get needsHingeSide => this == OpeningMechanism.hinged;

  /// Whether the leaf moves through the frame depth, making inward or outward
  /// a real choice. A sliding sash stays in its track either way.
  bool get needsSwingDirection =>
      this == OpeningMechanism.hinged || this == OpeningMechanism.tilt;

  bool get isSliding =>
      this == OpeningMechanism.slidingLeft ||
      this == OpeningMechanism.slidingRight;
}

/// Which edge the hinges are on.
///
/// Meaningful only when the mechanism is [OpeningMechanism.hinged] — see
/// [OpeningMechanism.needsHingeSide].
///
/// Always read together with the project's [ViewingSide]: "hinges on the left"
/// means the left of the elevation as drawn, and the app states which side
/// that is wherever this is shown (spec section 3C).
enum HingeSide {
  left('Hinges on the left'),
  right('Hinges on the right'),
  top('Hinges at the top'),
  bottom('Hinges at the bottom');

  final String label;

  const HingeSide(this.label);

  bool get isVerticalAxis => this == HingeSide.left || this == HingeSide.right;
}

/// Which way the leaf swings.
enum OpeningDirection {
  inward('Opens inward'),
  outward('Opens outward');

  final String label;

  const OpeningDirection(this.label);
}

/// The full opening specification for a Z panel.
///
/// A fixed (CH) panel has none of this: the absence of an [OpeningSpec] is
/// what makes it fixed, so there is no way to have a panel that is fixed and
/// carries a stale hinge side at the same time.
class OpeningSpec {
  final OpeningMechanism mechanism;
  final HingeSide hingeSide;
  final OpeningDirection direction;

  /// True once the user has actually chosen these rather than accepting a
  /// starting position. Unconfirmed handing is shown as a question, never as a
  /// decision the app made (spec section 2).
  final bool isConfirmed;

  const OpeningSpec({
    required this.hingeSide,
    required this.direction,
    this.mechanism = OpeningMechanism.hinged,
    this.isConfirmed = false,
  });

  /// Describes this opening in a full sentence, including the viewing side,
  /// because "hinges on the left" is ambiguous without it.
  ///
  /// Only the parts that apply to this mechanism are mentioned: a sliding sash
  /// has no hinge side to state, and stating one anyway would imply a decision
  /// nobody made.
  String describe(ViewingSide viewedFrom) {
    final parts = <String>[
      if (mechanism.needsHingeSide) hingeSide.label else mechanism.label,
      if (mechanism.needsSwingDirection) direction.label.toLowerCase(),
    ];
    return '${parts.join(', ')} (${viewedFrom.label.toLowerCase()})';
  }

  OpeningSpec copyWith({
    OpeningMechanism? mechanism,
    HingeSide? hingeSide,
    OpeningDirection? direction,
    bool? isConfirmed,
  }) =>
      OpeningSpec(
        mechanism: mechanism ?? this.mechanism,
        hingeSide: hingeSide ?? this.hingeSide,
        direction: direction ?? this.direction,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );

  @override
  bool operator ==(Object other) =>
      other is OpeningSpec &&
      other.mechanism == mechanism &&
      other.hingeSide == hingeSide &&
      other.direction == direction &&
      other.isConfirmed == isConfirmed;

  @override
  int get hashCode => Object.hash(mechanism, hingeSide, direction, isConfirmed);

  Map<String, dynamic> toJson() => {
        'mechanism': mechanism.name,
        'hinge': hingeSide.name,
        'direction': direction.name,
        'confirmed': isConfirmed,
      };

  static OpeningSpec fromJson(Object? json, {String path = 'opening'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');

    final mechanismName = json['mechanism'];
    final mechanism = OpeningMechanism.values
        .where((m) => m.name == mechanismName)
        .firstOrNull;
    if (mechanism == null) {
      // A project saved by a future build that supports sliding would land
      // here. Refusing is correct: opening it would mean silently turning a
      // sliding sash into a hinged one.
      throw FormatException(
        '$path.mechanism is not a mechanism this version can open: '
        '$mechanismName',
      );
    }

    final hinge =
        HingeSide.values.where((h) => h.name == json['hinge']).firstOrNull;
    if (hinge == null) {
      throw FormatException('$path.hinge is not a known hinge side: ${json['hinge']}');
    }

    final direction = OpeningDirection.values
        .where((d) => d.name == json['direction'])
        .firstOrNull;
    if (direction == null) {
      throw FormatException(
        '$path.direction is not a known direction: ${json['direction']}',
      );
    }

    return OpeningSpec(
      mechanism: mechanism,
      hingeSide: hinge,
      direction: direction,
      isConfirmed: json['confirmed'] == true,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

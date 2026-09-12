import 'product_basics.dart';

/// What a section does, using the factory's own labels (spec section 3C).
enum SectionBehaviour {
  /// CH — fixed. Does not open.
  fixed('CH', 'Fixed', 'Does not open.'),

  /// Z — an opening sash or door leaf.
  opening('Z', 'Opening', 'An opening sash or door leaf.');

  /// The label the factory uses. Shown alongside [name] rather than instead of
  /// it, because a new salesperson does not yet know what CH means.
  final String code;
  final String label;
  final String description;

  const SectionBehaviour(this.code, this.label, this.description);

  bool get isFixed => this == SectionBehaviour.fixed;
  bool get isOpening => this == SectionBehaviour.opening;
}

/// How an opening section moves.
///
/// This enum contains exactly one value on purpose. The specification requires
/// fixed and hinged in the first complete implementation, and requires that
/// other mechanisms are added only once their geometry and behaviour are
/// actually implemented and tested — nonfunctional choices must not be shown
/// (spec section 3C).
///
/// Sliding, tilt-and-turn, top-hung and folding are therefore *absent*, not
/// present and disabled: an absent value cannot be serialised into a saved
/// project, cannot reach the 3D generator, and cannot appear in a picker built
/// from `values`. Adding one means adding its geometry and its tests in the
/// same change.
enum OpeningMechanism {
  hinged('Hinged', 'Swings on hinges at one edge.');

  final String label;
  final String description;

  const OpeningMechanism(this.label, this.description);
}

/// Which edge the hinges are on.
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

/// The full opening specification for a Z section.
///
/// A fixed (CH) section has none of this: the absence of an [OpeningSpec] is
/// what makes it fixed, so there is no way to have a section that is fixed and
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
  String describe(ViewingSide viewedFrom) =>
      '${hingeSide.label}, ${direction.label.toLowerCase()} '
      '(${viewedFrom.label.toLowerCase()})';

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

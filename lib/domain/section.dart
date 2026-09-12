import 'geometry/polygon.dart';
import 'product/infill.dart';
import 'product/opening.dart';

/// One region of the product: a pane, a panel, a door leaf.
///
/// The [id] is stable for the life of the section. It survives dimension
/// changes and divider moves, so a CH/Z assignment made once is not lost when
/// the geometry is edited (spec section 10). Splitting or merging sections
/// creates new ids, and the caller records what became of the old ones.
class Section {
  final String id;

  /// The region's outline in model space, in millimetres. This is the opening
  /// the section occupies, before profile faces are subtracted.
  final Polygon boundary;

  /// CH or Z.
  final SectionBehaviour behaviour;

  /// How it opens. Non-null exactly when [behaviour] is
  /// [SectionBehaviour.opening] — enforced by the constructor.
  final OpeningSpec? opening;

  final Infill infill;

  /// A short label the user can set, e.g. "kitchen side".
  final String label;

  Section({
    required this.id,
    required this.boundary,
    required this.behaviour,
    required this.infill,
    this.opening,
    this.label = '',
  }) {
    if (behaviour.isOpening && opening == null) {
      throw ArgumentError.value(
        opening,
        'opening',
        'A Z (opening) section must carry an OpeningSpec.',
      );
    }
    if (behaviour.isFixed && opening != null) {
      throw ArgumentError.value(
        opening,
        'opening',
        'A CH (fixed) section must not carry an OpeningSpec.',
      );
    }
  }

  /// A fixed pane.
  factory Section.fixed({
    required String id,
    required Polygon boundary,
    Infill infill = Glazing.doubleGlazed,
    String label = '',
  }) =>
      Section(
        id: id,
        boundary: boundary,
        behaviour: SectionBehaviour.fixed,
        infill: infill,
        label: label,
      );

  /// An opening sash or leaf.
  factory Section.opening({
    required String id,
    required Polygon boundary,
    required OpeningSpec opening,
    Infill infill = Glazing.doubleGlazed,
    String label = '',
  }) =>
      Section(
        id: id,
        boundary: boundary,
        behaviour: SectionBehaviour.opening,
        infill: infill,
        opening: opening,
        label: label,
      );

  double get widthMm => boundary.width;
  double get heightMm => boundary.height;
  double get areaMm2 => boundary.area.abs();

  /// True when this section still needs the user to say how it opens.
  bool get needsOpeningConfirmation =>
      behaviour.isOpening && !(opening?.isConfirmed ?? false);

  /// Returns a copy as CH, dropping any opening settings.
  Section asFixed() => Section(
        id: id,
        boundary: boundary,
        behaviour: SectionBehaviour.fixed,
        infill: infill,
        label: label,
      );

  /// Returns a copy as Z with [spec].
  Section asOpening(OpeningSpec spec) => Section(
        id: id,
        boundary: boundary,
        behaviour: SectionBehaviour.opening,
        infill: infill,
        opening: spec,
        label: label,
      );

  Section copyWith({Polygon? boundary, Infill? infill, String? label, OpeningSpec? opening}) =>
      Section(
        id: id,
        boundary: boundary ?? this.boundary,
        behaviour: behaviour,
        infill: infill ?? this.infill,
        opening: behaviour.isOpening ? (opening ?? this.opening) : null,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is Section &&
      other.id == id &&
      other.boundary == boundary &&
      other.behaviour == behaviour &&
      other.opening == opening &&
      other.infill == infill &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, boundary, behaviour, opening, infill, label);

  @override
  String toString() => 'Section($id, ${behaviour.code}, '
      '${widthMm.round()}x${heightMm.round()}mm)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'boundary': boundary.toJson(),
        'behaviour': behaviour.name,
        if (opening != null) 'opening': opening!.toJson(),
        'infill': infill.toJson(),
        if (label.isNotEmpty) 'label': label,
      };

  static Section fromJson(Object? json, {String path = 'section'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    final behaviour = SectionBehaviour.values
        .where((b) => b.name == json['behaviour'])
        .firstOrNull;
    if (behaviour == null) {
      throw FormatException(
        '$path.behaviour is not CH or Z: ${json['behaviour']}',
      );
    }
    final openingJson = json['opening'];
    if (behaviour.isOpening && openingJson == null) {
      throw FormatException('$path is a Z section but has no opening settings.');
    }
    final label = json['label'];
    return Section(
      id: id,
      boundary: Polygon.fromJson(json['boundary'], path: '$path.boundary'),
      behaviour: behaviour,
      infill: Infill.fromJson(json['infill'], path: '$path.infill'),
      opening: behaviour.isOpening
          ? OpeningSpec.fromJson(openingJson, path: '$path.opening')
          : null,
      label: label is String ? label : '',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

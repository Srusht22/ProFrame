import 'geometry/polygon.dart';
import 'product/infill.dart';
import 'product/opening.dart';

/// One region of the product: a pane, a panel, a door leaf.
///
/// The [id] is stable for the life of the panel. It survives dimension
/// changes and divider moves, so a CH/Z assignment made once is not lost when
/// the geometry is edited (spec section 10). Splitting or merging panels
/// creates new ids, and the caller records what became of the old ones.
class Panel {
  final String id;

  /// The region's outline in model space, in millimetres. This is the opening
  /// the panel occupies, before profile faces are subtracted.
  final Polygon boundary;

  /// CH or Z.
  final PanelBehaviour behaviour;

  /// How it opens. Non-null exactly when [behaviour] is
  /// [PanelBehaviour.opening] — enforced by the constructor.
  final OpeningSpec? opening;

  final Infill infill;

  /// A short label the user can set, e.g. "kitchen side".
  final String label;

  /// Free text the user attached to this panel — "توري", "فارغ",
  /// "frosted glass", a customer request (spec Phase 2, item 5).
  ///
  /// Deliberately free text rather than a fixed vocabulary: the factory's own
  /// shorthand is not something this app should try to enumerate, and a note
  /// the app cannot parse is still a note the fabricator can read. Carried
  /// through to exports.
  final String note;

  /// An insect screen (توري) is fitted to this panel.
  final bool hasMesh;

  /// The panel is left empty — no glass and no infill board (فارغ).
  ///
  /// Distinct from the choice of [infill]: the infill is remembered, so
  /// unticking this restores what was there rather than making the user pick
  /// again.
  final bool isEmpty;

  Panel({
    required this.id,
    required this.boundary,
    required this.behaviour,
    required this.infill,
    this.opening,
    this.label = '',
    this.note = '',
    this.hasMesh = false,
    this.isEmpty = false,
  }) {
    if (behaviour.isOpening && opening == null) {
      throw ArgumentError.value(
        opening,
        'opening',
        'A Z (opening) panel must carry an OpeningSpec.',
      );
    }
    if (behaviour.isFixed && opening != null) {
      throw ArgumentError.value(
        opening,
        'opening',
        'A CH (fixed) panel must not carry an OpeningSpec.',
      );
    }
  }

  /// A fixed pane.
  factory Panel.fixed({
    required String id,
    required Polygon boundary,
    Infill infill = Glazing.doubleGlazed,
    String label = '',
    String note = '',
    bool hasMesh = false,
    bool isEmpty = false,
  }) =>
      Panel(
        id: id,
        boundary: boundary,
        behaviour: PanelBehaviour.fixed,
        infill: infill,
        label: label,
        note: note,
        hasMesh: hasMesh,
        isEmpty: isEmpty,
      );

  /// An opening sash or leaf.
  factory Panel.opening({
    required String id,
    required Polygon boundary,
    required OpeningSpec opening,
    Infill infill = Glazing.doubleGlazed,
    String label = '',
    String note = '',
    bool hasMesh = false,
    bool isEmpty = false,
  }) =>
      Panel(
        id: id,
        boundary: boundary,
        behaviour: PanelBehaviour.opening,
        infill: infill,
        opening: opening,
        label: label,
        note: note,
        hasMesh: hasMesh,
        isEmpty: isEmpty,
      );

  double get widthMm => boundary.width;
  double get heightMm => boundary.height;
  double get areaMm2 => boundary.area.abs();

  /// True when this panel still needs the user to say how it opens.
  bool get needsOpeningConfirmation =>
      behaviour.isOpening && !(opening?.isConfirmed ?? false);

  /// Returns a copy as CH, dropping any opening settings.
  Panel asFixed() => Panel(
        id: id,
        boundary: boundary,
        behaviour: PanelBehaviour.fixed,
        infill: infill,
        label: label,
        note: note,
        hasMesh: hasMesh,
        isEmpty: isEmpty,
      );

  /// Returns a copy as Z with [spec].
  Panel asOpening(OpeningSpec spec) => Panel(
        id: id,
        boundary: boundary,
        behaviour: PanelBehaviour.opening,
        infill: infill,
        opening: spec,
        label: label,
        note: note,
        hasMesh: hasMesh,
        isEmpty: isEmpty,
      );

  Panel copyWith({
    Polygon? boundary,
    Infill? infill,
    String? label,
    OpeningSpec? opening,
    String? note,
    bool? hasMesh,
    bool? isEmpty,
  }) =>
      Panel(
        id: id,
        boundary: boundary ?? this.boundary,
        behaviour: behaviour,
        infill: infill ?? this.infill,
        opening: behaviour.isOpening ? (opening ?? this.opening) : null,
        label: label ?? this.label,
        note: note ?? this.note,
        hasMesh: hasMesh ?? this.hasMesh,
        isEmpty: isEmpty ?? this.isEmpty,
      );

  /// True when there is a note worth showing an icon for.
  bool get hasNote => note.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is Panel &&
      other.id == id &&
      other.boundary == boundary &&
      other.behaviour == behaviour &&
      other.opening == opening &&
      other.infill == infill &&
      other.label == label &&
      other.note == note &&
      other.hasMesh == hasMesh &&
      other.isEmpty == isEmpty;

  @override
  int get hashCode => Object.hash(
        id,
        boundary,
        behaviour,
        opening,
        infill,
        label,
        note,
        hasMesh,
        isEmpty,
      );

  @override
  String toString() => 'Panel($id, ${behaviour.code}, '
      '${widthMm.round()}x${heightMm.round()}mm)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'boundary': boundary.toJson(),
        'behaviour': behaviour.name,
        if (opening != null) 'opening': opening!.toJson(),
        'infill': infill.toJson(),
        if (label.isNotEmpty) 'label': label,
        if (note.isNotEmpty) 'note': note,
        if (hasMesh) 'mesh': true,
        if (isEmpty) 'empty': true,
      };

  static Panel fromJson(Object? json, {String path = 'panel'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    final behaviour = PanelBehaviour.values
        .where((b) => b.name == json['behaviour'])
        .firstOrNull;
    if (behaviour == null) {
      throw FormatException(
        '$path.behaviour is not CH or Z: ${json['behaviour']}',
      );
    }
    final openingJson = json['opening'];
    if (behaviour.isOpening && openingJson == null) {
      throw FormatException('$path is a Z panel but has no opening settings.');
    }
    final label = json['label'];
    final note = json['note'];
    return Panel(
      id: id,
      boundary: Polygon.fromJson(json['boundary'], path: '$path.boundary'),
      behaviour: behaviour,
      infill: Infill.fromJson(json['infill'], path: '$path.infill'),
      opening: behaviour.isOpening
          ? OpeningSpec.fromJson(openingJson, path: '$path.opening')
          : null,
      label: label is String ? label : '',
      note: note is String ? note : '',
      hasMesh: json['mesh'] == true,
      isEmpty: json['empty'] == true,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

import 'geometry/polygon.dart';
import 'panel_note.dart';
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

  /// Free-text notes attached to this panel — "توري", "فارغ", "frosted
  /// glass", a customer request (spec section 8B).
  ///
  /// A list, because one panel can carry several remarks, and each knows where
  /// its label sits and whether it is currently shown. Deliberately free text
  /// rather than a fixed vocabulary: the factory's shorthand is not something
  /// this app should try to enumerate, and a note the app cannot parse is
  /// still one a fabricator can read.
  ///
  /// Kept separate from [behaviour]: a CH/Z assignment is structure, a note is
  /// an annotation, and mixing them would let a remark change the product.
  final List<PanelNote> notes;

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
    this.notes = const [],
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
    List<PanelNote> notes = const [],
    bool hasMesh = false,
    bool isEmpty = false,
  }) =>
      Panel(
        id: id,
        boundary: boundary,
        behaviour: PanelBehaviour.fixed,
        infill: infill,
        label: label,
        notes: notes,
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
    List<PanelNote> notes = const [],
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
        notes: notes,
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
        notes: notes,
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
        notes: notes,
        hasMesh: hasMesh,
        isEmpty: isEmpty,
      );

  Panel copyWith({
    Polygon? boundary,
    Infill? infill,
    String? label,
    OpeningSpec? opening,
    List<PanelNote>? notes,
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
        notes: notes ?? this.notes,
        hasMesh: hasMesh ?? this.hasMesh,
        isEmpty: isEmpty ?? this.isEmpty,
      );

  /// True when there is a note worth showing a marker for.
  bool get hasNote => notes.any((n) => !n.isEmpty);

  /// Notes currently shown on the drawing. Hiding is not deleting.
  List<PanelNote> get visibleNotes =>
      notes.where((n) => n.isVisible && !n.isEmpty).toList();

  /// All the note text, joined — for a summary line or an export row.
  String get noteSummary =>
      notes.where((n) => !n.isEmpty).map((n) => n.text.trim()).join(' · ');

  PanelNote? noteById(String noteId) =>
      notes.where((n) => n.id == noteId).firstOrNull;

  /// Adds a note.
  Panel withNote(PanelNote note) => copyWith(notes: [...notes, note]);

  /// Replaces a note by id, or leaves the panel alone when it has no such
  /// note.
  Panel withUpdatedNote(PanelNote note) => copyWith(
        notes: [
          for (final existing in notes)
            if (existing.id == note.id) note else existing,
        ],
      );

  Panel withoutNote(String noteId) =>
      copyWith(notes: [for (final n in notes) if (n.id != noteId) n]);

  @override
  bool operator ==(Object other) =>
      other is Panel &&
      other.id == id &&
      other.boundary == boundary &&
      other.behaviour == behaviour &&
      other.opening == opening &&
      other.infill == infill &&
      other.label == label &&
      _sameNotes(other.notes) &&
      other.hasMesh == hasMesh &&
      other.isEmpty == isEmpty;

  bool _sameNotes(List<PanelNote> other) {
    if (other.length != notes.length) return false;
    for (var i = 0; i < notes.length; i++) {
      if (notes[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        boundary,
        behaviour,
        opening,
        infill,
        label,
        Object.hashAll(notes),
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
        if (notes.isNotEmpty) 'notes': [for (final n in notes) n.toJson()],
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
    return Panel(
      id: id,
      boundary: Polygon.fromJson(json['boundary'], path: '$path.boundary'),
      behaviour: behaviour,
      infill: Infill.fromJson(json['infill'], path: '$path.infill'),
      opening: behaviour.isOpening
          ? OpeningSpec.fromJson(openingJson, path: '$path.opening')
          : null,
      label: label is String ? label : '',
      notes: _notesFromJson(json, path),
      hasMesh: json['mesh'] == true,
      isEmpty: json['empty'] == true,
    );
  }

  /// Reads the notes, accepting both shapes this app has ever written.
  ///
  /// Schema 1 stored one note as a plain string on `note`; schema 2 stores a
  /// list on `notes`. An old project is migrated here rather than rejected,
  /// because losing a fabricator's remark to a format change is exactly the
  /// silent data loss the spec forbids (section 10).
  static List<PanelNote> _notesFromJson(Map<Object?, Object?> json, String path) {
    final raw = json['notes'];
    if (raw is List) {
      return [
        for (var i = 0; i < raw.length; i++)
          PanelNote.fromJson(raw[i], path: '$path.notes[$i]'),
      ];
    }
    final legacy = json['note'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return [PanelNote(id: '${json['id']}.note', text: legacy)];
    }
    return const [];
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

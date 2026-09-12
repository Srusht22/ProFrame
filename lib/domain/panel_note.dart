import 'geometry/point2.dart';

/// A free-text note the user attached inside a panel.
///
/// Structured data bound to a stable id — never painted into an image
/// (spec section 8B), so it survives editing, export and reopening, and can be
/// read back out for the PDF.
///
/// A note is an annotation and nothing more. It never changes a dimension, an
/// infill or a piece of hardware, however it is worded: the factory's shorthand
/// is its own, and a note the app tried to obey would be a note that silently
/// redesigned the product.
class PanelNote {
  /// Stable for the life of the note.
  final String id;

  /// What the user wrote. Unicode, multiline, any direction.
  final String text;

  /// Where the label sits inside its panel, as a fraction of the panel's own
  /// width and height: (0,0) is the top-left corner, (1,1) the bottom-right.
  ///
  /// Fractional rather than absolute so the label stays where it was put when
  /// the panel is resized — an absolute position would drift outside a panel
  /// that got narrower (spec section 8B, "maintain note association when
  /// dimensions change").
  final Point2 position;

  /// Hidden notes are still stored; hiding is not deleting (spec section 8B).
  final bool isVisible;

  const PanelNote({
    required this.id,
    required this.text,
    this.position = const Point2(0.5, 0.5),
    this.isVisible = true,
  });

  bool get isEmpty => text.trim().isEmpty;

  /// The note's position clamped into the panel, for a label that would
  /// otherwise sit on or past an edge.
  Point2 get clampedPosition => Point2(
        position.x.clamp(0.05, 0.95),
        position.y.clamp(0.05, 0.95),
      );

  PanelNote copyWith({String? text, Point2? position, bool? isVisible}) =>
      PanelNote(
        id: id,
        text: text ?? this.text,
        position: position ?? this.position,
        isVisible: isVisible ?? this.isVisible,
      );

  @override
  bool operator ==(Object other) =>
      other is PanelNote &&
      other.id == id &&
      other.text == text &&
      other.position == position &&
      other.isVisible == isVisible;

  @override
  int get hashCode => Object.hash(id, text, position, isVisible);

  @override
  String toString() => 'PanelNote($id, "$text")';

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': position.toJson(),
        if (!isVisible) 'hidden': true,
      };

  static PanelNote fromJson(Object? json, {String path = 'note'}) {
    if (json is! Map) {
      throw FormatException('$path must be an object, got $json');
    }
    final id = json['id'];
    final text = json['text'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    if (text is! String) {
      throw FormatException('$path.text must be a string, got $text');
    }
    final at = json['at'];
    return PanelNote(
      id: id,
      text: text,
      position: at == null
          ? const Point2(0.5, 0.5)
          : Point2.fromJson(at, path: '$path.at'),
      isVisible: json['hidden'] != true,
    );
  }
}

/// What happened to a panel's notes when its panel stopped existing.
///
/// Splitting and merging change which panels exist (spec section 10), and the
/// notes have to go somewhere explicit. Silently dropping them, or silently
/// putting them on the wrong half, are both worse than saying what happened —
/// so every move is recorded and reported to the user.
class NoteTransfer {
  final String noteId;
  final String text;

  /// The panel the note used to be on.
  final String fromPanelId;

  /// Where it went, or null when it could not be placed.
  final String? toPanelId;

  /// Plain language, for the user.
  final String explanation;

  const NoteTransfer({
    required this.noteId,
    required this.text,
    required this.fromPanelId,
    required this.explanation,
    this.toPanelId,
  });

  bool get wasKept => toPanelId != null;

  @override
  String toString() => 'NoteTransfer($noteId: $fromPanelId -> '
      '${toPanelId ?? 'nowhere'})';
}

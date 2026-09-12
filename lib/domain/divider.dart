import 'geometry/point2.dart';
import 'geometry/polygon.dart';

/// An internal division: a mullion (vertical) or a transom (horizontal).
///
/// A divider is stored as a segment, not as "column 2 of 3", so a division
/// that spans only part of the frame — a transom over two bays of a five-bay
/// window — is an ordinary divider rather than a special case
/// (spec section 4).
class Divider {
  final String id;
  final Point2 start;
  final Point2 end;

  /// True when both ends meet the outer boundary, so the divider cuts the
  /// frame all the way across. False for a partial divider that ends on
  /// another divider, forming a T-junction.
  final bool spansFullFrame;

  const Divider({
    required this.id,
    required this.start,
    required this.end,
    required this.spansFullFrame,
  });

  Edge get edge => Edge(start, end);

  EdgeOrientation get orientation => edge.orientation;

  double get lengthMm => start.distanceTo(end);

  bool get isVertical => orientation == EdgeOrientation.vertical;
  bool get isHorizontal => orientation == EdgeOrientation.horizontal;

  /// A divider the user drew at an angle. Kept as drawn; never levelled.
  bool get isSloping => orientation == EdgeOrientation.sloping;

  Divider copyWith({Point2? start, Point2? end, bool? spansFullFrame}) => Divider(
        id: id,
        start: start ?? this.start,
        end: end ?? this.end,
        spansFullFrame: spansFullFrame ?? this.spansFullFrame,
      );

  @override
  bool operator ==(Object other) =>
      other is Divider &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.spansFullFrame == spansFullFrame;

  @override
  int get hashCode => Object.hash(id, start, end, spansFullFrame);

  @override
  String toString() =>
      'Divider($id, ${orientation.name}, $start -> $end, '
      '${spansFullFrame ? 'full' : 'partial'})';

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toJson(),
        'end': end.toJson(),
        'full': spansFullFrame,
      };

  static Divider fromJson(Object? json, {String path = 'divider'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    return Divider(
      id: id,
      start: Point2.fromJson(json['start'], path: '$path.start'),
      end: Point2.fromJson(json['end'], path: '$path.end'),
      spansFullFrame: json['full'] == true,
    );
  }
}

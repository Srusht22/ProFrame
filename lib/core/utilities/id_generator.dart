import 'package:uuid/uuid.dart';

/// Identifiers for designs, strokes and versions. UUIDv4 so a design created
/// offline never collides with one created on another device.
class IdGenerator {
  IdGenerator._();

  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v4();

  /// Short, human-readable id used for stroke ids in a single session —
  /// keeps saved sketches compact without risking collisions within a design.
  static String short(String prefix, int counter) =>
      '$prefix${counter.toRadixString(36)}';
}

import 'package:uuid/uuid.dart';

class IdGenerator {
  static const _uuid = Uuid();

  static String generate() {
    return _uuid.v4();
  }

  static String generateShortId() {
    return _uuid.v4().substring(0, 8).toUpperCase();
  }
}

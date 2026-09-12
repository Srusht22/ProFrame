/// A product colour or finish for the door or window itself.
///
/// Explicitly separate from the application's brand colours (spec section 7):
/// the app is always cream and deep green, while the product can be any finish
/// the factory offers.
class Finish {
  final String id;
  final String name;

  /// The finish colour as a 32-bit ARGB value.
  ///
  /// Stored as a plain int rather than a Flutter `Color` so the domain layer
  /// stays free of Flutter — the UI wraps it when it paints.
  final int argb;

  /// True for finishes that are not flat colours (woodgrain foils, anodised
  /// textures). The renderer shades these differently; the app does not
  /// pretend to reproduce the exact texture.
  final bool isTextured;

  const Finish({
    required this.id,
    required this.name,
    required this.argb,
    this.isTextured = false,
  });

  @override
  bool operator ==(Object other) => other is Finish && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'argb': argb, 'textured': isTextured};

  static Finish fromJson(Object? json, {String path = 'finish'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final id = json['id'];
    final name = json['name'];
    final argb = json['argb'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    if (name is! String) {
      throw FormatException('$path.name must be a string, got $name');
    }
    if (argb is! int) {
      throw FormatException('$path.argb must be an integer, got $argb');
    }
    return Finish(
      id: id,
      name: name,
      argb: argb,
      isTextured: json['textured'] == true,
    );
  }
}

/// The finishes offered before a factory supplies its own list.
abstract final class StockFinishes {
  static const Finish white = Finish(id: 'white', name: 'White', argb: 0xFFF4F4F1);
  static const Finish cream = Finish(id: 'cream', name: 'Cream', argb: 0xFFEFE6D2);
  static const Finish grey = Finish(id: 'grey', name: 'Grey', argb: 0xFF7D7F7C);
  static const Finish anthracite =
      Finish(id: 'anthracite', name: 'Anthracite', argb: 0xFF383B3A);
  static const Finish black = Finish(id: 'black', name: 'Black', argb: 0xFF22231F);
  static const Finish brown = Finish(id: 'brown', name: 'Brown', argb: 0xFF5A3A22);
  static const Finish goldenOak = Finish(
    id: 'golden_oak',
    name: 'Golden oak',
    argb: 0xFFA9762F,
    isTextured: true,
  );

  static const List<Finish> all = [
    white,
    cream,
    grey,
    anthracite,
    black,
    brown,
    goldenOak,
  ];

  static const Finish factoryDefault = white;

  const StockFinishes._();
}

/// What fills a panel: glass or a solid infill board.
sealed class Infill {
  /// Overall thickness in millimetres, used by the 3D generator and checked
  /// against the profile's glazing rebate.
  double get thicknessMm;

  /// Plain-language name for the properties panel.
  String get label;

  const Infill();

  Map<String, dynamic> toJson();

  static Infill fromJson(Object? json, {String path = 'infill'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final kind = json['kind'];
    return switch (kind) {
      'glazing' => Glazing.fromJson(json, path: path),
      'panel' => SolidPanel.fromJson(json, path: path),
      _ => throw FormatException('$path.kind is not a known infill: $kind'),
    };
  }
}

/// Glass. [paneCount] is 1 for single, 2 for a double-glazed unit, 3 for
/// triple.
class Glazing extends Infill {
  final int paneCount;
  @override
  final double thicknessMm;

  /// Obscure, frosted or patterned glass. Affects what the 3D view shows.
  final bool isObscure;

  const Glazing({
    required this.paneCount,
    required this.thicknessMm,
    this.isObscure = false,
  });

  static const Glazing doubleGlazed = Glazing(paneCount: 2, thicknessMm: 24);
  static const Glazing singleGlazed = Glazing(paneCount: 1, thicknessMm: 4);

  @override
  String get label => switch (paneCount) {
        1 => isObscure ? 'Single glazed, obscure' : 'Single glazed',
        2 => isObscure ? 'Double glazed, obscure' : 'Double glazed',
        3 => isObscure ? 'Triple glazed, obscure' : 'Triple glazed',
        _ => '$paneCount panes',
      };

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'glazing',
        'panes': paneCount,
        'thickness': thicknessMm,
        'obscure': isObscure,
      };

  static Glazing fromJson(Map<Object?, Object?> json, {String path = 'infill'}) {
    final panes = json['panes'];
    final thickness = json['thickness'];
    if (panes is! int || panes < 1) {
      throw FormatException('$path.panes must be a positive integer, got $panes');
    }
    if (thickness is! num || thickness <= 0) {
      throw FormatException('$path.thickness must be positive, got $thickness');
    }
    return Glazing(
      paneCount: panes,
      thicknessMm: thickness.toDouble(),
      isObscure: json['obscure'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Glazing &&
      other.paneCount == paneCount &&
      other.thicknessMm == thicknessMm &&
      other.isObscure == isObscure;

  @override
  int get hashCode => Object.hash(paneCount, thicknessMm, isObscure);
}

/// An opaque panel — a door's lower panel, an infill board.
class SolidPanel extends Infill {
  @override
  final double thicknessMm;
  final String material;

  const SolidPanel({this.thicknessMm = 24, this.material = 'Panel'});

  @override
  String get label => material;

  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'panel', 'thickness': thicknessMm, 'material': material};

  static SolidPanel fromJson(Map<Object?, Object?> json, {String path = 'infill'}) {
    final thickness = json['thickness'];
    if (thickness is! num || thickness <= 0) {
      throw FormatException('$path.thickness must be positive, got $thickness');
    }
    final material = json['material'];
    return SolidPanel(
      thicknessMm: thickness.toDouble(),
      material: material is String && material.isNotEmpty ? material : 'Panel',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SolidPanel &&
      other.thicknessMm == thicknessMm &&
      other.material == material;

  @override
  int get hashCode => Object.hash(thicknessMm, material);
}

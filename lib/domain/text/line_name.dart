import '../model/elements.dart';
import '../model/materials.dart';
import '../pricing/price_list.dart';
import '../pricing/profile_category.dart';
import 'names.dart';
import 'words.dart';

/// What a price line is, kept so it can be said in any language.
///
/// A price is kept as it was calculated, and a quotation keeps it longer
/// still, so what a line is called is part of the record. Kept as words in
/// the language of the day, a price calculated in Kurdish would read in
/// Kurdish after the application was switched to English. So the record
/// keeps the line's English label, as it always has, and this beside it:
/// which kind of line it is and the identifiers it was made from — enum
/// names, never words — and [sayIn] says it in whichever language is
/// shown. A catalog colour's own name is the factory's, kept as written.
///
/// A line kept before this has none, and is shown as its English label.
class LineName {
  final String key;
  final List<String> args;

  const LineName(this.key, [this.args = const []]);

  @override
  bool operator ==(Object other) =>
      other is LineName &&
      other.key == key &&
      other.args.length == args.length &&
      [for (var i = 0; i < args.length; i++) other.args[i] == args[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(args));

  Map<String, Object?> toJson() => {'k': key, if (args.isNotEmpty) 'a': args};

  /// What [json] keeps, or null where it is not a line name.
  static LineName? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final key = json['k'];
    final args = json['a'];
    if (key is! String) return null;
    if (args != null && args is! List<Object?>) return null;
    return LineName(key, [
      for (final a in (args as List<Object?>?) ?? const <Object?>[])
        if (a is String) a,
    ]);
  }

  /// The line in [w], or null where this version cannot say it — a key or
  /// an identifier it does not know — when its kept label is shown.
  String? sayIn(Words w) {
    String? material(String name) => MaterialKind.values
        .where((m) => m.name == name)
        .firstOrNull
        ?.labelIn(w);
    String arg(int i) => i < args.length ? args[i] : '';
    switch (key) {
      case 'profile':
        final what = arg(0);
        final named = what.startsWith('cat:')
            ? ProfileCategory.byName(what.substring(4))?.labelIn(w)
            : material(what.replaceFirst('mat:', ''));
        final part = ProfilePart.byName(arg(1))?.labelIn(w);
        if (named == null || part == null) return null;
        return w.lineProfile(named, part);
      case 'opening':
        final m = material(arg(0));
        return m == null ? null : w.lineOpeningProfile(m);
      case 'colour':
        final m = material(arg(1));
        final grade = ColourGrade.values
            .where((g) => g.name == arg(2))
            .firstOrNull;
        if (m == null || grade == null) return null;
        final colour = arg(0).isEmpty ? ColourGrade.special.labelIn(w) : arg(0);
        return w.lineColour(colour, m, grade.labelIn(w).toLowerCase());
      case 'track':
        return w.lineTrack;
      case 'glass':
        final look = arg(0) == 'custom'
            ? w.custom
            : GlassLook.values
                  .where((g) => g.name == arg(0))
                  .firstOrNull
                  ?.labelIn(w);
        if (look == null) return null;
        final glass = w.lineGlass(look);
        return arg(1) == 'sealed' ? w.lineSealed(glass) : glass;
      case 'panel':
        final colour = arg(0) == 'custom'
            ? w.custom
            : PanelColour.values
                  .where((c) => c.name == arg(0))
                  .firstOrNull
                  ?.labelIn(w);
        return colour == null ? null : w.linePanel(colour);
      case 'pieces':
        final piece = HardwareKind.values
            .where((k) => k.name == arg(0))
            .firstOrNull
            ?.labelIn(w);
        if (piece == null) return null;
        return arg(1) == 'one' ? piece : w.linePieces(piece);
      case 'rollers':
        return w.lineRollers;
      case 'making':
        return w.lineMaking;
      case 'makingArea':
        return w.lineMakingArea;
      case 'makingMaterials':
        return w.lineMakingMaterials;
      case 'installation':
        return w.lineInstallation;
      case 'installationArea':
        return w.lineInstallationArea;
    }
    return null;
  }

  /// The line in English — what is kept as its label.
  String get english => sayIn(const EnglishWords())!;
}

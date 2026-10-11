import '../model/design.dart';
import '../model/materials.dart';
import '../text/names.dart';
import '../text/words.dart';
import 'price_list.dart';

/// What a design is made of, as its price reads it: the material and the
/// colour of its profile.
///
/// It is not a second copy of anything. The profile is the frame's own
/// finish — the one the technical drawing and the solid are built in — so
/// choosing aluminium here is choosing it for the frame, and painting the
/// frame black in the inspector is choosing black here. The price list
/// then says what that material and that colour cost
/// (`PriceList.profiles`); nothing about either is a figure in a widget.
///
/// **Not chosen is a real answer.** The reading gives every new frame the
/// stock white uPVC, so a frame in that finish says nothing about what the
/// customer wants. A design is chosen when somebody said so
/// ([Design.profileChosen]) or when its frame is in any other finish —
/// which only a person can have put there, since nothing else writes one.
/// Until then [material] and [colour] are null, the card says *Not
/// selected*, and the design is not priced (`PriceReadiness`).
class ProfileSelection {
  /// The frame's material, or null where none has been chosen.
  final MaterialKind? material;

  /// The frame's colour, 0xAARRGGBB, or null where none has been chosen.
  /// It is what every view draws the profile in.
  final int? colour;

  /// The factory colour it was chosen as — an id of the price list's
  /// catalog — or null where it was not chosen from the catalog
  /// ([Design.profileColourId]).
  final String? colourId;

  const ProfileSelection._(this.material, this.colour, [this.colourId]);

  static const notChosen = ProfileSelection._(null, null);

  bool get isChosen => material != null;

  /// The profile [design] is priced in.
  static ProfileSelection of(Design design) {
    final frame = design.frame;
    if (frame == null) return notChosen;
    final said = design.profileChosen || frame.finish != Finish.frameDefault;
    if (!said) return notChosen;
    return ProfileSelection._(
      frame.finish.material,
      frame.finish.colour,
      design.profileColourId,
    );
  }

  /// What its colour adds in [list], or why it cannot be priced: always the
  /// material and the colour together (`PriceList.colourFor`). Null where
  /// nothing is chosen.
  ColourPricing? colourIn(PriceList list) {
    final m = material;
    final c = colour;
    if (m == null || c == null) return null;
    return list.colourFor(m, c, id: colourId);
  }

  /// The catalog colour it is, in [list]: the one chosen, or — chosen
  /// before the catalog, or painted in the inspector — the one its value
  /// matches on its own material. Null where it is no catalog colour.
  FactoryColour? catalogColourIn(PriceList list) {
    if (colourId case final id?) return list.colourById(id);
    final m = material;
    final c = colour;
    if (m == null || c == null) return null;
    return list.colourFor(m, c).entry;
  }

  /// What the material is called: *uPVC*, *Aluminium* — or *Not selected*.
  String get materialName => material?.label ?? 'Not selected';

  /// [materialName], in [w].
  String materialNameIn(Words w) => material?.labelIn(w) ?? w.notSelected;

  /// What the colour is called, in words: the name the catalog gives it —
  /// retired or not, so a colour the factory no longer offers is still
  /// named, never *Unknown* — or else the name the colour picker gives it,
  /// or else *Custom* — never only a swatch. *Not selected* where none is.
  String colourName([PriceList? list]) {
    final c = colour;
    if (c == null) return 'Not selected';
    if (list != null) {
      if (catalogColourIn(list) case final entry?) return entry.name;
    }
    for (final (value, name) in finishPalette) {
      if (value == c) return name;
    }
    return 'Custom';
  }

  /// [colourName], in [w]. A catalog colour's name is the factory's own,
  /// and stays as they wrote it.
  String colourNameIn(Words w, [PriceList? list]) {
    final c = colour;
    if (c == null) return w.notSelected;
    if (list != null) {
      if (catalogColourIn(list) case final entry?) return entry.name;
    }
    for (final (value, name) in finishPalette) {
      if (value == c) return paletteNameIn(w, name);
    }
    return w.custom;
  }

  /// [design] with its profile chosen as [material] in [colour] — the
  /// catalog's colour [colourId], where it was chosen from the catalog.
  ///
  /// The frame takes the finish, and so does every bar that was in the
  /// frame's own finish — the same profile system, cut from the same
  /// lengths. A bar the user gave a finish of its own keeps it. Nothing
  /// else changes: no line, no pane, no figure, no ironmongery.
  ///
  /// **Nothing is chosen for the user.** A material chosen with a colour it
  /// is not sold in keeps that colour, and the price then asks for one
  /// that is (`ColourPricing.problem`); no other colour is put in its
  /// place.
  static Design choose(
    Design design, {
    required MaterialKind material,
    required int colour,
    String? colourId,
  }) {
    final frame = design.frame;
    if (frame == null) return design;
    final was = frame.finish;
    final now = Finish(colour: colour, material: material);
    return design.copyWith(
      frame: frame.copyWith(finish: now),
      dividers: [
        for (final d in design.dividers)
          d.finish == was ? d.copyWith(finish: now) : d,
      ],
      profileChosen: true,
      profileColourId: colourId,
      clearProfileColour: colourId == null,
    );
  }

  Map<String, Object?> toJson([PriceList? list]) => {
    if (material != null) 'material': material!.name,
    if (colour != null) 'colour': colour,
    if (colourId != null) 'colourId': colourId,
    if (colour != null) 'colourName': colourName(list),
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileSelection &&
      other.material == material &&
      other.colour == colour &&
      other.colourId == colourId;

  @override
  int get hashCode => Object.hash(material, colour, colourId);
}

/// The materials a design's profile can be made of: those the price list
/// prices a profile in, in the order a joiner reads them.
List<MaterialKind> profileMaterialsOf(PriceList list) => [
  for (final m in MaterialKind.values)
    if (list.profiles.containsKey(m)) m,
];

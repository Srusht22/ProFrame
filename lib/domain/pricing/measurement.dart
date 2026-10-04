/// The factory's measurements, kept apart by what they measure.
///
/// A length of profile and an area of glass are different quantities, so
/// they are different types: [Metres] and [SquareMetres] cannot be added to
/// one another, and each writes its own unit — `56.80 m`, `8.40 m²` — so a
/// panel's area can never be shown as a length or summed into the profile.
library;

/// A length, in metres — of profile, as the factory cuts it.
class Metres implements Comparable<Metres> {
  final double value;

  const Metres(this.value);

  static const zero = Metres(0);

  /// [mm] millimetres, as a length in metres.
  factory Metres.ofMm(double mm) =>
      Metres(mm.isFinite && mm > 0 ? mm / 1000 : 0);

  Metres operator +(Metres other) => Metres(value + other.value);

  /// `7.60 m` — to the centimetre.
  String get label => '${value.toStringAsFixed(2)} m';

  @override
  int compareTo(Metres other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Metres && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => label;
}

/// An area, in square metres — of glass or panel, as it is cut.
class SquareMetres implements Comparable<SquareMetres> {
  final double value;

  const SquareMetres(this.value);

  static const zero = SquareMetres(0);

  /// [mm2] square millimetres, as square metres.
  factory SquareMetres.ofMm2(double mm2) =>
      SquareMetres(mm2.isFinite && mm2 > 0 ? mm2 / 1e6 : 0);

  SquareMetres operator +(SquareMetres other) =>
      SquareMetres(value + other.value);

  /// `2.00 m²` — to the hundredth of a square metre.
  String get label => '${value.toStringAsFixed(2)} m²';

  @override
  int compareTo(SquareMetres other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is SquareMetres && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => label;
}

/// What one design, or all of a customer's designs, measure: each kind of
/// profile by the metre, glass and panel by the square metre, and the
/// pieces of ironmongery by the piece.
class MeasurementSummary {
  /// The frame's border and every line inside it that is cut from the same
  /// profile — the design's own bars and those drawn inside openings.
  final Metres normalProfile;

  /// The profile round each opening, every opening counted once.
  final Metres openingProfile;

  /// Any other profile by the metre — a sliding design's track.
  final Metres otherProfile;

  final SquareMetres panelArea;
  final SquareMetres glassArea;
  final int hardwarePieces;
  final int openings;

  const MeasurementSummary({
    this.normalProfile = Metres.zero,
    this.openingProfile = Metres.zero,
    this.otherProfile = Metres.zero,
    this.panelArea = SquareMetres.zero,
    this.glassArea = SquareMetres.zero,
    this.hardwarePieces = 0,
    this.openings = 0,
  });

  static const none = MeasurementSummary();

  /// Every linear profile together — and only linear profile: no area and
  /// no count is ever added in.
  Metres get totalProfile => normalProfile + openingProfile + otherProfile;

  MeasurementSummary operator +(MeasurementSummary other) => MeasurementSummary(
    normalProfile: normalProfile + other.normalProfile,
    openingProfile: openingProfile + other.openingProfile,
    otherProfile: otherProfile + other.otherProfile,
    panelArea: panelArea + other.panelArea,
    glassArea: glassArea + other.glassArea,
    hardwarePieces: hardwarePieces + other.hardwarePieces,
    openings: openings + other.openings,
  );

  Map<String, Object?> toJson() => {
    'normalProfileM': normalProfile.value,
    'openingProfileM': openingProfile.value,
    'otherProfileM': otherProfile.value,
    'panelM2': panelArea.value,
    'glassM2': glassArea.value,
    'hardwarePieces': hardwarePieces,
    'openings': openings,
  };

  static MeasurementSummary fromJson(Object? json) {
    if (json is! Map<String, Object?>) return none;
    double read(String key) => switch (json[key]) {
      final num v when v.isFinite && v >= 0 => v.toDouble(),
      _ => 0,
    };
    return MeasurementSummary(
      normalProfile: Metres(read('normalProfileM')),
      openingProfile: Metres(read('openingProfileM')),
      otherProfile: Metres(read('otherProfileM')),
      panelArea: SquareMetres(read('panelM2')),
      glassArea: SquareMetres(read('glassM2')),
      hardwarePieces: read('hardwarePieces').round(),
      openings: read('openings').round(),
    );
  }
}

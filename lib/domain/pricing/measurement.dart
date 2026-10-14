/// The factory's measurements, kept apart by what they measure.
///
/// A length of profile and an area of glass are different quantities, so
/// they are different types: [Metres] and [SquareMetres] cannot be added to
/// one another, and each writes its own unit — `56.800 m`, `8.40 m²` — so a
/// panel's area can never be shown as a length or summed into the profile.
library;

/// A length, in metres — of profile, as the factory cuts it.
///
/// **Kept in whole millimetres**, the precision a length is cut to, so a sum
/// of lengths is exact: no row, total or customer's summary is ever off by
/// a rounding. It is shown to the millimetre too (`7.600 m`), so what is
/// written adds up: `20.980 m` and `14.230 m` are `35.210 m`, never a figure
/// a hundredth from the sum of the rows above it.
class Metres implements Comparable<Metres> {
  /// The length, in whole millimetres.
  final int mm;

  const Metres._(this.mm);

  /// [metres], to the millimetre. Nothing, or not a number, is nothing.
  factory Metres(double metres) => Metres.ofMm(metres * 1000);

  static const zero = Metres._(0);

  /// [mm] millimetres, to the millimetre.
  factory Metres.ofMm(double mm) =>
      Metres._(mm.isFinite && mm > 0 ? mm.round() : 0);

  /// The length in metres.
  double get value => mm / 1000;

  Metres operator +(Metres other) => Metres._(mm + other.mm);

  /// `7.600 m` — to the millimetre, as it is kept.
  String get label => '${(mm / 1000).toStringAsFixed(3)} m';

  @override
  int compareTo(Metres other) => mm.compareTo(other.mm);

  @override
  bool operator ==(Object other) => other is Metres && other.mm == mm;

  @override
  int get hashCode => mm.hashCode;

  @override
  String toString() => label;
}

/// An area, in square metres — of glass or panel, as it is cut.
///
/// Kept in whole square millimetres, so areas add exactly; shown to the
/// ten-thousandth of a square metre.
class SquareMetres implements Comparable<SquareMetres> {
  /// The area, in whole square millimetres.
  final int mm2;

  const SquareMetres._(this.mm2);

  /// [m2] square metres, to the square millimetre.
  factory SquareMetres(double m2) => SquareMetres.ofMm2(m2 * 1e6);

  static const zero = SquareMetres._(0);

  /// [mm2] square millimetres.
  factory SquareMetres.ofMm2(double mm2) =>
      SquareMetres._(mm2.isFinite && mm2 > 0 ? mm2.round() : 0);

  /// The area in square metres.
  double get value => mm2 / 1e6;

  SquareMetres operator +(SquareMetres other) =>
      SquareMetres._(mm2 + other.mm2);

  /// `1.4296 m²` — to the ten-thousandth of a square metre, a square
  /// centimetre. A line's amount is its exact area at its rate, and an area
  /// written to the hundredth could be a cent or more out from what the
  /// line charges — `1.43 m² × 45.00` reads as 64.35 against a line of
  /// 64.33. To four places the area is off by at most half a square
  /// centimetre, so the area written times the rate is within half a cent
  /// of the amount at any rate up to 100 a square metre, and every line can
  /// be checked by hand. The amount itself is never worked out from this.
  String get label => '${value.toStringAsFixed(4)} m²';

  @override
  int compareTo(SquareMetres other) => mm2.compareTo(other.mm2);

  @override
  bool operator ==(Object other) => other is SquareMetres && other.mm2 == mm2;

  @override
  int get hashCode => mm2.hashCode;

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

  /// The frame's border alone, and the lines alone — the two parts of
  /// [normalProfile], measured and shown apart. Both nothing in a price
  /// kept before they were kept apart, which then says [normalProfile]
  /// only ([splitsBorder]).
  final Metres borderLength;
  final Metres lineLength;

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
    this.borderLength = Metres.zero,
    this.lineLength = Metres.zero,
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

  /// Whether the border and the lines are known apart — false only for a
  /// price kept before they were.
  bool get splitsBorder =>
      normalProfile.value == 0 || borderLength.value + lineLength.value > 0;

  MeasurementSummary operator +(MeasurementSummary other) => MeasurementSummary(
    normalProfile: normalProfile + other.normalProfile,
    borderLength: borderLength + other.borderLength,
    lineLength: lineLength + other.lineLength,
    openingProfile: openingProfile + other.openingProfile,
    otherProfile: otherProfile + other.otherProfile,
    panelArea: panelArea + other.panelArea,
    glassArea: glassArea + other.glassArea,
    hardwarePieces: hardwarePieces + other.hardwarePieces,
    openings: openings + other.openings,
  );

  Map<String, Object?> toJson() => {
    'normalProfileM': normalProfile.value,
    'borderM': borderLength.value,
    'linesM': lineLength.value,
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
      borderLength: Metres(read('borderM')),
      lineLength: Metres(read('linesM')),
      openingProfile: Metres(read('openingProfileM')),
      otherProfile: Metres(read('otherProfileM')),
      panelArea: SquareMetres(read('panelM2')),
      glassArea: SquareMetres(read('glassM2')),
      hardwarePieces: read('hardwarePieces').round(),
      openings: read('openings').round(),
    );
  }
}

import '../core/units/length_unit.dart';

/// Where a number came from.
///
/// This is the most important distinction in the model. A rough sketch gives
/// design *intent*, not manufacturing dimensions (spec section 2), so every
/// length has to say whether a person stood behind it or the app inferred it.
/// Without this the two are indistinguishable downstream and the app would end
/// up presenting a guess as a specification.
enum MeasurementSource {
  /// The user typed or explicitly confirmed this number. Only these may be
  /// treated as manufacturing dimensions.
  confirmed,

  /// Scaled from the proportions of the sketch. Usable for a preview, never
  /// for production, and always shown as unconfirmed.
  estimated,

  /// Computed from confirmed values by a rule the user chose — the remainder
  /// of a width after two confirmed sections, or an equal distribution the
  /// user asked for. As trustworthy as its inputs, but recomputed rather than
  /// stored as intent.
  derived;

  /// Whether a value from this source may be presented as a real dimension.
  bool get isTrustworthy => this != MeasurementSource.estimated;
}

/// A length in millimetres that remembers where it came from.
///
/// Millimetres are the only unit stored (spec section 3D); [LengthUnit] is for
/// display and input.
class Measurement implements Comparable<Measurement> {
  final double millimetres;
  final MeasurementSource source;

  /// How this value was arrived at, for the user: "you entered this",
  /// "scaled from your drawing", "the rest of the width". Shown next to
  /// unconfirmed values so nothing looks more certain than it is.
  final String explanation;

  const Measurement._(this.millimetres, this.source, this.explanation);

  /// A number the user entered or confirmed.
  const Measurement.confirmed(double millimetres, {String explanation = 'You entered this.'})
      : this._(millimetres, MeasurementSource.confirmed, explanation);

  /// A number scaled from the drawing. Never a manufacturing dimension.
  const Measurement.estimated(
    double millimetres, {
    String explanation = 'Scaled from your drawing. Not confirmed.',
  }) : this._(millimetres, MeasurementSource.estimated, explanation);

  /// A number computed from confirmed values.
  const Measurement.derived(double millimetres, {required String explanation})
      : this._(millimetres, MeasurementSource.derived, explanation);

  bool get isConfirmed => source == MeasurementSource.confirmed;
  bool get isEstimated => source == MeasurementSource.estimated;

  /// Whether this may be used as a manufacturing dimension.
  bool get isTrustworthy => source.isTrustworthy;

  double inUnit(LengthUnit unit) => unit.fromMillimetres(millimetres);

  String format(LengthUnit unit) => unit.format(millimetres);

  /// Confirming a value the user has now typed.
  ///
  /// There is deliberately no method that promotes an estimate to confirmed
  /// while keeping its number — confirming means the user supplied the
  /// figure, so it takes a new one (spec section 2, "never silently invent
  /// missing dimensions").
  Measurement confirmedAs(double millimetres) => Measurement.confirmed(millimetres);

  @override
  int compareTo(Measurement other) => millimetres.compareTo(other.millimetres);

  @override
  bool operator ==(Object other) =>
      other is Measurement &&
      other.source == source &&
      (other.millimetres - millimetres).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(millimetres, source);

  @override
  String toString() => '${millimetres}mm (${source.name})';

  Map<String, dynamic> toJson() => {
        'mm': millimetres,
        'source': source.name,
        'explanation': explanation,
      };

  static Measurement fromJson(Map<String, dynamic> json, {String path = 'measurement'}) {
    final mm = json['mm'];
    if (mm is! num || !mm.isFinite) {
      throw FormatException('$path.mm must be a finite number, got $mm');
    }
    final sourceName = json['source'];
    final source = MeasurementSource.values
        .where((s) => s.name == sourceName)
        .firstOrNull;
    if (source == null) {
      throw FormatException('$path.source is not a known source: $sourceName');
    }
    final explanation = json['explanation'];
    return Measurement._(
      mm.toDouble(),
      source,
      explanation is String ? explanation : '',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// A dimension that may not be known yet.
///
/// `null` means "nobody has said". That is different from an estimate, which
/// is a number the app produced and must show as unconfirmed, and different
/// again from a confirmed value. The UI must be able to tell all three apart,
/// which is why unknown is absence rather than a zero or a sentinel.
typedef MaybeMeasurement = Measurement?;

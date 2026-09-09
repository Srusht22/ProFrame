import '../../shared/models/sketch.dart';

/// One piece of ink read back as text.
class InkTranscription {
  final String strokeId;
  final String text;
  final double? numericValue;
  final double confidence;

  const InkTranscription({
    required this.strokeId,
    required this.text,
    this.numericValue,
    this.confidence = 1,
  });
}

/// Reads handwritten annotations.
///
/// **Honest statement of what is implemented:** this app does *not* ship an
/// on-device handwriting OCR model. Recognising handwritten digits reliably
/// enough to size a manufactured product needs a trained model, and guessing
/// would be worse than useless — a misread "1100" as "1400" is a scrapped
/// frame.
///
/// So the pipeline is built around this interface (§64): the app asks for the
/// number instead of inventing it, [TypedValueRecognizer] supplies whatever
/// the user typed, and a real OCR or cloud recogniser can be dropped in later
/// without touching anything downstream.
abstract class HandwritingRecognizer {
  /// Whether this implementation can actually read ink.
  bool get canReadInk;

  /// Shown in the UI so the user always knows what the app is doing.
  String get capabilityDescription;

  Future<List<InkTranscription>> transcribe(List<Stroke> strokes);
}

/// The shipped implementation: values the user typed onto a stroke are
/// returned as-is. Ink with no typed value comes back as unread.
class TypedValueRecognizer implements HandwritingRecognizer {
  const TypedValueRecognizer();

  @override
  bool get canReadInk => false;

  @override
  String get capabilityDescription =>
      'Handwriting is not read automatically. Type the measurement when you '
      'draw a dimension and it is used exactly as entered.';

  @override
  Future<List<InkTranscription>> transcribe(List<Stroke> strokes) async {
    final result = <InkTranscription>[];
    for (final stroke in strokes) {
      final value = stroke.dimensionMm;
      final text = stroke.text;
      if (value == null && (text == null || text.isEmpty)) continue;
      result.add(InkTranscription(
        strokeId: stroke.id,
        text: text ?? '${value!.round()}',
        numericValue: value ?? parseMeasurement(text!),
        confidence: 1,
      ));
    }
    return result;
  }

  /// Parses the shorthand people actually write: `1200`, `1.2 m`, `120cm`,
  /// `48"`. Returns millimetres, or null when the text is not a measurement.
  static double? parseMeasurement(String raw) {
    final text = raw.trim().toLowerCase().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final match = RegExp(r'^([0-9]*\.?[0-9]+)\s*(mm|cm|m|in|"|inch|inches)?$').firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return switch (match.group(2)) {
      'cm' => value * 10,
      'm' => value * 1000,
      'in' || '"' || 'inch' || 'inches' => value * 25.4,
      _ => value,
    };
  }
}

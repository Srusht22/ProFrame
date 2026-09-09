/// How the app reports what it understood. Every reading is either confirmed
/// or explicitly questioned — nothing critical is decided silently (§16, §29).
enum InterpretationLevel { recognised, uncertain, missing }

/// One line on the "Understanding your design" screen.
class InterpretationItem {
  final String id;
  final InterpretationLevel level;
  final String title;
  final String detail;

  /// Choices offered when the app is not sure. Picking one applies it to the
  /// model; nothing is applied until the user picks.
  final List<InterpretationChoice> choices;

  const InterpretationItem({
    required this.id,
    required this.level,
    required this.title,
    required this.detail,
    this.choices = const [],
  });

  bool get needsAnswer => level != InterpretationLevel.recognised && choices.isNotEmpty;
}

/// A concrete option the user can pick for an uncertain reading. [apply] is
/// resolved by the caller through [id]; the model keeps the payload so the
/// screen stays a dumb renderer.
class InterpretationChoice {
  final String id;
  final String label;
  final Map<String, Object?> payload;
  final bool isSuggested;

  const InterpretationChoice({
    required this.id,
    required this.label,
    this.payload = const {},
    this.isSuggested = false,
  });
}

/// The full read-back of a sketch.
class InterpretationReport {
  final List<InterpretationItem> items;

  /// Overall confidence, 0..1 — the mean of the individual readings.
  final double confidence;

  const InterpretationReport({required this.items, required this.confidence});

  static const InterpretationReport empty =
      InterpretationReport(items: [], confidence: 0);

  List<InterpretationItem> get recognised =>
      items.where((i) => i.level == InterpretationLevel.recognised).toList();

  List<InterpretationItem> get uncertain =>
      items.where((i) => i.level != InterpretationLevel.recognised).toList();

  bool get hasQuestions => uncertain.isNotEmpty;
}

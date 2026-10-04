/// Something the application could not read off the drawing with confidence.
///
/// The rule is that the application never decides these quietly. When a
/// drawing is ambiguous — a line that might be a divider or might be an
/// opening symbol, an arc that could hinge on either side — it becomes a
/// question the user answers, and the answer is recorded as theirs.
class DesignQuestion {
  final String id;

  /// What is being asked, in the user's terms.
  final String prompt;

  /// A little more, when the prompt alone is not enough.
  final String? detail;

  /// The ids of the elements or strokes the question is about, so the canvas
  /// can highlight exactly what is being asked about.
  final List<String> aboutIds;

  final List<QuestionOption> options;

  const DesignQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.detail,
    this.aboutIds = const [],
  });
}

/// One answer the user can give.
class QuestionOption {
  /// A stable key the code matches on.
  final String key;

  /// What the user reads.
  final String label;

  final String? detail;

  const QuestionOption({required this.key, required this.label, this.detail});
}

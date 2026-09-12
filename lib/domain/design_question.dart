import 'measurement.dart';

/// What is still to confirm about a design.
enum DesignQuestionKind {
  /// Nothing has been drawn yet, so there is no layout to measure.
  notInterpreted,
  overallWidthMissing,
  overallWidthUnconfirmed,
  overallHeightMissing,
  overallHeightUnconfirmed,
  hingeSideUnconfirmed,
}

/// One thing the user has still to answer.
///
/// A question is data, not a sentence: the kind and its subject are what the
/// app knows, and the words are written where they are shown — in the
/// language the user reads. [message] is the English wording, kept for logs
/// and tests.
class DesignQuestion {
  final DesignQuestionKind kind;

  /// Which panel the question is about, where it is about one.
  final String? panelId;

  /// The panel's name, as the user would recognise it.
  final String? panelLabel;

  /// Where an unconfirmed measurement came from, so the answer can say so.
  final MeasurementSource? source;

  const DesignQuestion(
    this.kind, {
    this.panelId,
    this.panelLabel,
    this.source,
  });

  /// The English wording.
  String get message => switch (kind) {
        DesignQuestionKind.notInterpreted =>
          'The drawing has not been interpreted yet.',
        DesignQuestionKind.overallWidthMissing =>
          'The overall width has not been entered.',
        DesignQuestionKind.overallWidthUnconfirmed =>
          'The overall width is ${source?.name}, not confirmed.',
        DesignQuestionKind.overallHeightMissing =>
          'The overall height has not been entered.',
        DesignQuestionKind.overallHeightUnconfirmed =>
          'The overall height is ${source?.name}, not confirmed.',
        DesignQuestionKind.hingeSideUnconfirmed =>
          'Panel ${panelLabel ?? panelId} opens, but the hinge side has not '
              'been confirmed.',
      };

  @override
  String toString() => message;
}

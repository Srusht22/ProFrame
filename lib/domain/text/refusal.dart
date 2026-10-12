import 'words.dart';

/// A refusal a store or an operation makes, said in any language.
///
/// The screens check what they can before they ask, in the language shown,
/// so a refusal is the last word rather than the first. But when one does
/// reach the user it is a sentence for them, not a programming error, so it
/// carries what it says ([say]) and the screen says it in its own
/// language ([messageIn]). It is still an [ArgumentError], as before, so
/// nothing that caught one stops catching it.
class Refusal extends ArgumentError {
  final String Function(Words w) say;

  Refusal(this.say) : super(say(const EnglishWords()));

  /// What it says, in [w].
  String messageIn(Words w) => say(w);
}

/// A refusal of an operation in the state things are in — still a
/// [StateError], said in any language.
class StateRefusal extends StateError {
  final String Function(Words w) say;

  StateRefusal(this.say) : super(say(const EnglishWords()));

  /// What it says, in [w].
  String messageIn(Words w) => say(w);
}

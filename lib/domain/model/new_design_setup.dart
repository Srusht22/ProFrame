import '../text/words.dart';
import 'customer.dart';
import 'design.dart';

/// A new design on its way to existing: what has been said about it so far,
/// and nothing that has not.
///
/// **New Design** on a customer's page starts one of these, not a design.
/// It knows whose the design will be from the first moment — the customer
/// it was begun from — and it knows nothing else until the user says it:
/// no name until one is typed, no category until one is chosen.
///
/// **The design's name is the design's, and it is required.** *Basement
/// Door* is a design; *Adam* is the person it is for. The two are never
/// swapped: the customer's name is never taken as the design's, and no name
/// is ever made up for it — not *Door 1*, not *Untitled* — unless that is
/// what the user typed. [nameProblem] says what is wrong with a name as
/// typed, and a setup without one is not [isComplete]. Nothing is
/// filled in to make it look finished, and nothing is kept while it is
/// being set up, so turning back from the setup leaves the customer with
/// exactly the designs they had.
///
/// [begin] is the one way a setup becomes a design, and it refuses a setup
/// that is not [isComplete]. The steps a later setup asks for — a name of
/// the design's own, say — are more fields here and more conditions in
/// [isComplete]; the screens that walk through them carry this value from
/// one to the next.
class NewDesignSetup {
  /// The customer the design will belong to — `Design.customerId`. Null
  /// only for a design begun from the designs list, which is given its
  /// customer by name when it is kept.
  final String? customerId;

  /// Who the design is for, by name — `Design.customer`.
  final String? customer;

  /// The design's own name, as the user typed it and trimmed — null until
  /// they have given one.
  final String? name;

  /// What the product is — door, window, both or sliding — once chosen.
  /// Null until the user chooses it; nothing is chosen for them.
  final DesignKind? kind;

  const NewDesignSetup({this.customerId, this.customer, this.name, this.kind});

  /// A new design for [owner], begun from their own page: theirs from the
  /// start, and nothing else said yet.
  NewDesignSetup.forCustomer(Customer owner)
    : this(customerId: owner.id, customer: owner.name);

  /// A new design begun from the designs list, for the person typed there.
  /// Who it is for is not what it is called: its name is asked next.
  NewDesignSetup.forPerson(String who) : this(customer: who.trim());

  /// What is wrong with [typed] as a design's name, in words the user can
  /// act on, or null where it will do. Only emptiness is wrong — whitespace
  /// either side is trimmed away, and anything else is the user's name for
  /// their design.
  static String? nameProblem(String typed, [Words w = const EnglishWords()]) =>
      typed.trim().isEmpty ? w.nameProblem : null;

  /// Whether a name has been given.
  bool get isNamed => (name ?? '').trim().isNotEmpty;

  /// The same setup, named [typed] — trimmed of the whitespace either side.
  /// Refuses a name [nameProblem] finds wrong, so an empty name cannot get
  /// into a setup by any route.
  NewDesignSetup withName(String typed) {
    final problem = nameProblem(typed);
    if (problem != null) throw ArgumentError.value(typed, 'name', problem);
    return NewDesignSetup(
      customerId: customerId,
      customer: customer,
      name: typed.trim(),
      kind: kind,
    );
  }

  /// The same setup, with its category chosen.
  NewDesignSetup withKind(DesignKind chosen) => NewDesignSetup(
    customerId: customerId,
    customer: customer,
    name: name,
    kind: chosen,
  );

  /// Whether everything a design needs before it exists has been said: its
  /// name and its category.
  bool get isComplete => isNamed && kind != null;

  /// The design this setup describes, as [id], made at [now] — with nothing
  /// in it but what was said: its name, its category and its customer, and
  /// no drawing, no size (every size is asked once
  /// the drawing is read), and, for a door and a door & window set, what it
  /// is built of still to be asked.
  Design begin({required String id, DateTime? now}) {
    final chosen = kind;
    if (!isNamed) {
      throw StateError('A design cannot begin before it is named');
    }
    if (chosen == null) {
      throw StateError('A design cannot begin before its category is chosen');
    }
    return Design.empty(
      id: id,
      kind: chosen,
      name: name!.trim(),
      customer: customer,
      customerId: customerId,
      now: now,
      measured: const {},
      construction: chosen.asksConstruction ? Construction.pending : null,
    );
  }
}

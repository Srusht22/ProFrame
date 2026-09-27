import 'customer.dart';
import 'design.dart';

/// A new design on its way to existing: what has been said about it so far,
/// and nothing that has not.
///
/// **New Design** on a customer's page starts one of these, not a design.
/// It knows whose the design will be from the first moment — the customer
/// it was begun from — and it knows nothing else until the user says it:
/// no category until one is chosen, no name until one is typed. Nothing is
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

  /// The design's own name, where the user has given one. Null is *not
  /// named*: the design is kept with no name rather than with one made up.
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
  /// That list knows a design by who it is for, so it is called by them —
  /// the name the user typed, not one made up.
  NewDesignSetup.forPerson(String who) : this(customer: who, name: who);

  /// The same setup, with its category chosen.
  NewDesignSetup withKind(DesignKind chosen) => NewDesignSetup(
    customerId: customerId,
    customer: customer,
    name: name,
    kind: chosen,
  );

  /// Whether everything a design needs before it exists has been said.
  bool get isComplete => kind != null;

  /// The design this setup describes, as [id], made at [now] — with nothing
  /// in it but what was said: no drawing, no size (every size is asked once
  /// the drawing is read), and, for a door and a door & window set, what it
  /// is built of still to be asked.
  Design begin({required String id, DateTime? now}) {
    final chosen = kind;
    if (chosen == null) {
      throw StateError('A design cannot begin before its category is chosen');
    }
    return Design.empty(
      id: id,
      kind: chosen,
      name: name?.trim() ?? '',
      customer: customer,
      customerId: customerId,
      now: now,
      measured: const {},
      construction: chosen.asksConstruction ? Construction.pending : null,
    );
  }
}

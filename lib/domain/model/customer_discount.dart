/// A reduction the workshop gives a customer off what their designs come
/// to.
///
/// ```
/// designs' prices ─ subtotal ─ discount ─ final total ─ payments ─ balance
/// ```
///
/// **A discount is not a payment.** It lowers what the customer owes; a
/// payment is money they handed over. The two are kept apart and never
/// added to one another (`CustomerFinance`).
///
/// It is kept as what was said — a percentage, or an amount in the
/// customer's currency — and when, by whom and why, so the final total can
/// always be explained from the subtotal. The amount it takes off is worked
/// out from the subtotal each time ([offCents]), never stored in its place:
/// a percentage of a subtotal that grows takes more.
///
/// A customer's discounts are a log, newest last: applying one replaces the
/// one before and removing one is an entry of its own, so what was given and
/// taken away stays readable. The discount in force is the last entry,
/// unless that entry is a removal.
library;

import '../text/words.dart';

enum DiscountKind {
  percent('Percentage'),
  fixed('Fixed amount');

  const DiscountKind(this.label);
  final String label;
}

class CustomerDiscount {
  /// Stable: `DSC-20261005-0001`.
  final String id;

  /// Null on an entry that removes the discount in force.
  final DiscountKind? kind;

  /// A percentage in hundredths of a per cent (10% is 1000), or an amount
  /// in whole cents of [currency] — whole numbers, so nothing drifts.
  final int value;

  /// The currency of a fixed amount. Null for a percentage and a removal.
  final String? currency;

  final DateTime at;

  /// Who gave it: *Owner*, a member of staff's name.
  final String by;

  final String note;

  const CustomerDiscount({
    required this.id,
    required this.kind,
    required this.value,
    required this.at,
    required this.by,
    this.currency,
    this.note = '',
  });

  /// An entry that takes away the discount in force.
  const CustomerDiscount.removal({
    required this.id,
    required this.at,
    required this.by,
    this.note = '',
  }) : kind = null,
       value = 0,
       currency = null;

  bool get isRemoval => kind == null;

  /// What it takes off [subtotalCents]: a percentage of it, half a cent up,
  /// or the fixed amount — never more than the subtotal, never less than
  /// nothing. A fixed amount in a currency other than [currency] takes
  /// nothing: it cannot be.
  int offCents(int subtotalCents, String currency) {
    if (subtotalCents <= 0 || isRemoval) return 0;
    final off = switch (kind!) {
      DiscountKind.percent => (subtotalCents * value + 5000) ~/ 10000,
      DiscountKind.fixed => this.currency == currency ? value : 0,
    };
    return off.clamp(0, subtotalCents);
  }

  /// Whether, as a fixed amount, it is more than [subtotalCents] — a
  /// subtotal that fell below it after it was given, by a design deleted or
  /// made cheaper. It then takes the whole subtotal and no more, and says so.
  bool exceeds(int subtotalCents) =>
      kind == DiscountKind.fixed && value > subtotalCents;

  /// What it says, in words: *10%*, *75.00 USD* — [money] writes an amount.
  String describe(
    String Function(int cents) money, [
    Words w = const EnglishWords(),
  ]) => switch (kind) {
    DiscountKind.percent => '${_percentText(value)}%',
    DiscountKind.fixed => money(value),
    null => w.discountNone,
  };

  static String _percentText(int hundredths) {
    final whole = hundredths ~/ 100;
    final part = hundredths % 100;
    if (part == 0) return '$whole';
    return '$whole.${part.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}';
  }

  /// Why [kind] at [value] cannot be given against [subtotalCents] — or
  /// null where it can. A percentage is more than nothing and at most 100;
  /// a fixed amount more than nothing and no more than the subtotal, which
  /// must then be final. [money] writes an amount.
  static String? problemWith({
    required DiscountKind kind,
    required int? value,
    required int? subtotalCents,
    required String Function(int cents) money,
    Words words = const EnglishWords(),
  }) {
    final w = words;
    if (value == null) return w.discountEnter;
    if (value <= 0) return w.discountMoreThanNothing;
    switch (kind) {
      case DiscountKind.percent:
        if (value > 10000) return w.discountOver100;
      case DiscountKind.fixed:
        if (subtotalCents == null) return w.discountNotFinal;
        if (value > subtotalCents) {
          return w.discountOverSubtotal(money(subtotalCents));
        }
    }
    return null;
  }

  /// A percentage as typed — *10*, *12.5* — in hundredths of a per cent, or
  /// why it is not one.
  static ({int? value, String? problem}) readPercent(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim().replaceAll('%', '').trim();
    if (words.isEmpty) return (value: null, problem: w.discountEnter);
    if (words.startsWith('-')) {
      return (value: null, problem: w.discountMoreThanNothing);
    }
    final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(words);
    if (m == null) {
      return (value: null, problem: w.discountPercentNumber);
    }
    final whole = int.parse(m.group(1)!);
    if (whole > 100) {
      return (value: null, problem: w.discountOver100);
    }
    final part = int.parse((m.group(2) ?? '').padRight(2, '0'));
    return (value: whole * 100 + part, problem: null);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    if (kind != null) 'kind': kind!.name,
    if (kind != null) 'value': value,
    if (currency != null) 'currency': currency,
    'at': at.toIso8601String(),
    'by': by,
    if (note.isNotEmpty) 'note': note,
  };

  /// An entry as kept, or null where it is not one.
  static CustomerDiscount? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (id is! String || at == null) return null;
    final by = json['by'] as String? ?? '';
    final note = json['note'] as String? ?? '';
    if (!json.containsKey('kind')) {
      return CustomerDiscount.removal(id: id, at: at, by: by, note: note);
    }
    final kind = DiscountKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final value = json['value'];
    if (kind == null || value is! int || value <= 0) return null;
    if (kind == DiscountKind.percent && value > 10000) return null;
    final currency = json['currency'];
    if (kind == DiscountKind.fixed && currency is! String) return null;
    return CustomerDiscount(
      id: id,
      kind: kind,
      value: value,
      currency: currency as String?,
      at: at,
      by: by,
      note: note,
    );
  }
}

/// A customer's discount log, and the discount in force.
extension DiscountLog on List<CustomerDiscount> {
  /// The discount in force: the last entry, unless it took one away.
  CustomerDiscount? get inForce => isEmpty || last.isRemoval ? null : last;

  /// An id no entry here has had, for one given at [at].
  String nextDiscountId(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${at.year}${two(at.month)}${two(at.day)}';
    var n = length + 1;
    String id() => 'DSC-$day-${n.toString().padLeft(4, '0')}';
    while (any((d) => d.id == id())) {
      n++;
    }
    return id();
  }
}

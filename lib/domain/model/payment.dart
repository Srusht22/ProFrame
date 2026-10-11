/// Money a customer has handed over, or been handed back — the customer's
/// payment ledger.
///
/// ```
/// Customer
///   └── payments: PaymentTransaction, PaymentTransaction, …
///         ├── Payment  +500.00   Cash            05 Oct 2026
///         ├── Payment  +300.00   Bank transfer   28 Sep 2026
///         └── Refund   −100.00   Cash            02 Oct 2026
/// ```
///
/// **The ledger is the one record of money paid.** What a customer has paid
/// is never a figure kept beside it: it is the payments less the refunds,
/// worked out from the transactions every time (`PaymentLedger`), so the two
/// cannot disagree. What the customer's designs come to is not here either —
/// it is worked out from the designs (`CustomerPricing`) — and the balance
/// is the one less the other (`CustomerFinance`).
///
/// **A transaction is never changed or removed.** Money recorded wrongly is
/// put right by another transaction — a refund — so the history says what
/// happened, in the order it happened. Nothing in the application edits or
/// deletes one.
library;

import '../text/names.dart';
import '../text/words.dart';

/// Which way the money went.
enum PaymentType {
  /// Money received from the customer.
  payment('Payment'),

  /// Money returned to the customer.
  refund('Refund');

  const PaymentType(this.label);
  final String label;
}

/// How the money was handed over — a record of it, not a link to a bank.
enum PaymentMethod {
  cash('Cash'),
  bankTransfer('Bank transfer'),
  card('Card'),
  other('Other'),

  /// A payment brought over from the single paid figure customers were
  /// kept with before the ledger, whose method nobody recorded. Never
  /// offered for a new transaction.
  legacy('Legacy / unknown');

  const PaymentMethod(this.label);
  final String label;

  /// The methods a new transaction can be recorded with, in that order.
  static const offered = [cash, bankTransfer, card, other];
}

/// What a transaction in another currency was worth in the customer's
/// currency, at the rate the user gave when it was recorded.
///
/// **It is kept, never worked out again.** A rate is a fact about the day
/// the money changed hands; reading today's rate into an old payment would
/// change what the customer paid. Where no rate was given there is no
/// conversion, and the money is not counted towards a total in another
/// currency — it is shown in its own.
class Conversion {
  /// The currency it was converted into: the customer's, the price list's.
  final String to;

  /// How many of [to] one unit of the transaction's currency was worth.
  final double rate;

  /// The transaction's amount in [to], in whole cents, as worked out then.
  final int cents;

  const Conversion({required this.to, required this.rate, required this.cents});

  /// [amountCents] converted at [rate] into [to], half a cent rounded up.
  static Conversion of(int amountCents, double rate, String to) => Conversion(
    to: to,
    rate: rate,
    cents: (amountCents * rate + 1e-7).round(),
  );

  Map<String, Object?> toJson() => {'to': to, 'rate': rate, 'cents': cents};

  static Conversion? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final to = json['to'];
    final rate = json['rate'];
    final cents = json['cents'];
    if (to is! String || to.isEmpty) return null;
    if (rate is! num || !rate.isFinite || rate <= 0) return null;
    if (cents is! int || cents <= 0) return null;
    return Conversion(to: to, rate: rate.toDouble(), cents: cents);
  }
}

/// One payment or refund, as it was recorded.
///
/// Its [amountCents] is always more than nothing: a refund is not a
/// negative payment but a transaction of its own [type], so the history
/// reads as what happened. Money is kept in whole cents, as every price
/// line and total is (`Money.cents`), so nothing is summed from a figure
/// rounded for the screen.
class PaymentTransaction {
  /// Stable for as long as the transaction is kept — `PAY-20261005-0001`,
  /// `REF-20261005-0002` — and never its place in a list. Unique within its
  /// customer's ledger; with [customerId] it names one transaction.
  final String id;

  /// The customer it belongs to — by id, never by name, since two people
  /// can share one.
  final String customerId;

  final PaymentType type;
  final int amountCents;

  /// When the money changed hands — the date the user gave, never a future
  /// one, and never the day the customer was first kept.
  final DateTime at;

  final PaymentMethod method;

  /// What *Other* was, where the user said: *Company cheque*. Empty for
  /// every other method.
  final String methodDetail;

  /// The user's own note on it: *First installment*, *Refund for the
  /// cancelled hardware*. Never the customer's general notes.
  final String note;

  /// When it was recorded in the application — which, for a payment dated
  /// last week, is not [at].
  final DateTime createdAt;

  /// The currency it was recorded in — the price list's, as the prices
  /// were — or null for a legacy payment, which was recorded against the
  /// price list's currency without saying which.
  final String? currency;

  /// What it was worth in the customer's currency, where it was recorded in
  /// another and the user gave the rate — see [Conversion]. Null for money
  /// in the customer's own currency, and for money in another with no rate.
  final Conversion? conversion;

  /// Who recorded it — *Owner*, a member of staff's name — where that was
  /// known. Empty for a transaction recorded before it was asked.
  final String recordedBy;

  const PaymentTransaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountCents,
    required this.at,
    required this.method,
    required this.createdAt,
    this.methodDetail = '',
    this.note = '',
    this.currency,
    this.conversion,
    this.recordedBy = '',
  });

  /// The id the legacy payment of a customer is kept under: one only, so
  /// bringing the old figure over twice gives the same transaction, never a
  /// second.
  static const legacyId = 'PAY-LEGACY';

  /// The note a legacy payment carries.
  static const legacyNote =
      'Migrated from the previous customer payment balance.';

  bool get isLegacy => id == legacyId;

  double get amount => amountCents / 100;

  /// What it does to what the customer has paid: more for a payment, less
  /// for a refund.
  int get signedCents =>
      type == PaymentType.payment ? amountCents : -amountCents;

  /// The method in words: *Cash*, *Other — Company cheque*.
  String get methodLabel => methodLabelIn(const EnglishWords());

  /// [methodLabel], in [w].
  String methodLabelIn(Words w) =>
      method == PaymentMethod.other && methodDetail.isNotEmpty
      ? w.payOtherDetail(methodDetail)
      : method.labelIn(w);

  /// The note in [w]: the legacy payment's own note is the application's
  /// words and is said in [w]; any other is the user's, as written.
  String noteIn(Words w) =>
      isLegacy && note == legacyNote ? w.payLegacyNote : note;

  Map<String, Object?> toJson() => {
    'id': id,
    'customerId': customerId,
    'type': type.name,
    'amountCents': amountCents,
    'at': at.toIso8601String(),
    'method': method.name,
    if (methodDetail.isNotEmpty) 'methodDetail': methodDetail,
    if (note.isNotEmpty) 'note': note,
    'createdAt': createdAt.toIso8601String(),
    if (currency != null) 'currency': currency,
    if (conversion != null) 'conversion': conversion!.toJson(),
    if (recordedBy.isNotEmpty) 'recordedBy': recordedBy,
  };

  /// The transaction kept as [json], or null where it is not one — an id,
  /// a type, an amount of more than nothing in whole cents and a date are
  /// all required. [customerId] is the customer it is kept with, which it
  /// belongs to whatever it says.
  static PaymentTransaction? fromJson(Object? json, {String? customerId}) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final type = PaymentType.values
        .where((t) => t.name == json['type'])
        .firstOrNull;
    final cents = json['amountCents'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (id is! String || id.isEmpty || type == null || at == null) return null;
    if (cents is! int || cents <= 0) return null;
    final owner = customerId ?? json['customerId'];
    if (owner is! String) return null;
    return PaymentTransaction(
      id: id,
      customerId: owner,
      type: type,
      amountCents: cents,
      at: at,
      method:
          PaymentMethod.values
              .where((m) => m.name == json['method'])
              .firstOrNull ??
          PaymentMethod.legacy,
      methodDetail: json['methodDetail'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? at,
      currency: json['currency'] as String?,
      conversion: Conversion.fromJson(json['conversion']),
      recordedBy: json['recordedBy'] as String? ?? '',
    );
  }

  /// What it counts for in [base], in whole cents — its own amount where it
  /// was recorded in [base] (or, recorded before currencies were kept, in
  /// the price list's), its kept conversion where it was converted into
  /// [base], and null where it cannot be counted in [base] at all.
  int? countedIn(String base) {
    if (currency == null || currency == base) return amountCents;
    if (conversion case final c? when c.to == base) return c.cents;
    return null;
  }
}

/// A transaction's money in a currency it is not counted in: its own
/// payments and refunds, in that currency.
class CurrencyTotals {
  final String currency;
  final int paymentsCents;
  final int refundsCents;

  const CurrencyTotals(this.currency, this.paymentsCents, this.refundsCents);

  int get netCents => paymentsCents - refundsCents;
}

/// One page of a ledger's history, newest first, and how many there are.
class LedgerPage {
  final List<PaymentTransaction> items;
  final int total;
  final int offset;

  const LedgerPage(this.items, this.total, this.offset);

  bool get hasMore => offset + items.length < total;
}

/// A customer's transactions, and what they come to.
class PaymentLedger {
  /// As kept, in the order they were recorded.
  final List<PaymentTransaction> transactions;

  const PaymentLedger(this.transactions);

  static const empty = PaymentLedger([]);

  bool get isEmpty => transactions.isEmpty;

  /// Newest first: by when the money changed hands, then — for two on the
  /// same moment — by when each was recorded, then by id, so the order is
  /// the same every time it is read and never only the order of the list.
  List<PaymentTransaction> get newestFirst => [...transactions]
    ..sort((a, b) {
      final byDate = b.at.compareTo(a.at);
      if (byDate != 0) return byDate;
      final byRecorded = b.createdAt.compareTo(a.createdAt);
      if (byRecorded != 0) return byRecorded;
      return b.id.compareTo(a.id);
    });

  /// The transactions recorded in [currency] — or recorded before
  /// currencies were kept, against the price list's.
  Iterable<PaymentTransaction> inCurrency(String currency) =>
      transactions.where((t) => t.currency == null || t.currency == currency);

  /// The transactions that count towards a total in [base]: those recorded
  /// in it, and those converted into it at a rate kept with them.
  Iterable<PaymentTransaction> countedIn(String base) =>
      transactions.where((t) => t.countedIn(base) != null);

  /// How many cannot be counted in [base] — another currency, no rate. Not
  /// added to it, and said.
  int otherCurrencyCount(String base) =>
      transactions.length - countedIn(base).length;

  /// The money that cannot be counted in [base], currency by currency, in
  /// the order the currencies are named.
  List<CurrencyTotals> uncountedIn(String base) {
    final by = <String, (int, int)>{};
    for (final t in transactions) {
      if (t.countedIn(base) != null) continue;
      final (p, r) = by[t.currency!] ?? (0, 0);
      by[t.currency!] = t.type == PaymentType.payment
          ? (p + t.amountCents, r)
          : (p, r + t.amountCents);
    }
    final names = by.keys.toList()..sort();
    return [for (final c in names) CurrencyTotals(c, by[c]!.$1, by[c]!.$2)];
  }

  /// Every payment that counts in [base], summed, in whole cents.
  int grossPaymentsCents(String base) =>
      countedIn(base)
          .where((t) => t.type == PaymentType.payment)
          .fold(0, (s, t) => s + t.countedIn(base)!);

  /// Every refund that counts in [base], summed, in whole cents.
  int grossRefundsCents(String base) =>
      countedIn(base)
          .where((t) => t.type == PaymentType.refund)
          .fold(0, (s, t) => s + t.countedIn(base)!);

  /// The payments less the refunds.
  int netPaidCents(String base) =>
      grossPaymentsCents(base) - grossRefundsCents(base);

  /// Money paid, net, in [currency] that is not counted in [base].
  int netUncountedCents(String currency, String base) =>
      uncountedIn(base)
          .where((c) => c.currency == currency)
          .fold(0, (s, c) => s + c.netCents);

  /// [limit] transactions of the history from [offset], newest first, and
  /// how many there are in all. The figures never depend on how many pages
  /// have been read: they are the whole ledger's.
  LedgerPage page({int offset = 0, int limit = 10}) {
    final all = newestFirst;
    final start = offset.clamp(0, all.length);
    final end = (start + limit).clamp(start, all.length);
    return LedgerPage(all.sublist(start, end), all.length, start);
  }

  bool contains(String id) => transactions.any((t) => t.id == id);

  /// An id for a new transaction of [type] recorded at [at]: its kind, the
  /// day, and a number no transaction of this ledger has had —
  /// `PAY-20261005-0003`. Nothing is ever removed from a ledger, so the
  /// number only grows.
  String nextId(PaymentType type, DateTime at) {
    final prefix = type == PaymentType.payment ? 'PAY' : 'REF';
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${at.year}${two(at.month)}${two(at.day)}';
    var n = transactions.length + 1;
    String id() => '$prefix-$day-${n.toString().padLeft(4, '0')}';
    while (contains(id())) {
      n++;
    }
    return id();
  }

  /// This ledger with [transaction] added — or as it is, where one with its
  /// id is already in it.
  PaymentLedger plus(PaymentTransaction transaction) => contains(transaction.id)
      ? this
      : PaymentLedger([...transactions, transaction]);

  /// What the user typed for an amount, in whole cents, or why it is not
  /// one: a figure of more than nothing, to the cent at most, with no sign
  /// — a refund is its own kind of transaction, never a negative amount.
  /// Thousands may be separated by commas.
  static ({int? cents, String? problem}) readAmount(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim().replaceAll(',', '');
    if (words.isEmpty) return (cents: null, problem: w.amtEnter);
    if (words.startsWith('-')) {
      return (cents: null, problem: w.amtMoreThanNothing);
    }
    if (RegExp(r'^\d*\.\d{3,}$').hasMatch(words)) {
      return (cents: null, problem: w.amtToTheCent);
    }
    final match =
        RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(words) ??
        RegExp(r'^()\.(\d{1,2})$').firstMatch(words);
    if (match == null) {
      return (cents: null, problem: w.amtAsNumber);
    }
    final whole = int.tryParse(match.group(1)!.isEmpty ? '0' : match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    if (whole == null || whole > 1000000000) {
      return (cents: null, problem: w.amtSmaller);
    }
    final cents = whole * 100 + int.parse(fraction);
    if (cents <= 0) {
      return (cents: null, problem: w.amtMoreThanNothing);
    }
    return (cents: cents, problem: null);
  }

  /// What is wrong with recording [cents] of [type] at [at] in this
  /// ledger, as of [now] — keyed `amount` and `date` — where [currency] is
  /// the customer's (the prices') and [money] writes a figure in it. The
  /// transaction is in [inCurrency], [currency] where not said, and
  /// [conversion] is what it is worth in [currency] where it is in another.
  ///
  /// - The amount is more than nothing, for a payment and a refund alike.
  /// - Nothing is dated after [now]: the ledger holds money that has
  ///   changed hands, never money expected.
  /// - A refund is no more than has been paid, net, in what it is counted
  ///   in — so a customer's credit can be refunded, and their payments, but
  ///   never money they did not pay. A payment of more than is due is
  ///   taken: it is credit.
  Map<String, String> problemsWith({
    required PaymentType type,
    required int? cents,
    required DateTime at,
    required DateTime now,
    required String currency,
    required String Function(int cents) money,
    String? inCurrency,
    Conversion? conversion,
    String Function(int cents, String currency)? moneyIn,
    Words words = const EnglishWords(),
  }) {
    final w = words;
    final own = inCurrency ?? currency;
    final problems = <String, String>{};
    if (cents == null || cents <= 0) {
      problems['amount'] = w.amtMoreThanNothing;
    } else if (type == PaymentType.refund) {
      final counted = own == currency || conversion != null;
      final net = counted
          ? netPaidCents(currency)
          : netUncountedCents(own, currency);
      final asked = own == currency ? cents : (conversion?.cents ?? cents);
      final say = counted
          ? money(net)
          : (moneyIn?.call(net, own) ?? '${net / 100} $own');
      if (net <= 0) {
        problems['amount'] = counted
            ? w.refundNothingPaid
            : w.refundNothingPaidIn(own);
      } else if (asked > net) {
        problems['amount'] = w.refundTooMuch(say);
      }
    }
    if (at.isAfter(now)) {
      problems['date'] = type == PaymentType.refund
          ? w.refundNotFuture
          : w.paymentNotFuture;
    }
    return problems;
  }

  /// What the user typed for an exchange rate, or why it is not one: a
  /// figure of more than nothing, to six decimal places at most.
  static ({double? rate, String? problem}) readRate(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim().replaceAll(',', '');
    if (words.isEmpty) return (rate: null, problem: null);
    if (!RegExp(r'^\d*\.?\d{1,6}$').hasMatch(words) ||
        RegExp(r'^\d+\.$').hasMatch(words)) {
      return (rate: null, problem: w.rateAsNumber);
    }
    final rate = double.tryParse(words);
    if (rate == null || !rate.isFinite || rate <= 0) {
      return (rate: null, problem: w.rateMoreThanNothing);
    }
    return (rate: rate, problem: null);
  }
}

/// The currencies a payment can be recorded in, by their ISO codes.
abstract final class Currencies {
  /// Those offered beside the customer's own, in this order.
  static const common = ['USD', 'EUR', 'GBP', 'IQD', 'TRY', 'AED', 'SAR'];

  /// [base] first, then the rest of [common].
  static List<String> offeredWith(String base) => [
    base,
    for (final c in common)
      if (c != base) c,
  ];
}

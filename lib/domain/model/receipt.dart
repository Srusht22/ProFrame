import '../text/names.dart';
import '../text/words.dart';
import 'payment.dart';

/// A receipt: the workshop's written word that it received one payment.
///
/// **A receipt is not money.** It is issued *for* a payment already in the
/// customer's ledger and says so by the payment's id; it adds nothing to
/// what was paid, and issuing it — or opening it, or issuing it again —
/// changes no total. A payment has at most one receipt: asking for a second
/// gives back the first.
///
/// Its number is the workshop's, from a sequence kept on the device that
/// only ever goes up (`CustomerStore.issueReceipt`), so no two receipts share
/// one and none is ever reused — never worked out from how many receipts a
/// list holds.
///
/// It keeps what it says as it was said: the amount, currency, method and
/// note as recorded, and the balance as it stood when it was issued. It is
/// never edited or deleted.
class Receipt {
  /// Stable, with its number: `RCP-000001`.
  final String id;

  /// The sequence number — 1, 2, 3 …
  final int number;

  final String customerId;

  /// The payment it is for.
  final String transactionId;

  final int amountCents;
  final String currency;

  /// What the payment was worth in the customer's currency, where it was
  /// paid in another at a rate kept with it.
  final Conversion? conversion;

  /// When the money was received — the payment's date.
  final DateTime paidAt;

  /// When the receipt was issued.
  final DateTime issuedAt;

  final PaymentMethod method;
  final String methodDetail;
  final String note;

  /// The customer's balance in [balanceCurrency] just after it was issued:
  /// more than nothing is still due, less than nothing is credit. Null where
  /// the total was not final then, and nothing could be said.
  final int? balanceAfterCents;
  final String balanceCurrency;

  /// Who issued it.
  final String issuedBy;

  const Receipt({
    required this.id,
    required this.number,
    required this.customerId,
    required this.transactionId,
    required this.amountCents,
    required this.currency,
    required this.paidAt,
    required this.issuedAt,
    required this.method,
    required this.balanceCurrency,
    this.conversion,
    this.methodDetail = '',
    this.note = '',
    this.balanceAfterCents,
    this.issuedBy = '',
  });

  /// [number] as it is written: `RCP-000001`.
  static String numbered(int number) =>
      'RCP-${number.toString().padLeft(6, '0')}';

  String get label => numbered(number);

  String get methodLabel => methodLabelIn(const EnglishWords());

  /// [methodLabel], in [w].
  String methodLabelIn(Words w) =>
      method == PaymentMethod.other && methodDetail.isNotEmpty
      ? w.payOtherDetail(methodDetail)
      : method.labelIn(w);

  /// The receipt for [payment], numbered [number], issued at [now] by [by],
  /// with the balance as it then stood. [currency] is the customer's —
  /// what a payment recorded before currencies were kept was paid in.
  static Receipt forPayment(
    PaymentTransaction payment, {
    required int number,
    required DateTime now,
    required String currency,
    required int? balanceAfterCents,
    required String by,
  }) => Receipt(
    id: numbered(number),
    number: number,
    customerId: payment.customerId,
    transactionId: payment.id,
    amountCents: payment.amountCents,
    currency: payment.currency ?? currency,
    conversion: payment.conversion,
    paidAt: payment.at,
    issuedAt: now,
    method: payment.method,
    methodDetail: payment.methodDetail,
    note: payment.note,
    balanceAfterCents: balanceAfterCents,
    balanceCurrency: currency,
    issuedBy: by,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'transactionId': transactionId,
    'amountCents': amountCents,
    'currency': currency,
    if (conversion != null) 'conversion': conversion!.toJson(),
    'paidAt': paidAt.toIso8601String(),
    'issuedAt': issuedAt.toIso8601String(),
    'method': method.name,
    if (methodDetail.isNotEmpty) 'methodDetail': methodDetail,
    if (note.isNotEmpty) 'note': note,
    if (balanceAfterCents != null) 'balanceAfterCents': balanceAfterCents,
    'balanceCurrency': balanceCurrency,
    if (issuedBy.isNotEmpty) 'issuedBy': issuedBy,
  };

  /// A receipt as kept, or null where the entry is not one. [customerId]
  /// is the customer it is kept with.
  static Receipt? fromJson(Object? json, {String? customerId}) {
    if (json is! Map<String, Object?>) return null;
    final number = json['number'];
    final txn = json['transactionId'];
    final cents = json['amountCents'];
    final currency = json['currency'];
    final paid = DateTime.tryParse(json['paidAt'] as String? ?? '');
    final issued = DateTime.tryParse(json['issuedAt'] as String? ?? '');
    final owner = customerId ?? json['customerId'];
    if (number is! int || number <= 0 || txn is! String) return null;
    if (cents is! int || cents <= 0 || currency is! String) return null;
    if (paid == null || issued == null || owner is! String) return null;
    return Receipt(
      id: numbered(number),
      number: number,
      customerId: owner,
      transactionId: txn,
      amountCents: cents,
      currency: currency,
      conversion: Conversion.fromJson(json['conversion']),
      paidAt: paid,
      issuedAt: issued,
      method:
          PaymentMethod.values
              .where((m) => m.name == json['method'])
              .firstOrNull ??
          PaymentMethod.legacy,
      methodDetail: json['methodDetail'] as String? ?? '',
      note: json['note'] as String? ?? '',
      balanceAfterCents: json['balanceAfterCents'] as int?,
      balanceCurrency: json['balanceCurrency'] as String? ?? currency,
      issuedBy: json['issuedBy'] as String? ?? '',
    );
  }
}

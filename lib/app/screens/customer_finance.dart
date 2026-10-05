import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/payment.dart';
import '../../domain/pricing/design_price_state.dart';
import '../inspector/price_panel.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'designs_screen.dart' show monthNames;

/// A customer's money, under their design cards: what their designs come
/// to, what the ledger says they have paid and been refunded, what is due
/// or in credit — **Add payment** and **Refund** — then the payment history,
/// and each design's own price and what they all measure together.
///
/// **It holds no figure of its own.** The total is `CustomerPricing`'s,
/// summed from each design's current price; what was paid is the ledger's
/// (`Customer.payments`), summed; what is due or in credit and how they
/// stand are `CustomerFinance`'s. Where one of the designs has no current
/// price — incomplete, changed since it was calculated, or of a category
/// that cannot be priced — the total is said to be not final and why, and
/// no sum of some of the prices is shown as the customer's price.
class CustomerFinancialSummary extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerFinancialSummary({super.key, required this.customer});

  static const cardKey = ValueKey('customer-finance');
  static const totalKey = ValueKey('customer-finance-total');
  static const notFinalKey = ValueKey('customer-finance-not-final');
  static const pricedSoFarKey = ValueKey('customer-finance-so-far');
  static const grossPaymentsKey = ValueKey('customer-finance-payments');
  static const refundsKey = ValueKey('customer-finance-refunds');

  /// What has been paid, net of refunds.
  static const paidKey = ValueKey('customer-finance-paid');
  static const dueKey = ValueKey('customer-finance-due');
  static const creditKey = ValueKey('customer-finance-credit');
  static const statusKey = ValueKey('customer-finance-status');
  static const addPaymentKey = ValueKey('customer-finance-add-payment');
  static const refundKey = ValueKey('customer-finance-refund');
  static const historyKey = ValueKey('customer-finance-history');
  static const showAllKey = ValueKey('customer-finance-history-all');
  static const toggleKey = ValueKey('customer-finance-toggle');

  /// One transaction of the history, by its id.
  static ValueKey<String> transactionKey(String id) =>
      ValueKey('customer-finance-transaction-$id');

  /// What design [id] is and is made of, under its price.
  static ValueKey<String> profileKey(String id) =>
      ValueKey('summary-design-profile-$id');

  static ValueKey<String> designKey(String id) =>
      ValueKey('customer-finance-design-$id');

  /// How many transactions the history shows before **Show all**.
  static const shownFirst = 5;

  @override
  ConsumerState<CustomerFinancialSummary> createState() =>
      _CustomerFinancialSummaryState();
}

class _CustomerFinancialSummaryState
    extends ConsumerState<CustomerFinancialSummary> {
  bool _open = false;
  bool _allHistory = false;

  @override
  Widget build(BuildContext context) {
    final pricing = ref
        .watch(customerPricingProvider(widget.customer.id))
        .value;
    if (pricing == null) return const SizedBox.shrink();
    final ledger = widget.customer.ledger;
    final finance = CustomerFinance.of(pricing, ledger);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final currency = pricing.currency;
    String money(double v) => PricePanel.money(v, currency);

    Widget heading(String words, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        words,
        style: text.labelMedium?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: p.muted,
        ),
      ),
    );

    final history = ledger.newestFirst;
    final shown = _allHistory
        ? history
        : history.take(CustomerFinancialSummary.shownFirst).toList();

    return Container(
      key: CustomerFinancialSummary.cardKey,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('FINANCIAL SUMMARY'),
          PriceRow(
            'Designs',
            '${pricing.designs.length} · ${pricing.priced.length} priced',
          ),
          _BigRow(
            'Total price',
            finance.total == null ? 'Not final' : money(finance.total!),
            valueKey: CustomerFinancialSummary.totalKey,
          ),
          if (finance.total == null) ...[
            Text(
              'Customer price is not final. ${pricing.notFinalReason}',
              key: CustomerFinancialSummary.notFinalKey,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            PriceRow(
              'Priced so far (not the total)',
              money(pricing.pricedSoFar),
              valueKey: CustomerFinancialSummary.pricedSoFarKey,
            ),
          ],
          PriceRow(
            'Total payments',
            money(finance.grossPayments),
            valueKey: CustomerFinancialSummary.grossPaymentsKey,
          ),
          PriceRow(
            'Refunds',
            money(finance.grossRefunds),
            valueKey: CustomerFinancialSummary.refundsKey,
          ),
          PriceRow(
            'Net paid',
            money(finance.netPaid),
            valueKey: CustomerFinancialSummary.paidKey,
          ),
          const SizedBox(height: 4),
          PriceRow(
            'Amount due',
            finance.due == null ? '—' : money(finance.due!),
            strong: true,
            valueKey: CustomerFinancialSummary.dueKey,
          ),
          PriceRow(
            'Credit',
            finance.credit == null ? '—' : money(finance.credit!),
            strong: (finance.credit ?? 0) > 0,
            valueKey: CustomerFinancialSummary.creditKey,
          ),
          if ((finance.credit ?? 0) > 0)
            Text(
              'The customer has paid ${money(finance.credit!)} more than '
              'their designs now come to. It is theirs: it can be refunded, '
              'or stand against a later design.',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          if (finance.otherCurrency > 0)
            Text(
              '${finance.otherCurrency} '
              '${finance.otherCurrency == 1 ? 'transaction was' : 'transactions were'} '
              'recorded in another currency and '
              '${finance.otherCurrency == 1 ? 'is' : 'are'} not counted.',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              PaymentStatusChip(finance.status),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: CustomerFinancialSummary.addPaymentKey,
                    onPressed: () => recordTransaction(
                      context,
                      ref,
                      widget.customer,
                      finance,
                      PaymentType.payment,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add payment'),
                  ),
                  OutlinedButton.icon(
                    key: CustomerFinancialSummary.refundKey,
                    onPressed: finance.netPaidCents <= 0
                        ? null
                        : () => recordTransaction(
                            context,
                            ref,
                            widget.customer,
                            finance,
                            PaymentType.refund,
                          ),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Refund'),
                  ),
                ],
              ),
            ],
          ),
          heading('PAYMENT HISTORY', key: CustomerFinancialSummary.historyKey),
          if (history.isEmpty)
            Text(
              'No payments recorded yet.',
              style: text.bodyMedium?.copyWith(color: p.muted),
            ),
          for (final t in shown) TransactionRow(t, currency: currency),
          if (history.length > CustomerFinancialSummary.shownFirst)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: CustomerFinancialSummary.showAllKey,
                onPressed: () => setState(() => _allHistory = !_allHistory),
                child: Text(
                  _allHistory
                      ? 'Show the latest ${CustomerFinancialSummary.shownFirst}'
                      : 'Show all ${history.length}',
                ),
              ),
            ),
          const Divider(height: 18),
          InkWell(
            key: CustomerFinancialSummary.toggleKey,
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _open
                          ? 'Hide each design and the materials'
                          : 'Show each design and the materials',
                      style: text.bodyMedium?.copyWith(color: p.primary),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: p.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            heading('DESIGNS'),
            for (final d in pricing.designs) ...[
              PriceRow(
                key: CustomerFinancialSummary.designKey(d.designId),
                d.name,
                d.state.total == null ? d.state.note : money(d.state.total!),
              ),
              // What it is and what it is made of: why two designs cost
              // different amounts.
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Category: ${d.kind.label} · '
                  'Material: ${d.profile.materialName} · '
                  'Colour: ${d.colourName}',
                  key: CustomerFinancialSummary.profileKey(d.designId),
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
            ],
            heading('CUSTOMER MATERIAL SUMMARY'),
            MeasurementRows(pricing.measurements),
            if (pricing.priced.length < pricing.designs.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Of the ${pricing.priced.length} of '
                  '${pricing.designs.length} designs with a current price.',
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// How the customer stands, in a word, for a glance.
class PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;
  final bool small;

  const PaymentStatusChip(this.status, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colour = switch (status) {
      PaymentStatus.paidInFull ||
      PaymentStatus.nothingToPay ||
      PaymentStatus.credit => p.primary,
      PaymentStatus.outstanding ||
      PaymentStatus.pricingIncomplete => Theme.of(context).colorScheme.error,
    };
    return Container(
      key: small ? null : CustomerFinancialSummary.statusKey,
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colour,
        ),
      ),
    );
  }
}

/// The customer's money at a glance, on the bar beside their name: how
/// they stand, and what is due — or that the total is not final. The same
/// figures as the summary under the cards, read from the same place.
class CustomerMoneyGlance extends ConsumerWidget {
  final Customer customer;

  const CustomerMoneyGlance({super.key, required this.customer});

  static const glanceKey = ValueKey('customer-money-glance');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = ref.watch(customerPricingProvider(customer.id)).value;
    if (pricing == null) return const SizedBox.shrink();
    final finance = CustomerFinance.of(pricing, customer.ledger);
    final words = switch (finance.status) {
      PaymentStatus.outstanding =>
        'Due ${PricePanel.money(finance.due!, pricing.currency)}',
      PaymentStatus.credit =>
        'Credit ${PricePanel.money(finance.credit!, pricing.currency)}',
      final status => status.label,
    };
    return Container(
      key: glanceKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        words,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _BigRow extends StatelessWidget {
  final String label;
  final String value;
  final Key? valueKey;

  const _BigRow(this.label, this.value, {this.valueKey});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.titleMedium)),
          Text(
            value,
            key: valueKey,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// One payment or refund in the history: its date, what it was — said in
/// words and by its mark, never by colour alone — its amount with its sign,
/// how it was paid and the note on it.
class TransactionRow extends StatelessWidget {
  final PaymentTransaction transaction;
  final String currency;

  const TransactionRow(this.transaction, {super.key, required this.currency});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final refund = t.type == PaymentType.refund;
    final colour = refund ? Theme.of(context).colorScheme.error : p.primary;
    final amount =
        '${refund ? '−' : '+'}${PricePanel.money(t.amount, t.currency ?? currency)}';
    return Container(
      key: CustomerFinancialSummary.transactionKey(t.id),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              refund ? Icons.call_made : Icons.call_received,
              size: 18,
              color: colour,
              semanticLabel: t.type.label,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      t.type.label.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colour,
                      ),
                    ),
                    Text(dayOf(t.at), style: text.bodyMedium),
                  ],
                ),
                Text(
                  t.methodLabel,
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
                if (t.note.isNotEmpty) Text(t.note, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// [at] as a day: *05 Oct 2026*.
String dayOf(DateTime at) =>
    '${at.day.toString().padLeft(2, '0')} ${monthNames[at.month - 1]} '
    '${at.year}';

/// Asks for a payment or a refund of [customer]'s and records it in their
/// ledger — only it: no design and no price is touched.
Future<void> recordTransaction(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  CustomerFinance finance,
  PaymentType type,
) async {
  final transaction = await showDialog<PaymentTransaction>(
    context: context,
    builder: (_) =>
        TransactionDialog(customer: customer, finance: finance, type: type),
  );
  if (transaction == null) return;
  await ref.recordTransaction(transaction);
}

/// The fields and buttons of the payment and refund form.
abstract final class PaymentDialogKeys {
  static const amount = ValueKey('payment-amount');
  static const method = ValueKey('payment-method');
  static const other = ValueKey('payment-other');
  static const date = ValueKey('payment-date');
  static const note = ValueKey('payment-note');
  static const save = ValueKey('payment-save');
}

/// **Add payment** and **Refund**: the amount, how it was paid, the day it
/// was — today unless said, never a later one — and a note. What it records
/// is checked by the ledger (`PaymentLedger.problemsWith`) before it is
/// returned; nothing is recorded here.
class TransactionDialog extends StatefulWidget {
  final Customer customer;
  final CustomerFinance finance;
  final PaymentType type;

  /// The moment it is now — for a test to set.
  final DateTime Function() clock;

  const TransactionDialog({
    super.key,
    required this.customer,
    required this.finance,
    required this.type,
    this.clock = DateTime.now,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _amount = TextEditingController();
  final _other = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  late DateTime _day = _today;
  Map<String, String> _problems = const {};

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _refund => widget.type == PaymentType.refund;

  @override
  void dispose() {
    _amount.dispose();
    _other.dispose();
    _note.dispose();
    super.dispose();
  }

  String _money(int cents) =>
      PricePanel.money(cents / 100, widget.finance.currency);

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked != null) setState(() => _day = picked);
  }

  void _save() {
    final now = widget.clock();
    final read = PaymentLedger.readAmount(_amount.text);
    // Today is the moment it is recorded; an earlier day, its middle — the
    // day is what was said, and nothing on it can be after now.
    final at = _day == _today
        ? now
        : DateTime(_day.year, _day.month, _day.day, 12);
    final ledger = widget.customer.ledger;
    final problems = {
      ...ledger.problemsWith(
        type: widget.type,
        cents: read.cents,
        at: at,
        now: now,
        currency: widget.finance.currency,
        money: _money,
      ),
      if (read.problem != null) 'amount': read.problem!,
    };
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    Navigator.of(context).pop(
      PaymentTransaction(
        id: ledger.nextId(widget.type, now),
        customerId: widget.customer.id,
        type: widget.type,
        amountCents: read.cents!,
        at: at,
        method: _method,
        methodDetail: _method == PaymentMethod.other ? _other.text.trim() : '',
        note: _note.text.trim(),
        createdAt: now,
        currency: widget.finance.currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = widget.finance;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final total = finance.total;
    return AlertDialog(
      scrollable: true,
      title: Text(
        _refund
            ? 'Refund to ${widget.customer.name}'
            : 'Payment from ${widget.customer.name}',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _refund
                  ? 'Net paid: ${_money(finance.netPaidCents)}. A refund is '
                        'money returned; it cannot be more than that.'
                  : total == null
                  ? 'The total is not final yet: ${finance.pricing.notFinalReason}'
                  : 'Total price: ${_money(finance.pricing.totalCents!)} · '
                        'due ${_money(finance.dueCents!)}',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: PaymentDialogKeys.amount,
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _refund ? 'Refund amount' : 'Amount',
                suffixText: finance.currency,
                errorText: _problems['amount'],
                errorMaxLines: 3,
              ),
              onChanged: (_) {
                if (_problems.isNotEmpty) setState(() => _problems = const {});
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              key: PaymentDialogKeys.method,
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _refund ? 'Refund method' : 'Payment method',
              ),
              items: [
                for (final m in PaymentMethod.offered)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (m) {
                if (m != null) setState(() => _method = m);
              },
            ),
            if (_method == PaymentMethod.other) ...[
              const SizedBox(height: 8),
              TextField(
                key: PaymentDialogKeys.other,
                controller: _other,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Company cheque',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Date', style: text.labelMedium),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: PaymentDialogKeys.date,
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(dayOf(_day)),
              ),
            ),
            if (_problems['date'] case final problem?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: PaymentDialogKeys.note,
              controller: _note,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: _refund ? 'Reason / note' : 'Note',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: PaymentDialogKeys.save,
          onPressed: _save,
          child: Text(_refund ? 'Save refund' : 'Save payment'),
        ),
      ],
    );
  }
}

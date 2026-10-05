import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/customer_discount.dart';
import '../../domain/model/payment.dart';
import '../../domain/model/receipt.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/quotation.dart';
import '../inspector/price_panel.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'customer_finance.dart' show dayOf, say;

// The customer's financial documents: the discount given them, the
// quotations made them and the receipts issued them. Each is read from what
// is kept and changed only through the actions in `state/pricing.dart`,
// which the stores authorise.

// ─── Discount ───────────────────────────────────────────────────────────

/// The fields and buttons of the discount form.
abstract final class DiscountKeys {
  static const dialog = ValueKey('discount-dialog');
  static const percent = ValueKey('discount-percent');
  static const fixed = ValueKey('discount-fixed');
  static const value = ValueKey('discount-value');
  static const note = ValueKey('discount-note');
  static const previewDiscount = ValueKey('discount-preview-off');
  static const previewTotal = ValueKey('discount-preview-total');
  static const remove = ValueKey('discount-remove');
  static const apply = ValueKey('discount-apply');
}

/// Asks for [customer]'s discount and gives it — or takes the one in force
/// away.
Future<void> editDiscount(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  CustomerFinance finance,
) async {
  final by = ref.read(actorProvider).label;
  final entry = await showDialog<CustomerDiscount>(
    context: context,
    builder: (_) =>
        DiscountDialog(customer: customer, finance: finance, by: by),
  );
  if (entry == null) return;
  try {
    await ref.applyDiscount(customer.id, entry);
  } on AccessDenied catch (e) {
    if (context.mounted) say(context, e.toString());
  }
}

/// **Discount**: a percentage or a fixed amount off the subtotal, with the
/// subtotal, the discount and the final total shown as they would be.
class DiscountDialog extends StatefulWidget {
  final Customer customer;
  final CustomerFinance finance;
  final String by;
  final DateTime Function() clock;

  const DiscountDialog({
    super.key,
    required this.customer,
    required this.finance,
    required this.by,
    this.clock = DateTime.now,
  });

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late DiscountKind _kind =
      widget.customer.discount?.kind ?? DiscountKind.percent;
  late final _value = TextEditingController(text: _initialValue());
  final _note = TextEditingController();
  String? _problem;

  String _initialValue() {
    final d = widget.customer.discount;
    if (d == null) return '';
    return d.kind == DiscountKind.percent
        ? d.describe((c) => '').replaceAll('%', '')
        : (d.value / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  String _money(int cents) =>
      PricePanel.money(cents / 100, widget.finance.currency);

  ({int? value, String? problem}) _read() => switch (_kind) {
    DiscountKind.percent => CustomerDiscount.readPercent(_value.text),
    DiscountKind.fixed => switch (PaymentLedger.readAmount(_value.text)) {
      (cents: final c, problem: final p) => (
        value: c,
        problem: p == 'Enter an amount.' ? 'Enter the discount.' : p,
      ),
    },
  };

  CustomerDiscount? _entry() {
    final read = _read();
    if (read.value == null) return null;
    return CustomerDiscount(
      id: widget.customer.discounts.nextDiscountId(widget.clock()),
      kind: _kind,
      value: read.value!,
      currency: _kind == DiscountKind.fixed ? widget.finance.currency : null,
      at: widget.clock(),
      by: widget.by,
      note: _note.text.trim(),
    );
  }

  void _apply() {
    final read = _read();
    final problem =
        read.problem ??
        CustomerDiscount.problemWith(
          kind: _kind,
          value: read.value,
          subtotalCents: widget.finance.subtotalCents,
          money: _money,
        );
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_entry());
  }

  void _remove() => Navigator.of(context).pop(
    CustomerDiscount.removal(
      id: widget.customer.discounts.nextDiscountId(widget.clock()),
      at: widget.clock(),
      by: widget.by,
      note: _note.text.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtotal = widget.finance.subtotalCents;
    final entry = _entry();
    final off = subtotal == null || entry == null
        ? null
        : entry.offCents(subtotal, widget.finance.currency);
    return AlertDialog(
      key: DiscountKeys.dialog,
      scrollable: true,
      title: Text('Discount for ${widget.customer.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Discount type', style: text.labelMedium),
            RadioGroup<DiscountKind>(
              groupValue: _kind,
              onChanged: (k) => setState(() {
                _kind = k ?? _kind;
                _problem = null;
              }),
              child: const Column(
                children: [
                  RadioListTile(
                    key: DiscountKeys.percent,
                    contentPadding: EdgeInsets.zero,
                    value: DiscountKind.percent,
                    title: Text('Percentage'),
                  ),
                  RadioListTile(
                    key: DiscountKeys.fixed,
                    contentPadding: EdgeInsets.zero,
                    value: DiscountKind.fixed,
                    title: Text('Fixed amount'),
                  ),
                ],
              ),
            ),
            TextField(
              key: DiscountKeys.value,
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Discount',
                suffixText: _kind == DiscountKind.percent
                    ? '%'
                    : widget.finance.currency,
                errorText: _problem,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() => _problem = null),
            ),
            const SizedBox(height: 8),
            TextField(
              key: DiscountKeys.note,
              controller: _note,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
            const SizedBox(height: 12),
            PriceRow(
              'Subtotal',
              subtotal == null ? 'Not final' : _money(subtotal),
            ),
            PriceRow(
              'Discount',
              off == null ? '—' : '−${_money(off)}',
              valueKey: DiscountKeys.previewDiscount,
            ),
            PriceRow(
              'Final total',
              subtotal == null ? 'Not final' : _money(subtotal - (off ?? 0)),
              strong: true,
              valueKey: DiscountKeys.previewTotal,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.customer.discount != null)
          TextButton(
            key: DiscountKeys.remove,
            onPressed: _remove,
            child: const Text('Remove discount'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: DiscountKeys.apply,
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ─── Quotations ─────────────────────────────────────────────────────────

/// The fields and buttons of the quotation forms.
abstract final class QuotationKeys {
  static const dialog = ValueKey('quotation-new');
  static const notes = ValueKey('quotation-notes');
  static const problem = ValueKey('quotation-problem');
  static const create = ValueKey('quotation-create');
  static const sheet = ValueKey('quotation-sheet');
  static const total = ValueKey('quotation-total');
  static const subtotal = ValueKey('quotation-subtotal');
  static const discount = ValueKey('quotation-discount');
  static const changed = ValueKey('quotation-changed');
  static const status = ValueKey('quotation-status');

  static ValueKey<String> design(String id) => ValueKey('quotation-pick-$id');
  static ValueKey<String> line(String id) => ValueKey('quotation-line-$id');
  static ValueKey<String> become(QuotationStatus s) =>
      ValueKey('quotation-become-${s.name}');
}

/// Asks which of [customer]'s designs go on a new quotation, makes it, and
/// shows it.
Future<void> newQuotation(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
) async {
  final id = await showDialog<String>(
    context: context,
    builder: (_) => NewQuotationDialog(customer: customer),
  );
  if (id != null && context.mounted) await showQuotation(context, id);
}

/// **New quotation**: the customer's designs, each with where its price
/// stands, to choose from — all chosen to begin with — and a note.
class NewQuotationDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const NewQuotationDialog({super.key, required this.customer});

  @override
  ConsumerState<NewQuotationDialog> createState() => _NewQuotationState();
}

class _NewQuotationState extends ConsumerState<NewQuotationDialog> {
  Set<String>? _chosen;
  final _notes = TextEditingController();
  String? _problem;
  bool _making = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _create(CustomerPricing pricing) async {
    setState(() => _making = true);
    try {
      final made = await ref.createQuotation(
        widget.customer,
        _chosen!,
        notes: _notes.text,
        money: (c) => PricePanel.money(c / 100, pricing.currency),
      );
      if (!mounted) return;
      if (made.quotation == null) {
        setState(() => _problem = made.problem);
        return;
      }
      Navigator.of(context).pop(made.quotation!.id);
    } on AccessDenied catch (e) {
      if (mounted) setState(() => _problem = e.toString());
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricing = ref
        .watch(customerPricingProvider(widget.customer.id))
        .value;
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    if (pricing != null) {
      _chosen ??= {for (final d in pricing.designs) d.designId};
    }
    return AlertDialog(
      key: QuotationKeys.dialog,
      scrollable: true,
      title: Text('New quotation for ${widget.customer.name}'),
      content: SizedBox(
        width: 440,
        child: pricing == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'The quotation keeps every price as it is now. A '
                    'complete design is priced first; an incomplete one '
                    'cannot be quoted.',
                    style: text.bodySmall,
                  ),
                  if (pricing.designs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('This customer has no designs yet.'),
                    ),
                  for (final d in pricing.designs)
                    CheckboxListTile(
                      key: QuotationKeys.design(d.designId),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _chosen!.contains(d.designId),
                      onChanged: (on) => setState(() {
                        _problem = null;
                        on ?? false
                            ? _chosen!.add(d.designId)
                            : _chosen!.remove(d.designId);
                      }),
                      title: Text(d.name),
                      subtitle: Text(
                        d.state.isCurrent
                            ? PricePanel.money(d.state.total!, pricing.currency)
                            : d.state.canCalculate
                            ? 'Complete — priced when quoted'
                            : d.state.label,
                        style: TextStyle(
                          color: d.state.isCurrent || d.state.canCalculate
                              ? null
                              : error,
                        ),
                      ),
                    ),
                  if (widget.customer.discount case final dsc?)
                    Text(
                      'Discount: '
                      '${dsc.describe((c) => PricePanel.money(c / 100, pricing.currency))}',
                      style: text.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    key: QuotationKeys.notes,
                    controller: _notes,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  if (_problem case final problem?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        problem,
                        key: QuotationKeys.problem,
                        style: TextStyle(color: error),
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
          key: QuotationKeys.create,
          onPressed: pricing == null || _making || (_chosen?.isEmpty ?? true)
              ? null
              : () => _create(pricing),
          child: const Text('Create quotation'),
        ),
      ],
    );
  }
}

/// Where a quotation stands, in a word.
class QuotationStatusChip extends StatelessWidget {
  final QuotationStatus status;

  const QuotationStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colour = switch (status) {
      QuotationStatus.accepted => p.primary,
      QuotationStatus.rejected ||
      QuotationStatus.expired => Theme.of(context).colorScheme.error,
      QuotationStatus.draft || QuotationStatus.issued => p.ink,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colour,
        ),
      ),
    );
  }
}

/// Quotation [id], as kept.
final quotationProvider = FutureProvider.autoDispose.family<Quotation?, String>(
  (ref, id) {
    ref.watch(quotationsRevisionProvider);
    return ref.read(quotationStoreProvider).load(id);
  },
);

Future<void> showQuotation(BuildContext context, String id) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => QuotationSheet(id: id),
    );

/// A quotation as it was offered: each design with its price as quoted,
/// the subtotal, the discount and the final total — never worked out again
/// — and where it stands, with what it may become next.
class QuotationSheet extends ConsumerWidget {
  final String id;

  const QuotationSheet({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quotationProvider(id)).value;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    if (q == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    String money(int cents) => PricePanel.money(cents / 100, q.currency);
    final pricing = ref.watch(customerPricingProvider(q.customerId)).value;
    final changed = pricing == null
        ? const <QuotationLine>[]
        : q.changedDesigns({
            for (final d in pricing.designs) d.designId: d.designKey,
          });
    final list = ref.watch(priceListProvider).value;
    final pricesMoved =
        list != null && !list.isStarter && list.version != q.priceListVersion;
    final canEdit = ref.watch(actorProvider).can(Capability.quotationsEdit);
    return SafeArea(
      child: SingleChildScrollView(
        key: QuotationKeys.sheet,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QUOTATION', style: text.labelMedium),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(q.label, style: text.headlineSmall),
                KeyedSubtree(
                  key: QuotationKeys.status,
                  child: QuotationStatusChip(q.status),
                ),
              ],
            ),
            Text(
              'For ${q.customerName} · made ${dayOf(q.createdAt)}'
              '${q.createdBy.isEmpty ? '' : ' by ${q.createdBy}'} · '
              'prices of list version ${q.priceListVersion}',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
            if (changed.isNotEmpty || pricesMoved)
              Container(
                key: QuotationKeys.changed,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.notice,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  [
                    if (changed.isNotEmpty)
                      'Design changed after quotation: '
                          '${changed.map((l) => l.designName).join(', ')}.',
                    if (pricesMoved) 'The factory prices have changed since.',
                    'This quotation stays as it was offered; make a new one '
                        'for the current figures.',
                  ].join(' '),
                  style: text.bodySmall?.copyWith(color: p.onNotice),
                ),
              ),
            const SizedBox(height: 12),
            for (final l in q.lines)
              Padding(
                key: QuotationKeys.line(l.designId),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PriceRow(l.designName, money(l.totalCents), strong: true),
                    Text(
                      '${l.category} · ${l.material} · ${l.colour}',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            const Divider(),
            PriceRow(
              'Subtotal',
              money(q.subtotalCents),
              valueKey: QuotationKeys.subtotal,
            ),
            if (q.discount case final d?)
              PriceRow(
                'Discount (${d.describe(money)})',
                '−${money(q.discountCents)}',
                valueKey: QuotationKeys.discount,
              ),
            PriceRow(
              'Final total',
              money(q.totalCents),
              strong: true,
              valueKey: QuotationKeys.total,
            ),
            if (q.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(q.notes, style: text.bodySmall),
            ],
            const SizedBox(height: 8),
            for (final h in q.history)
              Text(
                '${h.status.label} — ${dayOf(h.at)}'
                '${h.by.isEmpty ? '' : ' by ${h.by}'}',
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            if (canEdit && q.status.next.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final next in q.status.next)
                    OutlinedButton(
                      key: QuotationKeys.become(next),
                      onPressed: () async {
                        final done = await ref.setQuotationStatus(q.id, next);
                        if (done.problem != null && context.mounted) {
                          say(context, done.problem!);
                        }
                      },
                      child: Text(switch (next) {
                        QuotationStatus.issued => 'Issue',
                        QuotationStatus.accepted => 'Mark accepted',
                        QuotationStatus.rejected => 'Mark rejected',
                        QuotationStatus.expired => 'Mark expired',
                        QuotationStatus.draft => 'Draft',
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Receipts ───────────────────────────────────────────────────────────

/// The parts of a receipt.
abstract final class ReceiptKeys {
  static const sheet = ValueKey('receipt-sheet');
  static const number = ValueKey('receipt-number');
  static const amount = ValueKey('receipt-amount');
  static const balance = ValueKey('receipt-balance');
}

Future<void> showReceipt(
  BuildContext context,
  Receipt receipt,
  String customerName,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => ReceiptSheet(receipt: receipt, customerName: customerName),
);

/// A receipt as it was issued: what was received, when, how, and the
/// balance as it then stood. Showing it changes nothing.
class ReceiptSheet extends StatelessWidget {
  final Receipt receipt;
  final String customerName;

  const ReceiptSheet({
    super.key,
    required this.receipt,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final balance = r.balanceAfterCents;
    return SafeArea(
      child: SingleChildScrollView(
        key: ReceiptKeys.sheet,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RECEIPT', style: text.labelMedium),
            Text(r.label, key: ReceiptKeys.number, style: text.headlineSmall),
            Text('Received from $customerName', style: text.bodyMedium),
            const SizedBox(height: 12),
            PriceRow(
              'Amount received',
              PricePanel.money(r.amountCents / 100, r.currency),
              strong: true,
              valueKey: ReceiptKeys.amount,
            ),
            if (r.conversion case final c?)
              PriceRow(
                'At 1 ${r.currency} = ${c.rate} ${c.to}',
                PricePanel.money(c.cents / 100, c.to),
              ),
            PriceRow('Date received', dayOf(r.paidAt)),
            PriceRow('Payment method', r.methodLabel),
            if (r.note.isNotEmpty) PriceRow('Note', r.note),
            PriceRow('Balance after this payment', switch (balance) {
              null => 'Total not final when issued',
              > 0 =>
                '${PricePanel.money(balance / 100, r.balanceCurrency)} due',
              < 0 =>
                '${PricePanel.money(-balance / 100, r.balanceCurrency)} credit',
              _ => 'Paid in full',
            }, valueKey: ReceiptKeys.balance),
            const SizedBox(height: 8),
            Text(
              'Issued ${dayOf(r.issuedAt)}'
              '${r.issuedBy.isEmpty ? '' : ' by ${r.issuedBy}'} · for payment '
              '${r.transactionId}',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

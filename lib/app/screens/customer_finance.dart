import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/pricing/design_price_state.dart';
import '../inspector/price_panel.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';

/// A customer's money, under their design cards: what their designs come
/// to, what they have paid, and what is still due — then each design's own
/// price and what they all measure together.
///
/// **It holds no figure of its own.** The total is `CustomerPricing`'s,
/// summed from each design's current price; what was paid is the
/// customer's one kept figure; what is due and how they stand are
/// `CustomerFinance`'s. Where one of the designs has no current price —
/// incomplete, changed since it was calculated, or of a category that
/// cannot be priced — the total is said to be not final and why, and no
/// sum of some of the prices is shown as the customer's price.
class CustomerFinancialSummary extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerFinancialSummary({super.key, required this.customer});

  static const cardKey = ValueKey('customer-finance');
  static const totalKey = ValueKey('customer-finance-total');
  static const notFinalKey = ValueKey('customer-finance-not-final');
  static const pricedSoFarKey = ValueKey('customer-finance-so-far');
  static const paidKey = ValueKey('customer-finance-paid');
  static const dueKey = ValueKey('customer-finance-due');
  static const statusKey = ValueKey('customer-finance-status');
  static const recordPaymentKey = ValueKey('customer-finance-record');
  static const toggleKey = ValueKey('customer-finance-toggle');
  static ValueKey<String> designKey(String id) =>
      ValueKey('customer-finance-design-$id');

  @override
  ConsumerState<CustomerFinancialSummary> createState() =>
      _CustomerFinancialSummaryState();
}

class _CustomerFinancialSummaryState
    extends ConsumerState<CustomerFinancialSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pricing = ref
        .watch(customerPricingProvider(widget.customer.id))
        .value;
    if (pricing == null) return const SizedBox.shrink();
    final finance = CustomerFinance.of(pricing, widget.customer.paid);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final currency = pricing.currency;
    String money(double v) => PricePanel.money(v, currency);

    Widget heading(String words) => Padding(
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
          heading('CUSTOMER FINANCIAL SUMMARY'),
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
            'Paid',
            money(finance.paid),
            valueKey: CustomerFinancialSummary.paidKey,
          ),
          PriceRow(
            'Amount due / loan',
            finance.due == null ? '—' : money(finance.due!),
            strong: true,
            valueKey: CustomerFinancialSummary.dueKey,
          ),
          if (finance.excess > 0)
            Text(
              'Recorded as paid is ${money(finance.excess)} more than the '
              'total now comes to. Check the payment.',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              PaymentStatusChip(finance.status),
              TextButton.icon(
                key: CustomerFinancialSummary.recordPaymentKey,
                onPressed: () =>
                    recordPayment(context, ref, widget.customer, pricing),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Record payment'),
              ),
            ],
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
            for (final d in pricing.designs)
              PriceRow(
                key: CustomerFinancialSummary.designKey(d.designId),
                d.name,
                d.state.total == null ? d.state.note : money(d.state.total!),
              ),
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
    final settled =
        status == PaymentStatus.paidInFull ||
        status == PaymentStatus.nothingToPay;
    final colour = settled ? p.primary : Theme.of(context).colorScheme.error;
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
    final finance = CustomerFinance.of(pricing, customer.paid);
    final words = switch (finance.due) {
      null => finance.status.label,
      final due when due > 0 =>
        'Due ${PricePanel.money(due, pricing.currency)}',
      _ => finance.status.label,
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

/// Asks what [customer] has paid in all, and keeps it — only it: no
/// design and no price is touched. More than a final total is refused,
/// because an overpayment is credit, which this does not record.
Future<void> recordPayment(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  CustomerPricing pricing,
) async {
  final amount = await showDialog<double>(
    context: context,
    builder: (_) => _PaymentDialog(customer: customer, pricing: pricing),
  );
  if (amount == null) return;
  await ref.recordPaid(customer, amount);
}

class _PaymentDialog extends StatefulWidget {
  final Customer customer;
  final CustomerPricing pricing;

  const _PaymentDialog({required this.customer, required this.pricing});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

/// The field and the button in the payment dialog.
abstract final class PaymentDialogKeys {
  static const field = ValueKey('payment-amount');
  static const save = ValueKey('payment-save');
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _field = TextEditingController(
    text: widget.customer.paid == 0
        ? ''
        : widget.customer.paid.toStringAsFixed(2),
  );
  String? _problem;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final text = _field.text.replaceAll(',', '').trim();
    final amount = text.isEmpty ? 0.0 : double.tryParse(text);
    final problem = CustomerFinance.problemWithPaid(amount, widget.pricing);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final pricing = widget.pricing;
    final total = pricing.total;
    final currency = pricing.currency;
    return AlertDialog(
      title: Text('Paid by ${widget.customer.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == null
                ? 'The total is not final yet: '
                      '${pricing.notFinalReason}'
                : 'Total price: ${PricePanel.money(total, currency)}',
          ),
          const SizedBox(height: 12),
          TextField(
            key: PaymentDialogKeys.field,
            controller: _field,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
            ],
            decoration: InputDecoration(
              labelText: 'Paid in all',
              suffixText: currency,
              errorText: _problem,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: PaymentDialogKeys.save,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

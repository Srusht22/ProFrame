import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/payment.dart';
import '../../domain/model/receipt.dart';
import '../../domain/pricing/design_price_state.dart';
import '../../domain/pricing/extra_charge.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../domain/pricing/quotation.dart';
import '../../domain/text/names.dart';
import '../inspector/extra_charges.dart';
import '../inspector/price_panel.dart';
import '../l10n/l10n.dart';
import '../state/access.dart';
import '../state/pricing.dart';
import '../theme/app_theme.dart';
import 'finance_documents.dart';

/// A customer's money, under their design cards: what their designs come
/// to, any discount and the final total, what the ledger says they have
/// paid and been refunded, what is due or in credit — **Add payment**,
/// **Refund** and **Discount** — then the payment history a page at a time
/// with each payment's receipt, the customer's quotations, and each
/// design's own price and what they all measure together.
///
/// **It holds no figure of its own.** The subtotal is `CustomerPricing`'s,
/// summed from each design's current price; the discount is the customer's
/// in force; what was paid is the ledger's (`Customer.payments`), summed in
/// the customer's currency; what is due or in credit and how they stand
/// are `CustomerFinance`'s. Where one of the designs has no current price
/// the total is said to be not final and why, and no sum of some of the
/// prices is shown as the customer's price.
///
/// What is offered follows who is at the device (`actorProvider`); what is
/// allowed is decided again by the store each action writes to.
class CustomerFinancialSummary extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerFinancialSummary({super.key, required this.customer});

  static const cardKey = ValueKey('customer-finance');
  static const noAccessKey = ValueKey('customer-finance-no-access');
  static const subtotalKey = ValueKey('customer-finance-subtotal');
  static const discountKey = ValueKey('customer-finance-discount');
  static const discountButtonKey = ValueKey('customer-finance-discount-edit');
  static const discountExceedsKey = ValueKey('customer-finance-discount-over');

  /// The final total: the subtotal less any discount.
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
  static const otherCurrenciesKey = ValueKey('customer-finance-currencies');
  static const addPaymentKey = ValueKey('customer-finance-add-payment');
  static const refundKey = ValueKey('customer-finance-refund');
  static const historyKey = ValueKey('customer-finance-history');
  static const emptyHistoryKey = ValueKey('customer-finance-history-empty');
  static const loadMoreKey = ValueKey('customer-finance-history-more');
  static const quotationsKey = ValueKey('customer-finance-quotations');
  static const newQuotationKey = ValueKey('customer-finance-new-quotation');
  static const moreQuotationsKey = ValueKey('customer-finance-quotes-more');
  static const toggleKey = ValueKey('customer-finance-toggle');

  /// The designs' prices summed, the customer's own extras summed, the
  /// list of those extras and the button adding one.
  static const designsTotalKey = ValueKey('customer-finance-designs-total');
  static const extrasTotalKey = ValueKey('customer-finance-extras-total');
  static const extrasKey = ValueKey('customer-finance-extras');
  static const addExtraKey = ValueKey('customer-finance-add-extra');

  /// One transaction of the history, by its id.
  static ValueKey<String> transactionKey(String id) =>
      ValueKey('customer-finance-transaction-$id');

  /// The receipt of transaction [id], or the button issuing it.
  static ValueKey<String> receiptKey(String id) =>
      ValueKey('customer-finance-receipt-$id');
  static ValueKey<String> issueReceiptKey(String id) =>
      ValueKey('customer-finance-issue-receipt-$id');

  /// One quotation, by its id.
  static ValueKey<String> quotationKey(String id) =>
      ValueKey('customer-finance-quotation-$id');

  /// What design [id] is and is made of, under its price.
  static ValueKey<String> profileKey(String id) =>
      ValueKey('summary-design-profile-$id');

  static ValueKey<String> designKey(String id) =>
      ValueKey('customer-finance-design-$id');

  /// How many transactions a page of the history holds.
  static const pageSize = 10;

  /// How many quotations a page holds.
  static const quotationPage = 5;

  @override
  ConsumerState<CustomerFinancialSummary> createState() =>
      _CustomerFinancialSummaryState();
}

class _CustomerFinancialSummaryState
    extends ConsumerState<CustomerFinancialSummary> {
  bool _open = false;
  int _shown = CustomerFinancialSummary.pageSize;
  int _quotes = CustomerFinancialSummary.quotationPage;

  @override
  Widget build(BuildContext context) {
    final pricing = ref
        .watch(customerPricingProvider(widget.customer.id))
        .value;
    if (pricing == null) return const SizedBox.shrink();
    final actor = ref.watch(actorProvider);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final w = context.words;

    Widget heading(String words, {Key? key, Widget? trailing}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              words,
              style: text.labelMedium?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: p.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.hairline),
    );
    if (!actor.can(Capability.financialView)) {
      return Container(
        key: CustomerFinancialSummary.cardKey,
        decoration: decoration,
        padding: const EdgeInsets.all(18),
        child: Text(
          l.finNoAccess,
          key: CustomerFinancialSummary.noAccessKey,
          style: text.bodyMedium?.copyWith(color: p.muted),
        ),
      );
    }

    final customer = widget.customer;
    final ledger = customer.ledger;
    final finance = CustomerFinance.of(
      pricing,
      ledger,
      discount: customer.discount,
      extras: customer.extras,
    );
    final currency = pricing.currency;
    String money(double v) => PricePanel.money(v, currency);
    String cents(int c) => money(c / 100);
    final discount = customer.discount;

    final page = ledger.page(limit: _shown);
    final canRefund =
        actor.can(Capability.paymentsRefund) &&
        (finance.netPaidCents > 0 ||
            finance.otherCurrencies.any((c) => c.netCents > 0));

    return Container(
      key: CustomerFinancialSummary.cardKey,
      decoration: decoration,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(l.finSummary),
          PriceRow(
            l.finDesigns,
            l.finDesignsPriced(pricing.designs.length, pricing.priced.length),
          ),
          if (customer.extras.isNotEmpty) ...[
            PriceRow(
              l.finDesignsTotal,
              finance.designsCents == null
                  ? l.finNotFinal
                  : cents(finance.designsCents!),
              valueKey: CustomerFinancialSummary.designsTotalKey,
            ),
            PriceRow(
              l.finExtrasWholeJob,
              cents(finance.extrasCents),
              valueKey: CustomerFinancialSummary.extrasTotalKey,
            ),
          ],
          if (discount != null || customer.extras.isNotEmpty)
            PriceRow(
              l.finSubtotal,
              finance.subtotal == null
                  ? l.finNotFinal
                  : money(finance.subtotal!),
              valueKey: CustomerFinancialSummary.subtotalKey,
            ),
          if (discount != null)
            PriceRow(
              l.finDiscountOf(discount.describe(cents, w)),
              finance.discountCents == null
                  ? l.finWhenFinal
                  : '−${cents(finance.discountCents!)}',
              valueKey: CustomerFinancialSummary.discountKey,
            ),
          _BigRow(
            discount == null && customer.extras.isEmpty
                ? l.finTotalPrice
                : l.finFinalTotal,
            finance.total == null ? l.finNotFinal : money(finance.total!),
            valueKey: CustomerFinancialSummary.totalKey,
          ),
          if (finance.discountExceedsSubtotal)
            Text(
              l.finDiscountExceeds(discount!.describe(cents, w)),
              key: CustomerFinancialSummary.discountExceedsKey,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (finance.total == null) ...[
            Text(
              l.finCustomerNotFinal(finance.notFinalReasonIn(w)),
              key: CustomerFinancialSummary.notFinalKey,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            PriceRow(
              l.finPricedSoFar,
              money(pricing.pricedSoFar),
              valueKey: CustomerFinancialSummary.pricedSoFarKey,
            ),
          ],
          PriceRow(
            l.finTotalPayments,
            money(finance.grossPayments),
            valueKey: CustomerFinancialSummary.grossPaymentsKey,
          ),
          PriceRow(
            l.finRefunds,
            money(finance.grossRefunds),
            valueKey: CustomerFinancialSummary.refundsKey,
          ),
          PriceRow(
            l.finNetPaid,
            money(finance.netPaid),
            valueKey: CustomerFinancialSummary.paidKey,
          ),
          const SizedBox(height: 4),
          PriceRow(
            l.finAmountDue,
            finance.due == null ? '—' : money(finance.due!),
            strong: true,
            valueKey: CustomerFinancialSummary.dueKey,
          ),
          PriceRow(
            l.finCredit,
            finance.credit == null ? '—' : money(finance.credit!),
            strong: (finance.credit ?? 0) > 0,
            valueKey: CustomerFinancialSummary.creditKey,
          ),
          if ((finance.credit ?? 0) > 0)
            Text(
              l.finCreditNote(money(finance.credit!)),
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          if (finance.otherCurrencies.isNotEmpty)
            _OtherCurrencies(
              finance,
              key: CustomerFinancialSummary.otherCurrenciesKey,
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
                  if (actor.can(Capability.discountsApply))
                    OutlinedButton.icon(
                      key: CustomerFinancialSummary.discountButtonKey,
                      onPressed: () =>
                          editDiscount(context, ref, customer, finance),
                      icon: const Icon(Icons.percent, size: 18),
                      label: Text(l.finDiscount),
                    ),
                  FilledButton.tonalIcon(
                    key: CustomerFinancialSummary.addPaymentKey,
                    onPressed: actor.can(Capability.paymentsCreate)
                        ? () => recordTransaction(
                            context,
                            ref,
                            customer,
                            finance,
                            PaymentType.payment,
                          )
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.finAddPayment),
                  ),
                  OutlinedButton.icon(
                    key: CustomerFinancialSummary.refundKey,
                    onPressed: canRefund
                        ? () => recordTransaction(
                            context,
                            ref,
                            customer,
                            finance,
                            PaymentType.refund,
                          )
                        : null,
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l.finRefund),
                  ),
                ],
              ),
            ],
          ),
          _CustomerExtras(
            customer: customer,
            heading: heading,
            pricing: pricing,
            canAdd: ref.offers(Capability.extrasCreate),
            canEdit: ref.offers(Capability.extrasEdit),
            canRemove: ref.offers(Capability.extrasDelete),
          ),
          if (actor.can(Capability.paymentsView)) ...[
            heading(l.finHistory, key: CustomerFinancialSummary.historyKey),
            if (page.total == 0)
              Text(
                l.finNoHistory,
                key: CustomerFinancialSummary.emptyHistoryKey,
                style: text.bodyMedium?.copyWith(color: p.muted),
              ),
            for (final t in page.items)
              TransactionRow(
                t,
                currency: currency,
                receipt: customer.receiptFor(t.id),
                canSeeReceipt: actor.can(Capability.receiptsView),
                onReceipt: (r) => showReceipt(context, r, customer.name),
                onIssue:
                    t.type == PaymentType.payment &&
                        actor.can(Capability.receiptsCreate)
                    ? () => issueAndShowReceipt(context, ref, customer, t.id)
                    : null,
              ),
            if (page.hasMore)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: CustomerFinancialSummary.loadMoreKey,
                  onPressed: () => setState(
                    () => _shown += CustomerFinancialSummary.pageSize,
                  ),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(l.finLoadMore(page.total - page.items.length)),
                ),
              ),
          ],
          if (actor.can(Capability.quotationsView))
            _Quotations(
              customer: customer,
              limit: _quotes,
              heading: heading,
              canCreate: actor.can(Capability.quotationsCreate),
              onMore: () => setState(
                () => _quotes += CustomerFinancialSummary.quotationPage,
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
                      _open ? l.finHideDesigns : l.finShowDesigns,
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
            heading(l.finDesignsHeading),
            for (final d in pricing.designs) ...[
              PriceRow(
                key: CustomerFinancialSummary.designKey(d.designId),
                d.nameIn(w),
                d.state.total == null
                    ? d.state.noteIn(w)
                    : money(d.state.total!),
              ),
              // What it is and what it is made of: why two designs cost
              // different amounts.
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, bottom: 4),
                child: Text(
                  l.finDesignFacts(
                    d.kind.labelIn(w),
                    d.profile.materialNameIn(w),
                    d.colourNameIn(w),
                  ),
                  key: CustomerFinancialSummary.profileKey(d.designId),
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
            ],
            heading(l.finMaterialSummary),
            MeasurementRows(pricing.measurements),
            if (pricing.priced.length < pricing.designs.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.finOfPriced(pricing.priced.length, pricing.designs.length),
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The customer's own extras — the whole job's, no one design's — each
/// quantity × unit price, with **Add extra**, edit and remove where the
/// person at the device may.
class _CustomerExtras extends ConsumerWidget {
  final Customer customer;
  final CustomerPricing pricing;
  final Widget Function(String words, {Key? key, Widget? trailing}) heading;
  final bool canAdd;
  final bool canEdit;
  final bool canRemove;

  const _CustomerExtras({
    required this.customer,
    required this.pricing,
    required this.heading,
    required this.canAdd,
    required this.canEdit,
    required this.canRemove,
  });

  Future<void> _write(
    BuildContext context,
    WidgetRef ref, [
    ExtraCharge? editing,
  ]) async {
    final answer = await ExtraDialog.show(
      context,
      newId: customer.extras.nextExtraId(DateTime.now()),
      currency: pricing.currency,
      scope: ExtraScope.customer,
      by: ref.read(actorProvider).label,
      where: context.l10n.finWholeJobOf(customer.name),
      editing: editing,
      calculated: [
        for (final d in pricing.priced) ...d.state.record!.result.lines,
      ],
    );
    if (answer == null) return;
    try {
      await ref.saveCustomerExtra(
        customer.id,
        answer.extra,
        additional: answer.additional,
      );
    } on AccessDenied catch (e) {
      if (context.mounted) say(context, e.messageIn(context.words));
    } on StateError catch (e) {
      if (context.mounted) say(context, e.message);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ExtraCharge extra,
  ) async {
    if (!await confirmRemoveExtra(
      context,
      extra,
      context.l10n.finWholeJob(customer.name),
    )) {
      return;
    }
    try {
      await ref.removeCustomerExtra(customer.id, extra.id);
    } on AccessDenied catch (e) {
      if (context.mounted) say(context, e.messageIn(context.words));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      key: CustomerFinancialSummary.extrasKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          context.l10n.finExtrasHeading,
          trailing: canAdd
              ? TextButton.icon(
                  key: CustomerFinancialSummary.addExtraKey,
                  onPressed: () => _write(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.finAddExtra),
                )
              : null,
        ),
        if (customer.extras.isEmpty)
          Text(
            context.l10n.finNoExtras,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        for (final e in customer.extras)
          ExtraRow(
            e,
            onEdit: canEdit ? () => _write(context, ref, e) : null,
            onRemove: canRemove ? () => _remove(context, ref, e) : null,
          ),
      ],
    );
  }
}

/// The money recorded in currencies the customer's total cannot count —
/// no rate was given — each in its own currency, and said so.
class _OtherCurrencies extends StatelessWidget {
  final CustomerFinance finance;

  const _OtherCurrencies(this.finance, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    final base = finance.currency;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.finOtherCurrencies(base),
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: error,
                  ),
                ),
              ),
            ],
          ),
          for (final c in finance.otherCurrencies) ...[
            PriceRow(
              context.l10n.finCurrencyPayments(c.currency),
              PricePanel.money(c.paymentsCents / 100, c.currency),
            ),
            if (c.refundsCents > 0)
              PriceRow(
                context.l10n.finCurrencyRefunds(c.currency),
                PricePanel.money(c.refundsCents / 100, c.currency),
              ),
          ],
          Text(context.l10n.finNoRate(base), style: text.bodySmall),
        ],
      ),
    );
  }
}

/// The customer's quotations, newest first, a page at a time.
class _Quotations extends ConsumerWidget {
  final Customer customer;
  final int limit;
  final bool canCreate;
  final VoidCallback onMore;
  final Widget Function(String words, {Key? key, Widget? trailing}) heading;

  const _Quotations({
    required this.customer,
    required this.limit,
    required this.canCreate,
    required this.onMore,
    required this.heading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref
        .watch(customerQuotationsProvider(QuotationsWanted(customer.id, limit)))
        .value;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          context.l10n.finQuotations,
          key: CustomerFinancialSummary.quotationsKey,
          trailing: canCreate
              ? TextButton.icon(
                  key: CustomerFinancialSummary.newQuotationKey,
                  onPressed: () => newQuotation(context, ref, customer),
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: Text(context.l10n.finNewQuotation),
                )
              : null,
        ),
        if (page != null && page.total == 0)
          Text(
            context.l10n.finNoQuotations,
            style: text.bodyMedium?.copyWith(color: p.muted),
          ),
        for (final q in page?.items ?? const <Quotation>[])
          InkWell(
            key: CustomerFinancialSummary.quotationKey(q.id),
            onTap: () => showQuotation(context, q.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.hairline)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    q.label,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  QuotationStatusChip(q.status),
                  Text(
                    PricePanel.money(q.totalCents / 100, q.currency),
                    textDirection: TextDirection.ltr,
                    style: text.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    context.l10n.finQuoteLine(
                      dayOf(q.createdAt, context.l10n),
                      q.lines.length,
                    ),
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        if (page != null && page.items.length < page.total)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: CustomerFinancialSummary.moreQuotationsKey,
              onPressed: onMore,
              child: Text(
                context.l10n.finLoadMore(page.total - page.items.length),
              ),
            ),
          ),
      ],
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
        status.labelIn(context.words).toUpperCase(),
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
    if (!ref.watch(actorProvider).can(Capability.financialView)) {
      return const SizedBox.shrink();
    }
    final finance = CustomerFinance.of(
      pricing,
      customer.ledger,
      discount: customer.discount,
      extras: customer.extras,
    );
    final words = switch (finance.status) {
      PaymentStatus.outstanding => context.l10n.finDue(
        PricePanel.money(finance.due!, pricing.currency),
      ),
      PaymentStatus.credit => context.l10n.finCreditOf(
        PricePanel.money(finance.credit!, pricing.currency),
      ),
      final status => status.labelIn(context.words),
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
            textDirection: context.directionOf(value),
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
/// words and by its mark, never by colour alone — its amount with its sign
/// and currency, how it was paid, the note on it, and its receipt: the
/// receipt's number where one was issued, or **Issue receipt**.
class TransactionRow extends StatelessWidget {
  final PaymentTransaction transaction;
  final String currency;
  final Receipt? receipt;
  final bool canSeeReceipt;
  final void Function(Receipt receipt)? onReceipt;
  final VoidCallback? onIssue;

  const TransactionRow(
    this.transaction, {
    super.key,
    required this.currency,
    this.receipt,
    this.canSeeReceipt = true,
    this.onReceipt,
    this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final refund = t.type == PaymentType.refund;
    final colour = refund ? Theme.of(context).colorScheme.error : p.primary;
    final own = t.currency ?? currency;
    final amount = '${refund ? '−' : '+'}${PricePanel.money(t.amount, own)}';
    final converted = t.conversion;
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
              semanticLabel: t.type.labelIn(context.words),
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
                      t.type.labelIn(context.words).toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colour,
                      ),
                    ),
                    Text(dayOf(t.at, context.l10n), style: text.bodyMedium),
                  ],
                ),
                Text(
                  t.methodLabelIn(context.words),
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
                if (converted != null)
                  Text(
                    context.l10n.finAtRate(
                      own,
                      '${converted.rate}',
                      converted.to,
                      PricePanel.money(converted.cents / 100, converted.to),
                    ),
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                if (t.note.isNotEmpty)
                  Text(t.noteIn(context.words), style: text.bodySmall),
                if (receipt case final r? when canSeeReceipt)
                  TextButton.icon(
                    key: CustomerFinancialSummary.receiptKey(t.id),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onReceipt?.call(r),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(r.label),
                  )
                else if (receipt == null && onIssue != null)
                  TextButton.icon(
                    key: CustomerFinancialSummary.issueReceiptKey(t.id),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onIssue,
                    icon: const Icon(Icons.add_card_outlined, size: 16),
                    label: Text(context.l10n.finIssueReceipt),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            textDirection: TextDirection.ltr,
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
///
/// In [l]'s language; English where none is given.
String dayOf(DateTime at, [AppLocalizations? l]) {
  final said = l ?? english;
  return said.finDay(
    at.day.toString().padLeft(2, '0'),
    shortMonth(said, at.month),
    '${at.year}',
  );
}

/// Asks for a payment or a refund of [customer]'s and records it in their
/// ledger — only it: no design and no price is touched — then, for a
/// payment the user asked a receipt for, issues it.
Future<void> recordTransaction(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  CustomerFinance finance,
  PaymentType type,
) async {
  final canIssue = ref.read(actorProvider).can(Capability.receiptsCreate);
  final asked = await showDialog<TransactionRequest>(
    context: context,
    builder: (_) => TransactionDialog(
      customer: customer,
      finance: finance,
      type: type,
      canIssueReceipt: canIssue,
    ),
  );
  if (asked == null) return;
  try {
    await ref.recordTransaction(asked.transaction);
    if (asked.issueReceipt) {
      await ref.issueReceipt(customer.id, asked.transaction.id);
    }
  } on AccessDenied catch (e) {
    if (context.mounted) say(context, e.messageIn(context.words));
  }
}

/// Issues the receipt for payment [transactionId] and shows it.
Future<void> issueAndShowReceipt(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  String transactionId,
) async {
  try {
    final receipt = await ref.issueReceipt(customer.id, transactionId);
    if (receipt != null && context.mounted) {
      await showReceipt(context, receipt, customer.name);
    }
  } on AccessDenied catch (e) {
    if (context.mounted) say(context, e.messageIn(context.words));
  }
}

/// [words] at the foot of the screen.
void say(BuildContext context, String words) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(words)));

/// What the payment dialog gives back: the transaction, and whether a
/// receipt is to be issued for it.
class TransactionRequest {
  final PaymentTransaction transaction;
  final bool issueReceipt;

  const TransactionRequest(this.transaction, {this.issueReceipt = false});
}

/// The fields and buttons of the payment and refund form.
abstract final class PaymentDialogKeys {
  static const amount = ValueKey('payment-amount');
  static const currency = ValueKey('payment-currency');
  static const rate = ValueKey('payment-rate');
  static const method = ValueKey('payment-method');
  static const other = ValueKey('payment-other');
  static const date = ValueKey('payment-date');
  static const note = ValueKey('payment-note');
  static const issueReceipt = ValueKey('payment-issue-receipt');
  static const save = ValueKey('payment-save');
}

/// **Add payment** and **Refund**: the amount and its currency — with the
/// rate where it is not the customer's, if the user knows it — how it was
/// paid, the day it was (today unless said, never a later one), a note, and
/// for a payment whether to issue its receipt. What it records is checked
/// by the ledger (`PaymentLedger.problemsWith`) before it is returned;
/// nothing is recorded here.
class TransactionDialog extends StatefulWidget {
  final Customer customer;
  final CustomerFinance finance;
  final PaymentType type;
  final bool canIssueReceipt;

  /// The moment it is now — for a test to set.
  final DateTime Function() clock;

  const TransactionDialog({
    super.key,
    required this.customer,
    required this.finance,
    required this.type,
    this.canIssueReceipt = false,
    this.clock = DateTime.now,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _other = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  late String _currency = widget.finance.currency;
  late DateTime _day = _today;
  late bool _issue = widget.canIssueReceipt;
  Map<String, String> _problems = const {};

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _refund => widget.type == PaymentType.refund;
  bool get _foreign => _currency != widget.finance.currency;

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
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
    final w = context.words;
    final read = PaymentLedger.readAmount(_amount.text, w);
    final rate = _foreign
        ? PaymentLedger.readRate(_rate.text, w)
        : (rate: null, problem: null);
    final base = widget.finance.currency;
    final conversion = read.cents != null && rate.rate != null
        ? Conversion.of(read.cents!, rate.rate!, base)
        : null;
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
        currency: base,
        money: _money,
        inCurrency: _currency,
        conversion: conversion,
        moneyIn: (c, cur) => PricePanel.money(c / 100, cur),
        words: w,
      ),
      if (read.problem != null) 'amount': read.problem!,
      if (rate.problem != null) 'rate': rate.problem!,
    };
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    Navigator.of(context).pop(
      TransactionRequest(
        PaymentTransaction(
          id: ledger.nextId(widget.type, now),
          customerId: widget.customer.id,
          type: widget.type,
          amountCents: read.cents!,
          at: at,
          method: _method,
          methodDetail: _method == PaymentMethod.other
              ? _other.text.trim()
              : '',
          note: _note.text.trim(),
          createdAt: now,
          currency: _currency,
          conversion: conversion,
        ),
        issueReceipt: !_refund && _issue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = widget.finance;
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final total = finance.total;
    final base = finance.currency;
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(
        _refund
            ? l.finRefundTo(widget.customer.name)
            : l.finPaymentFrom(widget.customer.name),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _refund
                  ? l.finRefundNote(_money(finance.netPaidCents))
                  : total == null
                  ? l.finNotFinalYet(
                      finance.pricing.notFinalReasonIn(context.words),
                    )
                  : l.finTotalDue(
                      finance.discount == null
                          ? l.finTotalPrice
                          : l.finFinalTotal,
                      _money(finance.totalCents!),
                      _money(finance.dueCents!),
                    ),
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: PaymentDialogKeys.amount,
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _refund ? l.finRefundAmount : l.finAmount,
                      errorText: _problems['amount'],
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) {
                      if (_problems.isNotEmpty) {
                        setState(() => _problems = const {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    key: PaymentDialogKeys.currency,
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.finCurrency),
                    items: [
                      for (final c in Currencies.offeredWith(base))
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (c) {
                      if (c != null) {
                        setState(() {
                          _currency = c;
                          _problems = const {};
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_foreign) ...[
              const SizedBox(height: 8),
              TextField(
                key: PaymentDialogKeys.rate,
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.finRateOptional,
                  prefixText: '1 $_currency = ',
                  suffixText: base,
                  errorText: _problems['rate'],
                  errorMaxLines: 3,
                  helperText: l.finRateHelp(base, _currency),
                  helperMaxLines: 4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              key: PaymentDialogKeys.method,
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _refund ? l.finRefundMethod : l.finPaymentMethod,
              ),
              items: [
                for (final m in PaymentMethod.offered)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m.labelIn(context.words)),
                  ),
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
                decoration: InputDecoration(
                  labelText: l.finDescriptionOptional,
                  hintText: l.finDescriptionHint,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(l.finDate, style: text.labelMedium),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: PaymentDialogKeys.date,
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(dayOf(_day, l)),
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
                labelText: _refund ? l.finReasonNote : l.finNote,
              ),
            ),
            if (!_refund && widget.canIssueReceipt)
              CheckboxListTile(
                key: PaymentDialogKeys.issueReceipt,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _issue,
                onChanged: (v) => setState(() => _issue = v ?? false),
                title: Text(l.finIssueAReceipt),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actCancel),
        ),
        FilledButton(
          key: PaymentDialogKeys.save,
          onPressed: _save,
          child: Text(_refund ? l.finSaveRefund : l.finSavePayment),
        ),
      ],
    );
  }
}

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id_generator.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/quotation.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/providers/settings_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../services/quotation_pdf_service.dart';

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  bool _converting = false;

  Future<Uint8List> _buildPdf(Quotation quotation, Customer customer, Project project) async {
    final settings = ref.read(settingsNotifierProvider).value;
    return const QuotationPdfService().build(
      quotation: quotation,
      customer: customer,
      project: project,
      company: settings?.company ?? const CompanyProfile(),
    );
  }

  Future<void> _convertToOrder(Quotation quotation) async {
    setState(() => _converting = true);
    final order = await ref.read(orderNotifierProvider.notifier).convertFromQuotation(quotation);
    if (!mounted) return;
    setState(() => _converting = false);
    context.pushReplacement(AppRoutes.order(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final quotations = ref.watch(quotationNotifierProvider).value ?? const <Quotation>[];
    final quotation = quotations.firstWhereOrNull((q) => q.id == widget.quotationId);
    if (quotation == null) {
      return const Scaffold(body: EmptyState(icon: Icons.description_outlined, title: 'Quotation not found', message: ''));
    }
    final customer = (ref.watch(customerNotifierProvider).value ?? const []).firstWhereOrNull((c) => c.id == quotation.customerId);
    final project = (ref.watch(projectNotifierProvider).value ?? const []).firstWhereOrNull((p) => p.id == quotation.projectId);

    return Scaffold(
      appBar: AppBar(
        title: Text(quotation.quoteNumber),
        actions: [
          if (customer != null && project != null)
            IconButton(
              tooltip: 'Export / print PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => Printing.layoutPdf(onLayout: (format) => _buildPdf(quotation, customer, project)),
            ),
          if (customer != null && project != null)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                final bytes = await _buildPdf(quotation, customer, project);
                await Printing.sharePdf(bytes: bytes, filename: '${quotation.quoteNumber}.pdf');
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(customer?.fullName ?? 'Unknown customer', style: Theme.of(context).textTheme.titleMedium),
                    StatusBadge(statusKey: quotation.status.name, label: quotation.status.label),
                  ],
                ),
                if (project != null) Text('${project.name} · ${project.projectNumber}'),
                const SizedBox(height: AppSpacing.sm),
                Text('Issued ${_fmt(quotation.issueDate)} · Valid until ${_fmt(quotation.expiryDate)}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final item in quotation.items)
            Card(
              child: ListTile(
                title: Text(item.configurationName),
                subtitle: Text('${item.productTypeLabel} · ${item.dimensionsLabel} · Qty ${item.quantity}'),
                trailing: Text('${item.currencySymbol}${item.lineTotal.toStringAsFixed(2)}'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _totalRow('Items subtotal', quotation.itemsSubtotal),
                if (quotation.globalDiscountAmount > 0) _totalRow('Discount', -quotation.globalDiscountAmount),
                if (quotation.installationTotal > 0) _totalRow('Installation', quotation.installationTotal),
                if (quotation.deliveryCost > 0) _totalRow('Delivery', quotation.deliveryCost),
                if (quotation.taxAmount > 0) _totalRow('Tax', quotation.taxAmount),
                const Divider(),
                _totalRow('Grand total', quotation.grandTotal, bold: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (quotation.status == QuotationStatus.draft)
                FilledButton.icon(
                  onPressed: () => ref.read(quotationNotifierProvider.notifier).updateStatus(quotation, QuotationStatus.sent),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Mark as sent'),
                ),
              if (quotation.status == QuotationStatus.sent)
                OutlinedButton.icon(
                  onPressed: () => ref.read(quotationNotifierProvider.notifier).updateStatus(quotation, QuotationStatus.viewed),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Mark as viewed'),
                ),
              if (quotation.status == QuotationStatus.sent || quotation.status == QuotationStatus.viewed) ...[
                FilledButton.icon(
                  onPressed: () => ref.read(quotationNotifierProvider.notifier).updateStatus(quotation, QuotationStatus.accepted),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Mark accepted'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.read(quotationNotifierProvider.notifier).updateStatus(quotation, QuotationStatus.rejected),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Mark rejected'),
                ),
              ],
              if (quotation.status == QuotationStatus.accepted)
                FilledButton.icon(
                  onPressed: _converting ? null : () => _convertToOrder(quotation),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(_converting ? 'Converting…' : 'Convert to order'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final duplicated = quotation.copyWith(
                    status: QuotationStatus.draft,
                  );
                  final newQuote = Quotation(
                    id: IdGenerator.generate(),
                    quoteNumber: await ref.read(quotationNotifierProvider.notifier).nextQuoteNumber(),
                    projectId: duplicated.projectId,
                    customerId: duplicated.customerId,
                    items: duplicated.items,
                    status: QuotationStatus.draft,
                    issueDate: DateTime.now(),
                    expiryDate: DateTime.now().add(const Duration(days: 30)),
                    globalDiscountPercent: duplicated.globalDiscountPercent,
                    globalDiscountFixed: duplicated.globalDiscountFixed,
                    taxPercent: duplicated.taxPercent,
                    installationCostPerUnit: duplicated.installationCostPerUnit,
                    deliveryCost: duplicated.deliveryCost,
                    termsAndConditions: duplicated.termsAndConditions,
                    createdByUserId: duplicated.createdByUserId,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(quotationNotifierProvider.notifier).save(newQuote, isNew: true);
                  if (context.mounted) context.pushReplacement(AppRoutes.quotation(newQuote.id));
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Duplicate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          Text('\$${amount.toStringAsFixed(2)}', style: bold ? const TextStyle(fontWeight: FontWeight.w800) : null),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

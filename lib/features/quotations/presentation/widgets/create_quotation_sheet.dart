import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../domain/configuration/product_configuration.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/entities/quotation.dart';
import '../../../../shared/providers/auth_notifier.dart';
import '../../../../shared/providers/quotation_notifier.dart';
import '../../../../shared/providers/settings_notifier.dart';

Future<void> showCreateQuotationSheet(
  BuildContext context,
  WidgetRef ref, {
  required Project project,
  required List<ProductConfiguration> items,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CreateQuotationSheet(project: project, items: items),
  );
}

class _CreateQuotationSheet extends ConsumerStatefulWidget {
  final Project project;
  final List<ProductConfiguration> items;
  const _CreateQuotationSheet({required this.project, required this.items});

  @override
  ConsumerState<_CreateQuotationSheet> createState() => _CreateQuotationSheetState();
}

class _CreateQuotationSheetState extends ConsumerState<_CreateQuotationSheet> {
  late final Set<String> _selectedIds = widget.items.map((e) => e.id).toSet();
  final _taxController = TextEditingController(text: '0');
  final _installController = TextEditingController(text: '0');
  final _deliveryController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _taxController.dispose();
    _installController.dispose();
    _deliveryController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item.')));
      return;
    }
    setState(() => _saving = true);
    final pricingEngine = ref.read(pricingEngineProvider);
    final settings = ref.read(settingsNotifierProvider).value;
    final currency = settings?.currency;
    final user = ref.read(currentUserProvider);
    final now = DateTime.now();
    final quoteNumber = await ref.read(quotationNotifierProvider.notifier).nextQuoteNumber();
    final validityDays = settings?.quoteValidityDays ?? 30;

    final selected = widget.items.where((c) => _selectedIds.contains(c.id)).toList();
    final quoteItems = [
      for (final c in selected)
        QuoteItem(
          id: IdGenerator.generate(),
          configurationId: c.id,
          configurationName: c.name,
          productTypeLabel: c.productTypeLabel,
          dimensionsLabel: c.formattedDimensions(),
          widthMm: c.widthMm,
          heightMm: c.heightMm,
          quantity: c.quantity,
          unitPrice: pricingEngine.calculate(c).unitPrice,
          currencyCode: currency?.code ?? 'USD',
          currencySymbol: currency?.symbol ?? '\$',
        ),
    ];

    final quotation = Quotation(
      id: IdGenerator.generate(),
      quoteNumber: quoteNumber,
      projectId: widget.project.id,
      customerId: widget.project.customerId,
      items: quoteItems,
      status: QuotationStatus.draft,
      issueDate: now,
      expiryDate: now.add(Duration(days: validityDays)),
      globalDiscountPercent: double.tryParse(_discountController.text) ?? 0,
      taxPercent: double.tryParse(_taxController.text) ?? 0,
      installationCostPerUnit: double.tryParse(_installController.text) ?? 0,
      deliveryCost: double.tryParse(_deliveryController.text) ?? 0,
      termsAndConditions: settings?.company.defaultTermsAndConditions ?? '',
      createdByUserId: user?.id ?? 'system',
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(quotationNotifierProvider.notifier).save(quotation, isNew: true);
    if (mounted) {
      Navigator.of(context).pop();
      context.push(AppRoutes.quotation(quotation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricingEngine = ref.watch(pricingEngineProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Create quotation', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('${widget.project.name} · ${widget.project.projectNumber}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            for (final item in widget.items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selectedIds.contains(item.id),
                title: Text(item.name),
                subtitle: Text(
                  '${item.productTypeLabel} · Qty ${item.quantity} · ${pricingEngine.calculate(item).formattedLineTotal}',
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIds.add(item.id);
                  } else {
                    _selectedIds.remove(item.id);
                  }
                }),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(labelText: 'Discount %'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _taxController,
                  decoration: const InputDecoration(labelText: 'Tax %'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _installController,
                  decoration: const InputDecoration(labelText: 'Installation / unit'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(labelText: 'Delivery (flat)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _create,
                child: Text(_saving ? 'Creating…' : 'Create quotation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

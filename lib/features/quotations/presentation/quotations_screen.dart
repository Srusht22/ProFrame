import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/quotation.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  QuotationStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final quotationsAsync = ref.watch(quotationNotifierProvider);
    final customers = ref.watch(customerNotifierProvider).value ?? const <Customer>[];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Quotations',
            subtitle: 'Create quotations from a project\'s configured items.',
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: AppSpacing.xs),
                for (final status in QuotationStatus.values) ...[
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _statusFilter == status,
                    onSelected: (_) => setState(() => _statusFilter = status),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView(
              value: quotationsAsync,
              onRetry: () => ref.invalidate(quotationNotifierProvider),
              builder: (quotations) {
                final filtered =
                    _statusFilter == null ? quotations : quotations.where((q) => q.status == _statusFilter).toList();
                if (quotations.isEmpty) {
                  return EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No quotations yet',
                    message: 'Open a project and select "Create quotation" once you have configured doors or windows.',
                    actionLabel: 'Go to projects',
                    onAction: () => context.go(AppRoutes.projects),
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No quotations with this status',
                    message: 'Try a different filter.',
                  );
                }
                final sorted = [...filtered]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final q = sorted[index];
                    final customer = customers.where((c) => c.id == q.customerId).toList();
                    return Card(
                      child: ListTile(
                        title: Text(q.quoteNumber),
                        subtitle: Text(
                          '${customer.isNotEmpty ? customer.first.fullName : 'Unknown customer'} · ${q.items.length} item(s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${q.grandTotal.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge(statusKey: q.status.name, label: q.status.label),
                          ],
                        ),
                        onTap: () => context.push(AppRoutes.quotation(q.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

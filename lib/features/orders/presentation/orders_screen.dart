import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/order.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderNotifierProvider);
    final customers = ref.watch(customerNotifierProvider).valueOrNull ?? const <Customer>[];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Orders', subtitle: 'Confirmed orders, from production through delivery.'),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(label: const Text('All'), selected: _statusFilter == null, onSelected: (_) => setState(() => _statusFilter = null)),
                const SizedBox(width: AppSpacing.xs),
                for (final status in OrderStatus.values) ...[
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
              value: ordersAsync,
              onRetry: () => ref.invalidate(orderNotifierProvider),
              builder: (orders) {
                final filtered = _statusFilter == null ? orders : orders.where((o) => o.status == _statusFilter).toList();
                if (orders.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No orders yet',
                    message: 'Orders are created automatically when a quotation is accepted and converted.',
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'No orders with this status', message: 'Try a different filter.');
                }
                final sorted = [...filtered]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final o = sorted[index];
                    final customer = customers.where((c) => c.id == o.customerId).toList();
                    return Card(
                      child: ListTile(
                        title: Text(o.orderNumber),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(customer.isNotEmpty ? customer.first.fullName : 'Unknown customer'),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(value: o.status.progressFraction, minHeight: 4),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${o.grandTotal.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            StatusBadge(statusKey: o.status.name, label: o.status.label),
                          ],
                        ),
                        onTap: () => context.push(AppRoutes.order(o.id)),
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

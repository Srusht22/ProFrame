import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/order.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/manufacturing_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderNotifierProvider).valueOrNull ?? const <Order>[];
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order == null) {
      return const Scaffold(body: EmptyState(icon: Icons.local_shipping_outlined, title: 'Order not found', message: ''));
    }
    final customer = (ref.watch(customerNotifierProvider).valueOrNull ?? const []).firstWhereOrNull((c) => c.id == order.customerId);
    final project = (ref.watch(projectNotifierProvider).valueOrNull ?? const []).firstWhereOrNull((p) => p.id == order.projectId);
    final manufacturingOrder = ref.watch(manufacturingByOrderProvider(order.id));

    final currentIndex = OrderStatus.progressionOrder.indexOf(order.status);

    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
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
                    StatusBadge(statusKey: order.status.name, label: order.status.label),
                  ],
                ),
                if (project != null) Text('${project.name} · ${project.projectNumber}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Production progress', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (order.status != OrderStatus.cancelled)
            Column(
              children: [
                for (var i = 0; i < OrderStatus.progressionOrder.length; i++)
                  _StageRow(
                    label: OrderStatus.progressionOrder[i].label,
                    done: i <= currentIndex,
                    isLast: i == OrderStatus.progressionOrder.length - 1,
                  ),
              ],
            )
          else
            const Text('This order was cancelled.'),
          const SizedBox(height: AppSpacing.lg),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final item in order.items)
            Card(
              child: ListTile(
                title: Text(item.configurationName),
                subtitle: Text('${item.productTypeLabel} · ${item.dimensionsLabel} · Qty ${item.quantity}'),
                trailing: Text('\$${item.lineTotal.toStringAsFixed(2)}'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grand total', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '\$${order.grandTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.brandDarkGreen, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (manufacturingOrder != null)
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.manufacturingOrder(manufacturingOrder.id)),
              icon: const Icon(Icons.precision_manufacturing_outlined, size: 18),
              label: Text('View manufacturing order ${manufacturingOrder.moNumber}'),
            ),
          const SizedBox(height: AppSpacing.md),
          if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (currentIndex >= 0 && currentIndex < OrderStatus.progressionOrder.length - 1)
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(orderNotifierProvider.notifier)
                        .updateStatus(order, OrderStatus.progressionOrder[currentIndex + 1]),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text('Advance to ${OrderStatus.progressionOrder[currentIndex + 1].label}'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => ref.read(orderNotifierProvider.notifier).updateStatus(order, OrderStatus.cancelled),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel order'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;

  const _StageRow({required this.label, required this.done, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.brandDarkGreen : Theme.of(context).colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined, color: color, size: 20),
              if (!isLast) Expanded(child: Container(width: 2, color: color.withOpacity(done ? 1 : 0.4))),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              label,
              style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.w400, color: done ? null : Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
            ),
          ),
        ],
      ),
    );
  }
}

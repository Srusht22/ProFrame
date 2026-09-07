import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/manufacturing_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';

class ManufacturingScreen extends ConsumerWidget {
  const ManufacturingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moAsync = ref.watch(manufacturingNotifierProvider);
    final orders = ref.watch(orderNotifierProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Manufacturing', subtitle: 'Production stage for every confirmed order.'),
          Expanded(
            child: AsyncValueView(
              value: moAsync,
              onRetry: () => ref.invalidate(manufacturingNotifierProvider),
              builder: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'Nothing in production',
                    message: 'A manufacturing order is created automatically when an order is confirmed.',
                  );
                }
                final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final mo = sorted[index];
                    final order = orders.where((o) => o.id == mo.orderId).toList();
                    return Card(
                      child: ListTile(
                        title: Text(mo.moNumber),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(mo.stage.label),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: mo.stage.progressFraction,
                                minHeight: 4,
                                color: AppColors.brandDarkGreen,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: order.isNotEmpty ? Text(order.first.orderNumber) : null,
                        onTap: () => context.push(AppRoutes.manufacturingOrder(mo.id)),
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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/order_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import 'widgets/customer_form_sheet.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerNotifierProvider).value ?? const [];
    final customer = customers.where((c) => c.id == customerId).firstOrNull;

    if (customer == null) {
      return const Scaffold(body: EmptyState(icon: Icons.person_off_rounded, title: 'Customer not found', message: ''));
    }

    final projects = (ref.watch(projectNotifierProvider).value ?? const [])
        .where((p) => p.customerId == customerId)
        .toList();
    final quotations = (ref.watch(quotationNotifierProvider).value ?? const [])
        .where((q) => q.customerId == customerId)
        .toList();
    final orders =
        (ref.watch(orderNotifierProvider).value ?? const []).where((o) => o.customerId == customerId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.fullName),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCustomerFormSheet(context, ref, existing: customer),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete customer?',
                message: 'This removes ${customer.fullName} from your customer list. Projects and quotations are kept.',
              );
              if (confirmed) {
                await ref.read(customerNotifierProvider.notifier).delete(customer);
                if (context.mounted) context.pop();
              }
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
                if (customer.company != null) _InfoRow(Icons.apartment_rounded, customer.company!),
                _InfoRow(Icons.phone_rounded, customer.phone),
                if (customer.email != null) _InfoRow(Icons.mail_outline_rounded, customer.email!),
                if (customer.address != null || customer.city != null)
                  _InfoRow(
                    Icons.place_outlined,
                    [customer.address, customer.city, customer.country].whereType<String>().join(', '),
                  ),
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  Text(customer.notes!),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Projects (${projects.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (projects.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text('No projects yet.'))
          else
            for (final p in projects)
              Card(
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.projectNumber} · ${p.type.label}'),
                  trailing: StatusBadge(statusKey: p.status.name, label: p.status.label),
                  onTap: () => context.push(AppRoutes.project(p.id)),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text('Quotation history (${quotations.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (quotations.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text('No quotations yet.'))
          else
            for (final q in quotations)
              Card(
                child: ListTile(
                  title: Text(q.quoteNumber),
                  subtitle: Text('\$${q.grandTotal.toStringAsFixed(0)}'),
                  trailing: StatusBadge(statusKey: q.status.name, label: q.status.label),
                  onTap: () => context.push(AppRoutes.quotation(q.id)),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text('Order history (${orders.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (orders.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text('No orders yet.'))
          else
            for (final o in orders)
              Card(
                child: ListTile(
                  title: Text(o.orderNumber),
                  subtitle: Text('\$${o.grandTotal.toStringAsFixed(0)}'),
                  trailing: StatusBadge(statusKey: o.status.name, label: o.status.label),
                  onTap: () => context.push(AppRoutes.order(o.id)),
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/customer.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import 'widgets/customer_form_sheet.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Customers',
            subtitle: 'Every customer, company and contact on file.',
            trailing: FilledButton.icon(
              onPressed: () => showCustomerFormSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add customer'),
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name, company or phone…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView(
              value: customersAsync,
              onRetry: () => ref.invalidate(customerNotifierProvider),
              builder: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers.where((c) {
                        return c.fullName.toLowerCase().contains(_query) ||
                            (c.company ?? '').toLowerCase().contains(_query) ||
                            c.phone.toLowerCase().contains(_query);
                      }).toList();
                if (customers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No customers yet',
                    message: 'Add your first customer to start creating projects and quotations.',
                    actionLabel: 'Add customer',
                    onAction: () => showCustomerFormSheet(context, ref),
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Try a different search term.',
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) => _CustomerTile(customer: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(customer.fullName),
        subtitle: Text([
          if (customer.company != null && customer.company!.isNotEmpty) customer.company,
          customer.phone,
        ].whereType<String>().join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.customer(customer.id)),
      ),
    );
  }
}

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/configuration/config_enums.dart';
import '../../../domain/entities/project.dart';
import '../../../shared/providers/configuration_notifier.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/providers/quotation_notifier.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../quotations/presentation/widgets/create_quotation_sheet.dart';
import 'widgets/project_form_sheet.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectNotifierProvider).valueOrNull ?? const [];
    final project = projects.firstWhereOrNull((p) => p.id == projectId);
    if (project == null) {
      return const Scaffold(body: EmptyState(icon: Icons.folder_off_outlined, title: 'Project not found', message: ''));
    }
    final customer = (ref.watch(customerNotifierProvider).valueOrNull ?? const [])
        .firstWhereOrNull((c) => c.id == project.customerId);
    final items = ref.watch(configurationsByProjectProvider(projectId));
    final quotations =
        (ref.watch(quotationNotifierProvider).valueOrNull ?? const []).where((q) => q.projectId == projectId).toList();
    final pricingEngine = ref.watch(pricingEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showProjectFormSheet(context, ref, existing: project),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete project?',
                message: 'This removes "${project.name}" from your project list.',
              );
              if (confirmed) {
                await ref.read(projectNotifierProvider.notifier).delete(project);
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
                Row(
                  children: [
                    Expanded(
                      child: Text(project.projectNumber, style: Theme.of(context).textTheme.labelLarge),
                    ),
                    StatusBadge(statusKey: project.status.name, label: project.status.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (customer != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(customer.fullName),
                    subtitle: Text(customer.phone),
                    onTap: () => context.push(AppRoutes.customer(customer.id)),
                  ),
                if (project.location != null) _InfoLine(Icons.place_outlined, project.location!),
                if (project.description != null) _InfoLine(Icons.notes_rounded, project.description!),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final status in ProjectStatus.values)
                      ChoiceChip(
                        label: Text(status.label),
                        selected: project.status == status,
                        onSelected: (_) => ref.read(projectNotifierProvider.notifier).updateStatus(project, status),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Configured items (${items.length})', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '${AppRoutes.configuratorNew}?projectId=$projectId&category=door',
                    ),
                    icon: const Icon(Icons.door_front_door_outlined, size: 18),
                    label: const Text('Add door'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '${AppRoutes.configuratorNew}?projectId=$projectId&category=window',
                    ),
                    icon: const Icon(Icons.window_outlined, size: 18),
                    label: const Text('Add window'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No doors or windows configured for this project yet.'),
            )
          else
            for (final item in items)
              Card(
                child: ListTile(
                  leading: Icon(item.category.icon, color: AppColors.brandDarkGreen),
                  title: Text(item.name),
                  subtitle: Text('${item.productTypeLabel} · ${item.formattedDimensions()} · Qty ${item.quantity}'),
                  trailing: Text(
                    pricingEngine.calculate(item).formattedLineTotal,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => context.push(AppRoutes.configurator(item.id)),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quotations (${quotations.length})', style: Theme.of(context).textTheme.titleMedium),
              if (items.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => showCreateQuotationSheet(context, ref, project: project, items: items),
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Create quotation'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (quotations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No quotations for this project yet.'),
            )
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
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

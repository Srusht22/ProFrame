import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/project.dart';
import '../../../shared/providers/customer_notifier.dart';
import '../../../shared/providers/project_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import 'widgets/project_form_sheet.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  ProjectStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectNotifierProvider);
    final customers = ref.watch(customerNotifierProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Projects',
            subtitle: 'Customer jobs — each may contain multiple doors and windows.',
            trailing: FilledButton.icon(
              onPressed: () => showProjectFormSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New project'),
            ),
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
                for (final status in ProjectStatus.values) ...[
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
              value: projectsAsync,
              onRetry: () => ref.invalidate(projectNotifierProvider),
              builder: (projects) {
                final filtered =
                    _statusFilter == null ? projects : projects.where((p) => p.status == _statusFilter).toList();
                if (projects.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_outlined,
                    title: 'No projects yet',
                    message: 'Create a project to start configuring doors and windows for a customer.',
                    actionLabel: 'New project',
                    onAction: () => showProjectFormSheet(context, ref),
                  );
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No projects with this status',
                    message: 'Try a different filter.',
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    final customerName =
                        customers.firstWhereOrNull((c) => c.id == project.customerId)?.fullName;
                    return Card(
                      child: ListTile(
                        title: Text(project.name),
                        subtitle: Text('${project.projectNumber} · ${customerName ?? 'Unknown customer'}'),
                        trailing: StatusBadge(statusKey: project.status.name, label: project.status.label),
                        onTap: () => context.push(AppRoutes.project(project.id)),
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

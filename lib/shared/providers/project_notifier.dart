import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/entities/project.dart';
import 'audit_log_notifier.dart';
import 'auth_notifier.dart';

class ProjectNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.watch(appRepositoriesProvider).projects.getAll();
  }

  Future<String> nextProjectNumber() => ref.read(appRepositoriesProvider).projects.nextProjectNumber();

  Future<void> save(Project project, {required bool isNew}) async {
    await ref.read(appRepositoriesProvider).projects.save(project);
    final list = [...state.value ?? const <Project>[]];
    final index = list.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      list[index] = project;
    } else {
      list.add(project);
    }
    state = AsyncData(list);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: isNew ? AuditAction.create : AuditAction.update,
          entityType: 'Project',
          entityId: project.id,
          entityLabel: project.name,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<void> updateStatus(Project project, ProjectStatus status) async {
    final previous = project.status.label;
    final updated = project.copyWith(status: status);
    await save(updated, isNew: false);
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.statusChange,
          entityType: 'Project',
          entityId: project.id,
          entityLabel: project.name,
          previousValue: previous,
          newValue: status.label,
          actingUser: ref.read(currentUserProvider),
        );
  }

  Future<void> delete(Project project) async {
    await ref.read(appRepositoriesProvider).projects.delete(project.id);
    state = AsyncData((state.value ?? const []).where((p) => p.id != project.id).toList());
    await ref.read(auditLogNotifierProvider.notifier).log(
          action: AuditAction.delete,
          entityType: 'Project',
          entityId: project.id,
          entityLabel: project.name,
          actingUser: ref.read(currentUserProvider),
        );
  }
}

final projectNotifierProvider = AsyncNotifierProvider<ProjectNotifier, List<Project>>(
  ProjectNotifier.new,
);

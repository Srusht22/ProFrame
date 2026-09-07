import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/audit_log_entry.dart';
import '../../../shared/providers/audit_log_notifier.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(auditLogNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: AsyncValueView(
        value: logAsync,
        onRetry: () => ref.invalidate(auditLogNotifierProvider),
        builder: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(icon: Icons.fact_check_outlined, title: 'No activity yet', message: 'Every create, update, delete and status change will show up here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final e = entries[index];
              return ListTile(
                leading: Icon(_iconFor(e.action), size: 20),
                title: Text('${e.userName} ${_verb(e.action)} ${e.entityType}${e.entityLabel != null ? ' "${e.entityLabel}"' : ''}'),
                subtitle: e.previousValue != null && e.newValue != null
                    ? Text('${e.previousValue} → ${e.newValue}')
                    : null,
                trailing: Text(_fmt(e.timestamp), style: Theme.of(context).textTheme.bodySmall),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle_outline_rounded;
      case AuditAction.update:
        return Icons.edit_outlined;
      case AuditAction.delete:
        return Icons.delete_outline_rounded;
      case AuditAction.statusChange:
        return Icons.swap_horiz_rounded;
      case AuditAction.login:
        return Icons.login_rounded;
      case AuditAction.logout:
        return Icons.logout_rounded;
    }
  }

  String _verb(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return 'created';
      case AuditAction.update:
        return 'updated';
      case AuditAction.delete:
        return 'deleted';
      case AuditAction.statusChange:
        return 'changed status of';
      case AuditAction.login:
        return 'signed in';
      case AuditAction.logout:
        return 'signed out';
    }
  }

  String _fmt(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month} $h:$m';
  }
}

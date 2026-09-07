import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/auth/permission.dart';
import '../providers/auth_notifier.dart';
import 'empty_state.dart';

/// Enforces role-based access *inside the UI* (spec §5: "Implement
/// permission checks both in UI and business logic") — repositories/
/// services independently refuse to let an unauthorized action mutate
/// data, this widget just keeps a restricted screen from ever rendering.
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;

  const PermissionGate({super.key, required this.permission, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(hasPermissionProvider(permission));
    if (allowed) return child;
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Access restricted',
        message: "Your role doesn't include permission to view this section. Contact an administrator if you need access.",
      ),
    );
  }
}

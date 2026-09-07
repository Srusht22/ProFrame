import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/auth/permission.dart';
import '../../../../shared/providers/user_notifier.dart';
import '../../../../shared/widgets/async_value_view.dart';

class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userNotifierProvider);
    return AsyncValueView(
      value: usersAsync,
      onRetry: () => ref.invalidate(userNotifierProvider),
      builder: (users) {
        return ListView(
          children: [
            Text(
              'Role determines what each teammate can see and do — see README → Roles & Permissions for the full matrix.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final user in users)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.initials)),
                  title: Text(user.fullName),
                  subtitle: Text(user.email),
                  trailing: DropdownButton<UserRole>(
                    value: user.role,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final role in UserRole.values) DropdownMenuItem(value: role, child: Text(role.label)),
                    ],
                    onChanged: (role) {
                      if (role != null) ref.read(userNotifierProvider.notifier).updateRole(user, role);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

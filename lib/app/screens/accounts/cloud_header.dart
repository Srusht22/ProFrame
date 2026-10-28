import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/accounts/accounts.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import 'account_ui.dart';
import 'approvals_screen.dart';
import 'workers_screen.dart';

/// Who is signed in, and what their account offers: the owner's workers
/// and approvals, and signing out.
class CloudAccountButton extends ConsumerWidget {
  final Color colour;
  const CloudAccountButton({super.key, required this.colour});

  static const buttonKey = ValueKey('cloud-account');
  static const workersKey = ValueKey('cloud-account-workers');
  static const approvalsKey = ValueKey('cloud-account-approvals');
  static const signOutKey = ValueKey('cloud-account-sign-out');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionProvider).value;
    final l = context.l10n;
    if (account == null) return const SizedBox.shrink();
    final role = account.isOwner ? l.clRoleOwner : l.clRoleLabour;
    return PopupMenuButton<String>(
      key: buttonKey,
      tooltip: l.clSignedInAs(account.name, role),
      icon: Icon(Icons.account_circle, color: colour),
      onSelected: (choice) async {
        final navigator = Navigator.of(context);
        switch (choice) {
          case 'workers':
            await navigator.push(
              MaterialPageRoute<void>(builder: (_) => const WorkersScreen()),
            );
          case 'approvals':
            await navigator.push(
              MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen()),
            );
          case 'out':
            navigator.popUntil((r) => r.isFirst);
            await ref.read(sessionProvider.notifier).signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('$role · ${account.factoryName}'),
              Text(
                account.login,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (account.isOwner) ...[
          PopupMenuItem(
            key: workersKey,
            value: 'workers',
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(l.clWorkers),
            ),
          ),
          PopupMenuItem(
            key: approvalsKey,
            value: 'approvals',
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l.clApprovals),
            ),
          ),
        ],
        PopupMenuItem(
          key: signOutKey,
          value: 'out',
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.clSignOut),
          ),
        ),
      ],
    );
  }
}

/// The owner's requests waiting, with how many.
class ApprovalsButton extends ConsumerWidget {
  final Color colour;
  const ApprovalsButton({super.key, required this.colour});

  static const buttonKey = ValueKey('approvals-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionProvider).value;
    if (account == null || !account.isOwner) return const SizedBox.shrink();
    final pending = ref.watch(pendingCountProvider);
    final l = context.l10n;
    return IconButton(
      key: buttonKey,
      tooltip: l.clApprovalsWaiting(pending),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen())),
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: Icon(Icons.fact_check_outlined, color: colour),
      ),
    );
  }
}

/// The notes sent to the signed-in account, with how many are unread.
class NotificationsButton extends ConsumerWidget {
  final Color colour;
  const NotificationsButton({super.key, required this.colour});

  static const buttonKey = ValueKey('notifications-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider).value == null) {
      return const SizedBox.shrink();
    }
    final unread =
        ref
            .watch(notificationsProvider)
            .value
            ?.where((n) => !n.isRead)
            .length ??
        0;
    final l = context.l10n;
    return IconButton(
      key: buttonKey,
      tooltip: l.clNotificationsUnread(unread),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const NotificationsSheet(),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: Icon(Icons.notifications_outlined, color: colour),
      ),
    );
  }
}

/// The account's notifications, newest first; opening them marks them read.
class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({super.key});

  static const emptyKey = ValueKey('notifications-empty');

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final backend = ref.read(backendProvider);
    final all = await ref.read(notificationsProvider.future);
    var any = false;
    for (final n in all.where((n) => !n.isRead)) {
      try {
        await backend!.markRead(n.id);
        any = true;
      } on Object {
        // Marked next time.
      }
    }
    if (any && mounted) ref.read(cloudRevisionProvider.notifier).changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final notes = ref.watch(notificationsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l.clNotifications,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: notes.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: FormProblem(problemOf(context, e)),
                ),
                data: (all) => all.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l.clNoNotifications,
                          key: NotificationsSheet.emptyKey,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final n in all)
                            ListTile(
                              leading: Icon(
                                n.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                              ),
                              title: Text(notificationText(context, n)),
                              subtitle: Text(whenIn(l, n.createdAt)),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a notification says, in the screen's language.
String notificationText(BuildContext context, AppNotification n) {
  final l = context.l10n;
  final kind = RequestKind.of(n.body['kind']);
  final what = kind == null ? '' : requestKindIn(l, kind);
  final note = '${n.body['note'] ?? ''}'.trim();
  return switch (n.kind) {
    'request_submitted' => l.clNoteSubmitted('${n.body['by'] ?? ''}', what),
    'request_approved' => l.clNoteApproved(what),
    'request_rejected' =>
      note.isEmpty ? l.clNoteRejected(what) : l.clNoteRejectedWhy(what, note),
    'design_assigned' => l.clNoteAssigned,
    'worker_joined' => l.clNoteJoined('${n.body['name'] ?? ''}'),
    _ => l.clNoteOther,
  };
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/accounts/accounts.dart';
import '../../../domain/model/design.dart';
import '../../../domain/text/names.dart';
import '../../../infrastructure/design_store.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import '../../state/workspace.dart';
import '../../theme/app_theme.dart';
import '../designs_screen.dart';
import 'account_ui.dart';
import 'approvals_screen.dart';

/// The most active workers a factory may have. The backend holds the
/// limit; this only says it.
const workerSeats = 3;

/// The owner's workers: who they are, what they may see and what they have
/// asked for — and inviting, suspending and reactivating them. Never a
/// password: a worker sets their own, by the invitation.
class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  static const inviteKey = ValueKey('workers-invite');
  static const seatsKey = ValueKey('workers-seats');
  static const emptyKey = ValueKey('workers-empty');
  static ValueKey<String> workerKey(String id) => ValueKey('worker-$id');
  static ValueKey<String> toggleKey(String id) => ValueKey('worker-toggle-$id');
  static ValueKey<String> viewKey(String id) => ValueKey('worker-view-$id');
  static ValueKey<String> revokeKey(String id) => ValueKey('invite-revoke-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const OwnerOnly(child: _Workers());
}

class _Workers extends ConsumerWidget {
  const _Workers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final workers = ref.watch(workersProvider);
    final invites = ref.watch(invitationsProvider);
    final used =
        (workers.value?.where((w) => w.isActive).length ?? 0) +
        (invites.value?.length ?? 0);
    final full = used >= workerSeats;
    return AccountScaffold(
      title: l.clWorkers,
      floating: FloatingActionButton.extended(
        key: WorkersScreen.inviteKey,
        onPressed: full || !workers.hasValue
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) => const InviteDialog(),
              ),
        backgroundColor: full ? context.palette.hairline : null,
        icon: const Icon(Icons.person_add_alt),
        label: Text(l.clInviteWorker),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.clSeatsUsed('$used', '$workerSeats'),
            key: WorkersScreen.seatsKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            full ? l.clSeatsFull : l.clWorkersLead,
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 16),
          workers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FormProblem(problemOf(context, e)),
            data: (all) => all.isEmpty
                ? Text(l.clNoWorkers, key: WorkersScreen.emptyKey)
                : Column(
                    children: [for (final w in all) _WorkerCard(worker: w)],
                  ),
          ),
          if (invites.value?.isNotEmpty ?? false) ...[
            const SizedBox(height: 20),
            Text(
              l.clOpenInvites,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final i in invites.value!)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(i.name),
                  subtitle: Text(
                    '${i.email}\n${l.clInviteUntil(whenIn(l, i.expiresAt))}',
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    key: WorkersScreen.revokeKey(i.id),
                    onPressed: () async {
                      try {
                        await ref.read(backendProvider)!.revokeInvitation(i.id);
                        ref.read(cloudRevisionProvider.notifier).changed();
                      } on Object catch (e) {
                        if (context.mounted) {
                          _say(context, problemOf(context, e));
                        }
                      }
                    },
                    child: Text(l.clRevoke),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

void _say(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _WorkerCard extends ConsumerWidget {
  final Worker worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final w = worker;
    return Card(
      key: WorkersScreen.workerKey(w.userId),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  w.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                StatusChip.account(context, w.status),
              ],
            ),
            Text(w.login, textDirection: TextDirection.ltr),
            const SizedBox(height: 6),
            Text(
              '${l.clAssignedCount(w.assigned)} · ${l.clPendingCount(w.pending)}',
              style: TextStyle(color: context.palette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: WorkersScreen.viewKey(w.userId),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkerScreen(workerId: w.userId),
                    ),
                  ),
                  icon: const Icon(Icons.key_outlined),
                  label: Text(l.clManageAccess),
                ),
                OutlinedButton.icon(
                  key: WorkersScreen.toggleKey(w.userId),
                  onPressed: () =>
                      setWorkerActive(context, ref, w, !w.isActive),
                  icon: Icon(
                    w.isActive ? Icons.pause_circle_outline : Icons.play_arrow,
                  ),
                  label: Text(w.isActive ? l.clSuspend : l.clReactivate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Suspends or reactivates [w], asking first before suspending.
Future<void> setWorkerActive(
  BuildContext context,
  WidgetRef ref,
  Worker w,
  bool active,
) async {
  final l = context.l10n;
  if (!active) {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.clSuspendTitle(w.name)),
        content: Text(l.clSuspendBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.actCancel),
          ),
          FilledButton(
            key: const ValueKey('suspend-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.clSuspend),
          ),
        ],
      ),
    );
    if (sure != true) return;
  }
  try {
    await ref.read(backendProvider)!.setWorkerActive(w.userId, active: active);
    ref.read(cloudRevisionProvider.notifier).changed();
    if (context.mounted) {
      _say(context, active ? l.clReactivated(w.name) : l.clSuspended(w.name));
    }
  } on Object catch (e) {
    if (context.mounted) _say(context, problemOf(context, e));
  }
}

/// Inviting a worker: their name and address, and then the code — shown
/// once, for the owner to give them. The worker sets their own password.
class InviteDialog extends ConsumerStatefulWidget {
  const InviteDialog({super.key});

  static const nameKey = ValueKey('invite-name');
  static const emailKey = ValueKey('invite-email');
  static const submitKey = ValueKey('invite-submit');
  static const codeKey = ValueKey('invite-code');

  @override
  ConsumerState<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<InviteDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _problem;
  InvitationCode? _made;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _name.text.trim().isEmpty
        ? l.clNameNeeded
        : !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())
        ? l.clEmailInvalid
        : null;
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final made = await ref
          .read(backendProvider)!
          .invite(name: _name.text.trim(), email: _email.text.trim());
      ref.read(cloudRevisionProvider.notifier).changed();
      if (mounted) setState(() => _made = made);
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final made = _made;
    return AlertDialog(
      title: Text(l.clInviteWorker),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: made == null
                ? [
                    Text(l.clInviteLead),
                    const SizedBox(height: 12),
                    TextField(
                      key: InviteDialog.nameKey,
                      controller: _name,
                      decoration: InputDecoration(labelText: l.clWorkerName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: InviteDialog.emailKey,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(labelText: l.clEmail),
                    ),
                    FormProblem(_problem),
                  ]
                : [
                    Text(
                      l.clInviteMade(
                        _name.text.trim(),
                        _email.text.trim(),
                        whenIn(l, made.expiresAt),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      made.code,
                      key: InviteDialog.codeKey,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: made.code),
                          );
                          if (context.mounted) _say(context, l.clCopied);
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(l.clCopyCode),
                      ),
                    ),
                    Text(
                      l.clInviteOnce,
                      style: TextStyle(color: context.palette.muted),
                    ),
                  ],
          ),
        ),
      ),
      actions: made == null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.actCancel),
              ),
              FilledButton(
                key: InviteDialog.submitKey,
                onPressed: _busy ? null : _submit,
                child: Text(l.clInvite),
              ),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.actDone),
              ),
            ],
    );
  }
}

/// One worker: who they are, which designs they may see — given and taken
/// away here, and only here — and what they have asked for.
class WorkerScreen extends ConsumerWidget {
  final String workerId;
  const WorkerScreen({super.key, required this.workerId});

  static const assignKey = ValueKey('worker-assign');
  static const noneKey = ValueKey('worker-no-designs');
  static ValueKey<String> removeKey(String designId) =>
      ValueKey('worker-unassign-$designId');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      OwnerOnly(child: _Worker(workerId: workerId));
}

class _Worker extends ConsumerWidget {
  final String workerId;
  const _Worker({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final worker = ref
        .watch(workersProvider)
        .value
        ?.where((w) => w.userId == workerId)
        .firstOrNull;
    final assigned = [
      for (final a
          in ref.watch(assignmentsProvider).value ?? const <Assignment>[])
        if (a.workerId == workerId) a.designId,
    ];
    final asked = [
      for (final r
          in ref.watch(requestsProvider).value ?? const <WorkRequest>[])
        if (r.requestedBy == workerId) r,
    ];
    if (worker == null) {
      return AccountScaffold(
        title: l.clWorkers,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return AccountScaffold(
      title: worker.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(worker.login, textDirection: TextDirection.ltr),
              StatusChip.account(context, worker.status),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () =>
                  setWorkerActive(context, ref, worker, !worker.isActive),
              child: Text(worker.isActive ? l.clSuspend : l.clReactivate),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.clDesignsAccess,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l.clDesignsAccessLead,
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 8),
          if (assigned.isEmpty)
            Text(l.clNoDesignsAssigned, key: WorkerScreen.noneKey)
          else
            for (final id in assigned)
              _AssignedRow(designId: id, workerId: workerId),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: WorkerScreen.assignKey,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AssignDialog(workerId: workerId, already: assigned.toSet()),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.clAssignDesign),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.clTheirRequests,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (asked.isEmpty)
            Text(l.clNoRequests)
          else
            for (final r in asked) RequestTile(request: r),
        ],
      ),
    );
  }
}

class _AssignedRow extends ConsumerWidget {
  final String designId;
  final String workerId;
  const _AssignedRow({required this.designId, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return FutureBuilder<Design?>(
      future: ref.read(designStoreProvider).load(designId),
      builder: (context, snap) {
        final d = snap.data;
        return Card(
          child: ListTile(
            leading: Icon(d == null ? Icons.description : kindIcon(d.kind)),
            title: Text(d?.shownNameIn(context.words) ?? designId),
            subtitle: d == null ? null : Text(d.kind.labelIn(context.words)),
            trailing: TextButton(
              key: WorkerScreen.removeKey(designId),
              onPressed: () async {
                try {
                  await ref.read(backendProvider)!.unassign(designId, workerId);
                  ref.read(cloudRevisionProvider.notifier).changed();
                } on Object catch (e) {
                  if (context.mounted) _say(context, problemOf(context, e));
                }
              },
              child: Text(l.clRemoveAccess),
            ),
          ),
        );
      },
    );
  }
}

/// Choosing a design of the factory's to give a worker. Only what is on the
/// owner's device is offered; the backend checks it is the factory's.
class AssignDialog extends ConsumerStatefulWidget {
  final String workerId;
  final Set<String> already;
  const AssignDialog({
    super.key,
    required this.workerId,
    required this.already,
  });

  static ValueKey<String> optionKey(String id) => ValueKey('assign-$id');

  @override
  ConsumerState<AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<AssignDialog> {
  String _query = '';
  bool _busy = false;
  String? _problem;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.clAssignDesign),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.clSearchDesigns,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            FormProblem(_problem),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<DesignPage>(
                future: ref
                    .read(designStoreProvider)
                    .page(query: _query, limit: 60),
                builder: (context, snap) {
                  final page = snap.data;
                  if (page == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final offered = [
                    for (final s in page.items)
                      if (!widget.already.contains(s.id)) s,
                  ];
                  if (offered.isEmpty) return Text(l.clNothingToAssign);
                  return ListView(
                    children: [
                      for (final s in offered)
                        ListTile(
                          key: AssignDialog.optionKey(s.id),
                          leading: Icon(kindIcon(s.kind)),
                          title: Text(s.shownNameIn(context.words)),
                          subtitle: Text(s.customer ?? ''),
                          enabled: !_busy,
                          onTap: () => _assign(s.id),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actClose),
        ),
      ],
    );
  }

  Future<void> _assign(String designId) async {
    setState(() => _busy = true);
    try {
      await ref.read(ownerSyncProvider)?.push();
      await ref.read(backendProvider)!.assign(designId, widget.workerId);
      ref.read(cloudRevisionProvider.notifier).changed();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

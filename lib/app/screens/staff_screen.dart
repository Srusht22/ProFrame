import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/staff.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../infrastructure/owner_access_store.dart';
import '../../infrastructure/staff_store.dart';
import '../state/access.dart';
import '../theme/app_theme.dart';
import 'factory_prices_screen.dart' show OwnerPinDialog;

/// Who is at the device, on the customers' header: *Owner*, a member of
/// staff's name, or *Sign in* — and the way to sign in as the owner or as a
/// member of staff, to sign out, and to the staff and their permissions.
class AccountButton extends ConsumerWidget {
  final Color colour;

  const AccountButton({super.key, required this.colour});

  static const buttonKey = ValueKey('account-button');
  static const whoKey = ValueKey('account-who');
  static const ownerKey = ValueKey('account-owner');
  static const staffKey = ValueKey('account-staff');
  static const manageKey = ValueKey('account-manage');
  static const signOutKey = ValueKey('account-sign-out');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(actorProvider);
    final signedIn = actor == WorkshopRole.owner || actor is StaffMember;
    final manages =
        actor.can(Capability.usersManage) ||
        actor.can(Capability.permissionsManage);
    return PopupMenuButton<String>(
      key: buttonKey,
      tooltip: signedIn ? 'Signed in as ${actor.label}' : 'Sign in',
      onSelected: (choice) async {
        switch (choice) {
          case 'owner':
            await signInOwner(context, ref);
          case 'staff':
            await showDialog<void>(
              context: context,
              builder: (_) => const StaffSignInDialog(),
            );
          case 'manage':
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
            );
          case 'out':
            ref.signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          key: whoKey,
          enabled: false,
          child: Text(
            signedIn
                ? 'Signed in as ${actor.label}'
                // With no staff accounts the device works as staff; once
                // there are accounts, nobody signed in can only look.
                : actor == WorkshopRole.staff
                ? 'No accounts yet — working as staff'
                : 'Nobody signed in',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: ownerKey,
          value: 'owner',
          child: Text('Sign in as owner'),
        ),
        const PopupMenuItem(
          key: staffKey,
          value: 'staff',
          child: Text('Sign in as staff'),
        ),
        if (manages)
          const PopupMenuItem(
            key: manageKey,
            value: 'manage',
            child: Text('Staff & permissions'),
          ),
        if (signedIn)
          const PopupMenuItem(
            key: signOutKey,
            value: 'out',
            child: Text('Sign out'),
          ),
      ],
      // An icon, as its neighbours on the header are: who it is is in its
      // tooltip and at the head of its menu.
      icon: Icon(
        actor == WorkshopRole.owner
            ? Icons.admin_panel_settings_outlined
            : actor is StaffMember
            ? Icons.badge_outlined
            : Icons.person_outline,
        color: colour,
      ),
    );
  }
}

/// The owner's PIN asked for — or set, the first time — and the owner
/// signed in.
Future<void> signInOwner(BuildContext context, WidgetRef ref) async {
  final store = ref.read(ownerAccessStoreProvider);
  final hasPin = await store.hasPin();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => OwnerPinDialog(store: store, setting: !hasPin),
  );
  if (ok ?? false) ref.signInAsOwner();
}

/// A member of staff chosen, and their PIN.
class StaffSignInDialog extends ConsumerStatefulWidget {
  const StaffSignInDialog({super.key});

  static const memberKey = ValueKey('staff-sign-in-member');
  static const pinKey = ValueKey('staff-sign-in-pin');
  static const okKey = ValueKey('staff-sign-in-ok');

  @override
  ConsumerState<StaffSignInDialog> createState() => _StaffSignInState();
}

class _StaffSignInState extends ConsumerState<StaffSignInDialog> {
  String? _id;
  final _pin = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    if (_id == null) {
      setState(() => _problem = 'Choose who you are.');
      return;
    }
    final member = await ref
        .read(staffStoreProvider)
        .signIn(_id!, _pin.text.trim());
    if (!mounted) return;
    if (member == null) {
      setState(() => _problem = 'That is not their PIN.');
      return;
    }
    ref.signInAs(member);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = [
      for (final m
          in ref.watch(staffMembersProvider).value ?? const <StaffMember>[])
        if (m.active) m,
    ];
    return AlertDialog(
      title: const Text('Sign in as staff'),
      content: SizedBox(
        width: 360,
        child: members.isEmpty
            ? const Text(
                'No member of staff has been added yet. The owner adds them '
                'under Staff & permissions.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: StaffSignInDialog.memberKey,
                    initialValue: _id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Who'),
                    items: [
                      for (final m in members)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (id) => setState(() {
                      _id = id;
                      _problem = null;
                    }),
                  ),
                  TextField(
                    key: StaffSignInDialog.pinKey,
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'PIN'),
                    onSubmitted: (_) => _ok(),
                  ),
                  if (_problem case final problem?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        problem,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (members.isNotEmpty)
          FilledButton(
            key: StaffSignInDialog.okKey,
            onPressed: _ok,
            child: const Text('Sign in'),
          ),
      ],
    );
  }
}

/// **Staff & permissions**: every member of staff, what each may do — a
/// switch for each capability, grouped — whether they are active, and a way
/// to add one. What can be changed follows who is at the device; what is
/// kept is decided again by `StaffStore`, which refuses anything they may
/// not do.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  static const addKey = ValueKey('staff-add');

  static ValueKey<String> memberKey(String id) => ValueKey('staff-member-$id');
  static ValueKey<String> capabilityKey(String id, Capability c) =>
      ValueKey('staff-$id-${c.key}');
  static ValueKey<String> activeKey(String id) => ValueKey('staff-active-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(actorProvider);
    final members = ref.watch(staffMembersProvider).value;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final groups = <String, List<Capability>>{};
    for (final c in Capability.values) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }

    Future<void> act(Future<void> Function(Authority by) change) async {
      try {
        await change(await ref.actorNow());
        ref.staffChanged();
      } on AccessDenied catch (e) {
        if (context.mounted) _say(context, e.toString());
      } on ArgumentError catch (e) {
        if (context.mounted) _say(context, '${e.message}');
      }
    }

    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(title: const Text('Staff & permissions')),
      floatingActionButton: actor.can(Capability.usersManage)
          ? FloatingActionButton.extended(
              key: addKey,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AddStaffDialog(),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add staff member'),
            )
          : null,
      body: members == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    Text(
                      'The owner may do everything. Each member of staff may '
                      'do what is ticked here, and nothing else. With nobody '
                      'signed in, the device may only look once any member '
                      'of staff is active.',
                      style: text.bodySmall,
                    ),
                    if (members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('No member of staff has been added yet.'),
                      ),
                    for (final m in members)
                      Card(
                        key: memberKey(m.id),
                        margin: const EdgeInsets.only(top: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: text.titleMedium,
                                    ),
                                  ),
                                  Text(m.active ? 'Active' : 'Inactive'),
                                  Switch(
                                    key: activeKey(m.id),
                                    value: m.active,
                                    onChanged: actor.can(Capability.usersManage)
                                        ? (on) => act(
                                            (by) => ref
                                                .read(staffStoreProvider)
                                                .setActive(
                                                  m.id,
                                                  active: on,
                                                  by: by,
                                                ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              for (final g in groups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    g.key.toUpperCase(),
                                    style: text.labelSmall?.copyWith(
                                      color: p.muted,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    for (final c in g.value)
                                      FilterChip(
                                        key: capabilityKey(m.id, c),
                                        label: Text(c.label),
                                        selected: m.capabilities.contains(c),
                                        onSelected:
                                            actor.can(
                                                  Capability.permissionsManage,
                                                ) &&
                                                actor.can(c)
                                            ? (on) => act(
                                                (by) => ref
                                                    .read(staffStoreProvider)
                                                    .setCapabilities(
                                                      m.id,
                                                      on
                                                          ? {
                                                              ...m.capabilities,
                                                              c,
                                                            }
                                                          : ({...m.capabilities}
                                                              ..remove(c)),
                                                      by: by,
                                                    ),
                                              )
                                            : null,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

void _say(BuildContext context, String words) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(words)));

/// A new member of staff: their name and PIN. They start able to look and
/// nothing more (`Capability.viewOnly`); what else they may do is ticked on
/// their card afterwards.
class AddStaffDialog extends ConsumerStatefulWidget {
  const AddStaffDialog({super.key});

  static const nameKey = ValueKey('staff-add-name');
  static const pinKey = ValueKey('staff-add-pin');
  static const againKey = ValueKey('staff-add-pin-again');
  static const okKey = ValueKey('staff-add-ok');

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffState();
}

class _AddStaffState extends ConsumerState<AddStaffDialog> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    final members = await ref.read(staffStoreProvider).all();
    final pin = _pin.text.trim();
    final problem =
        StaffStore.nameProblem(_name.text, members) ??
        OwnerAccessStore.problemWith(pin) ??
        (pin == _again.text.trim() ? null : 'The two PINs are not the same.');
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    try {
      await ref
          .read(staffStoreProvider)
          .add(
            name: _name.text,
            pin: pin,
            capabilities: Capability.viewOnly,
            by: await ref.actorNow(),
          );
      ref.staffChanged();
      if (mounted) Navigator.of(context).pop();
    } on AccessDenied catch (e) {
      setState(() => _problem = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add staff member'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: AddStaffDialog.nameKey,
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            key: AddStaffDialog.pinKey,
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          TextField(
            key: AddStaffDialog.againKey,
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'The PIN again'),
            onSubmitted: (_) => _ok(),
          ),
          const SizedBox(height: 8),
          Text(
            'They start able to look and nothing more. Tick what else they '
            'may do on their card.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_problem case final problem?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                problem,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: AddStaffDialog.okKey,
        onPressed: _ok,
        child: const Text('Add'),
      ),
    ],
  );
}

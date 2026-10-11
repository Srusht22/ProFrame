import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/staff.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../infrastructure/owner_access_store.dart';
import '../../infrastructure/staff_store.dart';
import '../l10n/l10n.dart';
import '../state/access.dart';
import '../state/language.dart';
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
    final l = context.l10n;
    final who = authorityLabelIn(actor, context.words);
    return PopupMenuButton<String>(
      key: buttonKey,
      tooltip: signedIn ? l.acSignedInAs(who) : l.acSignIn,
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
                ? l.acSignedInAs(who)
                // With no staff accounts the device works as staff; once
                // there are accounts, nobody signed in can only look.
                : actor == WorkshopRole.staff
                ? l.acNoAccounts
                : l.acNobody,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(key: ownerKey, value: 'owner', child: Text(l.acAsOwner)),
        PopupMenuItem(key: staffKey, value: 'staff', child: Text(l.acAsStaff)),
        if (manages)
          PopupMenuItem(
            key: manageKey,
            value: 'manage',
            child: Text(l.acStaffPermissions),
          ),
        if (signedIn)
          PopupMenuItem(
            key: signOutKey,
            value: 'out',
            child: Text(l.acSignOut),
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
      setState(() => _problem = context.l10n.acChooseWho);
      return;
    }
    final member = await ref
        .read(staffStoreProvider)
        .signIn(_id!, _pin.text.trim());
    if (!mounted) return;
    if (member == null) {
      setState(() => _problem = context.l10n.acWrongPin);
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
      title: Text(context.l10n.acAsStaff),
      content: SizedBox(
        width: 360,
        child: members.isEmpty
            ? Text(context.l10n.acNoStaffYet)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: StaffSignInDialog.memberKey,
                    initialValue: _id,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.l10n.acWho),
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
                    decoration: InputDecoration(labelText: context.l10n.acPin),
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
          child: Text(context.l10n.actCancel),
        ),
        if (members.isNotEmpty)
          FilledButton(
            key: StaffSignInDialog.okKey,
            onPressed: _ok,
            child: Text(context.l10n.acSignIn),
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
        if (context.mounted) _say(context, e.messageIn(context.words));
      } on ArgumentError catch (e) {
        if (context.mounted) _say(context, '${e.message}');
      }
    }

    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(title: Text(context.l10n.acStaffPermissions)),
      floatingActionButton: actor.can(Capability.usersManage)
          ? FloatingActionButton.extended(
              key: addKey,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AddStaffDialog(),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: Text(context.l10n.acAddStaff),
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
                    Text(context.l10n.acIntro, style: text.bodySmall),
                    if (members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(context.l10n.acNoStaff),
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
                                  Text(
                                    m.active
                                        ? context.l10n.acActive
                                        : context.l10n.acInactive,
                                  ),
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
                                    g.value.first
                                        .groupIn(context.words)
                                        .toUpperCase(),
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
                                        label: Text(c.labelIn(context.words)),
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
        StaffStore.nameProblem(_name.text, members, w: ref.words) ??
        OwnerAccessStore.problemWith(pin, ref.words) ??
        (pin == _again.text.trim() ? null : ref.l10n.pinNotSame);
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
      setState(() => _problem = e.messageIn(ref.words));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.acAddStaff),
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
            decoration: InputDecoration(labelText: context.l10n.acName),
          ),
          TextField(
            key: AddStaffDialog.pinKey,
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: context.l10n.acPin),
          ),
          TextField(
            key: AddStaffDialog.againKey,
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: context.l10n.pinAgain),
            onSubmitted: (_) => _ok(),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.acStartLooking,
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
        child: Text(context.l10n.actCancel),
      ),
      FilledButton(
        key: AddStaffDialog.okKey,
        onPressed: _ok,
        child: Text(context.l10n.actAdd),
      ),
    ],
  );
}

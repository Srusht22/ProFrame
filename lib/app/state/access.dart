import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/staff.dart';
import '../../domain/pricing/pricing_access.dart';
import '../../infrastructure/owner_access_store.dart';
import '../../infrastructure/staff_store.dart';
import 'pricing.dart';
import 'workspace.dart';

/// Where the owner's PIN is kept.
final ownerAccessStoreProvider = Provider<OwnerAccessStore>(
  (ref) => OwnerAccessStore(),
);

/// Where the workshop's staff are kept.
final staffStoreProvider = Provider<StaffStore>((ref) => StaffStore());

/// Changes whenever a member of staff is added or changed, so everything
/// listing them reads them again.
final staffRevisionProvider = NotifierProvider<DesignsRevision, int>(
  DesignsRevision.new,
);

/// The workshop's staff, as kept.
final staffMembersProvider = FutureProvider<List<StaffMember>>((ref) {
  ref.watch(staffRevisionProvider);
  return ref.read(staffStoreProvider).all();
});

/// The member of staff signed in on the device, if any. Every run starts
/// with nobody, as it starts as staff rather than owner.
final signedInStaffProvider = NotifierProvider<SignedInStaff, StaffMember?>(
  SignedInStaff.new,
);

class SignedInStaff extends Notifier<StaffMember?> {
  @override
  StaffMember? build() => null;

  void become(StaffMember? member) => state = member;
}

/// Who is at the device, and so what they may do — the one answer every
/// screen offers by and every action is asked of the stores as:
///
/// - the owner, unlocked by the owner's PIN: everything;
/// - a member of staff, signed in by their PIN: what the owner gave them,
///   as kept now — a capability taken away is gone at once;
/// - nobody signed in: the standard set while the workshop has no staff
///   accounts, as the device always allowed; only looking once it has.
///
/// While the staff are still being read, nobody signed in may only look —
/// never more than the device turns out to allow.
final actorProvider = Provider<Authority>((ref) {
  if (ref.watch(workshopRoleProvider) == WorkshopRole.owner) {
    return WorkshopRole.owner;
  }
  final members = ref.watch(staffMembersProvider).value;
  final member = ref.watch(signedInStaffProvider);
  if (member != null) {
    return members?.where((m) => m.id == member.id).firstOrNull ?? member;
  }
  if (members == null) return const NobodySignedIn();
  return members.any((m) => m.active)
      ? const NobodySignedIn()
      : WorkshopRole.staff;
});

/// Signing in and out, and who is at the device right now.
extension Signing on WidgetRef {
  /// Who is at the device, once the staff have been read — what an action
  /// hands the store it writes to.
  Future<Authority> actorNow() async {
    await read(staffMembersProvider.future);
    return read(actorProvider);
  }

  /// The owner, by the owner's PIN already checked.
  void signInAsOwner() {
    read(signedInStaffProvider.notifier).become(null);
    read(workshopRoleProvider.notifier).become(WorkshopRole.owner);
  }

  /// [member], by their PIN already checked.
  void signInAs(StaffMember member) {
    read(workshopRoleProvider.notifier).become(WorkshopRole.staff);
    read(signedInStaffProvider.notifier).become(member);
  }

  /// Nobody.
  void signOut() {
    read(signedInStaffProvider.notifier).become(null);
    read(workshopRoleProvider.notifier).become(WorkshopRole.staff);
  }

  /// The staff list read again.
  void staffChanged() => read(staffRevisionProvider.notifier).changed();
}

/// Who is at the device, for what is not a widget — a controller, a
/// provider.
extension ActorOfRef on Ref {
  /// Who is at the device, once the staff have been read.
  Future<Authority> actorNow() async {
    await read(staffMembersProvider.future);
    return read(actorProvider);
  }

  /// Who is at the device where that is known now — the owner, somebody
  /// signed in, or nobody once the staff have been read — and null while
  /// it is still being read. A check that has to answer at once refuses
  /// only what it knows is not allowed; whatever is then kept is asked of
  /// the store by [actorNow], which waits.
  Authority? actorKnown() {
    if (read(workshopRoleProvider) == WorkshopRole.owner) {
      return WorkshopRole.owner;
    }
    if (read(signedInStaffProvider) != null) return read(actorProvider);
    return read(staffMembersProvider).hasValue ? read(actorProvider) : null;
  }
}

/// What a screen offers.
extension Offering on WidgetRef {
  /// Whether to offer what needs [capability]: what the person at the
  /// device may do, **once that is known**.
  ///
  /// While the staff are still being read — the first moments of a run —
  /// nothing that needs a permission is offered: an unknown permission is
  /// never treated as one granted, so a control is shown disabled until it
  /// is known, and then offered or not. The store it is done through asks
  /// again either way (`actorNow`).
  bool offers(Capability capability) =>
      permissionsKnown && watch(actorProvider).can(capability);

  /// Whether who is at the device, and so what they may do, is known yet.
  bool get permissionsKnown {
    if (watch(workshopRoleProvider) == WorkshopRole.owner) return true;
    if (watch(signedInStaffProvider) != null) return true;
    final staff = watch(staffMembersProvider);
    // A staff list that could not be read is known, as nobody signed in.
    return staff.hasValue || staff.hasError;
  }
}

/// A thin bar under a screen's heading while who is at the device — and so
/// what may be done — is still being worked out; nothing at all once it is.
class PermissionsLoading extends ConsumerWidget implements PreferredSizeWidget {
  const PermissionsLoading({super.key});

  static const barKey = ValueKey('permissions-loading');

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.permissionsKnown
      ? const SizedBox(height: 2)
      : const LinearProgressIndicator(key: barKey, minHeight: 2);
}

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

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/accounts/accounts.dart';
import '../../domain/model/design.dart';
import '../../infrastructure/cloud/backend.dart';
import '../../infrastructure/cloud/device_data.dart';
import '../../infrastructure/cloud/owner_sync.dart';
import '../../infrastructure/cloud/supabase_backend.dart';
import 'workspace.dart';

/// The backend this build was given, or null — the application then runs
/// on its own, on one device, exactly as before there were accounts.
final backendProvider = Provider<Backend?>((ref) {
  final config = BackendConfig.fromBuild;
  return config == null ? null : SupabaseBackend(config);
});

/// Whether there are accounts: a backend to sign in to.
final cloudModeProvider = Provider<bool>(
  (ref) => ref.watch(backendProvider) != null,
);

/// The account signed in, as the backend has it — or null. Loading while
/// a session kept on the device is being restored.
final sessionProvider = AsyncNotifierProvider<Session, Account?>(Session.new);

/// The owner's records on the backend, kept in step with the device while
/// an owner is signed in — set by [Session], and null for anybody else.
final ownerSyncProvider = NotifierProvider<OwnerSyncHolder, OwnerSync?>(
  OwnerSyncHolder.new,
);

class OwnerSyncHolder extends Notifier<OwnerSync?> {
  @override
  OwnerSync? build() => null;

  void hold(OwnerSync? sync) {
    state?.stop();
    state = sync;
  }
}

/// What an owner signing in on a device holding records from before
/// accounts must decide: bring them into the factory, or keep them aside.
final unclaimedDataProvider = NotifierProvider<Flag, bool>(Flag.new);

/// A password-reset link was opened: a new password is asked first.
final recoveryProvider = NotifierProvider<Flag, bool>(Flag.new);

class Flag extends Notifier<bool> {
  @override
  bool build() => false;
  // A plain setter keeps the call sites short: `notifier.on = true`.
  // ignore: avoid_setters_without_getters
  set on(bool value) => state = value;
}

/// Changes whenever something the backend holds was changed from here —
/// a request decided, a worker invited — so what lists it reads again.
final cloudRevisionProvider = NotifierProvider<DesignsRevision, int>(
  DesignsRevision.new,
);

/// Signing in, out and up, and who is signed in.
class Session extends AsyncNotifier<Account?> {
  Backend? get _backend => ref.read(backendProvider);

  @override
  Future<Account?> build() async {
    final backend = ref.watch(backendProvider);
    if (backend == null) return null;
    // A session that ends by itself — expired, revoked — is no session: the
    // gate goes back to signing in, and nothing of the factory is shown.
    // The device's cache is kept for the same account to send on; another
    // account signing in clears it (`_prepare`).
    backend.onSessionEnded = () {
      if (state.value == null) return;
      ref.read(ownerSyncProvider.notifier).hold(null);
      state = const AsyncData(null);
    };
    try {
      final link = await backend.fromLink(Uri.base);
      if (link?.recovery ?? false) {
        ref.read(recoveryProvider.notifier).on = true;
      }
    } on Object catch (e) {
      debugPrint('ProFrame: the link could not be read: $e');
    }
    final token = await backend.restore();
    if (token == null) return null;
    final account = await backend.myAccount();
    if (account == null || !account.isActive) return account;
    await _prepare(account);
    return account;
  }

  /// Signs in with [email] and [password]. Throws [BackendError] —
  /// including `suspended`, after which nothing is signed in.
  Future<void> signIn(String email, String password) async {
    final backend = _backend!;
    await backend.signIn(email: email, password: password);
    final account = await backend.myAccount();
    if (account == null || !account.isActive) {
      await backend.signOut();
      throw BackendError(account == null ? 'no_account' : 'suspended');
    }
    await _prepare(account);
    state = AsyncData(account);
  }

  /// After a sign-up that needed no confirmation, or a reset link: whoever
  /// the session now is.
  Future<void> adopt() async {
    final account = await _backend!.myAccount();
    if (account == null || !account.isActive) {
      await _backend!.signOut();
      throw BackendError(account == null ? 'no_account' : 'suspended');
    }
    await _prepare(account);
    state = AsyncData(account);
  }

  /// The device made ready for [account]: another account's cache cleared;
  /// records from before accounts moved aside for a worker, and left for
  /// the owner to decide; an owner's records brought down.
  Future<void> _prepare(Account account) async {
    final cacheOf = await DeviceData.cacheOf();
    if (cacheOf != null && cacheOf != account.userId) {
      await DeviceData.clearCache();
    }
    if (await DeviceData.hasUnclaimed()) {
      if (!account.isOwner) {
        await DeviceData.archive();
      } else {
        ref.read(unclaimedDataProvider.notifier).on = true;
        return;
      }
    }
    if (account.isOwner) {
      await DeviceData.claimFor(account.userId);
      await _startSync(account);
    }
  }

  Future<void> _startSync(Account account) async {
    final backend = _backend;
    if (backend == null) return;
    final sync = OwnerSync(
      backend,
      onPulled: () {
        ref.read(designsRevisionProvider.notifier).changed();
        ref.read(customersRevisionProvider.notifier).changed();
      },
    );
    ref.read(ownerSyncProvider.notifier).hold(sync);
    sync.start();
    try {
      await sync.pull();
    } on BackendError catch (e) {
      debugPrint('ProFrame: bringing the factory down failed: ${e.code}');
    }
  }

  /// The owner's answer about records from before accounts: brought into
  /// the factory (sent to the backend as theirs), or moved aside.
  Future<void> settleUnclaimed({required bool bringIn}) async {
    final account = state.value;
    if (account == null || !account.isOwner) return;
    if (!bringIn) await DeviceData.archive();
    await DeviceData.claimFor(account.userId);
    ref.read(unclaimedDataProvider.notifier).on = false;
    await _startSync(account);
    ref.read(designsRevisionProvider.notifier).changed();
    ref.read(customersRevisionProvider.notifier).changed();
  }

  /// Signs out: an owner's last changes sent first, then the session ended
  /// and everything cached for it cleared from the device.
  Future<void> signOut() async {
    final backend = _backend;
    if (backend == null) return;
    final sync = ref.read(ownerSyncProvider);
    if (sync != null) {
      try {
        await sync.push();
      } on Object catch (e) {
        debugPrint('ProFrame: the last changes could not be sent: $e');
      }
      ref.read(ownerSyncProvider.notifier).hold(null);
    }
    await backend.signOut();
    await DeviceData.clearCache();
    ref.read(unclaimedDataProvider.notifier).on = false;
    ref.read(recoveryProvider.notifier).on = false;
    state = const AsyncData(null);
    ref.read(designsRevisionProvider.notifier).changed();
    ref.read(customersRevisionProvider.notifier).changed();
  }
}

/// What the screens read from the backend, each read again when
/// [cloudRevisionProvider] changes.
final workersProvider = FutureProvider<List<Worker>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.workers();
});

final invitationsProvider = FutureProvider<List<Invitation>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.openInvitations();
});

final assignmentsProvider = FutureProvider<List<Assignment>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.assignments();
});

final requestsProvider = FutureProvider<List<WorkRequest>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.requests();
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.notifications();
});

final accountNamesProvider = FutureProvider<Map<String, String>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.accountNames();
});

final myDesignsProvider = FutureProvider<List<AssignedDesign>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.myDesigns();
});

final myCustomersProvider = FutureProvider<List<ScopedCustomer>>((ref) {
  ref.watch(cloudRevisionProvider);
  return ref.watch(backendProvider)!.myCustomers();
});

/// How many requests wait on the owner.
final pendingCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(requestsProvider)
          .value
          ?.where((r) => r.status == RequestStatus.pending)
          .length ??
      0,
);

/// A worker proposing a change to the design open: which design, at which
/// revision, and whether they have begun changing it. Null for anybody
/// else. The design on the backend is not touched until the owner approves.
final proposalProvider = NotifierProvider<ProposalNotifier, Proposal?>(
  ProposalNotifier.new,
);

class Proposal {
  final String designId;
  final int revision;
  final bool active;

  /// The design as the backend gave it, to go back to on discarding.
  final Design? original;

  const Proposal(
    this.designId,
    this.revision, {
    this.active = false,
    this.original,
  });
}

class ProposalNotifier extends Notifier<Proposal?> {
  @override
  Proposal? build() => null;

  /// A worker has [designId] open, as it is at [revision].
  void viewing(String designId, int revision, {Design? original}) =>
      state = Proposal(designId, revision, original: original);

  /// Changing it begins: in the workspace, never on the backend.
  void begin() {
    final p = state;
    if (p != null) {
      state = Proposal(
        p.designId,
        p.revision,
        active: true,
        original: p.original,
      );
    }
  }

  /// Back to looking: the changes are put away.
  void discard() {
    final p = state;
    if (p != null) {
      state = Proposal(p.designId, p.revision, original: p.original);
    }
  }

  void end() => state = null;
}

/// A new key for a request, so the same submission sent twice is one
/// request.
String newClientKey() {
  final r = Random.secure();
  String hex(int n) =>
      [for (var i = 0; i < n; i++) r.nextInt(16).toRadixString(16)].join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${'89ab'[r.nextInt(4)]}${hex(3)}-${hex(12)}';
}

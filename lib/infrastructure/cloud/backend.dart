import '../../domain/accounts/accounts.dart';
import '../../domain/text/refusal.dart';
import '../../domain/text/words.dart';

/// What the application asks of the backend that keeps the accounts and
/// the factory's records — the one place it talks to it.
///
/// Every method is a request; the backend decides. A method an account may
/// not call is refused there ([BackendError] `not_owner`, `not_assigned`,
/// …), whatever the application shows or hides. `SupabaseBackend` is the
/// real one; the tests have one in memory with the same contract.
abstract interface class Backend {
  // ------------------------------------------------------------- sessions

  /// The session kept on the device, refreshed — or null.
  Future<String?> restore();

  /// A session from a link the provider sent (a confirmed address, or a
  /// password reset), where [link] carries one.
  Future<LinkSession?> fromLink(Uri link);

  Future<void> signIn({required String email, required String password});

  /// A new owner, with a factory of their own. True where the address has
  /// to be confirmed before signing in.
  Future<bool> signUpOwner({
    required String name,
    required String factoryName,
    required String email,
    required String password,
  });

  /// A worker joining by an owner's invitation. True where the address has
  /// to be confirmed before signing in.
  Future<bool> joinAsWorker({
    required String name,
    required String email,
    required String password,
    required String code,
  });

  /// Asks the provider to send [email] a link to set a new password.
  Future<void> recover(String email);

  /// Sets a new password for the session in hand (one from a reset link).
  Future<void> setPassword(String password);

  Future<void> signOut();

  /// Who the session is, from the backend's own records.
  Future<Account?> myAccount();

  /// Called when the session ends without signing out — it expired, or was
  /// revoked — so the application goes back to signing in rather than
  /// showing what it can no longer read.
  set onSessionEnded(void Function()? ended);

  // -------------------------------------------------------------- owner

  Future<List<Worker>> workers();
  Future<List<Invitation>> openInvitations();
  Future<InvitationCode> invite({required String name, required String email});
  Future<void> revokeInvitation(String id);
  Future<void> setWorkerActive(String workerId, {required bool active});
  Future<List<Assignment>> assignments();
  Future<void> assign(String designId, String workerId);
  Future<void> unassign(String designId, String workerId);

  /// Every request of the factory, newest first (owner); a worker's own
  /// (labour).
  Future<List<WorkRequest>> requests();

  /// The design a change request was drawn from.
  Future<Map<String, Object?>?> requestBase(String requestId);

  Future<({String designId, String customerId})> approveNewDesign(
    String requestId, {
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  });

  Future<({String designId, String customerId})> approveNewCustomer(
    String requestId, {
    required Map<String, Object?> customer,
    required Map<String, Object?> design,
    required bool assign,
    required String note,
  });

  Future<({int revision, Map<String, Object?> data})> approveChange(
    String requestId, {
    required String note,
  });

  Future<void> reject(String requestId, {required String note});

  /// Every record of the owner's factory.
  Future<FactoryRecords> records();

  Future<int> putCustomer(String id, String json, int? expected);
  Future<int> putDesign(String id, String json, int? expected);
  Future<void> deleteDesign(String id);
  Future<void> deleteCustomer(String id);
  Future<int> putDocument(String key, String value, int? expected);
  Future<void> deleteDocument(String key);

  // ------------------------------------------------------------- labour

  Future<List<AssignedDesign>> myDesigns();
  Future<AssignedDesign> assignedDesign(String id);
  Future<List<ScopedCustomer>> myCustomers();

  Future<String> requestNewDesign({
    required String customerId,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  });

  Future<String> requestNewCustomer({
    required Map<String, Object?> customer,
    required String name,
    required String category,
    required String description,
    required String clientKey,
  });

  Future<String> requestChange({
    required String designId,
    required int baseRevision,
    required Map<String, Object?> proposed,
    required String description,
    required String clientKey,
  });

  Future<void> cancelRequest(String id);

  // --------------------------------------------------------------- both

  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);

  /// The names of the accounts of the factory the caller may see — every
  /// one for an owner, their own for labour — by user id.
  Future<Map<String, String>> accountNames();
}

/// A session a link opened.
class LinkSession {
  /// True for a password-reset link: a new password is asked before
  /// anything else.
  final bool recovery;
  const LinkSession({required this.recovery});
}

/// One record of the factory, with its revision.
class Kept {
  final String value;
  final int revision;
  const Kept(this.value, this.revision);
}

class FactoryRecords {
  final Map<String, Kept> customers;
  final Map<String, Kept> designs;
  final Map<String, Kept> documents;

  const FactoryRecords({
    required this.customers,
    required this.designs,
    required this.documents,
  });
}

/// What the backend refused, by its own code — `worker_limit`,
/// `not_assigned`, `conflict`, … — or a sign-in failure, or the network.
class BackendError extends Refusal {
  final String code;

  BackendError(this.code) : super((w) => backendMessageIn(code, w));

  @override
  String toString() => 'BackendError($code)';
}

/// What [code] means, in [w].
String backendMessageIn(String code, Words w) => switch (code) {
  'invalid_credentials' => w.authInvalidCredentials,
  'email_not_confirmed' => w.authEmailNotConfirmed,
  'user_already_exists' => w.authEmailTaken,
  'email_taken' => w.authEmailTaken,
  'weak_password' => w.authWeakPassword,
  'invite_invalid' => w.authInviteInvalid,
  'name_required' => w.authNameRequired,
  'email_invalid' => w.authEmailInvalid,
  'suspended' => w.authSuspended,
  'no_account' => w.authNoAccount,
  'not_signed_in' => w.authNotSignedIn,
  'not_owner' => w.backendNotOwner,
  'not_labour' => w.backendNotOwner,
  'worker_limit' => w.workersLimit,
  'already_invited' => w.workersAlreadyInvited,
  'not_assigned' => w.backendNotAssigned,
  'customer_out_of_scope' => w.backendNotAssigned,
  'conflict' => w.requestConflict,
  'already_decided' => w.requestAlreadyDecided,
  'not_pending' => w.requestAlreadyDecided,
  'self_approval' => w.backendNotOwner,
  'customer_missing' => w.backendCustomerMissing,
  'customer_has_designs' => w.backendCustomerHasDesigns,
  'rate_limited' => w.authRateLimited,
  'network' => w.backendNetwork,
  _ => w.backendFailed,
};

/// The device did not keep what it was given.
///
/// Thrown where a store's write comes back refused, so a screen can say the
/// change was not kept rather than say it was. What was on the device
/// before is still there.
class KeepFailed implements Exception {
  /// Which record was not kept — for a log, never for the user.
  final String key;

  const KeepFailed(this.key);

  @override
  String toString() => 'KeepFailed: $key was not written';
}

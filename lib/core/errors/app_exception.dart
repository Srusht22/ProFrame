/// Base class for errors this app raises deliberately, so the UI can show a
/// useful message instead of a stack trace.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => 'AppException: $message';
}

/// The sketch could not be turned into a product — usually because there is
/// no closed outline yet.
class InterpretationException extends AppException {
  const InterpretationException(super.message, {super.cause});
}

/// Reading or writing local storage failed.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// Export or share failed.
class ExportException extends AppException {
  const ExportException(super.message, {super.cause});
}

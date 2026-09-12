/// Base class for every error this application raises deliberately.
///
/// Centralising them means the UI can tell a problem it is expected to explain
/// to the user from a genuine bug, and show the first as plain language rather
/// than a stack trace (spec section 9).
sealed class AppException implements Exception {
  /// A sentence the user can act on. No jargon, no error codes.
  final String message;

  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// A saved project could not be read: wrong shape, missing field, or a schema
/// version this build does not understand.
class DesignDataException extends AppException {
  /// Where in the document the problem is, e.g. `sections[2].behaviour`.
  final String path;

  const DesignDataException(super.message, {this.path = ''});

  @override
  String toString() =>
      path.isEmpty ? 'DesignDataException: $message' : 'DesignDataException at $path: $message';
}

/// The geometry given is not something the app can build from — a boundary
/// that does not close, a divider outside the frame, a section with no area.
class GeometryException extends AppException {
  const GeometryException(super.message);
}

/// The design is structurally fine but cannot be manufactured or measured as
/// specified, e.g. section widths that do not sum to the overall width.
///
/// This is reported to the user and never silently corrected (spec section 2).
class DimensionConflictException extends AppException {
  const DimensionConflictException(super.message);
}

/// Friendly, typed failures surfaced to the UI. Repositories/services never
/// let raw exceptions reach widgets — they catch and map to one of these so
/// every screen can render a consistent error state with a retry action.
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network connection unavailable. Working offline.']);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'The request timed out. Please try again.']);
}

class ServerFailure extends AppFailure {
  final int? statusCode;
  const ServerFailure({this.statusCode, String message = 'Something went wrong on the server.'})
      : super(message);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'The requested item could not be found.']);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Your session has expired. Please sign in again.']);
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.message = "You don't have permission to do that."]);
}

class ValidationFailure extends AppFailure {
  final Map<String, String> fieldErrors;
  const ValidationFailure(this.fieldErrors, [String message = 'Please check the highlighted fields.'])
      : super(message);
}

class CacheFailure extends AppFailure {
  const CacheFailure([super.message = 'Could not read local data.']);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}

/// A minimal, dependency-free Result type (avoids pulling in a functional
/// package purely for Either). Every repository method returns this instead
/// of throwing, so failure handling is explicit at every call site.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) {
    return switch (this) {
      Ok<T>(:final value) => ok(value),
      Err<T>(:final failure) => err(failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppFailure failure;
  const Err(this.failure);
}

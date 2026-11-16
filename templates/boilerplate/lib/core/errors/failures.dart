/// What can go wrong, as the presentation layer sees it (F5).
///
/// Branch on the type, or on [code] (the backend's error code), never on a message: a message may change without
/// notice. The text the user reads comes from the catalog (core/l10n/failure_messages.dart), never from here. A
/// feature's own failures extend one of these classes in `<feature>_failures.dart`. The class is sealed, so a
/// `switch` over a Failure must name every kind, and the compiler finds the one a new screen forgot.
sealed class Failure {
  const Failure({this.code});

  /// The backend's error code, such as `orders_disabled`, when it sent one.
  final String? code;

  @override
  String toString() => '$runtimeType(${code ?? '-'})';
}

/// No connection, or it dropped mid-call.
class NetworkFailure extends Failure {
  const NetworkFailure({super.code});
}

/// The server did not answer in time, or a call ran past its total time budget.
class TimeoutFailure extends Failure {
  const TimeoutFailure({super.code});
}

/// 401 after the one refresh attempt: the session is over.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.code});
}

/// 403: signed in, but not allowed.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.code});
}

/// 404: the thing is gone or never existed.
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.code});
}

/// 409: the server holds a newer version, or a duplicate.
class ConflictFailure extends Failure {
  const ConflictFailure({super.code});
}

/// 400 or 422 from the server, or a payload the app cannot read (a missing required field).
class ValidationFailure extends Failure {
  const ValidationFailure({super.code});
}

/// 429: too many calls; try again later.
class RateLimitFailure extends Failure {
  const RateLimitFailure({super.code});
}

/// 5xx: the server failed.
class ServerFailure extends Failure {
  const ServerFailure({super.code});
}

/// Anything else. Logged in debug builds; shown as a generic message.
class UnknownFailure extends Failure {
  const UnknownFailure({super.code});
}

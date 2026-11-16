import 'package:kit_app/core/errors/failures.dart';
import 'package:kit_app/core/l10n/generated/app_localizations.dart';

/// The user's text for each core kind of failure (F5, F11), in one place. The switch covers the sealed Failure,
/// so a new kind does not compile until it has its text. A controller checks its feature's own failures first.
extension FailureMessages on AppLocalizations {
  String failureMessage(Failure failure) {
    return switch (failure) {
      NetworkFailure() => commonErrorNetwork,
      TimeoutFailure() => commonErrorTimeout,
      UnauthorizedFailure() => commonErrorUnauthorized,
      ForbiddenFailure() => commonErrorForbidden,
      NotFoundFailure() => commonErrorNotFound,
      ConflictFailure() => commonErrorConflict,
      ValidationFailure() => commonErrorValidation,
      RateLimitFailure() => commonErrorRateLimit,
      ServerFailure() => commonErrorServer,
      UnknownFailure() => commonErrorUnknown,
    };
  }
}

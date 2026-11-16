import 'package:kit_app/core/errors/failures.dart';

/// What every repository returns (F5): a value or a typed failure. Never a throw to the presentation layer, never a
/// null that means "it failed". Sealed, so a `switch` must handle both.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;
}

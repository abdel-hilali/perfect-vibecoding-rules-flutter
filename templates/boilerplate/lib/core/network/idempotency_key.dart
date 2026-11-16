import 'package:kit_app/core/common/data/random_id.dart';

/// The key that makes a create safe to retry (F6): the server keeps the first answer for a key and returns it
/// again, so a retry after a lost answer never creates a second order.
abstract final class IdempotencyKey {
  static const header = 'Idempotency-Key';

  static String generate() => randomId();
}

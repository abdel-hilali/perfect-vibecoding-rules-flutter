import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/core/storage/session.dart';
import 'package:kit_app/core/storage/session_tokens.dart';

import '../../fakes/fake_secure_store.dart';

void main() {
  // Regression: one sign-out hook that threw once skipped every later hook, so their data stayed on screen,
  // and the error reached the 401 handler, whose call then never ended.
  test('a sign-out hook that fails does not stop the others', () async {
    final session = Session(FakeSecureStore());
    await session.signIn(SessionTokens.fakeAccount);
    var cleared = false;
    session
      ..addSignOutHook(() async => throw const FormatException('cache'))
      ..addSignOutHook(() async => cleared = true);
    await session.signOut();
    expect(cleared, isTrue);
    expect(session.isSignedIn, isFalse);
  });
}

import 'package:flutter/foundation.dart';
import 'package:kit_app/core/storage/secure_store.dart';
import 'package:kit_app/core/storage/session_tokens.dart';

/// Who is signed in (F14), shared by the whole app.
///
/// The router listens to it (refreshListenable), so signing out sends every screen to the sign-in gate at once.
/// The ApiClient reads its tokens. Sign-out runs every registered hook, so app-wide controllers clear their data.
class Session extends ChangeNotifier {
  Session(this._store);

  final SecureStore _store;
  final List<Future<void> Function()> _signOutHooks = [];
  SessionTokens? _tokens;
  bool _disposed = false;

  static const _storageKey = 'session.tokens';

  bool get isSignedIn => _tokens != null;

  String? get accessToken => _tokens?.accessToken;

  String? get refreshToken => _tokens?.refreshToken;

  /// Reads the saved session once at start. A broken keystore reads as signed out (SecureStore never throws).
  Future<void> restore() async {
    _tokens = SessionTokens.decode(await _store.read(_storageKey));
    _notify();
  }

  /// Also used after a token refresh, with the new pair.
  Future<void> signIn(SessionTokens tokens) async {
    _tokens = tokens;
    // Notify before the write: when the keystore refuses it, the user is still signed in for this run.
    _notify();
    await _store.write(_storageKey, tokens.encode());
  }

  void addSignOutHook(Future<void> Function() hook) => _signOutHooks.add(hook);

  Future<void> signOut() async {
    // Several calls can fail with 401 together; the first one signs out, the others find nothing to do.
    if (_tokens == null) {
      return;
    }
    _tokens = null;
    _notify();
    await _store.delete(_storageKey);
    for (final hook in List.of(_signOutHooks)) {
      // Each hook on its own: one that fails must not leave another feature's data on screen, nor reach the 401
      // handler that called this.
      try {
        await hook();
      } on Exception catch (e) {
        if (kDebugMode) {
          debugPrint('A sign-out hook failed: ${e.runtimeType}');
        }
      }
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

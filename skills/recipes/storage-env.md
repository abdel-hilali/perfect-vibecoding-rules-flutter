# Recipe: environment, secrets, storage and the session

## Problem

A missing config value shows up as a `null` deep in a screen, days later. A secret put in `assets/.env` ships to
every phone as plain text. A broken keystore (a backup restored to a new phone, a changed lock screen) makes the
secure storage plugin throw at every start, and the app crashes before its first frame.

## Rule

- `assets/.env` (flutter_dotenv) holds public values only: the API base URL, a publishable key. Everything in the
  app is readable by anyone who has the APK or IPA. Secrets live on the server or in CI (F13).
- `assets/.env` is git-ignored; `assets/.env.example` is committed with every key. `--dart-define` overrides a key.
- `lib/core/config/env.dart` is the typed `Env`: read once in `main()`; a missing or bad required key stops the app
  at start with the key's name.
- The session lives in secure storage through ONE `SecureStore` that never throws; plain settings live in
  shared_preferences through ONE wrapper (`AppPreferences`) (F14).
- Sign-out runs every registered hook: controllers clear their data, caches empty, timers stop.

## Code

```bash
# assets/.env.example
# The REST backend, HTTPS only.
API_BASE_URL=https://api.example.com
# Sent as X-App-Version on every call: the whole version of pubspec.yaml (x.y.z+build), the form q-build.sh passes
# with --dart-define.
APP_VERSION=1.0.0+1
```

```yaml
# pubspec.yaml (from the starter's pubspec.fragment.yaml)
  assets:
    # Created from assets/.env.example and git-ignored: public values only, the APK ships it as plain text.
    - assets/.env
```

```dart
// lib/core/config/env.dart
    String read(String key) {
      final defined = defines[key] ?? '';
      final value = defined.isNotEmpty ? defined : (file[key] ?? '').trim();
      if (value.isEmpty) {
        throw StateError(
          '$key is missing: add it to $assetPath (see assets/.env.example) or pass --dart-define=$key=...',
        );
      }
      return value;
    }
  // ...
  // String.fromEnvironment needs a constant name, so each key is listed once here.
  static const Map<String, String> _defines = {
    'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
    'APP_VERSION': String.fromEnvironment('APP_VERSION'),
  };
```

`Env.fromValues(file, defines: ...)` is pure, so `test/core/config/env_test.dart` checks the rules without the
asset bundle. A new key is a field, a `read('KEY')` line, a `_defines` entry and a line in `.env.example`.

```dart
// lib/core/storage/secure_store.dart
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception catch (e) {
      _log('read', key, e);
      return null;
    }
  }
```

```dart
// lib/core/storage/session.dart
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
```

```dart
// lib/core/storage/session_tokens.dart
  // The tokens never reach a log, even by accident.
  @override
  String toString() => 'SessionTokens(hidden)';
```

## Traps

- The build fails while `assets/.env` is missing, because `pubspec.yaml` declares it: `cp assets/.env.example
  assets/.env` on every new checkout and in CI.
- A `--dart-define` value is compiled into the app as well: public values only there too.
- `String.fromEnvironment` needs a constant name: one `_defines` entry per key, never a loop over key names.
- `SecureStore` logs the key and the error type only, never the value: it may be a token.
- `SharedPreferences.setMockInitialValues` fakes the old API only. Code on `SharedPreferencesAsync` (as
  `AppPreferences`) needs `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()` from
  `shared_preferences_platform_interface` (a dev dependency), or a fake of the wrapper itself.
- `Session.signIn` notifies before the write: when the keystore refuses the value, the user stays signed in for
  this run instead of being thrown out.
- Never store as truth what the server owns: a cache shows, the server decides (F14).

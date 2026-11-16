import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kit_app/core/config/env.dart';
import 'package:kit_app/core/network/api_client.dart';
import 'package:kit_app/core/network/token_refresher.dart';
import 'package:kit_app/core/storage/app_preferences.dart';
import 'package:kit_app/core/storage/secure_store.dart';
import 'package:kit_app/core/storage/session.dart';
import 'package:kit_app/core/storage/session_tokens.dart';

/// The app-wide objects every feature shares (F4): the session and the one ApiClient. Built on first use,
/// once; tests never reach in here, they build what they need by hand with fakes.
class SessionModule {
  SessionModule._();

  static final SessionModule instance = SessionModule._();

  /// true while the app has no sign-in: a fresh install starts signed in with a local, fake account, so every
  /// screen opens without a backend. The backend accepts none of its tokens. Set it to false when the auth
  /// feature lands: a fresh install then starts at the sign-in page.
  static const bool useFakeAccount = true;

  late final SecureStore secureStore = SecureStore();
  late final AppPreferences preferences = AppPreferences();
  late final Session session = Session(secureStore);
  late final TokenRefresher _refresher = TokenRefresher(session);

  // Read once in start(): the client's headers are fixed for the whole run.
  late final String _deviceId;

  late final ApiClient apiClient = ApiClient(
    baseUrl: Env.current.apiBaseUrl,
    headers: {
      ApiClient.appVersionHeader: Env.current.appVersion,
      ApiClient.platformHeader: defaultTargetPlatform.name,
      ApiClient.deviceIdHeader: _deviceId,
    },
    readAccessToken: () async => session.accessToken,
    refreshAccessToken: (Dio dio) => _refresher.refresh(dio),
    onUnauthorized: session.signOut,
  );

  /// Runs once in main(), before runApp, so the first frame already knows who is signed in.
  Future<void> start() async {
    _deviceId = await preferences.deviceId();
    await session.restore();
    if (useFakeAccount && !session.isSignedIn) {
      await session.signIn(SessionTokens.fakeAccount);
    }
  }
}

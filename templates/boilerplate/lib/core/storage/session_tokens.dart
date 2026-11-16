import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kit_app/core/common/data/json_fields.dart';

/// The pair of tokens of a signed-in user, as the backend sends them and as SecureStore keeps them.
@immutable
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});

  /// `{"access_token": "...", "refresh_token": "..."}`, the shape of the sign-in and refresh answers.
  factory SessionTokens.fromJson(JsonMap json) {
    return SessionTokens(
      accessToken: stringOf(json, 'access_token'),
      refreshToken: stringOf(json, 'refresh_token'),
    );
  }

  final String accessToken;
  final String refreshToken;

  /// The local account the app uses while it has no sign-in (SessionModule.useFakeAccount). The backend accepts
  /// neither token, so it opens nothing on a real server.
  static const fakeAccount = SessionTokens(
    accessToken: 'fake-access-token',
    refreshToken: 'fake-refresh-token',
  );

  JsonMap toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };

  String encode() => jsonEncode(toJson());

  /// The tokens saved by [encode], or null when nothing readable is saved: a damaged value means signed out.
  static SessionTokens? decode(String? saved) {
    if (saved == null) {
      return null;
    }
    try {
      return SessionTokens.fromJson(asJsonMap(jsonDecode(saved), 'session'));
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Saved session unreadable, starting signed out: ${e.runtimeType}',
        );
      }
      return null;
    }
  }

  // The tokens never reach a log, even by accident.
  @override
  String toString() => 'SessionTokens(hidden)';
}

import 'package:dio/dio.dart';
import 'package:kit_app/core/common/data/json_fields.dart';
import 'package:kit_app/core/storage/session.dart';
import 'package:kit_app/core/storage/session_tokens.dart';

/// Trades the refresh token for a new pair. It is the one caller outside a data source that knows a path: the
/// client needs it before any feature exists.
class TokenRefresher {
  const TokenRefresher(this._session);

  final Session _session;

  /// Under UnauthorizedInterceptor.authPathPrefix, so a 401 here never starts another refresh.
  static const refreshPath = '/auth/refresh';

  /// The new access token, or null when the session cannot go on. Errors are left to the caller, which signs out.
  Future<String?> refresh(Dio dio) async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null) {
      return null;
    }
    final response = await dio.post<Object?>(
      refreshPath,
      data: {'refresh_token': refreshToken},
    );
    final tokens = SessionTokens.fromJson(
      asJsonMap(response.data, 'refresh answer'),
    );
    await _session.signIn(tokens);
    return tokens.accessToken;
  }
}

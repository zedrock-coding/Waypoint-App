// lib/features/auth/domain/auth_link_handler.dart

abstract class ISupabaseAuth {
  String? get currentSessionToken;
  Future<void> setSessionFromToken(String accessToken, String? refreshToken);
}

class MockSupabaseAuth implements ISupabaseAuth {
  String? _sessionToken;

  @override
  String? get currentSessionToken => _sessionToken;

  @override
  Future<void> setSessionFromToken(String accessToken, String? refreshToken) async {
    _sessionToken = accessToken;
  }
}

class AuthLinkResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? accessToken;

  const AuthLinkResult({
    required this.isSuccess,
    this.errorMessage,
    this.accessToken,
  });

  factory AuthLinkResult.success(String token) => AuthLinkResult(
        isSuccess: true,
        accessToken: token,
      );

  factory AuthLinkResult.failure(String message) => AuthLinkResult(
        isSuccess: false,
        errorMessage: message,
      );
}

class AuthLinkHandler {
  final ISupabaseAuth supabaseAuth;

  AuthLinkHandler({required this.supabaseAuth});

  Future<AuthLinkResult> handleIncomingUri(Uri uri) async {
    final Map<String, String> params = {};
    if (uri.hasFragment && uri.fragment.isNotEmpty) {
      final fragmentUri = Uri.parse('?${uri.fragment}');
      params.addAll(fragmentUri.queryParameters);
    }
    params.addAll(uri.queryParameters);

    final error = params['error'];
    final errorDescription = params['error_description'];
    if (error != null || errorDescription != null) {
      final message = errorDescription != null
          ? Uri.decodeComponent(errorDescription.replaceAll('+', ' '))
          : (error ?? 'Authentication error');
      return AuthLinkResult.failure(message);
    }

    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (accessToken != null && accessToken.isNotEmpty) {
      await supabaseAuth.setSessionFromToken(accessToken, refreshToken);
      return AuthLinkResult.success(accessToken);
    }

    return AuthLinkResult.failure('No access token found in callback URL.');
  }
}


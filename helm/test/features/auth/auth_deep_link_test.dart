// test/features/auth/auth_deep_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/auth/domain/auth_link_handler.dart';

void main() {
  group('Auth Deep Link Routing Tests', () {
    late MockSupabaseAuth mockAuth;
    late AuthLinkHandler linkHandler;

    setUp(() {
      mockAuth = MockSupabaseAuth();
      linkHandler = AuthLinkHandler(supabaseAuth: mockAuth);
    });

    test('Valid callback URL parses token and completes session', () async {
      final uri = Uri.parse('waypoint://auth-callback#access_token=valid_token&refresh_token=valid_refresh&type=signup');
      final result = await linkHandler.handleIncomingUri(uri);

      expect(result.isSuccess, true);
      expect(mockAuth.currentSessionToken, 'valid_token');
    });

    test('Corrupted or expired link returns explicit failure and triggers alert state', () async {
      final uri = Uri.parse('waypoint://auth-callback#error=access_denied&error_description=Token+expired');
      final result = await linkHandler.handleIncomingUri(uri);

      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('Token expired'));
      expect(mockAuth.currentSessionToken, null);
    });
  });
}


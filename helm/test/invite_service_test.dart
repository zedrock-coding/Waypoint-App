import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/invite_service.dart';

void main() {
  group('InviteService URI parsing tests', () {
    test('extracts communityId from waypoint custom scheme', () {
      final uri = Uri.parse('waypoint://invite?communityId=comm-123');
      expect(InviteService.extractCommunityId(uri), 'comm-123');
    });

    test('extracts communityId from helm legacy scheme', () {
      final uri = Uri.parse('helm://invite?communityId=comm-legacy');
      expect(InviteService.extractCommunityId(uri), 'comm-legacy');
    });

    test('extracts communityId from web URL query parameters', () {
      final uri = Uri.parse('https://helm-omega-blue.vercel.app/?communityId=comm-web');
      expect(InviteService.extractCommunityId(uri), 'comm-web');
    });

    test('extracts communityId from path segments', () {
      final uri = Uri.parse('https://helm-omega-blue.vercel.app/invite/comm-path');
      expect(InviteService.extractCommunityId(uri), 'comm-path');
    });

    test('returns null for unrelated URLs', () {
      final uri = Uri.parse('https://helm-omega-blue.vercel.app/dashboard');
      expect(InviteService.extractCommunityId(uri), isNull);
    });

    test('manages pendingCommunityId state', () {
      final service = InviteService();
      service.pendingCommunityId = 'comm-pending';
      expect(service.pendingCommunityId, 'comm-pending');
      service.pendingCommunityId = null;
      expect(service.pendingCommunityId, isNull);
    });
  });
}


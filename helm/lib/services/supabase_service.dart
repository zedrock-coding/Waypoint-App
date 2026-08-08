import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  /// Fetch all communities the current logged-in user is a member of.
  Future<List<Map<String, dynamic>>> fetchUserCommunities() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      return await _fetchCommunitiesWithRetry();
    } catch (e) {
      debugPrint('Error fetching communities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCommunitiesWithRetry({int retries = 2}) async {
    try {
      final response = await client
          .from('communities')
          .select('*, community_members!inner(role)');
      return response;
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST303' && retries > 0) {
        debugPrint('Supabase: Clock skew detected (PGRST303). Retrying in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
        return _fetchCommunitiesWithRetry(retries: retries - 1);
      }
      rethrow;
    }
  }

  /// Create a new community. 
  /// Note: The 'admin' role assignment is handled automatically by the DB trigger.
  Future<void> createCommunity(String name) async {
    try {
      await client.from('communities').insert({
        'name': name,
      });
    } catch (e) {
      debugPrint('Error creating community: $e');
      rethrow;
    }
  }

  /// Fetch all members of a specific community.
  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    try {
      // Note: We'd typically join with a profiles table here to get names/avatars.
      // For now, we return the IDs and roles.
      return await client
          .from('community_members')
          .select('*')
          .eq('community_id', communityId);
    } catch (e) {
      debugPrint('Error fetching members: $e');
      return [];
    }
  }

  /// Join a community via invite ID.
  Future<void> joinCommunity(String communityId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Auth Required: Please log in to join.');

    try {
      // Check if already a member
      final existing = await client
          .from('community_members')
          .select()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('User is already a member of this community.');
        return;
      }

      // Add to community as 'member'
      await client.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      debugPrint('Failed to join community: $e');
      rethrow;
    }
  }

  /// Update a member's role (Admins only).
  Future<void> updateMemberRole(String communityId, String targetUserId, String newRole) async {
    try {
      await client
          .from('community_members')
          .update({'role': newRole})
          .eq('community_id', communityId)
          .eq('user_id', targetUserId);
    } catch (e) {
      debugPrint('Error updating member role: $e');
      rethrow;
    }
  }

  /// Remove a member from a community (Admins only).
  Future<void> removeMember(String communityId, String targetUserId) async {
    try {
      await client
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', targetUserId);
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await client.auth.signOut();
  }
}

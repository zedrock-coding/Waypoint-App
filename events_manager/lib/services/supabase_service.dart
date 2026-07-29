import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  /// Fetch all communities the current logged-in user is a member of.
  /// Uses a join with community_members to filter results.
  Future<List<Map<String, dynamic>>> fetchUserCommunities() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('communities')
          .select('*, community_members!inner(role)')
          .eq('community_members.user_id', userId);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Error fetching communities: $e');
      return [];
    }
  }

  /// Add a new user to a community with a 'member' role.
  /// Note: Admin check is handled on the server via RLS, 
  /// but we could add a client-side check if needed.
  Future<void> addUserToCommunity(String communityId, String userId) async {
    try {
      await client.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      print('Error adding user to community: $e');
      rethrow;
    }
  }

  /// Demote an 'admin' to a 'member'.
  /// Checks if the current user is an admin before attempting the update.
  Future<void> demoteAdminToMember(String communityId, String targetUserId) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      // 1. Client-side check for Admin role in this community
      final currentMemberResponse = await client
          .from('community_members')
          .select('role')
          .eq('community_id', communityId)
          .eq('user_id', currentUserId)
          .single();

      if (currentMemberResponse['role'] != 'admin') {
        throw Exception('Access Denied: Only admins can demote members.');
      }

      // 2. Perform the demotion
      await client
          .from('community_members')
          .update({'role': 'member'})
          .eq('community_id', communityId)
          .eq('user_id', targetUserId);
          
    } catch (e) {
      print('Error demoting member: $e');
      rethrow;
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
        print('User is already a member of this community.');
        return;
      }

      // Add to community
      await client.from('community_members').insert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      print('Failed to join community: $e');
      rethrow;
    }
  }
}

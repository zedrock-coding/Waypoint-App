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

  /// Fetch all members of a specific community, including their full names and avatars.
  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    try {
      final response = await client.rpc('get_community_member_names', params: {
        'p_community_id': communityId,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching members with names: $e. Falling back to IDs.');
      return await client
          .from('community_members')
          .select('*')
          .eq('community_id', communityId);
    }
  }

  /// Upload a profile picture to the 'avatars' bucket.
  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final path = '$userId/$fileName';
    
    try {
      await client.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final publicUrl = client.storage.from('avatars').getPublicUrl(path);
      
      // Sync to user metadata
      await client.auth.updateUser(UserAttributes(data: {'avatar_url': publicUrl}));
      
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  /// Fetch all members across all communities the user belongs to.
  Future<List<Map<String, dynamic>>> fetchAllAccessibleMembers() async {
    try {
      final communities = await fetchUserCommunities().timeout(const Duration(seconds: 5));
      final List<Map<String, dynamic>> allMembers = [];
      final Set<String> seenUserIds = {};

      for (var community in communities) {
        final members = await getCommunityMembers(community['id']).timeout(const Duration(seconds: 3));
        for (var member in members) {
          if (!seenUserIds.contains(member['user_id'])) {
            allMembers.add(member);
            seenUserIds.add(member['user_id']);
          }
        }
      }
      return allMembers;
    } catch (e) {
      debugPrint('SupabaseService: Context fetch timed out or failed: $e');
      return []; // Return empty context rather than hanging
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

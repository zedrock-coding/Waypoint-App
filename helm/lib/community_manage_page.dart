import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/user_avatar.dart';
import 'services/supabase_service.dart';

class CommunityManagePage extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityManagePage({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityManagePage> createState() => _CommunityManagePageState();
}

class _CommunityManagePageState extends State<CommunityManagePage> {
  final _supabaseService = SupabaseService();
  bool _isAdmin = false;
  bool _isOwner = false;

  /// The roster future is created once. A `FutureBuilder` with a fresh
  /// `future:` expression re-runs the RPC on every rebuild (including every
  /// setState for a role change), which also made the list flicker.
  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture =
        _supabaseService.getCommunityMembers(widget.communityId);
    _checkPermissions();
  }

  void _refreshMembers() {
    SupabaseService.clearMemberCache(widget.communityId);
    setState(() {
      _membersFuture =
          _supabaseService.getCommunityMembers(widget.communityId, forceRefresh: true);
    });
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final members = await _supabaseService.getCommunityMembers(widget.communityId);
    final currentMember = members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => {},
    );

    if (mounted) {
      setState(() {
        final String role = currentMember['role'] ?? 'member';
        _isOwner = role == 'owner';
        _isAdmin = role == 'admin' || _isOwner;
      });
    }
  }

  void _copyInviteLink() {
    final String link = 'waypoint://invite?communityId=${widget.communityId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $link'), 
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  Future<void> _removeMember(String targetUserId) async {
    try {
      await _supabaseService.removeMember(widget.communityId, targetUserId);
      if (mounted) _refreshMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  Future<void> _changeRole(String targetUserId, String newRole) async {
    try {
      await _supabaseService.updateMemberRole(widget.communityId, targetUserId, newRole);
      if (mounted) _refreshMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _leaveCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Community?'),
        content: const Text('You will lose access to all shared tasks and chat in this workspace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      await _supabaseService.removeMember(widget.communityId, userId);
      if (mounted) {
        Navigator.pop(context); // Close manage page
        // The dashboard will refresh via the stream/provider
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error leaving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String inviteLink = 'waypoint://invite?communityId=${widget.communityId}';

    // A plain page, not a second AppShell: nesting the shell inside the tab
    // shell duplicated the sidebar/header and created two navigation states.
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.communityName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to Tasks',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                const Icon(Icons.group_add_rounded, size: 48, color: Colors.teal),
                const SizedBox(height: 16),
                Text('Invite Members', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Share this unique link with your team to let them join this workspace.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteLink,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: _copyInviteLink,
                        tooltip: 'Copy Link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _copyInviteLink,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('SHARE INVITE LINK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('Member Directory', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const Spacer(),
                if (!_isOwner) 
                  TextButton.icon(
                    onPressed: _leaveCommunity, 
                    icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.red),
                    label: const Text('LEAVE', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final members = snapshot.data ?? [];
                if (members.isEmpty) return const Center(child: Text('No members found.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final String userId = member['user_id'].toString();
                    final String role = member['role'] ?? 'member';
                    final bool isSelf = userId == SupabaseService.client.auth.currentUser?.id;
                    
                    final bool memberIsOwner = role == 'owner';

                    return ListTile(
                      leading: UserAvatar(
                        fullName: member['full_name'] ?? 'User',
                        avatarUrl: member['avatar_url'],
                        radius: 20,
                      ),
                      title: Text('${member['full_name'] ?? userId.substring(0, 8)} ${isSelf ? "(You)" : ""}'),
                      subtitle: Text(role.toUpperCase()),
                      trailing: (_isAdmin && !isSelf && !memberIsOwner) 
                        ? PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'remove') _removeMember(userId);
                              if (val == 'admin') _changeRole(userId, 'admin');
                              if (val == 'member') _changeRole(userId, 'member');
                            },
                            itemBuilder: (ctx) => [
                              // Admins can see "Make Admin" for members
                              if (role == 'member') 
                                const PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                              
                              // ONLY Owners can see "Make Member" for Admins
                              if (role == 'admin' && _isOwner) 
                                const PopupMenuItem(value: 'member', child: Text('Make Member')),
                              
                              // Admins can remove members. Owners can remove both.
                              if (role == 'member' || (role == 'admin' && _isOwner))
                                const PopupMenuItem(value: 'remove', child: Text('Remove Member', style: TextStyle(color: Colors.red))),
                            ],
                          )
                        : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

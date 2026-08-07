import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'app_shell.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final members = await _supabaseService.getCommunityMembers(widget.communityId);
    final currentMember = members.firstWhere(
      (m) => m['user_id'] == userId,
      orElse: () => {},
    );

    if (mounted) {
      setState(() {
        _isAdmin = currentMember['role'] == 'admin';
      });
    }
  }

  void _copyInviteLink() {
    final String link = 'helm://invite?communityId=${widget.communityId}';
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
      if (mounted) setState(() {}); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  Future<void> _changeRole(String targetUserId, String newRole) async {
    try {
      await _supabaseService.updateMemberRole(widget.communityId, targetUserId, newRole);
      if (mounted) setState(() {}); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String inviteLink = 'helm://invite?communityId=${widget.communityId}';

    return AppShell(
      title: 'Manage ${widget.communityName}',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabaseService.getCommunityMembers(widget.communityId),
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
                    final bool isSelf = userId == SupabaseService.client.auth.currentUser?.id;
                    final bool memberIsAdmin = member['role'] == 'admin';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: memberIsAdmin ? colorScheme.primary : colorScheme.surfaceVariant,
                        child: Icon(memberIsAdmin ? Icons.shield_rounded : Icons.person_outline_rounded,
                            color: memberIsAdmin ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, size: 20),
                      ),
                      title: Text(userId.substring(0, 8) + '... ${isSelf ? "(You)" : ""}'),
                      subtitle: Text(memberIsAdmin ? 'Administrator' : 'Member'),
                      trailing: (_isAdmin && !isSelf) 
                        ? PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'remove') _removeMember(userId);
                              if (val == 'admin') _changeRole(userId, 'admin');
                              if (val == 'member') _changeRole(userId, 'member');
                            },
                            itemBuilder: (ctx) => [
                              if (!memberIsAdmin) const PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                              if (memberIsAdmin) const PopupMenuItem(value: 'member', child: Text('Make Member')),
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

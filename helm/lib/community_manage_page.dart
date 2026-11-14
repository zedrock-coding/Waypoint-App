import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/user_avatar.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

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

  void _showRoleDialog(String userId, String memberName, String currentRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHighColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(
          'Change Role: $memberName',
          style: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select new permission tier for this team member:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
            ),
            const SizedBox(height: 16),
            if (currentRole != 'admin')
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, color: AppTheme.priorityHigh, size: 20),
                title: Text('Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text(context))),
                subtitle: Text('Can manage workspace tasks, invite members, and configure team roles', style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeRole(userId, 'admin');
                },
              ),
            if (currentRole != 'member' && _isOwner)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded, color: AppTheme.priorityLow, size: 20),
                title: Text('Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text(context))),
                subtitle: Text('Can collaborate, view shared boards, and comment on tasks', style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeRole(userId, 'member');
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(context))),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(String userId, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHighColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(
          'Remove $memberName?',
          style: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text(context)),
        ),
        content: Text(
          'This user will lose access to all tasks, notes, and discussion in ${widget.communityName}.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted(context))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeMember(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.priorityUrgent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Remove Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String inviteLink = 'waypoint://invite?communityId=${widget.communityId}';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text(context)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 18, color: AppTheme.mint),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Manage ${widget.communityName}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text(context)),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to Tasks',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 40),
            children: [
              // 1. Invite Box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHighColor(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_add_rounded, size: 18, color: AppTheme.mint),
                        const SizedBox(width: 8),
                        Text(
                          'Invite Team Members',
                          style: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share this link or code with teammates to grant instant access to this workspace.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerColor(context),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              inviteLink,
                              style: AppTheme.monoStyle(fontSize: 11, color: AppTheme.mint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: _copyInviteLink,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 13, color: AppTheme.mint),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: AppTheme.monoStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.mint),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Member Directory Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WORKSPACE TEAM & ROLES',
                          style: AppTheme.monoStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.mint, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isOwner
                              ? 'Owner privileges: full control over members and roles'
                              : (_isAdmin
                                  ? 'Admin privileges: can invite and promote members'
                                  : 'Member directory'),
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted(context)),
                        ),
                      ],
                    ),
                    if (!_isOwner)
                      OutlinedButton.icon(
                        onPressed: _leaveCommunity,
                        icon: const Icon(Icons.exit_to_app_rounded, size: 13, color: AppTheme.priorityUrgent),
                        label: const Text('Leave', style: TextStyle(color: AppTheme.priorityUrgent, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.priorityUrgent),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 3. Member List
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.mint)));
                  }
                  final members = snapshot.data ?? [];
                  if (members.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No members found.', style: TextStyle(color: AppTheme.textMuted(context))),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: members.map((member) {
                        final String userId = member['user_id'].toString();
                        final String role = member['role'] ?? 'member';
                        final String fullName = member['full_name'] ?? userId.substring(0, 8);
                        final bool isSelf = userId == SupabaseService.client.auth.currentUser?.id;
                        final bool memberIsOwner = role == 'owner';

                        Color roleBadgeColor = AppTheme.priorityLow;
                        if (role == 'owner') {
                          roleBadgeColor = AppTheme.mint;
                        } else if (role == 'admin') {
                          roleBadgeColor = AppTheme.priorityHigh;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHighColor(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: ListTile(
                            leading: UserAvatar(
                              fullName: fullName,
                              avatarUrl: member['avatar_url'],
                              radius: 18,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.text(context),
                                    ),
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mint.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      'YOU',
                                      style: AppTheme.monoStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.mint),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'ID: ${userId.substring(0, 8)}...',
                              style: AppTheme.monoStyle(fontSize: 10, color: AppTheme.textMuted(context)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: roleBadgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(color: roleBadgeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: AppTheme.monoStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: roleBadgeColor,
                                    ),
                                  ),
                                ),

                                // Role Management Actions for Admins / Owners
                                if (_isAdmin && !isSelf && !memberIsOwner) ...[
                                  const SizedBox(width: 8),
                                  // Change Role Action Button
                                  OutlinedButton.icon(
                                    onPressed: () => _showRoleDialog(userId, fullName, role),
                                    icon: const Icon(Icons.manage_accounts_outlined, size: 13, color: AppTheme.mint),
                                    label: const Text('Role', style: TextStyle(fontSize: 10.5, color: AppTheme.mint)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppTheme.mint),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Remove Member Action Button
                                  if (role == 'member' || (role == 'admin' && _isOwner))
                                    IconButton(
                                      icon: const Icon(Icons.person_remove_outlined, size: 16, color: AppTheme.priorityUrgent),
                                      tooltip: 'Remove Member',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () => _confirmRemoveMember(userId, fullName),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

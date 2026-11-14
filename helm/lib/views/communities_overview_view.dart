import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/navigation_provider.dart';
import '../theme/app_theme.dart';

class CommunitiesOverviewView extends StatefulWidget {
  final VoidCallback onBackToToday;

  const CommunitiesOverviewView({super.key, required this.onBackToToday});

  @override
  State<CommunitiesOverviewView> createState() => _CommunitiesOverviewViewState();
}

class _CommunitiesOverviewViewState extends State<CommunitiesOverviewView> {
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppTheme.surfaceVariant),
        ),
        title: const Text('Create New Workspace / Community', style: TextStyle(fontSize: 15, color: AppTheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Community Name',
            labelStyle: AppTheme.monoStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            hintText: 'e.g. WES Foundation or Engineering Team',
            hintStyle: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppTheme.surfaceContainerLowest,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.surfaceVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.mint),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _supabaseService.createCommunity(name);
                  if (mounted) setState(() => _isLoading = false);
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: AppTheme.onMint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppTheme.surfaceVariant),
        ),
        title: const Text('Join Workspace via Code', style: TextStyle(fontSize: 15, color: AppTheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Invitation Code',
            labelStyle: AppTheme.monoStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            hintText: 'Enter 6-digit or UUID code',
            hintStyle: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppTheme.surfaceContainerLowest,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.surfaceVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.mint),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _supabaseService.joinCommunity(code);
                  if (mounted) setState(() => _isLoading = false);
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Join error: $e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: AppTheme.onMint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 90),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 18, color: AppTheme.onSurfaceVariant),
                            onPressed: widget.onBackToToday,
                            tooltip: 'Back to Today',
                          ),
                          Text(
                            'GROUPS & WORKSPACES',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mint,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showJoinDialog,
                            icon: const Icon(Icons.login_rounded, size: 14),
                            label: const Text('Join Code', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.onSurface,
                              side: const BorderSide(color: AppTheme.surfaceVariant),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _showCreateDialog,
                            icon: const Icon(Icons.add, size: 15, color: AppTheme.onMint),
                            label: const Text('Create', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onMint)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.mint,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Workspace Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Collaborate on team backlogs, campus cells, and community sprints.',
                    style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceVariant, height: 1),
                ],
              ),
            ),

            const SizedBox(height: 14),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.mint))
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabaseService.fetchUserCommunities(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.mint)));
                  }

                  final communities = snapshot.data ?? [];
                  if (communities.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.hub_outlined, size: 40, color: AppTheme.mint),
                            const SizedBox(height: 12),
                            const Text(
                              'No community workspaces joined yet',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create a community or join using an invite code from your team.',
                              style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: communities.map((comm) {
                        final id = comm['id']?.toString() ?? '';
                        final name = comm['name']?.toString() ?? 'Community';
                        final role = comm['role']?.toString().toUpperCase() ?? 'MEMBER';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHighColor(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: ListTile(
                            onTap: () {
                              context.read<NavigationProvider>().selectCommunity(id, name: name);
                            },
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerColor(context),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderColor(context)),
                              ),
                              child: const Icon(Icons.hub_outlined, size: 16, color: AppTheme.mint),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text(context)),
                            ),
                            subtitle: Text(
                              'Role: $role',
                              style: AppTheme.monoStyle(fontSize: 10.5, color: AppTheme.textMuted(context)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.group_outlined, size: 18, color: AppTheme.mint),
                                  tooltip: 'View Members & Roles',
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/manage-community',
                                      arguments: {'id': id, 'name': name},
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    role,
                                    style: AppTheme.monoStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.mint),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: AppTheme.onSurfaceVariant),
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
    );
  }
}

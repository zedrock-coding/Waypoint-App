import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/navigation_provider.dart';

class CommunityListView extends StatefulWidget {
  const CommunityListView({super.key});

  @override
  State<CommunityListView> createState() => _CommunityListViewState();
}

class _CommunityListViewState extends State<CommunityListView> {
  final _supabaseService = SupabaseService();

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Community'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Community Name', hintText: 'e.g. My Team'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await _supabaseService.createCommunity(controller.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Community'),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(labelText: 'Invite Link or ID', hintText: 'Paste helm://invite... or ID'), 
          autofocus: true
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                String communityId = input;
                if (input.contains('communityId=')) {
                  communityId = Uri.parse(input).queryParameters['communityId'] ?? input;
                }
                try {
                  await _supabaseService.joinCommunity(communityId);
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining: $e')));
                }
              }
            },
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.read<NavigationProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabaseService.fetchUserCommunities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final communities = snapshot.data ?? [];

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemCount: communities.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                elevation: 0,
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colorScheme.primary.withOpacity(0.2))),
                child: InkWell(
                  onTap: _showCreateDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 32),
                      const SizedBox(height: 8),
                      Text('New Community', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ],
                  ),
                ),
              );
            }
            if (index == 1) {
              return Card(
                elevation: 0,
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colorScheme.secondary.withOpacity(0.2))),
                child: InkWell(
                  onTap: _showJoinDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_rounded, color: colorScheme.secondary, size: 32),
                      const SizedBox(height: 8),
                      Text('Join via Link', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                    ],
                  ),
                ),
              );
            }

            final comm = communities[index - 2];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
              child: InkWell(
                onTap: () => navProvider.selectCommunity(comm['id'], name: comm['name']),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.hub_rounded, color: colorScheme.primary), const Spacer(), const Icon(Icons.chevron_right, size: 20)]),
                      const Spacer(),
                      Text(comm['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(comm['community_members']?[0]['role']?.toString().toUpperCase() ?? 'MEMBER',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.4), letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

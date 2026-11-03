// lib/features/sync/presentation/widgets/sync_badge.dart

import 'package:flutter/material.dart';
import '../../domain/sync_queue_manager.dart';

class SyncBadge extends StatelessWidget {
  final SyncQueueManager queueManager;

  const SyncBadge({super.key, required this.queueManager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: queueManager,
      builder: (context, _) {
        final count = queueManager.pendingMutationsCount;
        final isDraining = queueManager.isDraining;

        if (isDraining) {
          return const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (count == 0) {
          return IconButton(
            tooltip: 'All changes synced',
            icon: const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent),
            onPressed: () => _showSyncModal(context),
          );
        }

        return IconButton(
          tooltip: '$count pending sync changes',
          icon: Badge(
            label: Text('$count'),
            backgroundColor: Colors.amber,
            textColor: Colors.black87,
            child: const Icon(Icons.cloud_sync_rounded, color: Colors.amber),
          ),
          onPressed: () => _showSyncModal(context),
        );
      },
    );
  }

  void _showSyncModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SyncModalSheet(queueManager: queueManager),
    );
  }
}

class _SyncModalSheet extends StatelessWidget {
  final SyncQueueManager queueManager;

  const _SyncModalSheet({required this.queueManager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: queueManager,
      builder: (context, _) {
        final mutations = queueManager.mutations;
        final count = queueManager.pendingMutationsCount;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Offline Sync Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Text(
                      '$count pending',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                    )
                  else
                    const Text(
                      'Synced',
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (mutations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('All local mutations have been synced to the server.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mutations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final m = mutations[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          m.action == 'CREATE'
                              ? Icons.add_circle_outline
                              : m.action == 'DELETE'
                                  ? Icons.delete_outline
                                  : Icons.edit_outlined,
                        ),
                        title: Text('${m.action} ${m.entityType}: ${m.entityId}'),
                        subtitle: Text('Queued at ${m.queuedAt.toIso8601String().substring(11, 19)} (Retries: ${m.retryCount})'),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: queueManager.isDraining || count == 0
                      ? null
                      : () async {
                          await queueManager.drain();
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(queueManager.isDraining ? 'Syncing...' : 'Force Sync Now'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


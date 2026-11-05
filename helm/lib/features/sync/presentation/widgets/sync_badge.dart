// lib/features/sync/presentation/widgets/sync_badge.dart

import 'package:flutter/material.dart';
import '../../domain/sync_queue_manager.dart';

class SyncBadge extends StatelessWidget {
  final SyncQueueManager? queueManager;

  const SyncBadge({super.key, this.queueManager});

  SyncQueueManager get _manager => queueManager ?? SyncQueueManager.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final status = _manager.syncStatus;
        final count = _manager.queueDepth;

        if (status == SyncStatus.syncing || _manager.isDraining) {
          return Tooltip(
            message: 'Syncing changes...',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        }

        if (count == 0 || status == SyncStatus.synced) {
          return Tooltip(
            message: 'All changes synced',
            child: InkWell(
              onTap: () => _showSyncModal(context, _manager),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF88C0A4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: '$count pending sync ${count == 1 ? "change" : "changes"}',
          child: InkWell(
            onTap: () => _showSyncModal(context, _manager),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
              child: Badge(
                label: Text('$count'),
                backgroundColor: Colors.amber,
                textColor: Colors.black87,
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSyncModal(BuildContext context, SyncQueueManager manager) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SyncModalSheet(queueManager: manager),
    );
  }
}

class _SyncModalSheet extends StatefulWidget {
  final SyncQueueManager queueManager;

  const _SyncModalSheet({required this.queueManager});

  @override
  State<_SyncModalSheet> createState() => _SyncModalSheetState();
}

class _SyncModalSheetState extends State<_SyncModalSheet> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.queueManager,
      builder: (context, _) {
        final mutations = widget.queueManager.mutations;
        final count = widget.queueManager.queueDepth;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Text(
                      '$count Pending',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Synced',
                      style: TextStyle(
                        color: Color(0xFF88C0A4),
                        fontWeight: FontWeight.bold,
                      ),
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
                      final title = m.payload['title']?.toString() ??
                          m.payload['name']?.toString() ??
                          '${m.entityType} ${m.entityId}';
                      final action = m.action;
                      final timestamp = m.queuedAt.toIso8601String().substring(11, 19);

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          action.toUpperCase() == 'CREATE'
                              ? Icons.add_circle_outline
                              : action.toUpperCase() == 'DELETE'
                                  ? Icons.delete_outline
                                  : Icons.edit_outlined,
                          color: action.toUpperCase() == 'DELETE'
                              ? Colors.redAccent
                              : null,
                        ),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$action • Queued at $timestamp (Retries: ${m.retryCount})',
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          try {
                            final synced = await widget.queueManager.drain(force: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(synced > 0
                                      ? 'Synced $synced item${synced == 1 ? "" : "s"} successfully'
                                      : 'All items up to date'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sync error: $e'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSyncing = false);
                            }
                          }
                        },
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isSyncing ? 'Syncing...' : 'Force Sync Now'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

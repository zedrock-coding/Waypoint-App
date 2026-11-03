// lib/features/sync/domain/models/sync_mutation.dart

class SyncMutation {
  final String id;
  final String entityId;
  final String entityType; // 'task' | 'subtask'
  final String action; // 'CREATE' | 'UPDATE' | 'DELETE'
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? rollbackSnapshot;
  final DateTime queuedAt;
  int retryCount;

  SyncMutation({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.action,
    required this.payload,
    this.rollbackSnapshot,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_id': entityId,
        'entity_type': entityType,
        'action': action,
        'payload': payload,
        'rollback_snapshot': rollbackSnapshot,
        'queued_at': queuedAt.toIso8601String(),
        'retry_count': retryCount,
      };
}


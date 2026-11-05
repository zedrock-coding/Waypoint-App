import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sync_model.dart';
import '../features/sync/domain/sync_queue_manager.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Lazy on purpose: queue-only operations (enqueue, coalesce, pending lookup)
  // are pure Hive work and must not require an initialized Supabase client,
  // which also makes them unit-testable.
  SupabaseClient get _supabase => Supabase.instance.client;
  final _syncBox = Hive.box<SyncAction>('sync_queue');
  bool _isSyncing = false;

  /// Retry bookkeeping. In memory on purpose: a restart is a fresh retry budget,
  /// and persisting it would mean another Hive adapter migration.
  static const int _maxAttempts = 5;
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _retryAfter = {};

  /// Number of unflushed writes, exposed for the header indicator (D10).
  /// A notifier rather than a plain getter so the badge can rebuild without
  /// rebuilding the whole shell on every Hive write.
  final ValueNotifier<int> pendingChanges = ValueNotifier<int>(0);

  void _refreshPending() {
    pendingChanges.value = _syncBox.length;
  }

  void init() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        debugPrint('SyncService: Network online. Triggering sync...');
        processSyncQueue();
      }
    });

    // Listen to Auth changes to purge un-synced queue on logout
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        debugPrint(
          'SyncService: User signed out. Clearing pending sync queue.',
        );
        _syncBox.clear();
        _attempts.clear();
        _retryAfter.clear();
        _refreshPending();
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (!results.any((r) => r != ConnectivityResult.none)) {
      return false;
    }
    return await SyncQueueManager.checkInternetReachability();
  }

  /// Queue key. Includes the table because ids are client-generated UUIDs and
  /// a task and a category can legitimately collide; keying by id alone would
  /// merge them into a single action aimed at the wrong table.
  static String queueKey(String table, String id) => '$table:$id';

  /// True when this record has an unflushed local write.
  bool hasPending(String id, {String table = 'tasks'}) =>
      _syncBox.containsKey(queueKey(table, id));

  /// Drops any queued action for this record.
  ///
  /// Used after a write that already reached the server, so the queued copy
  /// cannot replay stale state on the next flush (undo-delete is the caller).
  Future<void> removeFromQueue({
    required String table,
    required String id,
  }) async {
    final key = queueKey(table, id);
    if (_syncBox.containsKey(key)) {
      await _syncBox.delete(key);
    }
    _attempts.remove(key);
    _retryAfter.remove(key);
    _refreshPending();
  }

  /// Number of unflushed local writes, for the pending-changes indicator.
  int get pendingCount => _syncBox.length;

  /// Safely enqueue mutations with smart action merging.
  Future<void> addToQueue({
    required String id,
    required SyncActionType action,
    required String table,
    required Map<dynamic, dynamic> payload,
  }) async {
    final key = queueKey(table, id);
    final existing = _syncBox.get(key);

    if (existing != null) {
      // 1. If created offline and then deleted offline -> Cancel out completely
      if (existing.action == SyncActionType.create &&
          action == SyncActionType.delete) {
        await _syncBox.delete(key);
        debugPrint('SyncService: Cancelled offline CREATE + DELETE for $key');
        _refreshPending();
        return;
      }

      // 2. If created offline and then updated offline -> Merge into CREATE
      if (existing.action == SyncActionType.create &&
          action == SyncActionType.update) {
        final mergedPayload = Map<dynamic, dynamic>.from(existing.payload)
          ..addAll(payload);
        final mergedAction = SyncAction(
          id: id,
          action: SyncActionType.create,
          table: table,
          payload: mergedPayload,
          timestamp: DateTime.now(),
        );
        await _syncBox.put(key, mergedAction);
        debugPrint('SyncService: Merged UPDATE into CREATE for $key');
        _refreshPending();
        return;
      }

      // 3. If updated offline and updated again -> Merge UPDATE payloads
      if (existing.action == SyncActionType.update &&
          action == SyncActionType.update) {
        final mergedPayload = Map<dynamic, dynamic>.from(existing.payload)
          ..addAll(payload);
        final mergedAction = SyncAction(
          id: id,
          action: SyncActionType.update,
          table: table,
          payload: mergedPayload,
          timestamp: DateTime.now(),
        );
        await _syncBox.put(key, mergedAction);
        debugPrint('SyncService: Merged consecutive UPDATEs for $key');
        _refreshPending();
        return;
      }

      // 4. A queued DELETE swallows any later update: the row is going away.
      if (existing.action == SyncActionType.delete &&
          action == SyncActionType.update) {
        debugPrint(
          'SyncService: Dropped UPDATE for $key, a DELETE is already queued',
        );
        return;
      }
    }

    // Default: Insert/Overwrite new action
    final syncAction = SyncAction(
      id: id,
      action: action,
      table: table,
      payload: payload,
      timestamp: DateTime.now(),
    );
    await _syncBox.put(key, syncAction);
    debugPrint('SyncService: Added $action to queue for $table ($id)');
    _refreshPending();
  }

  /// Flushes the queue in FIFO order.
  ///
  /// `_isSyncing` is released in a `finally` block: a throw inside the loop used
  /// to leave it stuck at `true`, which silently disabled syncing for the rest
  /// of the session. Failures back off instead of hot-looping, and give up
  /// after [_maxAttempts] so one poison payload cannot starve the queue.
  Future<int> processSyncQueue({bool force = false}) async {
    if (_isSyncing || _syncBox.isEmpty) return 0;

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 0;

    if (force) {
      _attempts.clear();
      _retryAfter.clear();
    }

    _isSyncing = true;
    int syncedCount = 0;
    try {
      debugPrint(
        'SyncService: Processing ${_syncBox.length} pending actions...',
      );
      final now = DateTime.now();

      final entries = _syncBox.toMap().entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      for (final entry in entries) {
        final key = entry.key.toString();
        final action = entry.value;

        if (!force) {
          final retryAt = _retryAfter[key];
          if (retryAt != null && retryAt.isAfter(now)) {
            continue;
          }

          final attempts = _attempts[key] ?? 0;
          if (attempts >= _maxAttempts) {
            debugPrint('SyncService: giving up on $key after $attempts attempts');
            continue;
          }
        }

        final attempts = _attempts[key] ?? 0;
        try {
          final bool success = await _performSyncAction(action);
          if (success) {
            await _syncBox.delete(key);
            _attempts.remove(key);
            _retryAfter.remove(key);
            syncedCount++;
            debugPrint('SyncService: Successfully synced $key');
          } else {
            _attempts[key] = attempts + 1;
            _retryAfter[key] = DateTime.now().add(_backoff(attempts + 1));
            debugPrint(
              'SyncService: queued retry for $key (attempt ${attempts + 1})',
            );
          }
        } catch (e) {
          _attempts[key] = attempts + 1;
          _retryAfter[key] = DateTime.now().add(_backoff(attempts + 1));
          debugPrint('SyncService: Failed to sync $key: $e');
        }
      }
    } finally {
      _isSyncing = false;
      _refreshPending();
      debugPrint('SyncService: Sync cycle complete.');
    }
    return syncedCount;
  }

  Duration _backoff(int attempt) {
    final seconds = 1 << attempt.clamp(0, 5);
    return Duration(seconds: seconds);
  }

  Future<bool> _performSyncAction(SyncAction action) async {
    final table = action.table;
    final payload = Map<String, dynamic>.from(action.payload);

    try {
      switch (action.action) {
        case SyncActionType.create:
          await _supabase.from(table).upsert(payload);
          break;
        case SyncActionType.update:
          // UPDATE is a patch, not an upsert. Upserting a partial payload can
          // insert a truncated row when the server copy is gone, and it rewrites
          // every column the payload happens to carry. The id is the filter, so
          // it is not part of the body.
          final patch = Map<String, dynamic>.from(payload)..remove('id');
          await _supabase.from(table).update(patch).eq('id', action.id);
          break;
        case SyncActionType.delete:
          await _supabase.from(table).delete().eq('id', action.id);
          break;
      }
      return true;
    } catch (e) {
      debugPrint('SyncService Error during _performSyncAction: $e');
      return false;
    }
  }
}

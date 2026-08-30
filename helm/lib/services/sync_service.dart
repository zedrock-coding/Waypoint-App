import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sync_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _supabase = Supabase.instance.client;
  final _syncBox = Hive.box<SyncAction>('sync_queue');
  bool _isSyncing = false;

  void init() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        debugPrint('SyncService: Network online. Triggering sync...');
        processSyncQueue();
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> addToQueue({
    required String id,
    required SyncActionType action,
    required String table,
    required Map<dynamic, dynamic> payload,
  }) async {
    final syncAction = SyncAction(
      id: id,
      action: action,
      table: table,
      payload: payload,
      timestamp: DateTime.now(),
    );
    await _syncBox.put(id, syncAction);
    debugPrint('SyncService: Added $action to queue for $table ($id)');
  }

  Future<void> processSyncQueue() async {
    if (_isSyncing || _syncBox.isEmpty) return;
    
    _isSyncing = true;
    debugPrint('SyncService: Processing ${_syncBox.length} pending actions...');

    final List<SyncAction> actions = _syncBox.values.toList();
    // Sort by timestamp to ensure FIFO
    actions.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (var action in actions) {
      try {
        final bool success = await _performSyncAction(action);
        if (success) {
          await _syncBox.delete(action.id);
          debugPrint('SyncService: Successfully synced ${action.id}');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync ${action.id}: $e');
        // Keep in queue for next retry
      }
    }

    _isSyncing = false;
    debugPrint('SyncService: Sync cycle complete.');
  }

  Future<bool> _performSyncAction(SyncAction action) async {
    final table = action.table;
    final payload = Map<String, dynamic>.from(action.payload);

    try {
      switch (action.action) {
        case SyncActionType.create:
        case SyncActionType.update:
          // Use upsert for "last-write-wins" and conflict resolution
          await _supabase.from(table).upsert(payload);
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

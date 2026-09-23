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

    // Listen to Auth changes to purge un-synced queue on logout
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        debugPrint('SyncService: User signed out. Clearing pending sync queue.');
        _syncBox.clear();
      }
    });
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Safely enqueue mutations with smart action merging.
  Future<void> addToQueue({
    required String id,
    required SyncActionType action,
    required String table,
    required Map<dynamic, dynamic> payload,
  }) async {
    final existing = _syncBox.get(id);

    if (existing != null) {
      // 1. If created offline and then deleted offline -> Cancel out completely
      if (existing.action == SyncActionType.create && action == SyncActionType.delete) {
        await _syncBox.delete(id);
        debugPrint('SyncService: Cancelled offline CREATE + DELETE for $id');
        return;
      }

      // 2. If created offline and then updated offline -> Merge into CREATE
      if (existing.action == SyncActionType.create && action == SyncActionType.update) {
        final mergedPayload = Map<dynamic, dynamic>.from(existing.payload)..addAll(payload);
        final mergedAction = SyncAction(
          id: id,
          action: SyncActionType.create,
          table: table,
          payload: mergedPayload,
          timestamp: DateTime.now(),
        );
        await _syncBox.put(id, mergedAction);
        debugPrint('SyncService: Merged UPDATE into CREATE for $id');
        return;
      }

      // 3. If updated offline and updated again -> Merge UPDATE payloads
      if (existing.action == SyncActionType.update && action == SyncActionType.update) {
        final mergedPayload = Map<dynamic, dynamic>.from(existing.payload)..addAll(payload);
        final mergedAction = SyncAction(
          id: id,
          action: SyncActionType.update,
          table: table,
          payload: mergedPayload,
          timestamp: DateTime.now(),
        );
        await _syncBox.put(id, mergedAction);
        debugPrint('SyncService: Merged consecutive UPDATEs for $id');
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
    await _syncBox.put(id, syncAction);
    debugPrint('SyncService: Added $action to queue for $table ($id)');
  }

  Future<void> processSyncQueue() async {
    if (_isSyncing || _syncBox.isEmpty) return;
    
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    _isSyncing = true;
    debugPrint('SyncService: Processing ${_syncBox.length} pending actions...');

    final List<SyncAction> actions = _syncBox.values.toList();
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

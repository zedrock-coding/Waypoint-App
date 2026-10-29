import '../models/hive_models.dart';

/// Merge policy between the local Hive mirror and the Supabase realtime stream.
///
/// The previous rule was "write the remote row if status, title or order
/// differ". That silently discarded local edits to priority, description, due
/// date, assignees and subtasks, and it could overwrite a record whose write was
/// still sitting in the offline queue with older server state.
///
/// The rule now mirrors the documented strategy (AGENTS.md §5): local-first with
/// last-write-wins on `updated_at`, and a pending local write always wins until
/// it has been flushed.
bool shouldApplyRemoteUpdate({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
  required bool hasPendingWrite,
}) {
  if (hasPendingWrite) return false;
  if (remoteUpdatedAt == null) return localUpdatedAt == null;
  if (localUpdatedAt == null) return true;
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}

/// Ids that exist locally, are backed by Supabase, and are absent from the
/// current remote snapshot — i.e. deleted on another device.
///
/// Rows created offline (`userId == null`) are never in the snapshot, so they
/// must be excluded or a reconnect would delete exactly the work the offline
/// queue exists to protect.
Set<String> localRowsMissingRemotely({
  required Iterable<Task> localRows,
  required Set<String> remoteIds,
  required bool Function(Task task) hasPendingWrite,
}) {
  return localRows
      .where((task) => task.id != null)
      .where((task) => task.userId != null || task.communityId != null)
      .where((task) => !hasPendingWrite(task))
      .where((task) => !remoteIds.contains(task.id))
      .map((task) => task.id!)
      .toSet();
}

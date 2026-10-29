import '../models/unified_task.dart';

/// Pure rules shared by the UI, so they can be tested without a widget tree or
/// a live Supabase connection.

/// Number of comments that count against the documented 2-comment limit.
///
/// AGENTS.md §5: count this user's comments where
/// `created_at >= task.updated_at`. Any task update moves `updated_at`, which
/// resets the allowance for every user. Comments with an unparseable timestamp
/// are not counted (they still render).
int countRecentComments({
  required Iterable<Map<String, dynamic>> comments,
  required String? userId,
  required DateTime updatedAt,
}) {
  if (userId == null) return 0;

  var count = 0;
  for (final comment in comments) {
    if (comment['user_id']?.toString() != userId) continue;
    final createdAt = DateTime.tryParse(comment['created_at']?.toString() ?? '');
    if (createdAt == null) continue;
    if (createdAt.isAfter(updatedAt) || createdAt.isAtSameMomentAs(updatedAt)) {
      count++;
    }
  }
  return count;
}

/// The 2-comment limit for one user on one task.
bool isCommentLimitReached({
  required Iterable<Map<String, dynamic>> comments,
  required String? userId,
  required DateTime updatedAt,
  int limit = 2,
}) {
  return countRecentComments(
        comments: comments,
        userId: userId,
        updatedAt: updatedAt,
      ) >=
      limit;
}

/// Finds the current value of a task by id.
///
/// The desktop detail panel stores only an id and re-resolves the task on each
/// build, so it never shows a snapshot that predates the last edit.
UnifiedTask? findTaskById(Iterable<UnifiedTask>? tasks, String id) {
  if (tasks == null) return null;
  for (final task in tasks) {
    if (task.id == id) return task;
  }
  return null;
}

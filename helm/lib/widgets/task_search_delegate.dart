import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unified_task.dart';
import '../providers/task_provider.dart';
import '../services/navigation_provider.dart';
import 'task_item_card.dart';
import 'app_snackbar.dart';
import '../task_detail_page.dart';

class CustomTaskSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search tasks...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: colorScheme.primary,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(color: colorScheme.onSurface, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  bool _matches(UnifiedTask task) {
    final needle = query.toLowerCase();
    return task.title.toLowerCase().contains(needle) ||
        task.description.toLowerCase().contains(needle);
  }

  Widget _buildResultList(BuildContext context, List<UnifiedTask> results) {
    final taskProvider = context.read<TaskProvider>();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No tasks found matching your search.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final unifiedTask = results[index];
        return TaskItemCard(
          key: ValueKey('search_task_${unifiedTask.id}'),
          task: unifiedTask,
          index: index,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailScreen(task: unifiedTask),
              ),
            );
          },
          onToggle: () => taskProvider.toggleTask(unifiedTask),
          onDismiss: (direction) async {
            final taskToDelete = unifiedTask;
            await taskProvider.deleteTask(taskToDelete.id, taskBackup: taskToDelete);
            if (context.mounted) {
              AppSnackBar.showUndo(
                context: context,
                message: 'Task deleted',
                onUndo: () => taskProvider.undoDelete(),
                duration: const Duration(seconds: 5),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final navProvider = context.read<NavigationProvider>();
    final communityId = navProvider.selectedCommunityId;

    final personal = taskProvider.personalTasks.where(_matches).toList();
    if (communityId == null) {
      return _buildResultList(context, personal);
    }

    // Search used to be personal-only, so community tasks were unreachable from
    // the search field. Merge the selected community's live tasks in, keyed by
    // id so a mirrored copy cannot appear twice.
    return StreamBuilder<List<UnifiedTask>>(
      stream: taskProvider.communityTasksStream(communityId),
      builder: (context, snapshot) {
        final merged = <UnifiedTask>[...personal];
        for (final task in snapshot.data ?? const <UnifiedTask>[]) {
          if (_matches(task) && !merged.any((t) => t.id == task.id)) {
            merged.add(task);
          }
        }
        return _buildResultList(context, merged);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Start typing to search...'));
    }
    return buildResults(context);
  }
}

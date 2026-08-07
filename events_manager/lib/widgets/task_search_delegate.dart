import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import 'task_item_card.dart';
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
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withOpacity(0.3),
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

  @override
  Widget buildResults(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final results = taskProvider.personalTasks.where((t) {
      return t.title.toLowerCase().contains(query.toLowerCase()) || 
             t.description.toLowerCase().contains(query.toLowerCase());
    }).toList();

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
          onDismiss: (direction) => taskProvider.deleteTask(unifiedTask.id),
        );
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

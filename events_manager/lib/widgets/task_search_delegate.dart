import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import '../models/event.dart';
import '../models/category.dart';
import '../repositories/event_repository.dart';
import '../repositories/category_repository.dart';
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
    final eventRepo = context.read<EventRepository>();
    final isar = context.read<Isar>();

    return FutureBuilder<List<Event>>(
      future: eventRepo.searchEvents(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No tasks found matching your search.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        final results = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            return TaskItemCard(
              key: ValueKey('search_task_${event.id}'),
              event: event,
              index: index,
              onTap: () {
                final double width = MediaQuery.of(context).size.width;
                if (width <= 900) {
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(event: event, isar: isar),
                    ),
                  );
                } else {
                  // For desktop search, we might want to close and select in dashboard,
                  // but for now, we'll follow the push behavior or just close and let the dashboard handle it.
                  // Best approach: Close search and return the event to the dashboard.
                  close(context, event);
                }
              },
              onDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await eventRepo.updateStatus(event, Status.done);
                } else {
                  await eventRepo.deleteEvent(event.id);
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      final categoryRepo = context.read<CategoryRepository>();
      final colorScheme = Theme.of(context).colorScheme;

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Searches',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Category>>(
              future: categoryRepo.getAllCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final categories = snapshot.data!;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.take(6).map((cat) {
                    return ActionChip(
                      label: Text(cat.name),
                      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
                      labelStyle: TextStyle(color: colorScheme.primary, fontSize: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
                      ),
                      onPressed: () {
                        query = cat.name;
                        showResults(context);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    return buildResults(context);
  }
}

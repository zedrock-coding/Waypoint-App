import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'models/event.dart';
import 'models/category.dart' as model;
import 'models/settings.dart';
import 'settings_page.dart';
import 'add_event_page.dart';
import 'category_page.dart';
import 'app_shell.dart';
import 'notification_service.dart';
import 'velocity_dashboard_card.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await NotificationService().init();
    final dir = await getApplicationDocumentsDirectory();
    
    final isar = await Isar.open(
      [EventSchema, model.CategorySchema, SettingsSchema],
      directory: dir.path,
    );
    
    await isar.writeTxn(() async {
      final settings = await isar.settings.get(0);
      if (settings == null) {
        await isar.settings.put(Settings()..id = 0);
      }
    });

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(isar),
        child: MyApp(isar: isar),
      ),
    );
  } catch (e) {
    debugPrint('FATAL INITIALIZATION ERROR: $e');
    runApp(MaterialApp(
      home: Scaffold(body: Center(child: Text('Failed to initialize: $e'))),
    ));
  }
}

class MyApp extends StatelessWidget {
  final Isar isar;
  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = themeProvider.settings;

    // --- REFINED LIGHT THEME ---
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF26A69A), // Teal/Mint
      brightness: Brightness.light,
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8), // Soft off-white
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // --- PREMIUM SLATE & MINT DARK THEME ---
    final ColorScheme slateScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF88C0A4), 
      brightness: Brightness.dark,
      surface: const Color(0xFF1E2124),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: slateScheme,
      scaffoldBackgroundColor: const Color(0xFF1E2124),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF2A2D32),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );

    final fontScales = [0.7, 0.85, 1.0, 1.2, 1.4];
    final double scale = fontScales[settings.fontSizeIndex.clamp(0, 4)];

    return MaterialApp(
      key: const ValueKey('helm_app_root'),
      title: 'Helm',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => MyHomePage(title: 'Helm', isar: isar),
        '/settings': (context) => SettingPage(isar: isar),
        '/add-event': (context) => AddEventPage(isar: isar),
        '/categories': (context) => CategoryPage(isar: isar),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.isar});
  final String title;
  final Isar isar;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Stream<void> _changeStream;
  bool _sortByCategory = true;
  Id? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _changeStream = widget.isar.events.watchLazy().asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.title,
      actions: [
        IconButton(
          icon: Icon(_sortByCategory ? Icons.sort_by_alpha : Icons.calendar_month),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _sortByCategory = !_sortByCategory);
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pushNamed(context, '/add-event');
        },
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          _buildVelocityDashboard(),
          if (_sortByCategory) _buildCategoryFilterDropdown(),
          Expanded(
            child: StreamBuilder<void>(
              stream: _changeStream,
              builder: (context, snapshot) {
                return FutureBuilder<List<dynamic>>(
                  future: _getOptimizedFlattenedList(),
                  builder: (context, listSnapshot) {
                    if (!listSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final flattenedList = listSnapshot.data!;
                    if (flattenedList.isEmpty) return const DashboardEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: flattenedList.length,
                      itemBuilder: (context, index) {
                        final item = flattenedList[index];
                        if (item is String) {
                          return CategoryHeaderRow(categoryName: item);
                        }
                        return TaskItemCard(event: item as Event, isar: widget.isar);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityDashboard() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<void>(
      stream: _changeStream,
      builder: (context, snapshot) {
        return FutureBuilder<List<Event>>(
          future: widget.isar.events.filter().dateTimeBetween(todayStart, todayEnd).findAll(),
          builder: (context, taskSnapshot) {
            if (!taskSnapshot.hasData) return const SizedBox.shrink();
            final todayTasks = taskSnapshot.data!;
            return VelocityDashboardCard(
              totalTasksToday: todayTasks.length,
              completedTasksToday: todayTasks.where((t) => t.status == Status.done).length,
              remindersEnabled: themeProvider.settings.remindersEnabled,
              onRemindersToggle: (enabled) async {
                HapticFeedback.selectionClick();
                final NotificationService ns = NotificationService();
                if (enabled) {
                  final granted = await ns.requestPermissions();
                  if (granted) await ns.scheduleDailyNotification(id: 0, title: 'Helm Reminder', body: 'Check your tasks!', time: const TimeOfDay(hour: 9, minute: 0));
                } else {
                  await ns.cancelAllNotifications();
                }
                themeProvider.settings.remindersEnabled = enabled;
                await widget.isar.writeTxn(() => widget.isar.settings.put(themeProvider.settings));
                themeProvider.refresh();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilterDropdown() {
    return FutureBuilder<List<model.Category>>(
      future: widget.isar.categorys.where().sortByName().findAll(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: DropdownButtonFormField<Id?>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Filter Category', border: OutlineInputBorder()),
            items: [const DropdownMenuItem(value: null, child: Text('All')), ...snapshot.data!.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))],
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategoryId = v);
            },
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _getOptimizedFlattenedList() async {
    final List<dynamic> flattened = [];
    if (_sortByCategory) {
      final categories = await widget.isar.categorys.where().sortByName().findAll();
      for (var cat in categories) {
        final events = await widget.isar.events.filter().categories((q) => q.idEqualTo(cat.id)).sortByDateTime().findAll();
        if (events.isNotEmpty) { flattened.add(cat.name); flattened.addAll(events); }
      }
    } else {
      flattened.addAll(await widget.isar.events.where().sortByDateTime().findAll());
    }
    return flattened;
  }
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the + button to add a task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryHeaderRow extends StatelessWidget {
  final String categoryName;
  const CategoryHeaderRow({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              categoryName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/add-event');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskItemCard extends StatelessWidget {
  final Event event;
  final Isar isar;
  const TaskItemCard({super.key, required this.event, required this.isar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = event.status == Status.done;
    final isOverdue = !isDone && event.dateTime.isBefore(DateTime.now());

    return Dismissible(
      key: ValueKey(event.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          await isar.writeTxn(() async {
            event.status = Status.done;
            await isar.events.put(event);
          });
        } else {
          // UNDO LOGIC
          final backupEvent = Event()
            ..title = event.title
            ..description = event.description
            ..dateTime = event.dateTime
            ..status = event.status
            ..priority = event.priority
            ..assignees = List.from(event.assignees);
          
          await event.categories.load();
          final categoryIds = event.categories.map((c) => c.id).toList();
          
          await isar.writeTxn(() async {
            await isar.events.delete(event.id);
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Task "${backupEvent.title}" deleted'),
                action: SnackBarAction(
                  label: 'UNDO',
                  onPressed: () async {
                    await isar.writeTxn(() async {
                      final restored = Event()
                        ..title = backupEvent.title
                        ..description = backupEvent.description
                        ..dateTime = backupEvent.dateTime
                        ..status = backupEvent.status
                        ..priority = backupEvent.priority
                        ..assignees = List.from(backupEvent.assignees);
                      
                      await isar.events.put(restored);
                      for (final catId in categoryIds) {
                        final cat = await isar.categorys.get(catId);
                        if (cat != null) restored.categories.add(cat);
                      }
                      await restored.categories.save();
                    });
                  },
                ),
              ),
            );
          }
        }
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddEventPage(isar: isar, eventToEdit: event)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Leading Status
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? Colors.green : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isDone 
                      ? const Icon(Icons.check, size: 14, color: Colors.green)
                      : null,
                ),
                const SizedBox(width: 16),
                // Center Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
                        ),
                      ),
                      if (event.description.isNotEmpty)
                        Text(
                          event.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _buildPillTag(context, event.priority.name.toUpperCase()),
                          ...event.assignees.take(2).map((a) => _buildPillTag(context, a, isAssignee: true)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Trailing
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      event.dateTime.toLocal().toString().split(' ')[0],
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag, color: Colors.red, size: 12),
                            const SizedBox(width: 2),
                            const Text('Overdue', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillTag(BuildContext context, String label, {bool isAssignee = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAssignee 
            ? colorScheme.tertiary.withOpacity(0.1)
            : colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isAssignee ? colorScheme.tertiary : colorScheme.primary,
        ),
      ),
    );
  }
}

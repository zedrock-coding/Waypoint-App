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
import 'about_page.dart';
import 'task_detail_page.dart';
import 'onboarding_page.dart';
import 'account_settings_page.dart';
import 'app_shell.dart';
import 'notification_service.dart';
import 'theme_provider.dart';
import 'theme/app_theme.dart';
import 'repositories/event_repository.dart';
import 'repositories/category_repository.dart';
import 'widgets/task_item_card.dart';
import 'widgets/category_header.dart';
import 'widgets/empty_states.dart';
import 'widgets/velocity_dashboard.dart';
import 'widgets/task_form_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Completely hide the status bar (Alternative approach)
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  try {
    await NotificationService().init();
    final dir = await getApplicationDocumentsDirectory();
    
    final isar = await Isar.open(
      [EventSchema, model.CategorySchema, SettingsSchema],
      directory: dir.path,
    );
    
    final categoryRepo = CategoryRepository(isar);
    await isar.writeTxn(() async {
      final settings = await isar.settings.get(0);
      if (settings == null) {
        await isar.settings.put(Settings()..id = 0);
      }
    });
    await categoryRepo.ensureGeneralCategoryExists();

    runApp(
      MultiProvider(
        providers: [
          Provider.value(value: isar),
          Provider(create: (context) => EventRepository(isar)),
          Provider(create: (context) => categoryRepo),
          ChangeNotifierProvider(create: (context) => ThemeProvider(isar)),
        ],
        child: const MyApp(),
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      key: const ValueKey('helm_app_root'),
      title: 'Helm',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeProvider.textScaleFactor),
          ),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Helm'),
        '/settings': (context) => SettingPage(isar: context.read<Isar>()),
        '/add-event': (context) => AddEventPage(isar: context.read<Isar>()),
        '/categories': (context) => CategoryPage(isar: context.read<Isar>()),
        '/about': (context) => const AboutScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/account-settings': (context) => const AccountSettingsScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _sortByCategory = true;
  Id? _selectedCategoryId;
  List<dynamic> _flattenedList = [];
  bool _isLoading = true;
  Event? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _refreshList();
    context.read<EventRepository>().watchEvents().listen((_) => _refreshList());
  }

  Future<void> _refreshList() async {
    final newList = await context.read<EventRepository>().getDashboardList(
      sortByCategory: _sortByCategory,
      selectedCategoryId: _selectedCategoryId,
    );
    if (mounted) {
      setState(() {
        _flattenedList = newList;
        _isLoading = false;
      });
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _flattenedList.removeAt(oldIndex);
      _flattenedList.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isar = context.read<Isar>();
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return AppShell(
      title: widget.title,
      isar: isar,
      actions: [
        IconButton(
          icon: Icon(_sortByCategory ? Icons.sort_by_alpha : Icons.calendar_month),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _sortByCategory = !_sortByCategory);
            _refreshList();
          },
        ),
      ],
      floatingActionButton: _selectedEvent == null ? FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showAddTaskForm(context, isar: isar);
        },
        child: const Icon(Icons.add),
      ) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildVelocityDashboard(),
                if (_sortByCategory) _buildCategoryFilterDropdown(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _flattenedList.isEmpty 
                        ? const DashboardEmptyState()
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _flattenedList.length,
                            onReorder: _handleReorder,
                            proxyDecorator: (child, index, animation) => WobbleDecorator(child: child),
                            itemBuilder: (context, index) {
                              final item = _flattenedList[index];
                              if (item is String) {
                                return CategoryHeaderRow(
                                  key: ValueKey('header_$item'),
                                  categoryName: item,
                                  onAddPressed: () => showAddTaskForm(context, isar: isar, category: item),
                                );
                              }
                              final event = item as Event;
                              return TaskItemCard(
                                key: ValueKey('task_${event.id}'),
                                event: event, 
                                index: index,
                                onTap: () {
                                  if (isDesktop) {
                                    setState(() => _selectedEvent = event);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TaskDetailScreen(event: event, isar: isar),
                                      ),
                                    );
                                  }
                                },
                                onDismiss: (direction) => _handleDismiss(event, direction, index),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          
          // Side Panel (Desktop only)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: (isDesktop && _selectedEvent != null) ? 400 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
            ),
            child: _selectedEvent == null 
                ? const SizedBox.shrink()
                : TaskDetailContent(
                    key: ValueKey('detail_${_selectedEvent!.id}'),
                    event: _selectedEvent!, 
                    isar: isar,
                    onClose: () => setState(() => _selectedEvent = null),
                    useHero: false,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDismiss(Event event, DismissDirection direction, int index) async {
    final eventRepo = context.read<EventRepository>();
    final backupItem = event;
    final originalIndex = index;

    setState(() {
      _flattenedList.removeAt(originalIndex);
    });

    if (direction == DismissDirection.startToEnd) {
      await eventRepo.updateStatus(event, Status.done);
    } else {
      await event.categories.load();
      final categoryIds = event.categories.map((c) => c.id).toList();
      await eventRepo.deleteEvent(event.id);

      if (mounted) {
        _showUndoSnackBar(backupItem, categoryIds, originalIndex);
      }
    }
  }

  void _showUndoSnackBar(Event backupItem, List<Id> categoryIds, int originalIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final isar = context.read<Isar>();
    final eventRepo = context.read<EventRepository>();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: colorScheme.surfaceVariant,
        content: Text(
          'Task "${backupItem.title}" deleted',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: colorScheme.onSurfaceVariant,
          onPressed: () async {
            setState(() {
              _flattenedList.insert(originalIndex, backupItem);
            });

            final restored = Event()
              ..title = backupItem.title
              ..description = backupItem.description
              ..dateTime = backupItem.dateTime
              ..status = backupItem.status
              ..priority = backupItem.priority
              ..assignees = List.from(backupItem.assignees);
            
            final selectedCategories = <model.Category>[];
            for (final catId in categoryIds) {
              final cat = await isar.categorys.get(catId);
              if (cat != null) selectedCategories.add(cat);
            }
            await eventRepo.saveEvent(restored, selectedCategories);
          },
        ),
      ),
    );
  }

  Widget _buildVelocityDashboard() {
    final eventRepo = context.read<EventRepository>();

    return FutureBuilder<List<Event>>(
      future: eventRepo.getEventsForToday(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final todayTasks = snapshot.data!;
        return VelocityDashboardCard(
          totalTasksToday: todayTasks.length,
          completedTasksToday: todayTasks.where((t) => t.status == Status.done).length,
        );
      },
    );
  }

  Widget _buildCategoryFilterDropdown() {
    return StreamBuilder<List<model.Category>>(
      stream: context.read<CategoryRepository>().watchCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: DropdownButtonFormField<Id?>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Filter Category', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ...snapshot.data!.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            ],
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategoryId = v);
              _refreshList();
            },
          ),
        );
      },
    );
  }
}

class WobbleDecorator extends StatefulWidget {
  final Widget child;
  const WobbleDecorator({super.key, required this.child});

  @override
  State<WobbleDecorator> createState() => _WobbleDecoratorState();
}

class _WobbleDecoratorState extends State<WobbleDecorator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat(reverse: true);
    
    // Trigger heavy haptic feedback on pickup
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: (_controller.value - 0.5) * 0.04, // Oscillates between -0.02 and 0.02 radians
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    color: Colors.black54,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

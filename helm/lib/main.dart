import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/event.dart';
import 'models/category.dart' as model;
import 'models/settings.dart';
import 'models/unified_task.dart';

import 'repositories/task_repository.dart';
import 'services/invite_service.dart';
import 'services/task_service.dart';
import 'services/navigation_provider.dart';
import 'services/hive_database.dart';
import 'services/ai_service.dart';
import 'providers/task_provider.dart';

import 'widgets/task_item_card.dart';
import 'widgets/empty_states.dart';
import 'widgets/velocity_dashboard.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/category_chip_bar.dart';
import 'widgets/legal_dialog.dart';
import 'widgets/command_bar.dart';

import 'auth_screen.dart';
import 'settings_page.dart';
import 'add_event_page.dart';
import 'category_page.dart';
import 'about_page.dart';
import 'task_detail_page.dart';
import 'onboarding_page.dart';
import 'account_settings_page.dart';
import 'community_list_view.dart';
import 'community_manage_page.dart';
import 'app_shell.dart';
import 'notification_service.dart';
import 'theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  debugPrint('INIT: Starting Supabase...');
  await Supabase.initialize(
    url: 'https://eknzdxexfcfdmqvbyvxt.supabase.co', 
    anonKey: 'sb_publishable_fUoY96CXli7DwbZayu8pFQ_4yExvoJg',
  );

  debugPrint('INIT: Starting InviteService...');
  unawaited(InviteService().init());
  
  debugPrint('INIT: Starting Hive...');
  await HiveDatabase.init();
  debugPrint('INIT: Hive Started.');

  try {
    debugPrint('INIT: Starting Notifications...');
    await NotificationService().init();
    debugPrint('INIT: Notifications Started.');
    
    Isar? isar;
    if (!kIsWeb) {
      try {
        debugPrint('INIT: Opening Isar migration bridge...');
        final dir = await getApplicationDocumentsDirectory();
        isar = await Isar.open(
          [EventSchema, model.CategorySchema, SettingsSchema],
          directory: dir.path,
        );
        debugPrint('INIT: Isar bridge opened.');
      } catch (e) {
        debugPrint('INIT: Skipping Isar bridge (Incompatible/Missing): $e');
      }
    }

    final TaskRepository taskRepo = TaskRepository();
    final TaskProvider taskProvider = TaskProvider(isar: isar);

    runApp(
      MultiProvider(
        providers: [
          Provider<TaskRepository>.value(value: taskRepo),
          Provider<TaskService>(create: (context) => TaskService()),
          Provider<AiService>(create: (context) => AiService()),
          ChangeNotifierProvider<ThemeProvider>(create: (context) => ThemeProvider()),
          ChangeNotifierProvider<NavigationProvider>(create: (context) => NavigationProvider()),
          ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
      } else {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
      }
    });

    // Check for legal consent on boot
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLegal());
  }

  Future<void> _checkLegal() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    if (tp.settings.legalAccepted != true) {
      final bool? accepted = await showDialog<bool>(
        context: _navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => const LegalDialog(),
      );

      if (accepted == true) {
        await tp.acceptLegal();
      } else {
        // Exit app if declined
        await SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      initialRoute: Supabase.instance.client.auth.currentSession == null ? '/auth' : '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/manage-community') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CommunityManagePage(
              communityId: args['id'],
              communityName: args['name'],
            ),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const MyHomePage(title: 'Helm'),
        '/auth': (context) => const AuthScreen(),
        '/settings': (context) => const SettingPage(),
        '/add-event': (context) => const AddEventPage(),
        '/categories': (context) => const CategoryPage(),
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
  UnifiedTask? _selectedTask;

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final taskService = context.read<TaskService>();
    final taskProvider = context.watch<TaskProvider>();
    
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    Widget body;
    String title = 'Helm';
    List<Widget> appBarActions = [];

    if (navProvider.selectedIndex == 0) {
      title = 'Personal Tasks';
      body = _buildPersonalTasksView(isDesktop, taskProvider);
    } else {
      if (navProvider.selectedCommunityId != null) {
        title = 'Community Workspace';
        appBarActions = [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/manage-community',
                arguments: {
                  'id': navProvider.selectedCommunityId,
                  'name': navProvider.selectedCommunityName ?? 'Community', 
                },
              );
            },
            tooltip: 'Manage Members',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => navProvider.selectCommunity(null),
          ),
        ];
        body = _buildSupabaseTaskStream(taskService, navProvider.selectedCommunityId!, taskProvider, isDesktop);
      } else {
        title = 'Communities';
        body = const CommunityListView();
      }
    }

    return AppShell(
      title: title,
      actions: appBarActions,
      floatingActionButton: _selectedTask == null ? FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showAddTaskForm(
            context, 
            initialCommunityId: navProvider.selectedCommunityId,
          );
        },
        child: const Icon(Icons.add),
      ) : null,
      child: Row(
        children: [
          Expanded(
            child: body,
          ),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: (isDesktop && _selectedTask != null) ? 400 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
            ),
            child: _selectedTask == null 
                ? const SizedBox.shrink()
                : TaskDetailContent(
                    key: ValueKey('detail_${_selectedTask!.id}'),
                    task: _selectedTask!, 
                    onClose: () => setState(() => _selectedTask = null),
                    useHero: false,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTasksView(bool isDesktop, TaskProvider taskProvider) {
    final tasks = taskProvider.personalTasks;
    return Column(
      children: [
        _buildVelocityDashboard(),
        CategoryChipBar(
          selectedCategoryId: taskProvider.selectedCategoryId,
          onSelected: (id) => taskProvider.selectCategory(id),
        ),
        Expanded(
          child: tasks.isEmpty 
          ? const DashboardEmptyState()
          : ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: tasks.length,
            onReorder: (oldIndex, newIndex) {
              taskProvider.reorderTasks(oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) => WobbleDecorator(child: child),
            buildDefaultDragHandles: false, // We will provide our own handle
            itemBuilder: (context, index) {
              final unifiedTask = tasks[index];
              return TaskItemCard(
                key: ValueKey('p_task_${unifiedTask.id}'),
                task: unifiedTask,
                index: index,
                onTap: () {
                  if (isDesktop) {
                    setState(() => _selectedTask = unifiedTask);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailScreen(task: unifiedTask),
                      ),
                    );
                  }
                },
                onToggle: () => taskProvider.toggleTask(unifiedTask),
                onDismiss: (direction) async {
                  final String id = unifiedTask.id;
                  await taskProvider.deleteTask(id);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Task deleted'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () => taskProvider.undoDelete(),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: CommandBarWidget(),
        ),
      ],
    );
  }

  Widget _buildSupabaseTaskStream(TaskService taskService, String communityId, TaskProvider taskProvider, bool isDesktop) {
    return StreamBuilder<List<UnifiedTask>>(
      stream: taskProvider.streamCommunityTasks(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) return const CommunityEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final unifiedTask = tasks[index];
            return TaskItemCard(
              key: ValueKey('s_task_${unifiedTask.id}'),
              task: unifiedTask,
              index: index,
              onTap: () {
                if (isDesktop) {
                  setState(() => _selectedTask = unifiedTask);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(task: unifiedTask),
                    ),
                  );
                }
              },
              onToggle: () => taskProvider.toggleTask(unifiedTask),
              onDismiss: (direction) async {
                final String id = unifiedTask.id;
                await taskProvider.deleteTask(id);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Task deleted'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () => taskProvider.undoDelete(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVelocityDashboard() {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.personalTasks;
    final now = DateTime.now();
    final todayTasks = tasks.where((t) {
      return t.dateTime.year == now.year &&
             t.dateTime.month == now.month &&
             t.dateTime.day == now.day;
    }).toList();

    return VelocityDashboardCard(
      totalTasksToday: todayTasks.length,
      completedTasksToday: todayTasks.where((t) => t.isCompleted).length,
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
          angle: (_controller.value - 0.5) * 0.04,
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

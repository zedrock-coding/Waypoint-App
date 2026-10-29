import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/unified_task.dart';

import 'config/app_config.dart';
import 'services/invite_service.dart';
import 'services/navigation_provider.dart';
import 'services/hive_database.dart';
import 'services/ai_service.dart';
import 'services/sync_service.dart';
import 'services/task_rules.dart';
import 'providers/task_provider.dart';

import 'widgets/task_item_card.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/empty_states.dart';
import 'widgets/velocity_dashboard.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/category_chip_bar.dart';
import 'widgets/legal_dialog.dart';
import 'widgets/command_bar.dart';
import 'calendar_page.dart';

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

  if (!AppConfig.isSupabaseConfigured) {
    debugPrint('INIT: Supabase configuration missing.');
    runApp(const _MisconfiguredApp());
    return;
  }

  debugPrint('INIT: Starting Supabase...');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  debugPrint('INIT: Starting InviteService...');
  unawaited(InviteService().init());
  
  debugPrint('INIT: Starting Hive...');
  await HiveDatabase.init();
  debugPrint('INIT: Hive Started.');

  debugPrint('INIT: Starting SyncService...');
  SyncService().init();

  try {
    debugPrint('INIT: Starting Notifications...');
    await NotificationService().init();
    debugPrint('INIT: Notifications Started.');
    
    final TaskProvider taskProvider = TaskProvider();

    runApp(
      MultiProvider(
        providers: [
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

class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waypoint',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              AppConfig.misconfiguredMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
      } else {
        if (!AuthScreen.isCompletingSetup) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    });

    InviteService().onInviteEvent.listen((event) {
      if (event.status == InviteStatus.success) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(event.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF88C0A4),
          ),
        );
      } else if (event.status == InviteStatus.alreadyMember || event.status == InviteStatus.failed) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(event.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLegal());
  }

  Future<void> _checkLegal() async {
    if (!mounted) return;
    try {
      final tp = Provider.of<ThemeProvider>(context, listen: false);
      
      final session = Supabase.instance.client.auth.currentSession;
      final bool hasSeenOnboarding = tp.hasSeenOnboarding;

      // If already onboarded, skip legal and tutorial
      if (hasSeenOnboarding && tp.settings.legalAccepted == true) {
        if (session == null) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (r) => false);
        }
        return;
      }

      // 1. Legal Check
      while (tp.settings.legalAccepted != true) {
        final bool? accepted = await showDialog<bool>(
          context: _navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => const LegalDialog(isFirstLaunch: true),
        );

        if (accepted == true) {
          await tp.acceptLegal();
          break;
        }

        if (!kIsWeb) {
          await SystemNavigator.pop();
          return;
        }
      }

      // 2. Onboarding Check
      if (!tp.hasSeenOnboarding) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboarding', (r) => false);
      } else if (session == null) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (r) => false);
      }
    } catch (e) {
      debugPrint('Launch check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      key: const ValueKey('waypoint_app_root'),
      title: 'Waypoint',
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
        '/': (context) => const MyHomePage(title: 'Waypoint'),
        '/auth': (context) => const AuthScreen(),
        '/settings': (context) => const SettingPage(),
        '/calendar': (context) => const CalendarPage(),
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
  /// Only the id is kept; the task itself is resolved from the provider/stream on
  /// every build. Holding a `UnifiedTask` meant the desktop panel showed a
  /// frozen snapshot that ignored every later edit until it was reopened.
  String? _selectedTaskId;
  String? _detailScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestNotificationPermissionOnce(),
    );
  }

  /// Android 13+ will not show a notification until the runtime permission is
  /// granted, and nothing used to ask outside the dashboard card — so reminders
  /// silently never appeared for most installs. Ask once, after sign-in, with a
  /// short rationale, then persist the decision.
  Future<void> _requestNotificationPermissionOnce() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (!Hive.isBoxOpen('settings')) return;

    final settingsBox = Hive.box('settings');
    if (settingsBox.get('notification_permission_requested') == true) return;

    if (!mounted) return;
    final wantsReminders = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable task reminders?'),
        content: const Text(
          'Waypoint can notify you before a task is due. Reminders are scheduled on '
          'this device only, and you can turn them off later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NOT NOW'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ENABLE'),
          ),
        ],
      ),
    );

    if (wantsReminders == true) {
      await NotificationService().requestPermissions();
    }
    await settingsBox.put('notification_permission_requested', true);
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final taskProvider = context.watch<TaskProvider>();

    // A selected task belongs to one scope (personal tab, or one community).
    // Changing tab or community drops the selection instead of showing a task
    // from somewhere else.
    final String scope =
        '${navProvider.selectedIndex}:${navProvider.selectedCommunityId ?? ''}';
    if (_detailScope != null && _detailScope != scope) {
      _selectedTaskId = null;
    }
    _detailScope = scope;
    
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    Widget body;
    String title = 'Waypoint';
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
        body = _buildSupabaseTaskStream(navProvider.selectedCommunityId!, taskProvider, isDesktop);
      } else {
        title = 'Communities';
        body = const CommunityListView();
      }
    }

    return AppShell(
      title: title,
      actions: appBarActions,
      floatingActionButton: _selectedTaskId == null ? FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showAddTaskForm(
            context, 
            initialCommunityId: navProvider.selectedCommunityId,
          );
        },
        child: const Icon(Icons.add),
      ) : null,
      bottomWidget: const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: CommandBarWidget(),
      ),
      child: Row(
        children: [
          Expanded(
            child: body,
          ),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: (isDesktop && _selectedTaskId != null) ? 400 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
            ),
            child: _buildDetailPanel(navProvider, taskProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(NavigationProvider nav, TaskProvider taskProvider) {
    final id = _selectedTaskId;
    if (id == null) return const SizedBox.shrink();

    Widget panel(UnifiedTask? task) {
      if (task == null) return const SizedBox.shrink();
      return TaskDetailContent(
        key: ValueKey('detail_${task.id}'),
        task: task,
        onClose: () => setState(() => _selectedTaskId = null),
        useHero: false,
      );
    }

    final communityId = nav.selectedCommunityId;
    if (nav.selectedIndex == 1 && communityId != null) {
      return StreamBuilder<List<UnifiedTask>>(
        stream: taskProvider.communityTasksStream(communityId),
        builder: (context, snapshot) {
          return panel(findTaskById(snapshot.data, id));
        },
      );
    }

    return panel(findTaskById(taskProvider.personalTasks, id));
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
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: tasks.length,
            onReorder: (oldIndex, newIndex) {
              taskProvider.reorderTasks(oldIndex, newIndex);
            },
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            proxyDecorator: (child, index, animation) => WobbleDecorator(child: child),
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final unifiedTask = tasks[index];
              return TaskItemCard(
                key: ValueKey('p_task_${unifiedTask.id}'),
                task: unifiedTask,
                index: index,
                onTap: () {
                  if (isDesktop) {
                    setState(() => _selectedTaskId = unifiedTask.id);
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
          ),
        ),
      ],
    );
  }

  Widget _buildSupabaseTaskStream(String communityId, TaskProvider taskProvider, bool isDesktop) {
    return StreamBuilder<List<UnifiedTask>>(
      stream: taskProvider.communityTasksStream(communityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) return CommunityEmptyState(communityId: communityId);

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final unifiedTask = tasks[index];
            return TaskItemCard(
              key: ValueKey('s_task_${unifiedTask.id}'),
              task: unifiedTask,
              index: index,
              onTap: () {
                if (isDesktop) {
                  setState(() => _selectedTaskId = unifiedTask.id);
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

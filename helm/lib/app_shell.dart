import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_voice_overlay.dart';
import 'widgets/task_search_delegate.dart';
import 'widgets/app_intents.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/notification_feed.dart';
import 'widgets/user_avatar.dart';
import 'widgets/waypoint_logo.dart';
import 'services/navigation_provider.dart';
import 'services/sync_service.dart';
import 'services/supabase_service.dart';
import 'providers/task_provider.dart';
import 'theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomWidget;

  const AppShell({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.bottomWidget,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  bool _showDesktopNotifications = false;
  final LayerLink _notificationLayerLink = LayerLink();
  bool _isSyncing = false;
  late final AnimationController _syncSpinController;
  List<Map<String, dynamic>> _communities = [];

  @override
  void initState() {
    super.initState();
    _syncSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadCommunities();
  }

  @override
  void dispose() {
    _syncSpinController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      final comms = await SupabaseService().fetchUserCommunities();
      if (mounted) {
        setState(() => _communities = comms);
      }
    } catch (_) {}
  }

  Future<void> _triggerManualSync(BuildContext context, TaskProvider taskProvider) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    _syncSpinController.repeat();
    try {
      final flushed = await SyncService().processSyncQueue(force: true);
      await taskProvider.loadRemoteTasks();
      await _loadCommunities();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              flushed > 0
                  ? 'Synced $flushed pending change${flushed == 1 ? '' : 's'}'
                  : 'All changes synced with cloud',
              style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurface),
            ),
            backgroundColor: AppTheme.surfaceContainerHigh,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e', style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.priorityUrgent)),
            backgroundColor: AppTheme.surfaceContainerHigh,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        _syncSpinController.stop();
        _syncSpinController.reset();
      }
    }
  }

  String _getUserDisplayName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'User';
    final metadata = user.userMetadata;
    final fullName = metadata?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'User';
  }

  String? _getUserAvatarUrl() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['avatar_url']?.toString();
  }

  void _showAIVoiceOverlay(BuildContext context, bool isDesktop) {
    if (!isDesktop) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => const AIVoiceOverlay(),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black45,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: AIVoiceOverlay(),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768; // Desktop threshold matching mockup md: breakpoint

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF): const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewTaskIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): const NewTaskIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space): const AIVoiceIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.space): const AIVoiceIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) => showSearch(context: context, delegate: CustomTaskSearchDelegate()),
          ),
          NewTaskIntent: CallbackAction<NewTaskIntent>(
            onInvoke: (_) => showAddTaskForm(context),
          ),
          AIVoiceIntent: CallbackAction<AIVoiceIntent>(
            onInvoke: (_) => _showAIVoiceOverlay(context, isDesktop),
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) {
              if (navProvider.currentView != WaypointNavView.today) {
                navProvider.setView(WaypointNavView.today);
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Row(
            children: [
              // 1. DESKTOP SIDEBAR (VISIBLE ON DESKTOP ONLY, HIDDEN ON MOBILE)
              if (isDesktop)
                _buildDesktopSidebar(context, navProvider, taskProvider),

              // 2. MAIN APPLICATION WORKSPACE
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Top Header Bar
                        _buildHeader(context, navProvider, taskProvider, isDesktop),

                        // Main Content View
                        Expanded(
                          child: widget.child,
                        ),
                      ],
                    ),

                    // Floating Command Bar
                    if (widget.bottomWidget != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: isDesktop ? 20 : 70, // Dock above mobile bottom bar
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 672),
                            child: widget.bottomWidget!,
                          ),
                        ),
                      ),

                    // Desktop Notifications Overlay
                    if (_showDesktopNotifications && isDesktop)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => setState(() => _showDesktopNotifications = false),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 56,
                                right: 24,
                                child: CompositedTransformFollower(
                                  link: _notificationLayerLink,
                                  showWhenUnlinked: false,
                                  offset: const Offset(-320, 48),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      width: 360,
                                      height: 480,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.surfaceVariant),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 16,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const NotificationFeedUI(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 3. MOBILE BOTTOM NAVIGATION DOCK (VISIBLE ON MOBILE ONLY, HIDDEN ON DESKTOP)
          bottomNavigationBar: isDesktop ? null : _buildMobileBottomDock(context, navProvider),
          floatingActionButton: widget.floatingActionButton,
        ),
      ),
    );
  }

  // --- 1. DESKTOP SIDEBAR ---
  Widget _buildDesktopSidebar(
    BuildContext context,
    NavigationProvider navProvider,
    TaskProvider taskProvider,
  ) {
    final activeCount = taskProvider.allActiveTasks.length;
    final inboxCount = taskProvider.tasksAssignedByOthers.length;
    final recurringCount = taskProvider.recurringTasks.length;

    return Container(
      width: 256,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: AppTheme.surfaceVariant, width: 1)),
      ),
      child: Column(
        children: [
          // Header / Brand Anchor
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => navProvider.setView(WaypointNavView.today),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      const WaypointLogo(size: 32),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waypoint',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Personal Workspace',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Add Button
                InkWell(
                  onTap: () => showAddTaskForm(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.mint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.add, size: 16, color: AppTheme.onMint),
                            SizedBox(width: 8),
                            Text(
                              'New Task',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onMint,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.onMint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            '⌘N',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onMint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'VIEWS',
                    style: AppTheme.monoStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                _buildSidebarNavItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Today',
                  count: '$activeCount',
                  isActive: navProvider.currentView == WaypointNavView.today,
                  onTap: () => navProvider.setView(WaypointNavView.today),
                ),

                _buildSidebarNavItem(
                  icon: Icons.inbox_rounded,
                  label: 'Inbox',
                  count: '$inboxCount',
                  isActive: navProvider.currentView == WaypointNavView.inbox,
                  onTap: () => navProvider.setView(WaypointNavView.inbox),
                ),

                _buildSidebarNavItem(
                  icon: Icons.repeat_rounded,
                  label: 'Recurring',
                  count: '$recurringCount',
                  isActive: navProvider.currentView == WaypointNavView.recurring,
                  onTap: () => navProvider.setView(WaypointNavView.recurring),
                ),

                _buildSidebarNavItem(
                  icon: Icons.event_rounded,
                  label: 'Schedule',
                  count: 'Today',
                  isActive: navProvider.currentView == WaypointNavView.schedule,
                  onTap: () => navProvider.setView(WaypointNavView.schedule),
                ),

                const SizedBox(height: 16),

                // Groups & Workspaces Section Header (Clickable to open Communities Overview!)
                InkWell(
                  onTap: () => navProvider.setView(WaypointNavView.communities),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GROUPS & WORKSPACES',
                          style: AppTheme.monoStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mint,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.mint),
                      ],
                    ),
                  ),
                ),

                if (_communities.isEmpty)
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                    onTap: () => navProvider.setView(WaypointNavView.communities),
                    leading: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppTheme.mint),
                    title: const Text(
                      '+ Add or Join Workspace',
                      style: TextStyle(fontSize: 12, color: AppTheme.mint, fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  ..._communities.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final comm = entry.value;
                    final name = comm['name']?.toString() ?? 'Workspace';
                    final id = comm['id']?.toString();
                    const colors = [
                      AppTheme.mint,
                      AppTheme.priorityHigh,
                      AppTheme.priorityLow,
                      AppTheme.priorityUrgent,
                      AppTheme.priorityMedium,
                    ];
                    final dotColor = colors[idx % colors.length];
                    final isSelected = navProvider.selectedCommunityId == id;
                    return _buildWorkspaceNavItem(
                      name: name,
                      dotColor: dotColor,
                      isSelected: isSelected,
                      onTap: () {
                        navProvider.selectCommunity(id, name: name);
                        navProvider.setView(WaypointNavView.today);
                      },
                    );
                  }),
              ],
            ),
          ),

          // Sidebar Footer Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    _triggerManualSync(context, taskProvider);
                    _showSyncDiagnosticsModal(context, taskProvider);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: ValueListenableBuilder<int>(
                    valueListenable: SyncService().pendingChanges,
                    builder: (context, pendingCount, _) {
                      final hasPending = pendingCount > 0;
                      final statusColor = hasPending ? AppTheme.priorityMedium : AppTheme.mint;
                      final statusText = _isSyncing
                          ? 'SYNCING...'
                          : (hasPending ? '$pendingCount PENDING' : 'ALL CHANGES SAVED');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.surfaceVariant),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusText,
                                  style: AppTheme.monoStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Cloud Active',
                              style: AppTheme.monoStyle(
                                fontSize: 9,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => navProvider.setView(WaypointNavView.settings),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: const [
                          Icon(Icons.tune_rounded, size: 15, color: AppTheme.onSurfaceVariant),
                          SizedBox(width: 6),
                          Text(
                            'Settings',
                            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Offline Ready',
                      style: AppTheme.monoStyle(
                        fontSize: 9.5,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required String count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.surfaceContainer : Colors.transparent,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
        border: isActive
            ? const Border(left: BorderSide(color: AppTheme.mint, width: 2))
            : null,
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        onTap: onTap,
        leading: Icon(
          icon,
          size: 17,
          color: isActive ? AppTheme.mint : AppTheme.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppTheme.mint : AppTheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.mint.withValues(alpha: 0.2) : AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isActive ? AppTheme.mint.withValues(alpha: 0.3) : AppTheme.surfaceVariant,
            ),
          ),
          child: Text(
            count,
            style: AppTheme.monoStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.mint : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceNavItem({
    required String name,
    required Color dotColor,
    String? count,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isSelected ? const Border(left: BorderSide(color: AppTheme.mint, width: 2)) : null,
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
        onTap: onTap,
        leading: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.mint : AppTheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: count != null
            ? Text(
                count,
                style: AppTheme.monoStyle(
                  fontSize: 10,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
    );
  }

  void _showSyncDiagnosticsModal(BuildContext context, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pending = SyncService().pendingCount;
          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: AppTheme.surfaceVariant),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            actionsPadding: const EdgeInsets.all(16),
            title: Row(
              children: [
                const Icon(Icons.sync_rounded, color: AppTheme.mint, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sync Diagnostics',
                  style: AppTheme.monoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagRow('Network / Cloud', 'Cloud Active', AppTheme.mint),
                const SizedBox(height: 8),
                _buildDiagRow('Pending Changes', '$pending', pending > 0 ? AppTheme.priorityMedium : AppTheme.mint),
                const SizedBox(height: 8),
                _buildDiagRow('Local Tasks Mirror', '${taskProvider.allActiveTasks.length} active', AppTheme.onSurfaceVariant),
                const SizedBox(height: 8),
                _buildDiagRow('Sync Strategy', 'Local-First (LWW)', AppTheme.onSurfaceVariant),
                const Divider(color: AppTheme.surfaceVariant, height: 20),
                Text(
                  'Local mutations are queued in Hive and sent to Supabase automatically.',
                  style: AppTheme.monoStyle(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Close', style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _triggerManualSync(context, taskProvider);
                  if (ctx.mounted) setModalState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.onMint),
                label: const Text('Flush Queue Now', style: TextStyle(fontSize: 12, color: AppTheme.onMint)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: AppTheme.onMint,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        Text(value, style: AppTheme.monoStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  // --- 2. TOP HEADER ---
  Widget _buildHeader(
    BuildContext context,
    NavigationProvider navProvider,
    TaskProvider taskProvider,
    bool isDesktop,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand (Mobile) / Search (Desktop)
          if (!isDesktop) ...[
            InkWell(
              onTap: () => navProvider.setView(WaypointNavView.today),
              child: Row(
                children: [
                  const WaypointLogo(size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Waypoint',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 14,
                    color: AppTheme.surfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getViewTitle(navProvider.currentView),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Desktop Omni Search Bar
            InkWell(
              onTap: () => showSearch(context: context, delegate: CustomTaskSearchDelegate()),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 280,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: AppTheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search tasks, notes...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '⌘K',
                        style: AppTheme.monoStyle(
                          fontSize: 9.5,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Right Controls Cluster
          Row(
            children: [
              // Add Task Button
              ElevatedButton.icon(
                onPressed: () => showAddTaskForm(context),
                icon: const Icon(Icons.add, size: 16, color: AppTheme.onMint),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isDesktop ? 'Add Task' : 'Add',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onMint,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.onMint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          '⌘N',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onMint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: AppTheme.onMint,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),

              const SizedBox(width: 8),

              // AI Voice Assistant Button
              OutlinedButton.icon(
                onPressed: () => _showAIVoiceOverlay(context, isDesktop),
                icon: const Icon(Icons.mic, size: 16, color: AppTheme.mint),
                label: isDesktop
                    ? Text('Voice', style: AppTheme.monoStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.mint))
                    : const SizedBox.shrink(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.surfaceVariant),
                  backgroundColor: AppTheme.surfaceContainer,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),

              const SizedBox(width: 8),

              // Interactive Sync Button (Desktop and Mobile)
              ValueListenableBuilder<int>(
                valueListenable: SyncService().pendingChanges,
                builder: (context, pendingCount, _) {
                  Widget iconWidget;
                  if (_isSyncing) {
                    iconWidget = RotationTransition(
                      turns: _syncSpinController,
                      child: const Icon(Icons.sync_rounded, size: 18, color: AppTheme.mint),
                    );
                  } else if (pendingCount > 0) {
                    iconWidget = Badge(
                      label: Text('$pendingCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.priorityMedium,
                      textColor: Colors.black87,
                      child: const Icon(Icons.sync_rounded, size: 18, color: AppTheme.priorityMedium),
                    );
                  } else {
                    iconWidget = const Icon(Icons.sync_rounded, size: 18, color: AppTheme.onSurfaceVariant);
                  }

                  return IconButton(
                    icon: iconWidget,
                    tooltip: _isSyncing
                        ? 'Syncing changes...'
                        : (pendingCount > 0
                            ? '$pendingCount pending change${pendingCount == 1 ? '' : 's'} (click to sync)'
                            : 'Sync with cloud'),
                    hoverColor: AppTheme.surfaceContainer,
                    onPressed: _isSyncing ? null : () => _triggerManualSync(context, taskProvider),
                  );
                },
              ),

              const SizedBox(width: 4),

              // Notifications Bell with LayerLink Target
              CompositedTransformTarget(
                link: _notificationLayerLink,
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  color: AppTheme.onSurfaceVariant,
                  hoverColor: AppTheme.surfaceContainer,
                  tooltip: 'Notifications',
                  onPressed: () {
                    if (isDesktop) {
                      setState(() => _showDesktopNotifications = !_showDesktopNotifications);
                    } else {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: const NotificationFeedUI(),
                        ),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(width: 4),

              // Dynamic User Profile Avatar (Desktop and Mobile)
              InkWell(
                onTap: () => navProvider.setView(WaypointNavView.account),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Tooltip(
                    message: 'Account (${_getUserDisplayName()})',
                    child: UserAvatar(
                      fullName: _getUserDisplayName(),
                      avatarUrl: _getUserAvatarUrl(),
                      radius: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. MOBILE BOTTOM NAVIGATION DOCK ---
  Widget _buildMobileBottomDock(BuildContext context, NavigationProvider navProvider) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileDockItem(
            icon: Icons.calendar_today_rounded,
            label: 'Today',
            isActive: navProvider.currentView == WaypointNavView.today,
            onTap: () => navProvider.setView(WaypointNavView.today),
          ),
          _buildMobileDockItem(
            icon: Icons.inbox_rounded,
            label: 'Inbox',
            isActive: navProvider.currentView == WaypointNavView.inbox,
            onTap: () => navProvider.setView(WaypointNavView.inbox),
          ),

          // Central FAB Add button
          GestureDetector(
            onTap: () => showAddTaskForm(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.mint,
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.mint.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: AppTheme.onMint, size: 22),
            ),
          ),

          _buildMobileDockItem(
            icon: Icons.repeat_rounded,
            label: 'Repeat',
            isActive: navProvider.currentView == WaypointNavView.recurring,
            onTap: () => navProvider.setView(WaypointNavView.recurring),
          ),
          _buildMobileDockItem(
            icon: Icons.event_rounded,
            label: 'Schedule',
            isActive: navProvider.currentView == WaypointNavView.schedule,
            onTap: () => navProvider.setView(WaypointNavView.schedule),
          ),
          _buildMobileDockItem(
            icon: Icons.tune_rounded,
            label: 'Settings',
            isActive: navProvider.currentView == WaypointNavView.settings,
            onTap: () => navProvider.setView(WaypointNavView.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDockItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppTheme.mint : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.mint : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getViewTitle(WaypointNavView view) {
    switch (view) {
      case WaypointNavView.today:
        return 'Today';
      case WaypointNavView.inbox:
        return 'Inbox';
      case WaypointNavView.recurring:
        return 'Recurring';
      case WaypointNavView.schedule:
        return 'Schedule';
      case WaypointNavView.settings:
        return 'Settings';
      case WaypointNavView.communities:
        return 'Workspaces';
      case WaypointNavView.account:
        return 'Account';
    }
  }
}

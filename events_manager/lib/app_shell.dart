import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'models/category.dart';
import 'ai_voice_overlay.dart';
import 'repositories/category_repository.dart';
import 'widgets/task_search_delegate.dart';
import 'widgets/app_intents.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/ai_text_drawer.dart';
import 'widgets/notification_feed.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Isar isar;

  const AppShell({
    super.key,
    required this.child,
    required this.title,
    required this.isar,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _showDesktopNotifications = false;
  final LayerLink _notificationLayerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    final categoryRepo = context.read<CategoryRepository>();
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Helper functions moved inside State
    Widget navItem({
      required IconData icon,
      required String label,
      required String route,
      bool isSubItem = false,
    }) {
      final bool isActive = currentRoute == route;
      
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isSubItem ? 8 : 12, vertical: 4),
        child: InkWell(
          onTap: () {
            if (isActive) {
              if (!isDesktop) Navigator.pop(context);
              return;
            }
            if (!isDesktop) Navigator.pop(context);
            Navigator.pushReplacementNamed(context, route);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSubItem ? 8 : 12),
            decoration: BoxDecoration(
              color: isActive ? colorScheme.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                  size: isSubItem ? 18 : 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: isSubItem ? 14 : 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget sidebarContent = SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  'assets/icon/icon.png',
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => 
                      Icon(Icons.shield, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Helm',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          navItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/'),
          
          StreamBuilder<List<Category>>(
            stream: categoryRepo.watchRootCategories(),
            builder: (context, snapshot) {
              final rootCategories = snapshot.data ?? [];
              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: colorScheme.onSurface,
                  collapsedIconColor: colorScheme.onSurface,
                  leading: Icon(Icons.hub_rounded, color: colorScheme.onSurface.withOpacity(0.6), size: 22),
                  title: Text('Communities', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 15)),
                  childrenPadding: const EdgeInsets.only(left: 24),
                  children: rootCategories.map((cat) => navItem(
                    icon: cat.isAdmin ? Icons.verified_user_rounded : Icons.label_outline_rounded, 
                    label: cat.name, 
                    route: '/categories/${cat.id}', 
                    isSubItem: true
                  )).toList(),
                ),
              );
            }
          ),
          
          navItem(icon: Icons.category_rounded, label: 'Manage All', route: '/categories'),
          navItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Divider(color: Colors.white10),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): const NewTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.space, control: true): const AIVoiceIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): const NewTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.space, meta: true): const AIVoiceIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewTaskIntent: CallbackAction<NewTaskIntent>(
            onInvoke: (intent) => showAddTaskForm(context, isar: widget.isar),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) => showSearch(
              context: context,
              delegate: CustomTaskSearchDelegate(),
            ),
          ),
          AIVoiceIntent: CallbackAction<AIVoiceIntent>(
            onInvoke: (intent) => _showAIVoiceOverlay(context, isDesktop),
          ),
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            top: true,
            child: GestureDetector(
              onTap: () {
                if (_showDesktopNotifications) setState(() => _showDesktopNotifications = false);
              },
              child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              drawer: isDesktop ? null : Drawer(
                backgroundColor: colorScheme.surface,
                child: sidebarContent,
              ),
              endDrawer: const AITextDrawer(),
              body: Stack(
                children: [
                  Row(
                    children: [
                      if (isDesktop) 
                        Container(
                          width: 280, 
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border(right: BorderSide(color: colorScheme.outlineVariant, width: 1)),
                          ),
                          child: sidebarContent
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                children: [
                                  if (!isDesktop)
                                    Builder(
                                      builder: (context) => IconButton(
                                        icon: Icon(Icons.menu, color: colorScheme.onSurface),
                                        onPressed: () => Scaffold.of(context).openDrawer(),
                                      ),
                                    ),
                                  if (!isDesktop) const SizedBox(width: 8),
                                  Text(
                                    widget.title,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.7)),
                                    onPressed: () => showSearch(
                                      context: context,
                                      delegate: CustomTaskSearchDelegate(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                                    onPressed: () => _showAIVoiceOverlay(context, isDesktop),
                                  ),
                                  Builder(
                                    builder: (context) => IconButton(
                                      icon: Icon(Icons.keyboard_alt_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
                                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                                    ),
                                  ),
                                  CompositedTransformTarget(
                                    link: _notificationLayerLink,
                                    child: IconButton(
                                      icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface.withOpacity(0.7)),
                                      onPressed: () {
                                        if (isDesktop) {
                                          setState(() => _showDesktopNotifications = !_showDesktopNotifications);
                                        } else {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => const NotificationFeedUI(),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.account_circle_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
                                    offset: const Offset(0, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    onSelected: (value) {
                                      if (value == 'settings') {
                                        Navigator.pushNamed(context, '/account-settings');
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: Icon(Icons.manage_accounts), title: Text('Account Settings'))),
                                      const PopupMenuItem(value: 'communities', child: ListTile(dense: true, leading: Icon(Icons.hub), title: Text('Manage Communities'))),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout, color: Colors.red), title: Text('Log Out', style: TextStyle(color: Colors.red)))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: widget.child),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Desktop Notification Overlay ( Snappy alternative to showMenu )
                  if (isDesktop && _showDesktopNotifications)
                    Positioned(
                      top: 60, // Positioned below header
                      right: 20,
                      child: CompositedTransformFollower(
                        link: _notificationLayerLink,
                        showWhenUnlinked: false,
                        offset: const Offset(-310, 45),
                        child: const NotificationFeedUI(),
                      ),
                    ),
                ],
              ),
              floatingActionButton: widget.floatingActionButton,
            ),
          ),
        ),
      ),
    ),
  );
}

  void _showAIVoiceOverlay(BuildContext context, bool isDesktop) {
    if (!isDesktop) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent, // Let our widget handle colors
        isScrollControlled: true,
        builder: (ctx) => const AIVoiceOverlay(),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: const Dialog(
              backgroundColor: Colors.transparent,
              child: AIVoiceOverlay(),
            ),
          ),
        ),
      );
    }
  }

  void _showNotificationMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(Offset(0, button.size.height));

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 300, // Offset to the left to align with right-hand button
        position.dy + 10,
        MediaQuery.of(context).size.width - position.dx,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
      items: [
        const PopupMenuItem(
          enabled: false,
          child: NotificationFeedUI(),
        ),
      ],
    );
  }
}

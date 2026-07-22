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

class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final categoryRepo = context.read<CategoryRepository>();
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // ... (rest of the helper functions remain similar but using proper routing)
    
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
        // Windows/Linux (Control)
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): const NewTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.space, control: true): const AIVoiceIntent(),
        // macOS (Meta)
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): const NewTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.space, meta: true): const AIVoiceIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewTaskIntent: CallbackAction<NewTaskIntent>(
            onInvoke: (intent) => showAddTaskForm(context, isar: isar),
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
            child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            drawer: isDesktop ? null : Drawer(
              backgroundColor: colorScheme.surface,
              child: sidebarContent,
            ),
            endDrawer: isDesktop ? null : _buildNotificationEndDrawer(context),
            body: Row(
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
                              title,
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
                            IconButton(
                              icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface.withOpacity(0.7)),
                              onPressed: () {
                                if (isDesktop) {
                                  _showNotificationMenu(context);
                                } else {
                                  Scaffold.of(context).openEndDrawer();
                                }
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.account_circle_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
                              offset: const Offset(0, 45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (value) {},
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
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: floatingActionButton,
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
    final Offset position = button.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy + 60, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        const PopupMenuItem(child: ListTile(dense: true, title: Text("Team meeting in 10 mins"), subtitle: Text("Sync on Project Helm"))),
        const PopupMenuItem(child: ListTile(dense: true, title: Text("Marketing tasks updated"), subtitle: Text("3 new items added"))),
      ],
    );
  }

  Widget _buildNotificationEndDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const DrawerHeader(child: Center(child: Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Expanded(
            child: ListView(
              children: const [
                ListTile(title: Text("Team meeting in 10 mins"), subtitle: Text("Sync on Project Helm")),
                ListTile(title: Text("Marketing tasks updated"), subtitle: Text("3 new items added")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

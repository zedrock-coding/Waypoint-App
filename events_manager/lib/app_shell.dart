import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_voice_overlay.dart';
import 'widgets/task_search_delegate.dart';
import 'widgets/app_intents.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/ai_text_drawer.dart';
import 'widgets/notification_feed.dart';
import 'services/supabase_service.dart';
import 'services/navigation_provider.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppShell({
    super.key,
    required this.child,
    required this.title,
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
    final supabaseService = SupabaseService();
    final navProvider = context.watch<NavigationProvider>();
    
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    Widget navItem({
      required IconData icon,
      required String label,
      required String route,
      String? communityId,
      bool isSubItem = false,
    }) {
      final bool isCurrentRoute = ModalRoute.of(context)?.settings.name == route;
      final bool isActive = communityId != null 
          ? navProvider.selectedCommunityId == communityId
          : (navProvider.currentRoute == route || (route == '/' && isCurrentRoute));
      
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isSubItem ? 8 : 12, vertical: 4),
        child: InkWell(
          onTap: () {
            if (communityId != null) {
              navProvider.selectCommunity(communityId, name: label);
            } else {
              navProvider.setRoute(route);
            }
            
            if (!isDesktop) Navigator.pop(context);
            
            if (!isCurrentRoute) {
              // If we are selecting a community, we must go back to the dashboard route ('/')
              final String targetRoute = communityId != null ? '/' : route;
              Navigator.pushReplacementNamed(context, targetRoute);
            }
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

    Widget sidebarContent = Column(
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
              const Flexible(
                child: Text(
                  'Helm',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                navItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/'),
                
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: supabaseService.fetchUserCommunities(),
                  builder: (context, snapshot) {
                    final communities = snapshot.data ?? [];
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
                        children: communities.map((comm) {
                          final members = comm['community_members'] as List?;
                          final isMemberAdmin = members != null && 
                                              members.isNotEmpty && 
                                              members[0]['role'] == 'admin';
                                              
                          return navItem(
                            icon: isMemberAdmin ? Icons.verified_user_rounded : Icons.label_outline_rounded, 
                            label: comm['name'], 
                            route: '/communities/${comm['id']}',
                            communityId: comm['id'],
                            isSubItem: true
                          );
                        }).toList(),
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
          ),
        ),
      ],
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
            onInvoke: (intent) => showAddTaskForm(
              context,
              initialCommunityId: Provider.of<NavigationProvider>(context, listen: false).selectedCommunityId,
            ),
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
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: navProvider.selectedIndex,
                onTap: (index) => navProvider.setTab(index),
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: colorScheme.onSurface.withOpacity(0.5),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded),
                    activeIcon: Icon(Icons.person_rounded),
                    label: 'Personal',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.hub_outlined),
                    activeIcon: Icon(Icons.hub_rounded),
                    label: 'Communities',
                  ),
                ],
              ),
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
                                    navProvider.selectedIndex == 0 ? 'Personal Tasks' : 'Communities',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.actions != null) ...widget.actions!,
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
                                      } else if (value == 'communities') {
                                        navProvider.setTab(1); // Switch to Communities tab
                                      } else if (value == 'logout') {
                                        Supabase.instance.client.auth.signOut();
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
                  
                  if (isDesktop && _showDesktopNotifications)
                    Positioned(
                      top: 60, 
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
        backgroundColor: Colors.transparent, 
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
}

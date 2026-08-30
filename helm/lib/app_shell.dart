import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_voice_overlay.dart';
import 'widgets/task_search_delegate.dart';
import 'widgets/app_intents.dart';
import 'widgets/task_form_utils.dart';
import 'widgets/ai_text_drawer.dart';
import 'widgets/notification_feed.dart';
import 'widgets/notification_bell.dart';
import 'widgets/user_avatar.dart';
import 'services/supabase_service.dart';
import 'services/navigation_provider.dart';

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

class _AppShellState extends State<AppShell> {
  bool _showDesktopNotifications = false;
  final LayerLink _notificationLayerLink = LayerLink();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      
      bool isActive;
      if (communityId != null) {
        // Specific community is active
        isActive = navProvider.selectedCommunityId == communityId;
      } else if (route == '/') {
        // Main dashboard is active only if we are in the Personal tab (index 0)
        isActive = navProvider.currentRoute == '/' && navProvider.selectedIndex == 0;
      } else {
        // Other routes (Calendar, Categories, etc)
        isActive = navProvider.currentRoute == route;
      }
      
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

    Widget urlNavItem({
      required IconData icon,
      required String label,
      required String url,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () async {
            if (!isDesktop) Navigator.pop(context);
            final uri = Uri.parse(url);
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Could not launch URL: $e');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.onSurface.withOpacity(0.6), size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 14, color: colorScheme.onSurface.withOpacity(0.3)),
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
                navItem(icon: Icons.calendar_today_rounded, label: 'Calendar', route: '/calendar'),
                
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: supabaseService.fetchUserCommunities(),
                  builder: (context, snapshot) {
                    final communities = snapshot.data ?? [];
                    final bool isCommunitiesHubActive = navProvider.selectedIndex == 1 && navProvider.currentRoute == '/';
                    final Color headerColor = isCommunitiesHubActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6);
                    
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        iconColor: headerColor,
                        collapsedIconColor: headerColor,
                        leading: Icon(Icons.groups_rounded, color: headerColor, size: 22),
                        title: InkWell(
                          onTap: () {
                            navProvider.setTab(1);
                            if (!isDesktop) Navigator.pop(context);
                            if (ModalRoute.of(context)?.settings.name != '/') {
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          },
                          child: Text('Communities', style: TextStyle(color: headerColor, fontSize: 15, fontWeight: isCommunitiesHubActive ? FontWeight.bold : FontWeight.normal)),
                        ),
                        childrenPadding: const EdgeInsets.only(left: 24),
                        children: communities.map((comm) {
                          final members = comm['community_members'] as List?;
                          final isMemberAdmin = members != null && 
                                              members.isNotEmpty && 
                                              members[0]['role'] == 'admin';
                                              
                          return navItem(
                            icon: isMemberAdmin ? Icons.admin_panel_settings_rounded : Icons.group_work_outlined, 
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
                
                navItem(icon: Icons.layers_rounded, label: 'Manage All', route: '/categories'),
                urlNavItem(
                  icon: Icons.contact_support_rounded, 
                  label: 'Support & Feedback', 
                  url: 'https://helm-omega-blue.vercel.app/feedback.html' 
                ),
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
        
        // UX Enhancement: Tab control
        const SingleActivator(LogicalKeyboardKey.tab, control: true): const CycleTabIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, alt: true): const EnterIntent(),
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
          CycleTabIntent: CallbackAction<CycleTabIntent>(
            onInvoke: (intent) {
              final nav = Provider.of<NavigationProvider>(context, listen: false);
              nav.setTab((nav.selectedIndex + 1) % 2);
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (intent) {
              if (_showDesktopNotifications) {
                setState(() => _showDesktopNotifications = false);
              } else if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                Navigator.pop(context);
              } else if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                Navigator.pop(context);
              } else if (navProvider.selectedCommunityId != null) {
                navProvider.selectCommunity(null);
              }
              return null;
            },
          ),
          EnterIntent: CallbackAction<EnterIntent>(
            onInvoke: (intent) {
              showAddTaskForm(
                context,
                initialCommunityId: Provider.of<NavigationProvider>(context, listen: false).selectedCommunityId,
              );
              return null;
            },
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
              key: _scaffoldKey,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              drawer: isDesktop ? null : Drawer(
                backgroundColor: colorScheme.surface,
                child: sidebarContent,
              ),
              endDrawer: const AITextDrawer(),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.bottomWidget != null) widget.bottomWidget!,
                  BottomNavigationBar(
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
                                    IconButton(
                                      icon: Icon(Icons.menu, color: colorScheme.onSurface),
                                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                    ),
                                  if (!isDesktop) const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      navProvider.selectedIndex == 0 ? 'Personal Tasks' : 'Communities',
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Action group
                                  Flexible(
                                    flex: 0,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.actions != null) ...widget.actions!,
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.7)),
                                          onPressed: () => showSearch(
                                            context: context,
                                            delegate: CustomTaskSearchDelegate(),
                                          ),
                                        ),
                                        CompositedTransformTarget(
                                          link: _notificationLayerLink,
                                          child: NotificationBellWidget(
                                            isDesktop: isDesktop,
                                            layerLink: _notificationLayerLink,
                                            onToggle: () => setState(() => _showDesktopNotifications = !_showDesktopNotifications),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: UserAvatar(
                                            fullName: Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'User',
                                            avatarUrl: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'],
                                            radius: 16,
                                          ),
                                          offset: const Offset(0, 45),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          onSelected: (value) {
                                            if (value == 'settings') {
                                              Navigator.pushNamed(context, '/account-settings');
                                            } else if (value == 'communities') {
                                              navProvider.setTab(1); 
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
                        child: NotificationFeedUI(),
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

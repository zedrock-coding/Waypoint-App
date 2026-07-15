import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    Widget navItem({
      required IconData icon,
      required String label,
      required String route,
    }) {
      final bool isActive = currentRoute == route;
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () {
            if (isActive) {
              if (!isDesktop) Navigator.pop(context);
              return;
            }
            Navigator.pushReplacementNamed(context, route);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? colorScheme.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
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
              Text(
                'Helm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        navItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/'),
        navItem(icon: Icons.category_rounded, label: 'Categories', route: '/categories'),
        navItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Divider(color: colorScheme.outlineVariant),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: isDesktop ? null : Drawer(
        backgroundColor: colorScheme.surface,
        child: sidebarContent,
      ),
      body: Row(
        children: [
          if (isDesktop) 
            Container(
              width: 260, 
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(right: BorderSide(color: colorScheme.outlineVariant, width: 1)),
              ),
              child: sidebarContent
            ),
          Expanded(
            child: Column(
              children: [
                // Custom Header
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
                      if (actions != null) ...actions!,
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.person_outline, color: colorScheme.onSurface.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface.withOpacity(0.7)),
                        onPressed: () {},
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
    );
  }
}

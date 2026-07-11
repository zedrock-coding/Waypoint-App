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

    Widget sidebar = Drawer(
      elevation: isDesktop ? 0 : null,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              if (ModalRoute.of(context)?.settings.name == '/') {
                if (!isDesktop) Navigator.pop(context);
                return;
              }
              if (!isDesktop) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/');
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              if (ModalRoute.of(context)?.settings.name == '/settings') {
                if (!isDesktop) Navigator.pop(context);
                return;
              }
              if (!isDesktop) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/settings');
              } else {
                Navigator.pushReplacementNamed(context, '/settings');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            onTap: () {
              if (ModalRoute.of(context)?.settings.name == '/categories') {
                if (!isDesktop) Navigator.pop(context);
                return;
              }
              if (!isDesktop) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/categories');
              } else {
                Navigator.pushReplacementNamed(context, '/categories');
              }
            },
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            Image.asset(
              'assets/icon/Helm_logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.event),
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        leading: isDesktop ? const SizedBox.shrink() : null,
        actions: actions,
      ),
      drawer: isDesktop ? null : sidebar,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 250, child: sidebar),
          if (isDesktop) const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

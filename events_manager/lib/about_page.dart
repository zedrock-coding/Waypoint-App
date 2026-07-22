import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('About Helm'),
        ),
        body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info != null ? 'Version ${info.version} (${info.buildNumber})' : 'Loading...';

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    const SizedBox(height: 40),
                    // App Identity Header
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.change_history,
                            size: 80,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Helm',
                            style: textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            version,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Navigate your tasks seamlessly.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Actionable List Tiles
                    _buildActionTile(
                      context,
                      title: 'Terms of Service',
                      onTap: () {
                        // Placeholder for future implementation
                      },
                    ),
                    _buildActionTile(
                      context,
                      title: 'Privacy Policy',
                      onTap: () {
                        // Placeholder for future implementation
                      },
                    ),
                    _buildActionTile(
                      context,
                      title: 'Open Source Licenses',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Helm',
                        applicationVersion: info?.version ?? '1.0.0',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.change_history, color: colorScheme.primary),
                        ),
                      ),
                    ),
                    _buildActionTile(
                      context,
                      title: 'Check for Updates',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App is up to date.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Made with ♥ by Lakshya Jadhav And Shivam Chauhan',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ));
  }

  Widget _buildActionTile(BuildContext context, {required String title, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'app_shell.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  Future<void> _handleNotificationToggle(String key, bool enabled, ThemeProvider provider) async {
    try {
      await provider.updateNotificationSetting(key, enabled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = themeProvider.settings;

    return AppShell(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Theme Mode'),
            trailing: DropdownButton<int>(
              value: settings.themeMode ?? 1,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Light')),
                DropdownMenuItem(value: 1, child: Text('Dark')),
              ],
              onChanged: (val) => themeProvider.updateThemeMode(val!),
            ),
          ),
          ListTile(
            title: const Text('Font Size'),
            subtitle: const Text('Adjust app-wide text scale'),
            trailing: DropdownButton<int>(
              value: settings.fontSizeIndex ?? 2,
              items: List.generate(5, (index) => DropdownMenuItem(value: index, child: Text('Level ${index + 1}'))),
              onChanged: (v) => themeProvider.updateFontSize(v!),
            ),
          ),
          const Divider(height: 40),
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Task Assignments'),
            subtitle: const Text('Notify when someone assigns you a task'),
            value: settings.taskAssignmentsEnabled ?? true,
            onChanged: (v) => _handleNotificationToggle('taskAssignments', v, themeProvider),
          ),
          SwitchListTile(
            title: const Text('Due Date Reminders'),
            subtitle: const Text('Alerts for upcoming and overdue tasks'),
            value: settings.dueDateRemindersEnabled ?? true,
            onChanged: (v) => _handleNotificationToggle('dueDateReminders', v, themeProvider),
          ),
          SwitchListTile(
            title: const Text('Community Mentions'),
            subtitle: const Text('Notify when you are mentioned in a group'),
            value: settings.communityMentionsEnabled ?? true,
            onChanged: (v) => _handleNotificationToggle('communityMentions', v, themeProvider),
          ),
          const Divider(height: 40),
          Text('App Info', style: Theme.of(context).textTheme.titleLarge),
          const ListTile(
            title: Text('Version'),
            trailing: Text('2.1.0+2'),
          ),
        ],
      ),
    );
  }
}

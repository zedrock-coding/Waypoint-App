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

  void _showShortcutsDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.keyboard_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Keyboard Shortcuts'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShortcutRow('Ctrl + N', 'Create New Task'),
              _buildShortcutRow('Ctrl + F', 'Search Tasks'),
              _buildShortcutRow('Ctrl + Space', 'AI Voice Command'),
              _buildShortcutRow('Ctrl + Tab', 'Switch Tabs'),
              _buildShortcutRow('Alt + Enter', 'Quick Add Task'),
              _buildShortcutRow('Enter', 'Submit Form / Save'),
              _buildShortcutRow('Esc', 'Close Panel / Exit'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(action, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            ),
            child: Text(
              keys,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = themeProvider.settings;
    final fontSizeNames = ['Extra Small', 'Small', 'Medium', 'Large', 'Extra Large'];

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
              items: List.generate(
                fontSizeNames.length, 
                (index) => DropdownMenuItem(value: index, child: Text(fontSizeNames[index]))
              ),
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
          Text('System', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.keyboard_rounded),
            title: const Text('Keyboard Shortcuts'),
            subtitle: const Text('View navigation and action keys'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showShortcutsDialog,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Helm'),
            subtitle: const Text('Version, Licenses, and Legal'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

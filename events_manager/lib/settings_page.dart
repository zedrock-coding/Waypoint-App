import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'models/settings.dart';
import 'app_shell.dart';
import 'notification_service.dart';
import 'theme_provider.dart';

class SettingPage extends StatefulWidget {
  final Isar isar;
  const SettingPage({super.key, required this.isar});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final NotificationService _notificationService = NotificationService();

  Future<void> _toggleReminders(bool enabled, ThemeProvider provider) async {
    HapticFeedback.selectionClick();
    if (enabled) {
      final granted = await _notificationService.requestPermissions();
      if (granted) {
        await _notificationService.scheduleDailyNotification(
          id: 0,
          title: 'Helm Reminder',
          body: 'Time to check your tasks for the day!',
          time: const TimeOfDay(hour: 9, minute: 0),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permissions denied.')),
          );
        }
        return;
      }
    } else {
      await _notificationService.cancelAllNotifications();
    }

    provider.settings.remindersEnabled = enabled;
    await widget.isar.writeTxn(() async {
      await widget.isar.settings.put(provider.settings);
    });
    provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = themeProvider.settings;
    final fontSizeLabels = ['Very Small', 'Small', 'Normal', 'Medium', 'Large'];
    final colorScheme = Theme.of(context).colorScheme;

    return AppShell(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                RadioListTile<int>(
                  title: const Text('Light Mode'),
                  value: 0,
                  groupValue: settings.themeMode,
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    themeProvider.updateThemeMode(val!);
                  },
                ),
                RadioListTile<int>(
                  title: const Text('Dark Mode'),
                  value: 1,
                  groupValue: settings.themeMode,
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    themeProvider.updateThemeMode(val!);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Typography', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: settings.fontSizeIndex,
            decoration: InputDecoration(
              border: const OutlineInputBorder(), 
              labelText: 'Font Size',
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            items: List.generate(fontSizeLabels.length, (i) => DropdownMenuItem(value: i, child: Text(fontSizeLabels[i]))),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              themeProvider.updateFontSize(v!);
            },
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            subtitle: const Text('Morning briefing at 9:00 AM'),
            value: settings.remindersEnabled,
            onChanged: (v) => _toggleReminders(v, themeProvider),
          ),
        ],
      ),
    );
  }
}

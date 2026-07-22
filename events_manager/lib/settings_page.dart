import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
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

  Future<void> _handleNotificationToggle(String key, bool enabled, ThemeProvider provider) async {
    HapticFeedback.selectionClick();
    
    // Specifically handle Daily Briefing for notification scheduling
    if (key == 'dailyBriefing') {
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
    }

    await provider.updateNotificationSetting(key, enabled);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = themeProvider.settings;
    final fontSizeLabels = ['Very Small', 'Small', 'Normal', 'Medium', 'Large'];
    final colorScheme = Theme.of(context).colorScheme;

    return AppShell(
      title: 'Settings',
      isar: widget.isar,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 16),
          _buildCard(
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
          _buildSectionHeader('Typography'),
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
          
          const SizedBox(height: 32),
          _buildSectionHeader('Essential Alerts', color: colorScheme.primary),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              children: [
                _buildNotificationSwitch(
                  title: 'Task Assignments',
                  subtitle: 'Notify when I am assigned a task',
                  value: settings.taskAssignmentsEnabled,
                  onChanged: (v) => _handleNotificationToggle('taskAssignments', v, themeProvider),
                ),
                _buildNotificationSwitch(
                  title: 'Due Date Reminders',
                  subtitle: 'Notify 24 hours before a task is due',
                  value: settings.dueDateRemindersEnabled,
                  onChanged: (v) => _handleNotificationToggle('dueDateReminders', v, themeProvider),
                ),
                _buildNotificationSwitch(
                  title: 'Community Mentions',
                  subtitle: 'Notify when I am tagged in a comment',
                  value: settings.communityMentionsEnabled,
                  onChanged: (v) => _handleNotificationToggle('communityMentions', v, themeProvider),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('General & Promotional'),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              children: [
                _buildNotificationSwitch(
                  title: 'Daily Briefing',
                  subtitle: 'Morning summary at 9:00 AM',
                  value: settings.dailyBriefingEnabled,
                  onChanged: (v) => _handleNotificationToggle('dailyBriefing', v, themeProvider),
                ),
                _buildNotificationSwitch(
                  title: 'News & Offers',
                  subtitle: 'Receive tips, marketing, and promotional updates',
                  value: settings.newsAndOffersEnabled,
                  onChanged: (v) => _handleNotificationToggle('newsAndOffers', v, themeProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support & Info'),
          const SizedBox(height: 16),
          _buildCard(
            child: ListTile(
              title: const Text('About Helm'),
              subtitle: const Text('Version, Licenses, and more'),
              leading: const Icon(Icons.info_outline),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/about'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: onChanged,
    );
  }
}

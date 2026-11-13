import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../theme_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _voiceConfirmation = true;
  bool _taskNotifications = true;
  bool _dueReminders = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'user@waypoint.app';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 90),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'PREFERENCES & SYSTEM',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mint,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: AppTheme.surfaceVariant)),
                      ),
                      Text(
                        'Waypoint Settings',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Settings & Preferences',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Customize audio interaction, appearance, and synchronization options.',
                    style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceVariant, height: 1),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. AI Voice Assistant Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic_rounded, size: 18, color: AppTheme.mint),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Voice Assistant',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Waypoint extracts tasks, dates, and subtasks directly from spoken dictation.',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.surfaceVariant),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Voice Confirmation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.onSurface)),
                                    Text('Speak back verified details', style: AppTheme.monoStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                                  ],
                                ),
                                Switch(
                                  value: _voiceConfirmation,
                                  activeTrackColor: AppTheme.mint,
                                  onChanged: (val) => setState(() => _voiceConfirmation = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.surfaceVariant),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Voice Speed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.onSurface)),
                                    Text('1.05x (Optimal)', style: AppTheme.monoStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                                  ],
                                ),
                                Text('Fast', style: AppTheme.monoStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mint)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Appearance & Theme Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 18, color: AppTheme.mint),
                        const SizedBox(width: 8),
                        const Text(
                          'Appearance & Theme',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => themeProvider.updateThemeMode(1),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: themeProvider.themeMode == ThemeMode.dark
                                    ? AppTheme.mint.withValues(alpha: 0.15)
                                    : AppTheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: themeProvider.themeMode == ThemeMode.dark ? AppTheme.mint : AppTheme.surfaceVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 16,
                                    color: themeProvider.themeMode == ThemeMode.dark ? AppTheme.mint : AppTheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dark (Obsidian)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: themeProvider.themeMode == ThemeMode.dark ? FontWeight.w600 : FontWeight.w400,
                                      color: themeProvider.themeMode == ThemeMode.dark ? AppTheme.mint : AppTheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => themeProvider.updateThemeMode(0),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: themeProvider.themeMode == ThemeMode.light
                                    ? AppTheme.mint.withValues(alpha: 0.15)
                                    : AppTheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: themeProvider.themeMode == ThemeMode.light ? AppTheme.mint : AppTheme.surfaceVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 16,
                                    color: themeProvider.themeMode == ThemeMode.light ? AppTheme.mint : AppTheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Light',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: themeProvider.themeMode == ThemeMode.light ? FontWeight.w600 : FontWeight.w400,
                                      color: themeProvider.themeMode == ThemeMode.light ? AppTheme.mint : AppTheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. Notifications Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_outlined, size: 18, color: AppTheme.mint),
                        const SizedBox(width: 8),
                        const Text(
                          'Notification Reminders',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Task Assignments', style: TextStyle(fontSize: 12.5, color: AppTheme.onSurface)),
                      subtitle: Text('Alerts when colleagues delegate tasks to you', style: AppTheme.monoStyle(fontSize: 10.5)),
                      value: _taskNotifications,
                      activeTrackColor: AppTheme.mint,
                      onChanged: (val) => setState(() => _taskNotifications = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date Reminders', style: TextStyle(fontSize: 12.5, color: AppTheme.onSurface)),
                      subtitle: Text('Notify 30 minutes before milestone deadline', style: AppTheme.monoStyle(fontSize: 10.5)),
                      value: _dueReminders,
                      activeTrackColor: AppTheme.mint,
                      onChanged: (val) => setState(() => _dueReminders = val),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Account & Cloud Backup Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.surfaceVariant),
                      ),
                      child: Center(
                        child: Text(
                          email.isNotEmpty ? email.substring(0, 1).toUpperCase() : 'U',
                          style: AppTheme.monoStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                          Text('Offline Ready • Supabase Cloud Synchronized', style: AppTheme.monoStyle(fontSize: 10.5, color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.mint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'CONNECTED',
                        style: AppTheme.monoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../notification_service.dart';
import '../providers/task_provider.dart';

class VelocityDashboardCard extends StatelessWidget {
  final int totalTasksToday;
  final int completedTasksToday;

  const VelocityDashboardCard({
    super.key,
    required this.totalTasksToday,
    required this.completedTasksToday,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final double progress = totalTasksToday == 0 ? 0 : completedTasksToday / totalTasksToday;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Decision based on ACTUAL available width, not global screen width
          final bool useVerticalLayout = constraints.maxWidth < 550;

          if (useVerticalLayout) {
            return _buildVelocityContent(context, progress, colorScheme, isCramped: true);
          }

          return IntrinsicHeight( // Re-adding with safer child constraints
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildVelocityContent(context, progress, colorScheme, isCramped: false),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _buildSettingsContent(context, themeProvider, colorScheme, isCramped: false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVelocityContent(BuildContext context, double progress, ColorScheme colorScheme, {required bool isCramped}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Velocity",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Use Wrap if cramped to prevent horizontal overflow
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.start,
            children: [
              _buildProgressIndicator(progress, colorScheme),
              _buildTaskStats(colorScheme, isCramped),
              if (!isCramped) _buildStreakInfo(context, colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double progress, ColorScheme colorScheme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 54,
          width: 54,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        Text(
          "${(progress * 100).toInt()}%",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTaskStats(ColorScheme colorScheme, bool isCramped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$completedTasksToday',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              ' / $totalTasksToday',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(
          'Tasks Done',
          style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildStreakInfo(BuildContext context, ColorScheme colorScheme) {
    final int streak = context.select<TaskProvider, int>((provider) => provider.currentStreak);
    
    if (streak == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
        const SizedBox(width: 4),
        Text(
          '$streak-Day Streak',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context, ThemeProvider themeProvider, ColorScheme colorScheme, {required bool isCramped}) {
    final settings = themeProvider.settings;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.settings_suggest_rounded, size: 14, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text("Quick Settings", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(
              'Reminders',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            value: settings.dailyBriefingEnabled ?? true,
            activeThumbColor: colorScheme.primary,
            onChanged: (enabled) => _toggleReminders(context, enabled, themeProvider),
          ),
          const SizedBox(height: 4),
          const Text('Font Size', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: 0, label: Text('S', style: TextStyle(fontSize: 10))),
                  ButtonSegment(value: 1, label: Text('M', style: TextStyle(fontSize: 10))),
                  ButtonSegment(value: 2, label: Text('L', style: TextStyle(fontSize: 10))),
                ],
                selected: <int>{
                  (settings.fontSizeIndex ?? 2) <= 1
                      ? 0
                      : ((settings.fontSizeIndex ?? 2) == 2 ? 1 : 2)
                },
                onSelectionChanged: (val) {
                  HapticFeedback.selectionClick();
                  // S/M/L map onto the shared scale [0.7, 0.85, 1.0, 1.2, 1.4]:
                  // S = 0.85, M = 1.0 (the default), L = 1.2.
                  final quickIndex = val.first;
                  themeProvider.updateFontSize(quickIndex + 1);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReminders(BuildContext context, bool enabled, ThemeProvider provider) async {
    HapticFeedback.selectionClick();
    final NotificationService ns = NotificationService();
    if (enabled) {
      final granted = await ns.requestPermissions();
      if (granted) {
        await ns.scheduleDailyNotification(
          id: 0, 
          title: 'Helm Reminder', 
          body: 'Time to check your tasks!', 
          time: const TimeOfDay(hour: 9, minute: 0),
        );
      }
    } else {
      await ns.cancelAllNotifications();
    }
    await provider.updateNotificationSetting('dailyBriefing', enabled);
  }
}

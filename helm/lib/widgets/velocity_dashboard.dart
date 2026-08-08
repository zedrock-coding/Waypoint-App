import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../notification_service.dart';

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
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 900;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: isMobile
          ? _buildVelocityContent(context, progress, colorScheme)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildVelocityContent(context, progress, colorScheme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _buildSettingsContent(context, themeProvider, colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildVelocityContent(BuildContext context, double progress, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Velocity",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_note, color: colorScheme.onSurface.withOpacity(0.4), size: 18),
                onPressed: () => _showAdjustGoalDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressIndicator(progress, colorScheme),
              const SizedBox(width: 16),
              _buildTaskStats(colorScheme),
              const SizedBox(width: 12),
              _buildStreakInfo(colorScheme),
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
          height: 60,
          width: 60,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        Text(
          "${(progress * 100).toInt()}%",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskStats(ColorScheme colorScheme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(color: colorScheme.onSurface),
              children: [
                TextSpan(
                  text: '$completedTasksToday',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' of ',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
                TextSpan(
                  text: '$totalTasksToday',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            'Tasks Completed',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakInfo(ColorScheme colorScheme) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 24),
          const SizedBox(height: 4),
          Text(
            '3-Day Streak',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context, ThemeProvider themeProvider, ColorScheme colorScheme) {
    final settings = themeProvider.settings;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Settings",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(
              'Reminders',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.7)),
            ),
            value: settings.dailyBriefingEnabled ?? true,
            activeColor: colorScheme.primary,
            onChanged: (enabled) => _toggleReminders(context, enabled, themeProvider),
          ),
          const SizedBox(height: 4),
          Text(
            'Font Size',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                selectedBackgroundColor: colorScheme.primary,
                selectedForegroundColor: colorScheme.onPrimary,
              ),
              segments: const [
                ButtonSegment(value: 0, label: Text('S', style: TextStyle(fontSize: 9))),
                ButtonSegment(value: 1, label: Text('M', style: TextStyle(fontSize: 9))),
                ButtonSegment(value: 2, label: Text('L', style: TextStyle(fontSize: 9))),
              ],
              selected: <int>{
                (settings.fontSizeIndex ?? 2) <= 1 ? 0 : ((settings.fontSizeIndex ?? 2) >= 4 ? 2 : 1)
              },
              onSelectionChanged: (val) {
                HapticFeedback.selectionClick();
                final quickIndex = val.first;
                int modelIndex;
                if (quickIndex == 0) {
                  modelIndex = 1; // Small
                } else if (quickIndex == 1) {
                  modelIndex = 3; // Medium
                } else {
                  modelIndex = 4; // Large
                }
                themeProvider.updateFontSize(modelIndex);
              },
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
      } else {
        return; // Permission denied
      }
    } else {
      await ns.cancelAllNotifications();
    }
    await provider.updateNotificationSetting('dailyBriefing', enabled);
  }

  void _showAdjustGoalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Adjust Daily Goal"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Set your daily task target to help calculate velocity snapshots."),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: "Daily Target",
                hintText: "e.g. 10",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("SAVE")),
        ],
      ),
    );
  }
}

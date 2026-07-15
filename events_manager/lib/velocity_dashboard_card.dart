import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class VelocityDashboardCard extends StatelessWidget {
  final int totalTasksToday;
  final int completedTasksToday;
  final bool remindersEnabled;
  final Function(bool) onRemindersToggle;

  const VelocityDashboardCard({
    super.key,
    required this.totalTasksToday,
    required this.completedTasksToday,
    required this.remindersEnabled,
    required this.onRemindersToggle,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalTasksToday == 0 ? 0 : completedTasksToday / totalTasksToday;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 800;

        Widget velocityContent = Container(
          padding: const EdgeInsets.all(20),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Icon(Icons.edit_note, color: colorScheme.onSurface.withOpacity(0.4), size: 20),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 70,
                        width: 70,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      ),
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
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
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: ' of ',
                                style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                              ),
                              TextSpan(
                                text: '$totalTasksToday',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Tasks Completed',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          '3-Day Streak',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        Widget settingsContent = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Settings",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text('Reminders', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7))),
                value: remindersEnabled,
                activeColor: colorScheme.primary,
                onChanged: onRemindersToggle,
              ),
              const SizedBox(height: 8),
              Text('Font Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.5))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    selectedBackgroundColor: colorScheme.primary,
                    selectedForegroundColor: colorScheme.onPrimary,
                  ),
                  segments: const [
                    ButtonSegment(value: 1, label: Text('S', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: 2, label: Text('M', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: 3, label: Text('L', style: TextStyle(fontSize: 10))),
                  ],
                  selected: {themeProvider.settings.fontSizeIndex.clamp(1, 3)},
                  onSelectionChanged: (val) => themeProvider.updateFontSize(val.first),
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: isMobile
              ? Column(
                  children: [
                    velocityContent,
                    const SizedBox(height: 16),
                    settingsContent,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: velocityContent),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: settingsContent),
                  ],
                ),
        );
      },
    );
  }
}

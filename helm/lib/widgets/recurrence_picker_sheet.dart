import 'package:flutter/material.dart';
import '../models/recurrence_rule.dart';

/// Bottom sheet dialog for choosing recurrence presets or custom recurrence rules.
class RecurrencePickerSheet extends StatefulWidget {
  final RecurrenceRule? initialRule;
  final DateTime? anchorDate;

  const RecurrencePickerSheet({
    super.key,
    this.initialRule,
    this.anchorDate,
  });

  static Future<RecurrenceRule?> show(
    BuildContext context, {
    RecurrenceRule? initialRule,
    DateTime? anchorDate,
  }) {
    return showModalBottomSheet<RecurrenceRule?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecurrencePickerSheet(
        initialRule: initialRule,
        anchorDate: anchorDate,
      ),
    );
  }

  @override
  State<RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<RecurrencePickerSheet> {
  late bool _isCustom;
  String? _selectedPreset; // null = Does Not Repeat, or 'daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom'

  late int _customInterval;
  late String _customFrequency; // 'daily', 'weekly', 'monthly'
  late Set<int> _customDaysOfWeek; // 1 = Mon ... 7 = Sun
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    if (rule == null) {
      _selectedPreset = null;
      _isCustom = false;
      _customInterval = 1;
      _customFrequency = 'daily';
      _customDaysOfWeek = {widget.anchorDate?.weekday ?? DateTime.now().weekday};
    } else if (rule.frequency == 'custom' || rule.interval > 1 || (rule.frequency == 'weekly' && rule.daysOfWeek != null && rule.daysOfWeek!.length > 1)) {
      _selectedPreset = 'custom';
      _isCustom = true;
      _customInterval = rule.interval;
      _customFrequency = rule.frequency == 'custom' ? 'daily' : rule.frequency;
      _customDaysOfWeek = rule.daysOfWeek != null ? Set<int>.from(rule.daysOfWeek!) : {widget.anchorDate?.weekday ?? DateTime.now().weekday};
      _endDate = rule.endDate;
    } else {
      _selectedPreset = rule.frequency;
      _isCustom = false;
      _customInterval = rule.interval;
      _customFrequency = rule.frequency;
      _customDaysOfWeek = rule.daysOfWeek != null ? Set<int>.from(rule.daysOfWeek!) : {widget.anchorDate?.weekday ?? DateTime.now().weekday};
      _endDate = rule.endDate;
    }
  }

  void _selectPreset(String? preset) {
    if (preset == 'custom') {
      setState(() {
        _isCustom = true;
        _selectedPreset = 'custom';
      });
      return;
    }

    if (preset == null) {
      Navigator.of(context).pop(null); // Does not repeat
      return;
    }

    final anchor = widget.anchorDate ?? DateTime.now();
    RecurrenceRule rule;
    switch (preset) {
      case 'daily':
        rule = const RecurrenceRule(frequency: 'daily', interval: 1);
        break;
      case 'weekly':
        rule = RecurrenceRule(frequency: 'weekly', interval: 1, daysOfWeek: [anchor.weekday]);
        break;
      case 'biweekly':
        rule = const RecurrenceRule(frequency: 'biweekly', interval: 1);
        break;
      case 'monthly':
        rule = const RecurrenceRule(frequency: 'monthly', interval: 1);
        break;
      case 'yearly':
        rule = const RecurrenceRule(frequency: 'yearly', interval: 1);
        break;
      default:
        rule = RecurrenceRule(frequency: preset);
    }
    Navigator.of(context).pop(rule);
  }

  void _applyCustom() {
    final rule = RecurrenceRule(
      frequency: _customFrequency,
      interval: _customInterval,
      daysOfWeek: _customFrequency == 'weekly' ? (_customDaysOfWeek.toList()..sort()) : null,
      endDate: _endDate,
    );
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.repeat_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                _isCustom ? 'Custom Recurrence' : 'Repeat',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isCustom)
                TextButton(
                  onPressed: () => setState(() => _isCustom = false),
                  child: const Text('Presets'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isCustom) ..._buildPresetList(colorScheme)
          else ..._buildCustomForm(theme, colorScheme),
        ],
      ),
    );
  }

  List<Widget> _buildPresetList(ColorScheme colorScheme) {
    final anchor = widget.anchorDate ?? DateTime.now();
    const weekdayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdayStr = weekdayNames[anchor.weekday];

    final presets = [
      {'id': null, 'label': 'Does not repeat', 'icon': Icons.block_rounded},
      {'id': 'daily', 'label': 'Every day', 'icon': Icons.calendar_today_rounded},
      {'id': 'weekly', 'label': 'Every week (on $weekdayStr)', 'icon': Icons.view_week_rounded},
      {'id': 'biweekly', 'label': 'Every 2 weeks (Bi-weekly)', 'icon': Icons.date_range_rounded},
      {'id': 'monthly', 'label': 'Every month (on day ${anchor.day})', 'icon': Icons.calendar_month_rounded},
      {'id': 'yearly', 'label': 'Every year', 'icon': Icons.event_repeat_rounded},
      {'id': 'custom', 'label': 'Custom...', 'icon': Icons.tune_rounded},
    ];

    return presets.map((p) {
      final isSelected = _selectedPreset == p['id'];
      return ListTile(
        leading: Icon(
          p['icon'] as IconData,
          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          p['label'] as String,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_rounded, color: colorScheme.primary) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _selectPreset(p['id'] as String?),
      );
    }).toList();
  }

  List<Widget> _buildCustomForm(ThemeData theme, ColorScheme colorScheme) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return [
      Row(
        children: [
          const Text('Repeat every:'),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _customInterval,
            items: List.generate(30, (i) => i + 1).map((val) {
              return DropdownMenuItem<int>(
                value: val,
                child: Text('$val'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _customInterval = val);
            },
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _customFrequency,
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Days')),
              DropdownMenuItem(value: 'weekly', child: Text('Weeks')),
              DropdownMenuItem(value: 'monthly', child: Text('Months')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _customFrequency = val);
            },
          ),
        ],
      ),
      if (_customFrequency == 'weekly') ...[
        const SizedBox(height: 16),
        const Text('On days:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final day = index + 1; // 1 = Mon ... 7 = Sun
            final isChecked = _customDaysOfWeek.contains(day);
            return FilterChip(
              label: Text(weekdays[index]),
              selected: isChecked,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _customDaysOfWeek.add(day);
                  } else if (_customDaysOfWeek.length > 1) {
                    _customDaysOfWeek.remove(day);
                  }
                });
              },
            );
          }),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          const Text('Ends:'),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('Never'),
            selected: _endDate == null,
            onSelected: (sel) {
              if (sel) setState(() => _endDate = null);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(_endDate == null ? 'On Date' : 'On ${_endDate!.toLocal().toString().split(' ')[0]}'),
            selected: _endDate != null,
            onSelected: (sel) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.check_rounded),
        label: const Text('Set Recurrence'),
        onPressed: _applyCustom,
      ),
    ];
  }
}


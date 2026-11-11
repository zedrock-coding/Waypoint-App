import 'package:flutter/foundation.dart';

/// Defines the recurrence pattern for a recurring task.
class RecurrenceRule {
  /// Frequency: 'daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom'
  final String frequency;

  /// Recurrence interval (e.g. every 1 day, every 2 weeks, etc.)
  final int interval;

  /// Days of the week for weekly recurrence: 1 = Monday ... 7 = Sunday (ISO-8601)
  final List<int>? daysOfWeek;

  /// Optional boundary date after which no new instances will be generated
  final DateTime? endDate;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
  });

  Map<String, dynamic> toMap() => {
        'frequency': frequency,
        'interval': interval,
        if (daysOfWeek != null) 'days_of_week': daysOfWeek,
        if (endDate != null) 'end_date': endDate!.toIso8601String(),
      };

  factory RecurrenceRule.fromMap(Map<dynamic, dynamic> map) {
    List<int>? parsedDays;
    final rawDays = map['days_of_week'] ?? map['recurrence_days_of_week'];
    if (rawDays is List) {
      parsedDays = rawDays.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7).toList();
    }

    DateTime? parsedEndDate;
    final rawEnd = map['end_date'] ?? map['recurrence_end_date'];
    if (rawEnd != null && rawEnd.toString().isNotEmpty && rawEnd.toString() != 'null') {
      parsedEndDate = DateTime.tryParse(rawEnd.toString());
    }

    return RecurrenceRule(
      frequency: (map['frequency'] ?? map['recurrence_frequency'] ?? 'daily').toString().toLowerCase(),
      interval: int.tryParse((map['interval'] ?? map['recurrence_interval'] ?? 1).toString()) ?? 1,
      daysOfWeek: parsedDays,
      endDate: parsedEndDate,
    );
  }

  RecurrenceRule copyWith({
    String? frequency,
    int? interval,
    List<int>? daysOfWeek,
    DateTime? endDate,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Human-friendly display string (e.g. "Every day", "Every week on Mon, Wed")
  String get readableDescription {
    final cleanFreq = frequency.toLowerCase();
    switch (cleanFreq) {
      case 'daily':
        return interval == 1 ? 'Repeats daily' : 'Every $interval days';
      case 'weekly':
        if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
          const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayNames = daysOfWeek!.map((d) => (d >= 1 && d <= 7) ? names[d] : '').where((s) => s.isNotEmpty).join(', ');
          return interval == 1 ? 'Every week on $dayNames' : 'Every $interval weeks on $dayNames';
        }
        return interval == 1 ? 'Repeats weekly' : 'Every $interval weeks';
      case 'biweekly':
        return 'Repeats bi-weekly (every 2 weeks)';
      case 'monthly':
        return interval == 1 ? 'Repeats monthly' : 'Every $interval months';
      case 'yearly':
        return interval == 1 ? 'Repeats yearly' : 'Every $interval years';
      case 'custom':
        return 'Repeats every $interval days';
      default:
        return 'Repeats ($frequency)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurrenceRule &&
        other.frequency == frequency &&
        other.interval == interval &&
        listEquals(other.daysOfWeek, daysOfWeek) &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(
        frequency,
        interval,
        daysOfWeek == null ? null : Object.hashAll(daysOfWeek!),
        endDate,
      );
}


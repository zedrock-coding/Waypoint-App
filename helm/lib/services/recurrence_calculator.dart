import 'dart:math';
import '../models/recurrence_rule.dart';

/// Deterministic calculator for recurring task rollover dates.
class RecurrenceCalculator {
  /// Computes the next scheduled due date based on the current due date and recurrence rule.
  ///
  /// If [anchor] is provided and [advancePastAnchor] is true, the calculator advances
  /// successive cycles until the resulting due date is strictly after [anchor].
  static DateTime calculateNextDueDate(
    DateTime currentDue,
    RecurrenceRule rule, {
    DateTime? anchor,
    bool advancePastAnchor = false,
  }) {
    final base = (anchor != null && !advancePastAnchor && currentDue.isBefore(anchor))
        ? DateTime(anchor.year, anchor.month, anchor.day, currentDue.hour, currentDue.minute, currentDue.second)
        : currentDue;

    DateTime next = _computeSingleCycle(base, rule);

    if (advancePastAnchor && anchor != null) {
      int guard = 0;
      while (!next.isAfter(anchor) && guard < 500) {
        next = _computeSingleCycle(next, rule);
        guard++;
      }
    }

    return next;
  }

  static DateTime _computeSingleCycle(DateTime base, RecurrenceRule rule) {
    final cleanFreq = rule.frequency.toLowerCase();
    final interval = max(1, rule.interval);

    switch (cleanFreq) {
      case 'daily':
        return base.add(Duration(days: interval));

      case 'weekly':
        if (rule.daysOfWeek != null && rule.daysOfWeek!.isNotEmpty) {
          return _calculateNextWeeklyDay(base, rule.daysOfWeek!, interval);
        }
        return base.add(Duration(days: 7 * interval));

      case 'biweekly':
        return base.add(Duration(days: 14 * interval));

      case 'monthly':
        return _addMonthsClamped(base, interval);

      case 'yearly':
        return _addYearsClamped(base, interval);

      case 'custom':
        return base.add(Duration(days: interval));

      default:
        return base.add(Duration(days: interval));
    }
  }

  static DateTime _calculateNextWeeklyDay(DateTime base, List<int> daysOfWeek, int weekInterval) {
    final sortedDays = List<int>.from(daysOfWeek)..sort();
    final currentWeekday = base.weekday; // 1 = Mon ... 7 = Sun

    for (final day in sortedDays) {
      if (day > currentWeekday) {
        return DateTime(
          base.year,
          base.month,
          base.day + (day - currentWeekday),
          base.hour,
          base.minute,
          base.second,
        );
      }
    }

    // Roll over to the next week cycle
    final daysUntilEndOfWeek = 7 - currentWeekday;
    final daysUntilFirstNextCycle = daysUntilEndOfWeek + sortedDays.first;
    final totalDaysToAdd = daysUntilFirstNextCycle + (7 * (weekInterval - 1));

    return DateTime(
      base.year,
      base.month,
      base.day + totalDaysToAdd,
      base.hour,
      base.minute,
      base.second,
    );
  }

  static DateTime _addMonthsClamped(DateTime base, int monthsToAdd) {
    final targetYear = base.year + ((base.month - 1 + monthsToAdd) ~/ 12);
    final targetMonth = ((base.month - 1 + monthsToAdd) % 12) + 1;
    final maxDaysInTargetMonth = _daysInMonth(targetYear, targetMonth);
    final targetDay = min(base.day, maxDaysInTargetMonth);

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      base.hour,
      base.minute,
      base.second,
    );
  }

  static DateTime _addYearsClamped(DateTime base, int yearsToAdd) {
    final targetYear = base.year + yearsToAdd;
    final targetMonth = base.month;
    final maxDays = _daysInMonth(targetYear, targetMonth);
    final targetDay = min(base.day, maxDays);

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      base.hour,
      base.minute,
      base.second,
    );
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  /// Determines if a subsequent instance should be generated given the rule's end date condition.
  static bool shouldSpawnNextInstance(DateTime nextDueDate, RecurrenceRule rule) {
    if (rule.endDate == null) return true;
    return !nextDueDate.isAfter(rule.endDate!);
  }
}


import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/models/recurrence_rule.dart';
import 'package:waypoint/services/recurrence_calculator.dart';

void main() {
  group('RecurrenceCalculator Tests', () {
    test('Daily recurrence advances by interval days', () {
      final base = DateTime(2026, 11, 10, 14, 30);
      final rule = RecurrenceRule(frequency: 'daily', interval: 1);
      final next = RecurrenceCalculator.calculateNextDueDate(base, rule);

      expect(next, DateTime(2026, 11, 11, 14, 30));

      final rule3 = RecurrenceRule(frequency: 'daily', interval: 3);
      final next3 = RecurrenceCalculator.calculateNextDueDate(base, rule3);
      expect(next3, DateTime(2026, 11, 13, 14, 30));
    });

    test('Weekly recurrence with specific weekdays (Mon, Wed, Fri)', () {
      // 2026-11-09 is a Monday (weekday = 1)
      final monday = DateTime(2026, 11, 9, 10, 0);
      final rule = RecurrenceRule(
        frequency: 'weekly',
        interval: 1,
        daysOfWeek: [1, 3, 5], // Mon, Wed, Fri
      );

      // From Monday, next is Wednesday (day 3)
      final nextFromMon = RecurrenceCalculator.calculateNextDueDate(monday, rule);
      expect(nextFromMon.weekday, 3);
      expect(nextFromMon, DateTime(2026, 11, 11, 10, 0));

      // From Wednesday, next is Friday (day 5)
      final nextFromWed = RecurrenceCalculator.calculateNextDueDate(nextFromMon, rule);
      expect(nextFromWed.weekday, 5);
      expect(nextFromWed, DateTime(2026, 11, 13, 10, 0));

      // From Friday, rolls over to next week Monday (day 1)
      final nextFromFri = RecurrenceCalculator.calculateNextDueDate(nextFromWed, rule);
      expect(nextFromFri.weekday, 1);
      expect(nextFromFri, DateTime(2026, 11, 16, 10, 0));
    });

    test('Weekly recurrence with 2-week interval rolls over correctly', () {
      // 2026-11-13 is a Friday (weekday = 5)
      final friday = DateTime(2026, 11, 13, 10, 0);
      final rule = RecurrenceRule(
        frequency: 'weekly',
        interval: 2, // Every 2 weeks
        daysOfWeek: [1, 5], // Mon, Fri
      );

      // From Friday, next cycle is Monday in 2 weeks (skips one Monday)
      final next = RecurrenceCalculator.calculateNextDueDate(friday, rule);
      expect(next.weekday, 1);
      // Friday 13 + 2 days = Sun 15 + 1 day = Mon 16 (+ 7 days for 2-week interval) = Mon 23
      expect(next, DateTime(2026, 11, 23, 10, 0));
    });

    test('Bi-weekly recurrence adds 14 days', () {
      final base = DateTime(2026, 11, 10, 9, 0);
      final rule = RecurrenceRule(frequency: 'biweekly');
      final next = RecurrenceCalculator.calculateNextDueDate(base, rule);
      expect(next, DateTime(2026, 11, 24, 9, 0));
    });

    test('Monthly recurrence clamps days for shorter months', () {
      // Jan 31 -> Feb 28 in non-leap year (2027)
      final baseJan31 = DateTime(2027, 1, 31, 15, 0);
      final rule = RecurrenceRule(frequency: 'monthly', interval: 1);
      final nextFeb = RecurrenceCalculator.calculateNextDueDate(baseJan31, rule);
      expect(nextFeb, DateTime(2027, 2, 28, 15, 0));

      // Jan 31 -> Feb 29 in leap year (2028)
      final baseLeap = DateTime(2028, 1, 31, 15, 0);
      final nextLeap = RecurrenceCalculator.calculateNextDueDate(baseLeap, rule);
      expect(nextLeap, DateTime(2028, 2, 29, 15, 0));
    });

    test('Yearly recurrence handles leap year Feb 29', () {
      final baseLeap = DateTime(2028, 2, 29, 12, 0);
      final rule = RecurrenceRule(frequency: 'yearly', interval: 1);
      final nextYear = RecurrenceCalculator.calculateNextDueDate(baseLeap, rule);
      expect(nextYear, DateTime(2029, 2, 28, 12, 0));
    });

    test('shouldSpawnNextInstance respects endDate boundary', () {
      final rule = RecurrenceRule(
        frequency: 'daily',
        endDate: DateTime(2026, 11, 20),
      );

      expect(RecurrenceCalculator.shouldSpawnNextInstance(DateTime(2026, 11, 15), rule), isTrue);
      expect(RecurrenceCalculator.shouldSpawnNextInstance(DateTime(2026, 11, 20), rule), isTrue);
      expect(RecurrenceCalculator.shouldSpawnNextInstance(DateTime(2026, 11, 21), rule), isFalse);
    });
  });
}


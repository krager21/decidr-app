import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decidr_app/services/reminder_service.dart';

void main() {
  group('nextInstanceOf', () {
    test('later today when the time is still ahead', () {
      final now = DateTime(2026, 7, 7, 8, 30);
      final next =
          ReminderService.nextInstanceOf(const TimeOfDay(hour: 19, minute: 0), now);
      expect(next, DateTime(2026, 7, 7, 19));
    });

    test('tomorrow when the time already passed', () {
      final now = DateTime(2026, 7, 7, 20, 0);
      final next =
          ReminderService.nextInstanceOf(const TimeOfDay(hour: 19, minute: 0), now);
      expect(next, DateTime(2026, 7, 8, 19));
    });

    test('exactly-now rolls to tomorrow (strictly after)', () {
      final now = DateTime(2026, 7, 7, 19, 0);
      final next =
          ReminderService.nextInstanceOf(const TimeOfDay(hour: 19, minute: 0), now);
      expect(next, DateTime(2026, 7, 8, 19));
    });
  });

  group('tonightInstant', () {
    test('morning ask lands at 7pm today', () {
      final at = ReminderService.tonightInstant(DateTime(2026, 7, 7, 10));
      expect(at, DateTime(2026, 7, 7, 19));
    });

    test('evening ask lands two hours out', () {
      final at = ReminderService.tonightInstant(DateTime(2026, 7, 7, 19, 30));
      expect(at, DateTime(2026, 7, 7, 21, 30));
    });

    test('late-night ask defers to 7pm tomorrow, never past 22:30', () {
      final at = ReminderService.tonightInstant(DateTime(2026, 7, 7, 22));
      expect(at, DateTime(2026, 7, 8, 19),
          reason: 'now+2h would be midnight — nobody wants that nudge');
    });
  });
}

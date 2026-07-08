import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/activity_history_model.dart';

void main() {
  group('persistence', () {
    test('recordActivity persists after the debounce window', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);

      model.recordActivity('read-a-book');
      // Nothing hits storage until the 500 ms debounce fires.
      expect(prefs.getString('activityHistory'), isNull);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      final stored = jsonDecode(prefs.getString('activityHistory')!)
          as List<dynamic>;
      expect((stored.single as Map<String, dynamic>)['id'], 'read-a-book');
    });

    test('rapid records coalesce into one save with all entries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);

      model.recordActivity('a');
      model.recordActivity('b');
      model.recordActivity('c');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final stored = jsonDecode(prefs.getString('activityHistory')!)
          as List<dynamic>;
      expect(
        stored.map((e) => (e as Map<String, dynamic>)['id']).toSet(),
        {'a', 'b', 'c'},
      );
    });

    test('save and load use the same key (round-trip)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);
      model.recordActivity('a');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final reloaded = ActivityHistoryModel(prefs);
      expect(reloaded.activityHistory.keys, ['a']);
    });

    test('malformed JSON resets to empty instead of crashing', () async {
      SharedPreferences.setMockInitialValues({
        'activityHistory': '{definitely not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);
      expect(model.activityHistory, isEmpty);
    });

    test('non-map JSON resets to empty instead of crashing', () async {
      SharedPreferences.setMockInitialValues({
        'activityHistory': '["a", "b"]',
      });
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);
      expect(model.activityHistory, isEmpty);
    });
  });

  group('getRecentActivities', () {
    test('sorts newest first and honors the limit', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'activityHistory': jsonEncode({
          'oldest': now.subtract(const Duration(days: 3)).toIso8601String(),
          'newest': now.toIso8601String(),
          'middle': now.subtract(const Duration(days: 1)).toIso8601String(),
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);

      final all = model.getRecentActivities();
      expect(all.map((e) => e.key).toList(), ['newest', 'middle', 'oldest']);

      final limited = model.getRecentActivities(limit: 2);
      expect(limited.map((e) => e.key).toList(), ['newest', 'middle']);
    });

    test('re-recording an activity moves it to the top', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'activityHistory': jsonEncode({
          'a': now.subtract(const Duration(days: 3)).toIso8601String(),
          'b': now.subtract(const Duration(days: 1)).toIso8601String(),
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);

      model.recordActivity('a');

      expect(model.getRecentActivities().first.key, 'a');
      expect(model.activityHistory, hasLength(2),
          reason: 'latest-per-id view collapses repeats');
      expect(model.events, hasLength(3),
          reason: 'the event log keeps every completion');
    });
  });

  group('events, streaks, and per-day stats', () {
    Future<ActivityHistoryModel> modelWithEventDays(List<int> daysAgo) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);
      final now = DateTime.now();
      for (final d in daysAgo) {
        model.events.add(
          ActivityEvent('act-$d', now.subtract(Duration(days: d))),
        );
      }
      return model;
    }

    test('repeat completions accumulate as events', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);

      model.recordActivity('cook');
      model.recordActivity('cook');

      expect(model.totalCompletions, 2);
      expect(model.getRecentEvents(), hasLength(2),
          reason: 'History shows both completions');
      expect(model.activityHistory, hasLength(1),
          reason: 'compat view stays latest-per-id');
    });

    test('v2 map payload loads via the tolerant loader', () async {
      SharedPreferences.setMockInitialValues({
        'activityHistory': jsonEncode({
          'a': '2026-06-01T10:00:00.000',
          'b': '2026-06-02T10:00:00.000',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final model = ActivityHistoryModel(prefs);
      expect(model.events, hasLength(2));
      expect(model.events.first.id, 'a', reason: 'sorted ascending');
    });

    test('currentStreak counts consecutive days back from today', () async {
      final model = await modelWithEventDays([0, 1, 2, 5]);
      expect(model.currentStreak, 3);
      expect(model.completedToday, isTrue);
    });

    test('streak survives an unfinished today', () async {
      final model = await modelWithEventDays([1, 2]);
      expect(model.currentStreak, 2,
          reason: 'today is not over — yesterday anchors the streak');
      expect(model.completedToday, isFalse);
    });

    test('a gap breaks the streak', () async {
      final model = await modelWithEventDays([2, 3]);
      expect(model.currentStreak, 0);
    });

    test('empty history means zero streak', () async {
      final model = await modelWithEventDays([]);
      expect(model.currentStreak, 0);
      expect(model.totalCompletions, 0);
    });
  });
}

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
          as Map<String, dynamic>;
      expect(stored.keys, ['read-a-book']);
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
          as Map<String, dynamic>;
      expect(stored.keys.toSet(), {'a', 'b', 'c'});
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
          reason: 'record updates the timestamp, not a duplicate entry');
    });
  });
}

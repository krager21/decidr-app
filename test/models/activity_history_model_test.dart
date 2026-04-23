import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decidr_app/models/activity_history_model.dart';
import 'package:decidr_app/utils/constants.dart';

void main() {
  group('ActivityHistoryModel', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('starts empty when no stored history', () {
      final model = ActivityHistoryModel(prefs);
      expect(model.activityHistory, isEmpty);
      expect(model.getRecentActivities(), isEmpty);
    });

    test('recordActivity adds an entry immediately and notifies listeners', () {
      final model = ActivityHistoryModel(prefs);
      var notified = 0;
      model.addListener(() => notified++);

      model.recordActivity('Take a walk');

      expect(model.activityHistory.containsKey('Take a walk'), isTrue);
      expect(notified, 1);
    });

    test('recordActivity does not create duplicate entries for same name',
        () {
      final model = ActivityHistoryModel(prefs);

      model.recordActivity('Read a book');
      model.recordActivity('Read a book');
      model.recordActivity('Read a book');

      expect(model.activityHistory.length, 1);
      expect(model.activityHistory.containsKey('Read a book'), isTrue);
    });

    test('getRecentActivities returns newest first, respecting limit', () {
      final model = ActivityHistoryModel(prefs);
      final base = DateTime(2024, 1, 1);

      // Seed directly with known timestamps for determinism.
      model.activityHistory
        ..['oldest'] = base
        ..['middle'] = base.add(const Duration(hours: 1))
        ..['newest'] = base.add(const Duration(hours: 2));

      final recent = model.getRecentActivities(limit: 2);
      expect(recent.map((e) => e.key).toList(), ['newest', 'middle']);
    });

    test('loads history from SharedPreferences on construction', () async {
      final stored = {
        'Meditate': DateTime(2024, 5, 1).toIso8601String(),
        'Cook a meal': DateTime(2024, 5, 2).toIso8601String(),
      };
      SharedPreferences.setMockInitialValues({
        StorageConstants.keyActivityHistory: jsonEncode(stored),
      });
      prefs = await SharedPreferences.getInstance();

      final model = ActivityHistoryModel(prefs);

      expect(model.activityHistory.keys,
          containsAll(['Meditate', 'Cook a meal']));
      expect(model.activityHistory['Meditate'], DateTime(2024, 5, 1));
    });

    test('recovers from corrupted JSON', () async {
      SharedPreferences.setMockInitialValues({
        StorageConstants.keyActivityHistory: 'not-valid-json{',
      });
      prefs = await SharedPreferences.getInstance();

      // Should not throw and should fall back to an empty map.
      final model = ActivityHistoryModel(prefs);
      expect(model.activityHistory, isEmpty);
    });

    test('debounced save persists to SharedPreferences', () async {
      final model = ActivityHistoryModel(prefs);
      model.recordActivity('Go for a run');

      // Wait for debounce window to elapse plus a small buffer.
      await Future<void>.delayed(
        StorageConstants.saveDebounceDuration + const Duration(milliseconds: 50),
      );

      final raw = prefs.getString(StorageConstants.keyActivityHistory);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded.containsKey('Go for a run'), isTrue);
    });

    test('dispose cancels any pending save timer', () {
      final model = ActivityHistoryModel(prefs);
      model.recordActivity('Bake something');
      // If dispose did not cancel the timer, the save would fire after
      // teardown and could write to a disposed prefs instance. We only
      // assert that calling dispose does not throw.
      expect(() => model.dispose(), returnsNormally);
    });
  });
}

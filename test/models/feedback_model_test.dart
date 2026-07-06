import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/feedback_model.dart';

/// Seed `activity_rejections` with timestamps at fixed offsets from now.
Future<FeedbackModel> modelWithRejections(
    Map<String, List<Duration>> agoById) async {
  final now = DateTime.now();
  final payload = agoById.map((id, agos) => MapEntry(
        id,
        agos.map((ago) => now.subtract(ago).toIso8601String()).toList(),
      ));
  SharedPreferences.setMockInitialValues({
    'activity_rejections': jsonEncode(payload),
  });
  final prefs = await SharedPreferences.getInstance();
  return FeedbackModel(prefs);
}

void main() {
  group('getActivityWeight decay tiers', () {
    test('same-day rejection costs 0.3', () async {
      final model = await modelWithRejections({
        'a': [const Duration(hours: 1)],
      });
      expect(model.getActivityWeight('a'), closeTo(0.7, 1e-9));
    });

    test('this-week rejection costs 0.2', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 3)],
      });
      expect(model.getActivityWeight('a'), closeTo(0.8, 1e-9));
    });

    test('this-month rejection costs 0.1', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 10)],
      });
      expect(model.getActivityWeight('a'), closeTo(0.9, 1e-9));
    });

    test('rejections older than 30 days are ignored', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 45)],
      });
      expect(model.getActivityWeight('a'), 1.0);
    });

    test('penalties stack across rejections', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 3), const Duration(days: 10)],
      });
      // 0.2 + 0.1 → weight 0.7
      expect(model.getActivityWeight('a'), closeTo(0.7, 1e-9));
    });

    test('weight is floored at 0.1 no matter how many rejections', () async {
      final model = await modelWithRejections({
        'a': List.filled(5, const Duration(hours: 1)),
      });
      expect(model.getActivityWeight('a'), closeTo(0.1, 1e-9));
    });

    test('no feedback means full weight', () async {
      final model = await modelWithRejections({});
      expect(model.getActivityWeight('unknown'), 1.0);
    });

    test('dislike overrides everything with 0.0', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 45)],
      });
      model.dislikeActivity('a');
      expect(model.getActivityWeight('a'), 0.0);
      expect(model.isDisliked('a'), isTrue);
    });
  });

  group('rejection bookkeeping', () {
    test('rejectActivity caps stored timestamps at 5', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = FeedbackModel(prefs);

      for (var i = 0; i < 8; i++) {
        model.rejectActivity('a');
      }

      expect(model.rejections['a'], hasLength(5));
    });

    test('getRecentRejectionsCount counts the 30-day window only',
        () async {
      final model = await modelWithRejections({
        'a': [
          const Duration(days: 1),
          const Duration(days: 20),
          const Duration(days: 45),
        ],
      });
      expect(model.getRecentRejectionsCount('a'), 2);
    });
  });

  group('persistence round-trip', () {
    test('reject + dislike survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = FeedbackModel(prefs);
      model.rejectActivity('a');
      model.dislikeActivity('b');
      // _saveFeedback is fire-and-forget; give it a tick to flush.
      await Future<void>.delayed(Duration.zero);

      final reloaded = FeedbackModel(prefs);
      expect(reloaded.rejections['a'], hasLength(1));
      expect(reloaded.isDisliked('b'), isTrue);
    });

    test('clearFeedback removes one id and persists', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 1)],
        'b': [const Duration(days: 1)],
      });
      model.clearFeedback('a');
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final reloaded = FeedbackModel(prefs);
      expect(reloaded.getActivityWeight('a'), 1.0);
      expect(reloaded.getActivityWeight('b'), lessThan(1.0));
    });

    test('clearAllFeedback wipes everything and persists', () async {
      final model = await modelWithRejections({
        'a': [const Duration(days: 1)],
      });
      model.dislikeActivity('b');
      model.clearAllFeedback();
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final reloaded = FeedbackModel(prefs);
      expect(reloaded.rejections, isEmpty);
      expect(reloaded.dislikes, isEmpty);
    });

    test('malformed rejections JSON loads as empty instead of crashing',
        () async {
      SharedPreferences.setMockInitialValues({
        'activity_rejections': '{broken',
        'activity_dislikes': ['b'],
      });
      final prefs = await SharedPreferences.getInstance();
      final model = FeedbackModel(prefs);
      expect(model.rejections, isEmpty);
      expect(model.getActivityWeight('a'), 1.0);
    });
  });
}

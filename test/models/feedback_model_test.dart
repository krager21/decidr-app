import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decidr_app/models/feedback_model.dart';

void main() {
  group('FeedbackModel', () {
    late SharedPreferences prefs;
    late FeedbackModel model;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      model = FeedbackModel(prefs);
    });

    test('activity with no feedback has full weight (1.0)', () {
      expect(model.getActivityWeight('Take a walk'), 1.0);
    });

    test('disliked activities get 0 weight', () {
      model.dislikeActivity('Go for a run');
      expect(model.getActivityWeight('Go for a run'), 0.0);
      expect(model.isDisliked('Go for a run'), isTrue);
    });

    test('rejections reduce weight but keep it above 0.1', () {
      model.rejectActivity('Read a book');
      final weight = model.getActivityWeight('Read a book');
      expect(weight, lessThan(1.0));
      expect(weight, greaterThanOrEqualTo(0.1));
    });

    test('multiple same-day rejections compound the penalty', () {
      final one = model.getActivityWeight('Meditate');
      model.rejectActivity('Meditate');
      final two = model.getActivityWeight('Meditate');
      model.rejectActivity('Meditate');
      final three = model.getActivityWeight('Meditate');

      expect(two, lessThan(one));
      expect(three, lessThan(two));
    });

    test('rejection list is capped at 5 entries per activity', () {
      for (var i = 0; i < 10; i++) {
        model.rejectActivity('Cook a meal');
      }
      expect(model.rejections['Cook a meal']!.length, 5);
    });

    test('rejections older than 30 days do not penalize', () {
      // Seed the internal map with an old rejection.
      final oldDate = DateTime.now().subtract(const Duration(days: 45));
      model.rejections['Old activity'] = [oldDate];
      expect(model.getActivityWeight('Old activity'), 1.0);
      expect(model.getRecentRejectionsCount('Old activity'), 0);
    });

    test('getRecentRejectionsCount only counts last 30 days', () {
      final now = DateTime.now();
      model.rejections['Yoga'] = [
        now.subtract(const Duration(days: 1)),
        now.subtract(const Duration(days: 20)),
        now.subtract(const Duration(days: 60)), // outside window
      ];
      expect(model.getRecentRejectionsCount('Yoga'), 2);
    });

    test('clearFeedback removes both rejections and dislikes for the activity',
        () {
      model.rejectActivity('Dance');
      model.dislikeActivity('Dance');
      model.clearFeedback('Dance');

      expect(model.rejections['Dance'], isNull);
      expect(model.isDisliked('Dance'), isFalse);
      expect(model.getActivityWeight('Dance'), 1.0);
    });

    test('clearAllFeedback wipes all entries', () {
      model.rejectActivity('A');
      model.dislikeActivity('B');
      model.clearAllFeedback();

      expect(model.rejections, isEmpty);
      expect(model.dislikes, isEmpty);
    });

    test('notifies listeners on reject / dislike / clear', () async {
      // _loadFeedback() in the constructor is async and fires notifyListeners;
      // let that microtask flush before we start counting.
      await Future<void>.delayed(Duration.zero);

      var count = 0;
      model.addListener(() => count++);

      model.rejectActivity('X');
      model.dislikeActivity('Y');
      model.clearFeedback('X');
      model.clearAllFeedback();

      expect(count, 4);
    });

    test('feedback persists across instances', () async {
      model.dislikeActivity('Swim');
      model.rejectActivity('Swim');

      // Let the async save complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reloaded = FeedbackModel(prefs);
      // Give the async load a chance to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(reloaded.isDisliked('Swim'), isTrue);
      expect(reloaded.rejections['Swim'], isNotEmpty);
    });
  });
}

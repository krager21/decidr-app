import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/activity_history_model.dart';
import 'package:decidr_app/models/feedback_model.dart';
import 'package:decidr_app/models/preferences_model.dart';
import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/screens/card_reveal_page.dart';
import 'package:decidr_app/services/places_service.dart';
import 'package:decidr_app/services/premium_service.dart';
import 'package:decidr_app/services/reminder_service.dart';
import 'package:decidr_app/services/weather_service.dart';

/// Widget tests for the deal → settle → act flow. This page is the
/// sole write path for history (recordActivity) and negative feedback
/// (rejectActivity/dislikeActivity); these tests pin the id wiring the
/// Phase-3 migration exists to protect.
///
/// The reveal choreography runs ~5.2 s of animations and timers, so
/// tests advance frames with explicit pumps — pumpAndSettle would
/// never return while the considering-pulse loop is live.
Future<
    ({
      ActivityHistoryModel history,
      FeedbackModel feedback,
      PreferencesModel prefs,
    })> pumpDealPage(WidgetTester tester) async {
  // The settled state's action row sits below the default 800x600
  // test viewport — use a phone-shaped surface so taps can land.
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'activityPreference': 'Indoor',
    'autoDetectTime': true,
  });
  final sharedPrefs = await SharedPreferences.getInstance();
  final prefs = PreferencesModel(sharedPrefs);
  await prefs.loadPreferences();
  prefs.mood = 'Relaxed'; // session-only, set in memory like the app does

  final repo = SuggestionsRepository(sharedPrefs);
  await repo.loadSuggestions();
  final history = ActivityHistoryModel(sharedPrefs);
  final feedback = FeedbackModel(sharedPrefs);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider.value(value: feedback),
        ChangeNotifierProvider(create: (_) => WeatherService()),
        ChangeNotifierProvider(create: (_) => PlacesService()),
        ChangeNotifierProvider(
          create: (_) => PremiumService(storeAvailable: false),
        ),
        Provider<ReminderService>(create: (_) => ReminderService()),
      ],
      child: const MaterialApp(home: CardRevealPage()),
    ),
  );
  return (history: history, feedback: feedback, prefs: prefs);
}

/// Advance through the full deal choreography (considering ~1.9s,
/// deal-in ~1.1s, flips + settle ~2.3s) to the settled state.
Future<void> dealToSettled(WidgetTester tester) async {
  await tester.tap(find.text('Deal cards'));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(find.text('Did it!'), findsOneWidget,
      reason: 'deal should have settled by now');
}

void main() {
  testWidgets('deal settles and "Did it!" records the chosen id',
      (tester) async {
    final models = await pumpDealPage(tester);
    await dealToSettled(tester);

    await tester.tap(find.text('Did it!'));
    await tester.pump();

    expect(models.history.activityHistory, hasLength(1),
        reason: 'exactly the chosen card lands in history');
    final recordedId = models.history.activityHistory.keys.single;
    expect(recordedId, isNotEmpty);
    // The id must resolve to a real catalog suggestion (not a title).
    final repo = SuggestionsRepository(
        await SharedPreferences.getInstance());
    expect(repo.suggestionById(recordedId), isNotNull,
        reason: 'history must be keyed by Suggestion.id, got $recordedId');

    // Let the snackbar's 2s timer elapse before the test tears down.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('"Not right now" records a rejection for the chosen id',
      (tester) async {
    final models = await pumpDealPage(tester);
    await dealToSettled(tester);

    await tester.tap(find.text('Not this'));
    // Let the modal bottom sheet finish animating in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not right now'), findsOneWidget,
        reason: 'the Not-this options sheet should be open');
    await tester.tap(find.text('Not right now'));
    // The tap kicks off a fresh deal — walk it forward far enough to
    // flush its timers before teardown.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(models.feedback.rejections, hasLength(1));
    expect(models.feedback.dislikes, isEmpty);
  });

  testWidgets('favorite heart on the chosen card toggles the id',
      (tester) async {
    final models = await pumpDealPage(tester);
    await dealToSettled(tester);

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pump();

    expect(models.prefs.favoriteActivities, hasLength(1));
    // The same control removes it again.
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pump();
    expect(models.prefs.favoriteActivities, isEmpty);
  });

  testWidgets('incomplete preferences never show the deal CTA',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PreferencesModel(sharedPrefs);
    await prefs.loadPreferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: prefs),
          ChangeNotifierProvider(
              create: (_) => SuggestionsRepository(sharedPrefs)),
          ChangeNotifierProvider(
              create: (_) => ActivityHistoryModel(sharedPrefs)),
          ChangeNotifierProvider(create: (_) => FeedbackModel(sharedPrefs)),
          ChangeNotifierProvider(create: (_) => WeatherService()),
          ChangeNotifierProvider(create: (_) => PlacesService()),
          ChangeNotifierProvider(
              create: (_) => PremiumService(storeAvailable: false)),
        ],
        child: const MaterialApp(home: CardRevealPage()),
      ),
    );

    expect(find.text('Deal cards'), findsNothing);
  });
}

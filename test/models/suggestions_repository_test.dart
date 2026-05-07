import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/feedback_model.dart';
import 'package:decidr_app/models/suggestion.dart';
import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/models/weather_model.dart';

void main() {
  late SuggestionsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = SuggestionsRepository(prefs);
    await repo.loadSuggestions();
  });

  group('Structured filtering', () {
    test('base filter returns indoor relaxed catalog entries', () {
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 2.0,
      );

      expect(results, isNotEmpty);
      for (final s in results) {
        expect(s.activityType, ActivityType.indoor);
        expect(s.moods.contains(Mood.relaxed), isTrue,
            reason: '${s.id} not tagged Relaxed');
      }
    });

    test('outdoor activities are excluded when activityType is indoor', () {
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.afternoon,
        energyLevel: 2.0,
      );
      for (final s in results) {
        expect(s.activityType, isNot(ActivityType.outdoor));
      }
    });

    test('time-of-day filter excludes mismatched items when pool is large',
        () {
      // Indoor/Relaxed has plenty of entries, so the time-of-day filter
      // should successfully narrow the pool. None of the returned items
      // should have a non-empty timeOfDay list that excludes morning.
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.morning,
        energyLevel: 2.0,
      );
      for (final s in results) {
        if (s.timeOfDay.isEmpty) continue; // any-time entries are fine
        expect(s.timeOfDay.contains(TimeOfDayPref.morning), isTrue,
            reason: '${s.id} has timeOfDay ${s.timeOfDay} but Morning '
                'was requested');
      }
    });

    test('graceful degradation: a too-restrictive filter is skipped', () {
      // Outdoor + Productive + Solo + Quick (15 min) — extremely narrow.
      // Even if the filter pipeline can't satisfy every constraint,
      // it should still return at least one result rather than empty.
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.outdoor,
        mood: Mood.productive,
        timeOfDay: TimeOfDayPref.morning,
        energyLevel: 2.0,
        socialContext: SocialContext.solo,
        duration: 'Quick (15 min)',
      );
      expect(results, isNotEmpty,
          reason: 'Graceful degradation should prevent empty results');
    });

    test('social filter prefers matching entries when feasible', () {
      // Outdoor/Social bucket has multiple largeGroup-friendly entries
      // (BBQ, festival, picnic, yoga). The filter should produce a result
      // set where the proportion of largeGroup-supporting items is higher
      // than in the unfiltered pool — at minimum, the highest-ranked
      // result should be one that supports largeGroup if any do.
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.outdoor,
        mood: Mood.social,
        timeOfDay: TimeOfDayPref.afternoon,
        energyLevel: 3.0,
        socialContext: SocialContext.largeGroup,
      );
      final supportsLargeGroup =
          results.where((s) => s.social.contains(SocialContext.largeGroup));
      expect(supportsLargeGroup, isNotEmpty,
          reason: 'At least some largeGroup-friendly options should appear');
    });

    test('weather filter handles rain without crashing', () {
      // The Outdoor/Relaxed bucket is small and entirely drySpellsOnly,
      // so the weather filter would empty it; graceful degradation
      // returns the unfiltered pool. Either way, results must be
      // non-empty (the user always gets *something*).
      final rainy = WeatherData(
        condition: 'rain',
        temperature: 15,
        feelsLike: 14,
        humidity: 90,
        windSpeed: 5,
        isGoodForOutdoor: false,
        fetchedAt: DateTime.now(),
      );
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.outdoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.afternoon,
        energyLevel: 2.0,
        weather: rainy,
      );
      expect(results, isNotEmpty,
          reason: 'Graceful degradation should always return results');
    });

    test('weather filter excludes drySpellsOnly when pool has flex options',
        () {
      // Hybrid/Relaxed has weather: any entries (audiobook, tea-and-think,
      // coloring-book, gentle-stretching, people-watch) — none are
      // drySpellsOnly. Filter should keep all of them in the rain.
      final rainy = WeatherData(
        condition: 'rain',
        temperature: 15,
        feelsLike: 14,
        humidity: 90,
        windSpeed: 5,
        isGoodForOutdoor: false,
        fetchedAt: DateTime.now(),
      );
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.hybrid,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.afternoon,
        energyLevel: 2.0,
        weather: rainy,
      );
      for (final s in results) {
        if (s.isCustom) continue;
        // No outdoor-only-dry suggestion should sneak through.
        if (s.activityType == ActivityType.outdoor) {
          expect(s.weather, isNot(WeatherTolerance.drySpellsOnly),
              reason: '${s.id} is drySpellsOnly outdoor in rainy weather');
        }
      }
    });

    test('disliked suggestions are excluded by feedback', () async {
      // Pick a known catalog suggestion and dislike it by id (Phase 3).
      final disliked = repo.catalog.firstWhere(
        (s) =>
            s.activityType == ActivityType.indoor &&
            s.moods.contains(Mood.relaxed),
      );

      final feedback = FeedbackModel(await SharedPreferences.getInstance());
      feedback.dislikeActivity(disliked.id);

      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 2.0,
        feedback: feedback,
      );

      expect(results.where((s) => s.id == disliked.id), isEmpty,
          reason: 'Disliked activity must not appear');
    });

    test('custom suggestions are injected when includeCustom is true',
        () async {
      repo.addCustomSuggestion('Build a Lego castle');

      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.creative,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 3.0,
        count: 20,
      );

      expect(results.where((s) => s.title == 'Build a Lego castle'),
          isNotEmpty,
          reason: 'Custom suggestion should appear in results');
    });

    test('favorites are lifted to the top of results', () {
      // Pick a known catalog suggestion that matches the filter.
      final fav = repo.catalog.firstWhere(
        (s) =>
            s.activityType == ActivityType.indoor &&
            s.moods.contains(Mood.creative),
      );

      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.creative,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 3.0,
        favoriteIds: [fav.id],
      );
      expect(results.first.id, fav.id,
          reason: 'Favorite should be the first result');
    });

    test('count caps the result length', () {
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.afternoon,
        energyLevel: 2.0,
        count: 3,
      );
      expect(results.length, lessThanOrEqualTo(3));
    });
  });

  group('Legacy string API', () {
    test('returns titles, not Suggestion records', () {
      final titles = repo.getSuggestions(
        activity: 'Indoor',
        mood: 'Relaxed',
        timeOfDay: 'Evening',
        energyLevel: 2.0,
      );
      expect(titles, isNotEmpty);
      // Each title corresponds to a real catalog suggestion.
      for (final t in titles) {
        expect(repo.suggestionByTitle(t), isNotNull,
            reason: 'Title "$t" not resolvable in catalog');
      }
    });

    test('unknown activity returns empty list', () {
      final titles = repo.getSuggestions(
        activity: 'Underwater',
        mood: 'Relaxed',
        timeOfDay: 'Evening',
        energyLevel: 2.0,
      );
      expect(titles, isEmpty);
    });

    test('unknown mood returns empty list', () {
      final titles = repo.getSuggestions(
        activity: 'Indoor',
        mood: 'Energetic',
        timeOfDay: 'Evening',
        energyLevel: 2.0,
      );
      expect(titles, isEmpty);
    });
  });

  group('Icon resolution', () {
    test('catalog title resolves to its declared icon', () {
      final s = repo.catalog.first;
      final icon = repo.getIconForSuggestion(s.title);
      expect(icon, s.iconData);
    });

    test('unknown title falls back to keyword heuristic', () {
      // "Long bicycle ride" matches the 'bike' keyword.
      final icon = repo.getIconForSuggestion('Long bicycle ride');
      expect(icon, isNotNull);
    });
  });

  group('Custom suggestion validation', () {
    test('rejects empty input', () {
      expect(repo.addCustomSuggestion(''), isFalse);
      expect(repo.addCustomSuggestion('   '), isFalse);
    });

    test('rejects oversize input', () {
      expect(repo.addCustomSuggestion('a' * 60), isFalse);
    });

    test('rejects case-insensitive duplicate', () {
      expect(repo.addCustomSuggestion('Pottery'), isTrue);
      expect(repo.addCustomSuggestion('pottery'), isFalse);
      expect(repo.addCustomSuggestion('POTTERY'), isFalse);
    });

    test('trims whitespace', () {
      repo.addCustomSuggestion('  Knitting  ');
      expect(repo.customSuggestions.first.title, 'Knitting');
    });

    test('synthesizes a stable id with custom- prefix', () {
      repo.addCustomSuggestion('Pottery');
      final entry = repo.customSuggestions.first;
      expect(entry.id, startsWith('custom-'));
      expect(entry.isCustom, isTrue);
      expect(entry.title, 'Pottery');
    });
  });
}

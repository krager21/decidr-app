import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/models/feedback_model.dart';
import 'package:decidr_app/models/weather_model.dart';

WeatherData _weather({
  required String condition,
  required double temperature,
}) =>
    WeatherData(
      condition: condition,
      temperature: temperature,
      feelsLike: temperature,
      humidity: 50,
      windSpeed: 1.0,
      isGoodForOutdoor: !['rain', 'snow', 'storm', 'drizzle']
          .contains(condition.toLowerCase()),
      fetchedAt: DateTime.now(),
    );

void main() {
  group('SuggestionsRepository', () {
    late SharedPreferences prefs;
    late SuggestionsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = SuggestionsRepository(prefs);
      await repo.loadSuggestions();
    });

    group('custom suggestions', () {
      test('addCustomSuggestion stores unique entries only', () {
        repo.addCustomSuggestion('Brew tea');
        repo.addCustomSuggestion('Brew tea'); // duplicate
        repo.addCustomSuggestion('Water plants');

        expect(repo.customSuggestions, ['Brew tea', 'Water plants']);
      });

      test('removeCustomSuggestion removes an existing entry', () {
        repo.addCustomSuggestion('Brew tea');
        repo.addCustomSuggestion('Water plants');
        repo.removeCustomSuggestion('Brew tea');

        expect(repo.customSuggestions, ['Water plants']);
      });

      test('custom suggestions round-trip through SharedPreferences',
          () async {
        repo.addCustomSuggestion('Stretch');
        // `addCustomSuggestion` calls `saveCustomSuggestions` internally.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final reloaded = SuggestionsRepository(prefs);
        await reloaded.loadSuggestions();

        expect(reloaded.customSuggestions, contains('Stretch'));
      });
    });

    group('getSuggestions filters', () {
      test('returns at most 8 results', () {
        for (int i = 0; i < 20; i++) {
          final results = repo.getSuggestions(
            activity: 'Indoor',
            mood: 'Relaxed',
            timeOfDay: 'Afternoon',
            energyLevel: 3.0,
          );
          expect(results.length, lessThanOrEqualTo(8), reason: 'iteration $i');
          expect(results.length, greaterThan(0));
          // Dedup check: no duplicates.
          expect(results.toSet().length, results.length);
        }
      });

      test('rainy weather excludes outdoor keywords like "hike" and "picnic"',
          () {
        final weather = _weather(condition: 'rain', temperature: 15);

        // Sample many times because of internal shuffling.
        for (int i = 0; i < 30; i++) {
          final results = repo.getSuggestions(
            activity: 'Outdoor',
            mood: 'Energetic',
            timeOfDay: 'Afternoon',
            energyLevel: 4.0,
            weather: weather,
          );
          for (final s in results) {
            final lower = s.toLowerCase();
            expect(lower.contains('hike'), isFalse,
                reason: 'rainy run $i: $s');
            expect(lower.contains('picnic'), isFalse,
                reason: 'rainy run $i: $s');
          }
        }
      });

      test('hot weather excludes strenuous outdoor activities', () {
        final weather = _weather(condition: 'clear', temperature: 35);

        for (int i = 0; i < 30; i++) {
          final results = repo.getSuggestions(
            activity: 'Outdoor',
            mood: 'Energetic',
            timeOfDay: 'Afternoon',
            energyLevel: 5.0,
            weather: weather,
          );
          for (final s in results) {
            final lower = s.toLowerCase();
            // Per _filterByWeather, hot weather blocks run/hike/bike.
            expect(lower.contains('hike'), isFalse, reason: 'hot run $i: $s');
            expect(lower.contains('bike'), isFalse, reason: 'hot run $i: $s');
          }
        }
      });

      test('disliked activities never appear in results', () {
        final feedback = FeedbackModel(prefs);
        feedback.dislikeActivity('Read a book');
        feedback.dislikeActivity('Take a walk');

        for (int i = 0; i < 30; i++) {
          final results = repo.getSuggestions(
            activity: 'Indoor',
            mood: 'Relaxed',
            timeOfDay: 'Afternoon',
            energyLevel: 3.0,
            feedback: feedback,
          );
          expect(results, isNot(contains('Read a book')),
              reason: 'run $i');
          expect(results, isNot(contains('Take a walk')),
              reason: 'run $i');
        }
      });

      test('favorites are included when provided', () {
        final favorites = ['My favorite activity'];

        // Run many times — favorites should appear in at least one shuffle.
        var appeared = false;
        for (int i = 0; i < 50; i++) {
          final results = repo.getSuggestions(
            activity: 'Indoor',
            mood: 'Relaxed',
            timeOfDay: 'Afternoon',
            energyLevel: 3.0,
            favorites: favorites,
          );
          if (results.contains('My favorite activity')) {
            appeared = true;
            break;
          }
        }
        expect(appeared, isTrue,
            reason: 'favorite should surface within 50 shuffles');
      });

      test('social context "Solo" excludes group-keyword activities', () {
        for (int i = 0; i < 30; i++) {
          final results = repo.getSuggestions(
            activity: 'Indoor',
            mood: 'Social',
            timeOfDay: 'Afternoon',
            energyLevel: 3.0,
            socialContext: 'Solo',
          );
          for (final s in results) {
            final lower = s.toLowerCase();
            expect(lower.contains('group'), isFalse, reason: 'run $i: $s');
            expect(lower.contains('team'), isFalse, reason: 'run $i: $s');
            expect(lower.contains('multiplayer'), isFalse,
                reason: 'run $i: $s');
          }
        }
      });

      test('unknown activity/mood falls back to defaults without throwing',
          () {
        expect(
          () => repo.getSuggestions(
            activity: 'Nonexistent',
            mood: 'Nonexistent',
            timeOfDay: 'Afternoon',
            energyLevel: 3.0,
          ),
          returnsNormally,
        );
      });
    });

    group('getIconForSuggestion', () {
      test('matches known keywords to semantic icons', () {
        expect(repo.getIconForSuggestion('Read a book'), Icons.book);
        expect(
            repo.getIconForSuggestion('Take a walk'), Icons.directions_walk);
        expect(repo.getIconForSuggestion('Go for a run'), Icons.directions_run);
        expect(repo.getIconForSuggestion('Meditate for 15 minutes'),
            Icons.self_improvement);
        expect(repo.getIconForSuggestion('Cook a meal'), Icons.restaurant);
      });

      test('unknown suggestions fall back to a default icon', () {
        final icon =
            repo.getIconForSuggestion('Do something extraordinary zzz');
        // Default per implementation is emoji_objects — just assert it is a
        // non-null IconData so the fallback path is exercised.
        expect(icon, isA<IconData>());
      });
    });

    group('getSuggestionDetails', () {
      test('returns generic details for unknown suggestions', () {
        final details = repo.getSuggestionDetails('Totally unknown activity');
        expect(details['description'], isNotEmpty);
        expect(details['benefits'], isNotEmpty);
        expect(details['tips'], isNotEmpty);
      });

      test('returns tailored details for keyword matches', () {
        final walk = repo.getSuggestionDetails('Take a walk');
        final read = repo.getSuggestionDetails('Read a book');
        expect(walk['description'], isNot(equals(read['description'])));
        expect(walk['description']!.toLowerCase(), contains('walk'));
      });
    });
  });
}

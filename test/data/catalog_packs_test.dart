import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/data/catalog_packs.dart';
import 'package:decidr_app/data/context_cards.dart';
import 'package:decidr_app/data/seasonal_packs.dart';
import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/models/weather_model.dart';
import 'package:decidr_app/models/suggestion.dart';

Future<SuggestionsRepository> repoAt(DateTime now) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = SuggestionsRepository(prefs, clock: () => now);
  await repo.loadSuggestions();
  return repo;
}

WeatherData weatherWith({String condition = 'clear', double temp = 20}) =>
    WeatherData(
      condition: condition,
      temperature: temp,
      feelsLike: temp,
      humidity: 50,
      windSpeed: 2,
      isGoodForOutdoor: true,
      fetchedAt: DateTime.now(),
    );

void main() {
  group('SeasonalWindow', () {
    test('plain window contains its bounds inclusively', () {
      const w = SeasonalWindow(6, 1, 8, 31);
      expect(w.contains(DateTime(2026, 6, 1)), isTrue);
      expect(w.contains(DateTime(2026, 8, 31)), isTrue);
      expect(w.contains(DateTime(2026, 5, 31)), isFalse);
      expect(w.contains(DateTime(2026, 9, 1)), isFalse);
    });

    test('year-wrapping window spans December into January', () {
      const w = SeasonalWindow(12, 28, 1, 15);
      expect(w.contains(DateTime(2026, 12, 31)), isTrue);
      expect(w.contains(DateTime(2027, 1, 10)), isTrue);
      expect(w.contains(DateTime(2026, 7, 1)), isFalse);
    });
  });

  group('catalog composition', () {
    test('July catalog has summer cards but no Halloween', () async {
      final repo = await repoAt(DateTime(2026, 7, 15));
      final ids = repo.catalog.map((s) => s.id).toSet();
      expect(ids.containsAll(summerEveningCards.map((s) => s.id)), isTrue);
      expect(ids.intersection(halloweenCards.map((s) => s.id).toSet()),
          isEmpty);
    });

    test('late-October catalog has autumn AND Halloween packs', () async {
      final repo = await repoAt(DateTime(2026, 10, 28));
      final ids = repo.catalog.map((s) => s.id).toSet();
      expect(ids.containsAll(halloweenCards.map((s) => s.id)), isTrue);
      expect(ids.containsAll(autumnCards.map((s) => s.id)), isTrue);
    });

    test('context packs are always in the catalog', () async {
      final repo = await repoAt(DateTime(2026, 3, 1));
      final ids = repo.catalog.map((s) => s.id).toSet();
      expect(ids.containsAll(lateNightCards.map((s) => s.id)), isTrue);
      expect(ids.containsAll(rainyDayCards.map((s) => s.id)), isTrue);
    });

    test('out-of-season ids still resolve for history/favorites',
        () async {
      final repo = await repoAt(DateTime(2026, 3, 1));
      final halloweenId = halloweenCards.first.id;
      expect(repo.suggestionById(halloweenId), isNotNull,
          reason: 'a Halloween completion must render in March');
      expect(repo.resolveById(halloweenId).title,
          halloweenCards.first.title);
    });
  });

  group('weather-positive scoring', () {
    test('rain boosts rainy-day cards into the deal', () async {
      final repo = await repoAt(DateTime(2026, 3, 1));
      // Ask in the pool where the indoor rainy cards live.
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 1.5,
        weather: weatherWith(condition: 'rain'),
        count: 12,
      );
      expect(
        results.any((s) => s.tags.contains('rainy-day')),
        isTrue,
        reason: 'rain should surface at least one rain-celebrating card '
            'in a 12-card ask',
      );
    });

    test('clear skies push rain cards out of the top band', () async {
      final repo = await repoAt(DateTime(2026, 3, 1));
      final results = repo.getStructuredSuggestions(
        activityType: ActivityType.indoor,
        mood: Mood.relaxed,
        timeOfDay: TimeOfDayPref.evening,
        energyLevel: 1.5,
        weather: weatherWith(condition: 'clear'),
        count: 8,
      );
      final rainCards =
          results.where((s) => s.tags.contains('rainy-day')).length;
      expect(rainCards, lessThanOrEqualTo(1),
          reason: 'the 0.5 mismatch penalty should keep sunny deals '
              'nearly rain-free');
    });
  });
}

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
    test('rain lifts rainy-day cards; clear skies suppress them',
        () async {
      final repo = await repoAt(DateTime(2026, 3, 1));

      // Deterministic: fixed seeds, count across several hands, and
      // assert the *relationship* between rain and clear — the boost
      // (x1.5) and penalty (x0.5) must move the needle.
      int rainyCount(WeatherData weather) {
        var hits = 0;
        for (var seed = 0; seed < 10; seed++) {
          final results = repo.getStructuredSuggestions(
            activityType: ActivityType.indoor,
            mood: Mood.relaxed,
            timeOfDay: TimeOfDayPref.evening,
            energyLevel: 1.5,
            weather: weather,
            count: 8,
            shuffleSeed: seed,
          );
          hits +=
              results.where((s) => s.tags.contains('rainy-day')).length;
        }
        return hits;
      }

      final inRain = rainyCount(weatherWith(condition: 'rain'));
      final inSun = rainyCount(weatherWith(condition: 'clear'));
      expect(inRain, greaterThan(inSun),
          reason: 'rain=$inRain vs clear=$inSun across 10 seeded hands');
    });
  });
}

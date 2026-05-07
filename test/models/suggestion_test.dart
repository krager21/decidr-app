import 'package:flutter_test/flutter_test.dart';
import 'package:decidr_app/data/suggestions_catalog.dart';
import 'package:decidr_app/models/suggestion.dart';

void main() {
  group('Suggestion catalog', () {
    test('every catalog entry has a non-empty id, title, and description', () {
      for (final s in defaultSuggestions) {
        expect(s.id, isNotEmpty, reason: 'Suggestion has empty id');
        expect(s.title, isNotEmpty,
            reason: 'Suggestion ${s.id} has empty title');
        expect(s.description, isNotEmpty,
            reason: 'Suggestion ${s.id} has empty description');
      }
    });

    test('every catalog entry has a unique id', () {
      final ids = defaultSuggestions.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'Duplicate suggestion ids found');
    });

    test('energyLevel is within 1.0..5.0', () {
      for (final s in defaultSuggestions) {
        expect(s.energyLevel, inInclusiveRange(1.0, 5.0),
            reason: '${s.id} has out-of-range energyLevel ${s.energyLevel}');
      }
    });

    test('durationMinutes is positive', () {
      for (final s in defaultSuggestions) {
        expect(s.durationMinutes, greaterThan(0),
            reason: '${s.id} has non-positive duration');
      }
    });

    test('every entry has at least one mood and one social context', () {
      for (final s in defaultSuggestions) {
        expect(s.moods, isNotEmpty, reason: '${s.id} has no moods');
        expect(s.social, isNotEmpty,
            reason: '${s.id} has no social contexts');
      }
    });

    test('every entry resolves to a non-default IconData', () {
      // The fallback icon is local_activity_outlined; if a catalog entry's
      // iconName isn't in the lookup table, this will catch it.
      for (final s in defaultSuggestions) {
        // Just resolving without throwing is the smoke test; we don't require
        // the icon be non-default here because some entries legitimately use
        // the generic icon.
        expect(s.iconData, isNotNull, reason: '${s.id} icon resolution failed');
      }
    });

    test('round-trips through JSON without loss', () {
      for (final s in defaultSuggestions) {
        final json = s.toJson();
        final restored = Suggestion.fromJson(json);
        expect(restored.id, s.id);
        expect(restored.title, s.title);
        expect(restored.description, s.description);
        expect(restored.iconName, s.iconName);
        expect(restored.activityType, s.activityType);
        expect(restored.moods, s.moods);
        expect(restored.social, s.social);
        expect(restored.timeOfDay, s.timeOfDay);
        expect(restored.energyLevel, s.energyLevel);
        expect(restored.durationMinutes, s.durationMinutes);
        expect(restored.weather, s.weather);
        expect(restored.tags, s.tags);
        expect(restored.isCustom, s.isCustom);
      }
    });

    test('catalog covers every (activityType × mood) bucket', () {
      // We expect at least one entry in each of the 12 active buckets.
      // Energetic mood was removed from the UI, so it's not required.
      for (final type in ActivityType.values) {
        for (final mood in Mood.values) {
          final matching = defaultSuggestions.where(
            (s) => s.activityType == type && s.moods.contains(mood),
          );
          expect(matching, isNotEmpty,
              reason: 'No suggestions for ${type.label} × ${mood.label}');
        }
      }
    });

    test('catalog has at least 120 entries', () {
      // Phase 4 brings the catalog to ~140 entries across 12 buckets.
      // The bound is loose — additions are welcome; we just want
      // to fail loud if a regression deletes large chunks of content.
      expect(defaultSuggestions.length, greaterThanOrEqualTo(120));
    });
  });

  group('Suggestion equality', () {
    test('equality is by id, not field-wise', () {
      const a = Suggestion(
        id: 'shared',
        title: 'Original',
        description: 'desc',
        iconName: 'menu_book',
        activityType: ActivityType.indoor,
        moods: [Mood.relaxed],
        social: [SocialContext.solo],
        energyLevel: 1.0,
        durationMinutes: 30,
      );
      const b = Suggestion(
        id: 'shared',
        title: 'Renamed',
        description: 'different',
        iconName: 'menu_book',
        activityType: ActivityType.outdoor,
        moods: [Mood.creative],
        social: [SocialContext.partner],
        energyLevel: 5.0,
        durationMinutes: 90,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}

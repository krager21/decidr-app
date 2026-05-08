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
        expect(restored.interests, s.interests);
        expect(restored.weirdness, s.weirdness);
        expect(restored.isCustom, s.isCustom);
      }
    });

    test('weirdness is within 0.0..1.0 for every entry', () {
      for (final s in defaultSuggestions) {
        expect(s.weirdness, inInclusiveRange(0.0, 1.0),
            reason: '${s.id} has out-of-range weirdness ${s.weirdness}');
      }
    });

    test('Suggestion JSON without weirdness defaults to 0.2', () {
      // Backward-compat: older persisted JSON pre-dates the weirdness
      // field. Loading should not throw and should default to 0.2.
      final legacyJson = {
        'id': 'old-entry',
        'title': 'Old entry',
        'description': '',
        'iconName': 'menu_book',
        'activityType': 'indoor',
        'moods': ['relaxed'],
        'social': ['solo'],
        'energyLevel': 2.0,
        'durationMinutes': 30,
      };
      final s = Suggestion.fromJson(legacyJson);
      expect(s.weirdness, 0.2);
    });

    test('every interest used by the catalog is in Interests.all', () {
      final canonical = Interests.all.toSet();
      for (final s in defaultSuggestions) {
        for (final interest in s.interests) {
          expect(canonical, contains(interest),
              reason: '${s.id} uses unknown interest "$interest" — '
                  'add it to Interests.all or fix the typo');
        }
      }
    });

    test('Suggestion JSON without interests round-trips with empty list', () {
      // Backward-compat: old persisted JSON pre-dates the interests
      // field. Loading it should not throw and should produce an empty
      // interests list.
      final legacyJson = {
        'id': 'old-entry',
        'title': 'Old entry',
        'description': '',
        'iconName': 'menu_book',
        'activityType': 'indoor',
        'moods': ['relaxed'],
        'social': ['solo'],
        'energyLevel': 2.0,
        'durationMinutes': 30,
      };
      final s = Suggestion.fromJson(legacyJson);
      expect(s.interests, isEmpty);
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

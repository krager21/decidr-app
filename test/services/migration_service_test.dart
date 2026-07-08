import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/data/suggestions_catalog.dart';
import 'package:decidr_app/models/suggestion.dart';
import 'package:decidr_app/services/migration_service.dart';

void main() {
  group('MigrationService v1 → v2', () {
    test('fresh install (no v1 data) sets schema version to 2', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      expect(prefs.getInt('prefsSchemaVersion'), 3);
    });

    test('skips migration when already at target version', () async {
      SharedPreferences.setMockInitialValues({
        'prefsSchemaVersion': 3,
        'favoriteActivities': ['some-id-already-migrated'],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      // Untouched.
      expect(prefs.getStringList('favoriteActivities'),
          ['some-id-already-migrated']);
    });

    test('converts catalog title favorites to ids', () async {
      // Pick a known catalog title to migrate.
      final entry = defaultSuggestions.first;
      SharedPreferences.setMockInitialValues({
        'favoriteActivities': [entry.title, 'My weird custom thing'],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      final after = prefs.getStringList('favoriteActivities')!;
      expect(after.first, entry.id, reason: 'Catalog title should map to id');
      expect(after.last, startsWith('custom-'),
          reason: 'Unknown title should map to a custom-* id');
    });

    test('converts custom suggestions list-of-strings to JSON list', () async {
      SharedPreferences.setMockInitialValues({
        'customSuggestions': ['Pottery', 'Skateboarding'],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      // After migration the key holds a JSON String. The List<String>
      // shape is gone — getStringList on a String-typed key throws,
      // which is fine because nothing in the app reads it that way
      // post-Phase-3.
      final raw = prefs.getString('customSuggestions');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List<dynamic>;
      final suggestions = decoded
          .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(suggestions, hasLength(2));
      expect(suggestions.map((s) => s.title), ['Pottery', 'Skateboarding']);
      for (final s in suggestions) {
        expect(s.isCustom, isTrue);
        expect(s.id, startsWith('custom-'));
      }
    });

    test('migrates history map keys from titles to ids', () async {
      final entry = defaultSuggestions.first;
      final ts = DateTime(2025, 1, 1, 12).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'activityHistory': jsonEncode({entry.title: ts}),
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      // After the full 1→3 run, history is the v3 event-list shape.
      final raw = prefs.getString('activityHistory')!;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final event = decoded.single as Map<String, dynamic>;
      expect(event['id'], entry.id);
      expect(event['at'], ts);
    });

    test('migrates feedback rejections and dislikes', () async {
      final entry = defaultSuggestions.first;
      final ts = DateTime(2025, 1, 1, 12).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'activity_rejections': jsonEncode({
          entry.title: [ts],
        }),
        'activity_dislikes': [entry.title, 'A custom thing I dislike'],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      final rejRaw = prefs.getString('activity_rejections')!;
      final rejMap = jsonDecode(rejRaw) as Map<String, dynamic>;
      expect(rejMap.keys, contains(entry.id));

      final dislikes = prefs.getStringList('activity_dislikes')!;
      expect(dislikes.first, entry.id);
      expect(dislikes.last, startsWith('custom-'));
    });

    test('custom titles get consistent ids across migration steps', () async {
      // A custom title appearing in customSuggestions, favorites, history,
      // and feedback should resolve to the *same* id everywhere.
      const customTitle = 'Build a Lego castle';
      final ts = DateTime(2025, 1, 1, 12).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'customSuggestions': [customTitle],
        'favoriteActivities': [customTitle],
        'activityHistory': jsonEncode({customTitle: ts}),
        'activity_dislikes': [customTitle],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      // Pull out the synthesized id from the customs JSON.
      final customsRaw = prefs.getString('customSuggestions')!;
      final customsList = jsonDecode(customsRaw) as List<dynamic>;
      final customId = (customsList.first as Map<String, dynamic>)['id'] as String;

      // Same id should appear everywhere.
      expect(prefs.getStringList('favoriteActivities')!.first, customId);
      final hist = jsonDecode(prefs.getString('activityHistory')!)
          as List<dynamic>;
      expect((hist.single as Map<String, dynamic>)['id'], customId);
      expect(prefs.getStringList('activity_dislikes')!.first, customId);
    });

    test('schema bump only happens after success', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // No prior version key.
      expect(prefs.getInt('prefsSchemaVersion'), isNull);

      await MigrationService.migrateIfNeeded(prefs);
      expect(prefs.getInt('prefsSchemaVersion'), 3);

      // Calling again is a no-op.
      await MigrationService.migrateIfNeeded(prefs);
      expect(prefs.getInt('prefsSchemaVersion'), 3);
    });
  });

  group('MigrationService re-entrancy (retry after partial run)', () {
    test('does not crash when customSuggestions is already v2 JSON', () async {
      // Simulate a kill after step 2 wrote the JSON but before the
      // version bump: value is a String, version still v1.
      final v2Json = jsonEncode([
        const Suggestion(
          id: 'custom-abc123',
          title: 'Pottery',
          description: '',
          iconName: 'local_activity_outlined',
          activityType: ActivityType.hybrid,
          moods: [Mood.relaxed],
          social: [SocialContext.solo],
          energyLevel: 3.0,
          durationMinutes: 30,
          isCustom: true,
        ).toJson(),
      ]);
      SharedPreferences.setMockInitialValues({
        'customSuggestions': v2Json,
        // Favorites still v1: one custom title, one catalog title.
        'favoriteActivities': [
          'Pottery',
          defaultSuggestions.first.title,
        ],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      // Migration completed rather than throwing a TypeError.
      expect(prefs.getInt('prefsSchemaVersion'), 3);
      // The custom title resolved to the id from the existing v2 JSON,
      // not to a freshly synthesized one.
      final favorites = prefs.getStringList('favoriteActivities')!;
      expect(favorites.first, 'custom-abc123');
      expect(favorites.last, defaultSuggestions.first.id);
      // The JSON payload itself was left alone.
      expect(prefs.getString('customSuggestions'), v2Json);
    });

    test('already-migrated ids pass through unchanged on a re-run', () async {
      final entry = defaultSuggestions.first;
      // Favorites/history/dislikes already hold v2 ids, but the
      // version bump never landed (partial run with no v1 customs).
      SharedPreferences.setMockInitialValues({
        'favoriteActivities': [entry.id, 'custom-deadbeef'],
        'activityHistory': jsonEncode({entry.id: '2026-01-01T00:00:00Z'}),
        'activity_dislikes': [entry.id],
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      expect(prefs.getStringList('favoriteActivities'),
          [entry.id, 'custom-deadbeef'],
          reason: 'ids must not be rewritten to custom-<hash>');
      final hist = jsonDecode(prefs.getString('activityHistory')!)
          as List<dynamic>;
      expect((hist.single as Map<String, dynamic>)['id'], entry.id);
      expect(prefs.getStringList('activity_dislikes'), [entry.id]);
    });
  });

  group('MigrationService v2 → v3 (history events)', () {
    test('converts the latest-per-id map to a sorted event list', () async {
      SharedPreferences.setMockInitialValues({
        'prefsSchemaVersion': 2,
        'activityHistory': jsonEncode({
          'newer-id': '2026-06-02T10:00:00.000',
          'older-id': '2026-06-01T10:00:00.000',
        }),
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      expect(prefs.getInt('prefsSchemaVersion'), 3);
      final events = jsonDecode(prefs.getString('activityHistory')!)
          as List<dynamic>;
      expect(events, hasLength(2));
      expect((events.first as Map<String, dynamic>)['id'], 'older-id',
          reason: 'events sorted ascending by timestamp');
      expect((events.last as Map<String, dynamic>)['id'], 'newer-id');
    });

    test('re-run with an already-v3 list payload is a no-op', () async {
      final v3 = jsonEncode([
        {'id': 'a', 'at': '2026-06-01T10:00:00.000'},
      ]);
      SharedPreferences.setMockInitialValues({
        'prefsSchemaVersion': 2,
        'activityHistory': v3,
      });
      final prefs = await SharedPreferences.getInstance();

      await MigrationService.migrateIfNeeded(prefs);

      expect(prefs.getString('activityHistory'), v3);
      expect(prefs.getInt('prefsSchemaVersion'), 3);
    });
  });
}

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

      expect(prefs.getInt('prefsSchemaVersion'), 2);
    });

    test('skips migration when already at target version', () async {
      // Simulate a device that's already on v2.
      SharedPreferences.setMockInitialValues({
        'prefsSchemaVersion': 2,
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

      final raw = prefs.getString('activityHistory')!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded.keys, contains(entry.id));
      expect(decoded[entry.id], ts);
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
          as Map<String, dynamic>;
      expect(hist.keys.first, customId);
      expect(prefs.getStringList('activity_dislikes')!.first, customId);
    });

    test('schema bump only happens after success', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // No prior version key.
      expect(prefs.getInt('prefsSchemaVersion'), isNull);

      await MigrationService.migrateIfNeeded(prefs);
      expect(prefs.getInt('prefsSchemaVersion'), 2);

      // Calling again is a no-op.
      await MigrationService.migrateIfNeeded(prefs);
      expect(prefs.getInt('prefsSchemaVersion'), 2);
    });
  });
}

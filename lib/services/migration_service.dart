import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/suggestions_catalog.dart';
import '../models/suggestion.dart';

/// One-time migration of persisted user data to the schema introduced
/// in Phase 3 of the suggestions catalog refactor.
///
/// Pre-Phase 3 (v1):
///   - `favoriteActivities`  : `List<String>` of titles
///   - `activityHistory`     : JSON map of {title: ISO8601}
///   - `activity_rejections` : JSON map of {title: [ISO8601, ...]}
///   - `activity_dislikes`   : `List<String>` of titles
///   - `customSuggestions`   : `List<String>` of titles
///
/// Phase 3 (v2):
///   - `favoriteActivities`  : `List<String>` of catalog/custom **ids**
///   - `activityHistory`     : JSON map of {id: ISO8601}
///   - `activity_rejections` : JSON map of {id: [ISO8601, ...]}
///   - `activity_dislikes`   : `List<String>` of **ids**
///   - `customSuggestions`   : JSON `List<Suggestion>` (full structured records)
///
/// Migration is keyed by [_versionKey]; once it runs successfully, the
/// version is bumped to [_targetVersion] and the migration is skipped on
/// subsequent launches. If the migration crashes mid-way, the version
/// stays at v1 and migration retries on the next launch.
///
/// Title-to-id resolution looks up the catalog first; titles that don't
/// match any catalog entry are treated as custom suggestions and assigned
/// a stable `custom-<hash>` id (with collision-suffixing).
class MigrationService {
  static const String _versionKey = 'prefsSchemaVersion';
  static const int _targetVersion = 2;

  /// Run any outstanding migrations. Call once at app startup before
  /// any model loads from [SharedPreferences].
  static Future<void> migrateIfNeeded(SharedPreferences prefs) async {
    final current = prefs.getInt(_versionKey) ?? 1;
    if (current >= _targetVersion) return;

    debugPrint('Running prefs migration $current → $_targetVersion');

    if (current < 2) {
      await _migrateV1ToV2(prefs);
    }

    await prefs.setInt(_versionKey, _targetVersion);
    debugPrint('Migration complete; schema is now v$_targetVersion');
  }

  /// v1 → v2: title-keyed → id-keyed.
  ///
  /// Order matters: customs are migrated first so the title→id resolver
  /// includes their freshly-assigned ids when favorites/history/feedback
  /// reference them.
  static Future<void> _migrateV1ToV2(SharedPreferences prefs) async {
    // 1. Build a base resolver from the catalog (title → id).
    final resolver = <String, String>{};
    for (final s in defaultSuggestions) {
      resolver[s.title.toLowerCase()] = s.id;
    }

    // 2. Migrate custom suggestions (List<String> titles → JSON list).
    //    Skip if not present (fresh install or already migrated).
    final oldCustomTitles = prefs.getStringList('customSuggestions');
    if (oldCustomTitles != null) {
      final newCustoms = <Suggestion>[];
      final usedIds = <String>{...resolver.values};
      for (final title in oldCustomTitles) {
        final id = _customIdFor(title, usedIds);
        usedIds.add(id);
        newCustoms.add(_synthesizeCustomFromTitle(title, id));
        resolver[title.toLowerCase()] = id;
      }
      // SharedPreferences keys are typed; explicitly remove the old
      // List<String> entry before writing the new String JSON.
      await prefs.remove('customSuggestions');
      await prefs.setString(
        'customSuggestions',
        jsonEncode(newCustoms.map((s) => s.toJson()).toList()),
      );
      debugPrint('Migrated ${newCustoms.length} custom suggestions');
    }

    // 3. Migrate favorites (List<String> of titles → List<String> of ids).
    final oldFavorites = prefs.getStringList('favoriteActivities');
    if (oldFavorites != null) {
      final newFavorites = oldFavorites
          .map((title) => _resolveOrSynthesize(title, resolver))
          .toList();
      await prefs.setStringList('favoriteActivities', newFavorites);
      debugPrint('Migrated ${newFavorites.length} favorites');
    }

    // 4. Migrate activity history (JSON map keyed by title → keyed by id).
    final oldHistoryJson = prefs.getString('activityHistory');
    if (oldHistoryJson != null) {
      try {
        final decoded = jsonDecode(oldHistoryJson) as Map<String, dynamic>;
        final newHistory = <String, dynamic>{};
        decoded.forEach((title, value) {
          final id = _resolveOrSynthesize(title, resolver);
          newHistory[id] = value;
        });
        await prefs.setString('activityHistory', jsonEncode(newHistory));
        debugPrint('Migrated ${newHistory.length} history entries');
      } on FormatException catch (e) {
        debugPrint('History JSON malformed during migration: $e');
        // Leave the old payload alone; ActivityHistoryModel handles it.
      }
    }

    // 5. Migrate feedback rejections (JSON map keyed by title → keyed by id).
    final oldRejectionsJson = prefs.getString('activity_rejections');
    if (oldRejectionsJson != null) {
      try {
        final decoded = jsonDecode(oldRejectionsJson) as Map<String, dynamic>;
        final newRejections = <String, dynamic>{};
        decoded.forEach((title, value) {
          final id = _resolveOrSynthesize(title, resolver);
          newRejections[id] = value;
        });
        await prefs.setString(
          'activity_rejections',
          jsonEncode(newRejections),
        );
        debugPrint('Migrated ${newRejections.length} rejection entries');
      } on FormatException catch (e) {
        debugPrint('Rejections JSON malformed during migration: $e');
      }
    }

    // 6. Migrate feedback dislikes (List<String> of titles → List<String> of ids).
    final oldDislikes = prefs.getStringList('activity_dislikes');
    if (oldDislikes != null) {
      final newDislikes = oldDislikes
          .map((title) => _resolveOrSynthesize(title, resolver))
          .toList();
      await prefs.setStringList('activity_dislikes', newDislikes);
      debugPrint('Migrated ${newDislikes.length} dislikes');
    }
  }

  /// Look up [title] in [resolver]. If not found, generate a stable
  /// `custom-<hash>` id, register it in the resolver so future lookups
  /// return the same id, and return it.
  static String _resolveOrSynthesize(
    String title,
    Map<String, String> resolver,
  ) {
    final lower = title.toLowerCase();
    final existing = resolver[lower];
    if (existing != null) return existing;
    final id = _customIdFor(title, resolver.values.toSet());
    resolver[lower] = id;
    return id;
  }

  /// Generate a stable id for a custom title, with collision suffixing.
  static String _customIdFor(String title, Set<String> usedIds) {
    final base =
        'custom-${title.hashCode.toUnsigned(32).toRadixString(16)}';
    if (!usedIds.contains(base)) return base;
    var i = 2;
    while (usedIds.contains('$base-$i')) {
      i++;
    }
    return '$base-$i';
  }

  /// Build a [Suggestion] for a migrated custom title with permissive
  /// defaults so it survives every filter at runtime.
  static Suggestion _synthesizeCustomFromTitle(String title, String id) {
    return Suggestion(
      id: id,
      title: title,
      description: '',
      iconName: 'local_activity_outlined',
      activityType: ActivityType.hybrid,
      moods: const [Mood.relaxed, Mood.productive, Mood.creative, Mood.social],
      social: const [
        SocialContext.solo,
        SocialContext.partner,
        SocialContext.smallGroup,
        SocialContext.largeGroup,
      ],
      timeOfDay: const [],
      energyLevel: 3.0,
      durationMinutes: 30,
      weather: WeatherTolerance.any,
      tags: const ['custom'],
      isCustom: true,
    );
  }
}

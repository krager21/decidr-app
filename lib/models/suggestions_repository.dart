import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/suggestions_catalog.dart';
import '../utils/constants.dart';
import 'feedback_model.dart';
import 'suggestion.dart';
import 'weather_model.dart';

/// Repository for activity suggestions.
///
/// Backed by [defaultSuggestions] — a hand-curated catalog of structured
/// [Suggestion] records. User-added custom titles live in
/// [customSuggestions] (legacy `List<String>` storage); they are
/// synthesized into permissive [Suggestion]s at filter time so they
/// always survive the pipeline.
///
/// Filtering pipeline (Phase 2):
///   1. Base — match `activityType` and `mood` against the catalog.
///   2. Optional filters — time-of-day, social context, duration,
///      weather. Each is applied with **graceful degradation**: if a
///      filter would reduce the pool below
///      [SuggestionConstants.minFilteredSuggestionsCount], the filter
///      is skipped instead of returning a thin or empty result.
///   3. Feedback — disliked items are dropped, rejected items are
///      down-weighted (score = energyMatch × feedbackWeight).
///   4. Custom suggestions injected as synthesized Suggestions.
///   5. Favorites lifted to the top; remaining items ranked by score
///      with a shuffle within the top band for variety.
///   6. Take `count` (default 8), deduplicated by id.
///
/// Returns rich records via [getStructuredSuggestions]; the legacy
/// string API [getSuggestions] is a thin adapter.
class SuggestionsRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// User-added custom suggestion titles.
  ///
  /// Phase 2 keeps the legacy `List<String>` shape for backward
  /// compatibility with the profile page UI; Phase 3 will migrate this
  /// to structured `List<Suggestion>` JSON storage.
  List<String> customSuggestions = [];

  SuggestionsRepository(this._prefs);

  /// Load custom suggestions from SharedPreferences.
  Future<void> loadSuggestions() async {
    customSuggestions = _prefs.getStringList('customSuggestions') ?? [];
    notifyListeners();
  }

  /// The shipped catalog (immutable view).
  List<Suggestion> get catalog => List.unmodifiable(defaultSuggestions);

  /// Look up a catalog suggestion by stable id. Returns `null` if not found.
  Suggestion? suggestionById(String id) {
    for (final s in defaultSuggestions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Look up a catalog suggestion by display title (case-insensitive).
  ///
  /// Used by the upcoming Phase-3 persistence migration to map legacy
  /// title-keyed favorites/history/feedback to their structured equivalents.
  Suggestion? suggestionByTitle(String title) {
    final lower = title.toLowerCase();
    for (final s in defaultSuggestions) {
      if (s.title.toLowerCase() == lower) return s;
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // Custom suggestion CRUD (legacy string storage)
  // ──────────────────────────────────────────────────────────────

  /// Persist [customSuggestions] to SharedPreferences.
  Future<void> saveCustomSuggestions() async {
    await _prefs.setStringList('customSuggestions', customSuggestions);
    notifyListeners();
  }

  /// Add a custom user-defined suggestion.
  ///
  /// Trims whitespace, enforces a max length of
  /// [SuggestionConstants.customSuggestionMaxLength], deduplicates
  /// case-insensitively, and caps the total count at
  /// [SuggestionConstants.customSuggestionMaxCount].
  ///
  /// Returns `true` if the suggestion was added, `false` if it was
  /// rejected (empty, too long, duplicate, or list is full).
  bool addCustomSuggestion(String suggestion) {
    final trimmed = suggestion.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > SuggestionConstants.customSuggestionMaxLength) {
      return false;
    }
    if (customSuggestions.length >=
        SuggestionConstants.customSuggestionMaxCount) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (customSuggestions.any((s) => s.toLowerCase() == lower)) return false;

    customSuggestions.add(trimmed);
    saveCustomSuggestions();
    return true;
  }

  /// Remove a custom suggestion by exact title match.
  void removeCustomSuggestion(String suggestion) {
    if (customSuggestions.contains(suggestion)) {
      customSuggestions.remove(suggestion);
      saveCustomSuggestions();
    }
  }

  /// Resolve an icon for a suggestion title.
  ///
  /// Looks up the title in the catalog first (icons are first-class
  /// fields on [Suggestion]). Falls back to a small keyword-based
  /// heuristic for custom user-added titles that aren't in the catalog.
  ///
  /// Used by the legacy wheel painter; new code should resolve via
  /// `Suggestion.iconData` directly.
  IconData getIconForSuggestion(String suggestion) {
    final fromCatalog = suggestionByTitle(suggestion);
    if (fromCatalog != null) return fromCatalog.iconData;

    final lower = suggestion.toLowerCase();
    if (lower.contains('read')) return Icons.menu_book;
    if (lower.contains('walk') || lower.contains('hike')) {
      return Icons.directions_walk;
    }
    if (lower.contains('run')) return Icons.directions_run;
    if (lower.contains('meditat') || lower.contains('yoga')) {
      return Icons.self_improvement;
    }
    if (lower.contains('cook') ||
        lower.contains('bake') ||
        lower.contains('recipe')) {
      return Icons.restaurant;
    }
    if (lower.contains('music') || lower.contains('listen')) {
      return Icons.music_note;
    }
    if (lower.contains('movie') || lower.contains('watch')) return Icons.movie;
    if (lower.contains('call') || lower.contains('friend')) return Icons.phone;
    if (lower.contains('art') ||
        lower.contains('draw') ||
        lower.contains('paint')) {
      return Icons.palette;
    }
    if (lower.contains('bike')) return Icons.directions_bike;
    if (lower.contains('swim')) return Icons.pool;
    if (lower.contains('garden')) return Icons.yard;
    if (lower.contains('clean') || lower.contains('organize')) {
      return Icons.cleaning_services;
    }
    if (lower.contains('workout') || lower.contains('exercise')) {
      return Icons.fitness_center;
    }
    if (lower.contains('photo')) return Icons.photo_camera;
    if (lower.contains('write') || lower.contains('journal')) {
      return Icons.edit;
    }
    if (lower.contains('coffee')) return Icons.local_cafe;
    if (lower.contains('park')) return Icons.park;
    if (lower.contains('podcast')) return Icons.headphones;
    if (lower.contains('dance')) return Icons.music_note;
    if (lower.contains('sleep') || lower.contains('nap')) return Icons.bedtime;
    if (lower.contains('chat')) return Icons.chat;
    if (lower.contains('star')) return Icons.star;

    return Icons.local_activity_outlined;
  }

  // ──────────────────────────────────────────────────────────────
  // Structured filtering
  // ──────────────────────────────────────────────────────────────

  /// Get matching suggestions as structured [Suggestion] records.
  ///
  /// This is the new typed entry point — see the class docs for the full
  /// pipeline. The legacy [getSuggestions] string API is a thin adapter
  /// that calls this method and projects to titles.
  List<Suggestion> getStructuredSuggestions({
    required ActivityType activityType,
    required Mood mood,
    required TimeOfDayPref timeOfDay,
    required double energyLevel,
    SocialContext? socialContext,
    String? duration,
    WeatherData? weather,
    FeedbackModel? feedback,
    bool includeCustom = true,
    bool includeFavorites = true,
    List<String> favoriteTitles = const [],
    int count = SuggestionConstants.defaultSuggestionsCount,
  }) {
    // Stage 1: base filter — activity type + mood.
    var pool = catalog
        .where((s) => s.activityType == activityType && s.moods.contains(mood))
        .toList();

    // Stage 2: optional filters with graceful degradation.
    pool = _applyOrSkip(
      pool,
      (p) => p
          .where((s) => s.timeOfDay.isEmpty || s.timeOfDay.contains(timeOfDay))
          .toList(),
    );

    if (socialContext != null) {
      pool = _applyOrSkip(
        pool,
        (p) => p.where((s) => s.social.contains(socialContext)).toList(),
      );
    }

    if (duration != null) {
      pool = _applyOrSkip(
        pool,
        (p) => p.where((s) => _durationMatches(s, duration)).toList(),
      );
    }

    if (weather != null) {
      pool = _applyOrSkip(
        pool,
        (p) => p.where((s) => _weatherMatches(s, weather)).toList(),
      );
    }

    // Stage 3: drop disliked items (feedback weight 0.0).
    if (feedback != null) {
      pool = pool
          .where((s) => feedback.getActivityWeight(s.title) > 0.0)
          .toList();
    }

    // Stage 4: score by energy proximity × feedback weight.
    final scored = <_ScoredSuggestion>[];
    for (final s in pool) {
      final delta = (s.energyLevel - energyLevel).abs();
      final energyScore = 1.0 - (delta / 4.0); // 1.0 = perfect match
      final fbWeight = feedback?.getActivityWeight(s.title) ?? 1.0;
      scored.add(_ScoredSuggestion(s, energyScore * fbWeight));
    }

    // Stage 5: inject custom suggestions as permissive synthesized records.
    if (includeCustom && customSuggestions.isNotEmpty) {
      for (final title in customSuggestions) {
        final synth = _synthesizeCustom(
          title,
          activityType: activityType,
          mood: mood,
        );
        scored.add(_ScoredSuggestion(synth, 1.0));
      }
    }

    // Stage 6: favorites first, then top-by-score with intra-band shuffle.
    final favSet = favoriteTitles.map((f) => f.toLowerCase()).toSet();
    final favorites = <Suggestion>[];
    final rest = <_ScoredSuggestion>[];
    for (final entry in scored) {
      if (includeFavorites &&
          favSet.contains(entry.suggestion.title.toLowerCase())) {
        favorites.add(entry.suggestion);
      } else {
        rest.add(entry);
      }
    }
    rest.sort((a, b) => b.score.compareTo(a.score));

    // Take 2× count from the top band, shuffle for variety, then deduplicate
    // and trim to count. Favorites bypass the shuffle so they're consistent.
    final topBand = rest.take(count * 2).map((s) => s.suggestion).toList()
      ..shuffle(Random());

    final result = <Suggestion>[...favorites, ...topBand];
    final seen = <String>{};
    return result.where((s) => seen.add(s.id)).take(count).toList();
  }

  /// Get matching suggestion **titles** — legacy string API.
  ///
  /// Internally calls [getStructuredSuggestions] and projects to
  /// [Suggestion.title]. String parameters are converted to enum
  /// values; an unrecognized `activity`, `mood`, or `timeOfDay`
  /// returns an empty list.
  List<String> getSuggestions({
    required String activity,
    required String mood,
    required String timeOfDay,
    required double energyLevel,
    bool includeCustom = true,
    bool includeFavorites = true,
    List<String> favorites = const [],
    WeatherData? weather,
    FeedbackModel? feedback,
    String? socialContext,
    String? duration,
  }) {
    final activityType = _tryParseEnum(
      ActivityType.values,
      (e) => e.label,
      activity,
    );
    final moodEnum = _tryParseEnum(Mood.values, (e) => e.label, mood);
    final timeEnum =
        _tryParseEnum(TimeOfDayPref.values, (e) => e.label, timeOfDay);
    final socialEnum = socialContext == null
        ? null
        : _tryParseEnum(SocialContext.values, (e) => e.label, socialContext);

    if (activityType == null || moodEnum == null || timeEnum == null) {
      return [];
    }

    final structured = getStructuredSuggestions(
      activityType: activityType,
      mood: moodEnum,
      timeOfDay: timeEnum,
      energyLevel: energyLevel,
      socialContext: socialEnum,
      duration: duration,
      weather: weather,
      feedback: feedback,
      includeCustom: includeCustom,
      includeFavorites: includeFavorites,
      favoriteTitles: favorites,
    );

    return structured.map((s) => s.title).toList();
  }

  // ──────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────

  /// Apply [filter] to [pool], but reject the result if it shrinks
  /// the pool below [SuggestionConstants.minFilteredSuggestionsCount].
  /// In that case, the original pool is returned unchanged — graceful
  /// degradation prevents dead-end queries.
  List<Suggestion> _applyOrSkip(
    List<Suggestion> pool,
    List<Suggestion> Function(List<Suggestion>) filter,
  ) {
    final filtered = filter(pool);
    if (filtered.length < SuggestionConstants.minFilteredSuggestionsCount) {
      return pool;
    }
    return filtered;
  }

  /// Whether a suggestion fits a duration label like `'Quick (15 min)'`,
  /// `'Medium (1 hr)'`, `'Half Day'`, or `'Full Day'`.
  bool _durationMatches(Suggestion s, String durationLabel) {
    final mins = s.durationMinutes;
    if (durationLabel.startsWith('Quick')) return mins <= 30;
    if (durationLabel.startsWith('Medium')) return mins > 15 && mins <= 90;
    if (durationLabel.startsWith('Half Day')) return mins >= 60 && mins <= 240;
    if (durationLabel.startsWith('Full Day')) return mins > 180;
    return true;
  }

  /// Whether a suggestion is appropriate for the current weather.
  ///
  /// Indoor and `WeatherTolerance.indoorOnly` activities always pass.
  /// Outdoor activities are blocked when wet (rain/snow) if their
  /// [Suggestion.weather] is `drySpellsOnly`. High-energy outdoor
  /// activities (energy ≥ 4.0) are also blocked in extreme heat or cold.
  bool _weatherMatches(Suggestion s, WeatherData weather) {
    if (s.weather == WeatherTolerance.indoorOnly) return true;
    if (s.activityType == ActivityType.indoor) return true;

    if (s.weather == WeatherTolerance.drySpellsOnly) {
      if (weather.isRainy || weather.isSnowy) return false;
    }

    if (s.activityType == ActivityType.outdoor && s.energyLevel >= 4.0) {
      if (weather.isHot || weather.isCold) return false;
    }

    return true;
  }

  /// Build a permissive synthetic [Suggestion] for a user-supplied
  /// custom title. Uses the requested filter context so it always
  /// passes the base filter and reaches the user.
  Suggestion _synthesizeCustom(
    String title, {
    required ActivityType activityType,
    required Mood mood,
  }) {
    return Suggestion(
      id: 'custom-${title.hashCode.toUnsigned(32).toRadixString(16)}',
      title: title,
      description: '',
      iconName: 'local_activity_outlined',
      activityType: activityType,
      moods: [mood],
      social: SocialContext.values,
      timeOfDay: const [],
      energyLevel: SuggestionConstants.energyLevelDefault,
      durationMinutes: 30,
      weather: WeatherTolerance.any,
      tags: const ['custom'],
      isCustom: true,
    );
  }

  /// Parse a label string into one of [values], returning null if no
  /// value's [toLabel] matches the input.
  T? _tryParseEnum<T>(
    List<T> values,
    String Function(T) toLabel,
    String label,
  ) {
    for (final v in values) {
      if (toLabel(v) == label) return v;
    }
    return null;
  }
}

class _ScoredSuggestion {
  final Suggestion suggestion;
  final double score;
  const _ScoredSuggestion(this.suggestion, this.score);
}

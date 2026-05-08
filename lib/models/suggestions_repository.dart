import 'dart:convert';
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
/// [Suggestion] records. User-added custom suggestions are stored as
/// full structured records (Phase 3) in `customSuggestions` and
/// persisted as JSON to SharedPreferences under `customSuggestions`.
///
/// All cross-references (favorites, history, feedback) key off
/// [Suggestion.id] post-Phase-3. Use [resolveById] to render an id
/// back to a renderable [Suggestion] — it falls back to a synthesized
/// "unknown" Suggestion for ids that don't match anything in the
/// catalog or custom list, so display layers never crash on stale data.
///
/// Filtering pipeline (see [getStructuredSuggestions]):
///   1. Base — match `activityType` and `mood` against the catalog.
///   2. Optional filters — time-of-day, social context, duration,
///      weather. Each is applied with **graceful degradation**: if a
///      filter would reduce the pool below
///      [SuggestionConstants.minFilteredSuggestionsCount], the filter
///      is skipped instead of returning a thin or empty result.
///   3. Feedback — disliked items are dropped, rejected items are
///      down-weighted (score = energyMatch × feedbackWeight).
///   4. Custom suggestions injected directly from the stored list.
///   5. Favorites lifted to the top; remaining items ranked by score
///      with a shuffle within the top band for variety.
///   6. Take `count` (default 8), deduplicated by id.
class SuggestionsRepository extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// User-added custom suggestions as full structured records.
  ///
  /// Persisted as a JSON list under `customSuggestions`. Phase 3
  /// migrates the legacy `List<String>` storage shape on first launch
  /// (see `MigrationService`).
  List<Suggestion> customSuggestions = [];

  SuggestionsRepository(this._prefs);

  /// Load custom suggestions from SharedPreferences.
  ///
  /// Expects v2 format (JSON array of [Suggestion]); the migration
  /// service will have converted any v1 string-list payload before
  /// this method is called.
  Future<void> loadSuggestions() async {
    final raw = _prefs.getString('customSuggestions');
    if (raw == null || raw.isEmpty) {
      customSuggestions = [];
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      customSuggestions = decoded
          .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException catch (e) {
      debugPrint('customSuggestions JSON malformed: $e — resetting');
      customSuggestions = [];
    }
    notifyListeners();
  }

  /// The shipped catalog (immutable view).
  List<Suggestion> get catalog => List.unmodifiable(defaultSuggestions);

  /// Convenience: the titles of custom suggestions, in storage order.
  List<String> get customSuggestionTitles =>
      customSuggestions.map((s) => s.title).toList();

  /// Look up a catalog suggestion by stable id. Returns `null` if not found.
  Suggestion? suggestionById(String id) {
    for (final s in defaultSuggestions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Look up a catalog suggestion by display title (case-insensitive).
  ///
  /// Searches **catalog only** — for a search across both catalog and
  /// the user's custom list, use [findByTitle].
  Suggestion? suggestionByTitle(String title) {
    final lower = title.toLowerCase();
    for (final s in defaultSuggestions) {
      if (s.title.toLowerCase() == lower) return s;
    }
    return null;
  }

  /// Look up a [Suggestion] by display title (case-insensitive),
  /// across both the catalog and the user's custom list. Returns
  /// `null` if no match is found.
  ///
  /// Used by the legacy string-API call sites to convert a displayed
  /// title back to a [Suggestion.id] for history and feedback
  /// recording.
  Suggestion? findByTitle(String title) {
    final fromCatalog = suggestionByTitle(title);
    if (fromCatalog != null) return fromCatalog;
    final lower = title.toLowerCase();
    for (final s in customSuggestions) {
      if (s.title.toLowerCase() == lower) return s;
    }
    return null;
  }

  /// Convenience: resolve a title to its [Suggestion.id], or fall back
  /// to using the title itself as the id when nothing matches.
  ///
  /// The fallback ensures legacy code paths can pass a title-as-id to
  /// history/feedback without losing data when an entry is missing.
  String idForTitle(String title) => findByTitle(title)?.id ?? title;

  /// Resolve an id to a renderable [Suggestion].
  ///
  /// Tries the catalog first, then the user's custom list. If neither
  /// matches (e.g. an id from a stale persisted reference), returns a
  /// synthesized "unknown" Suggestion using the id itself as the title
  /// so display layers degrade gracefully instead of crashing.
  Suggestion resolveById(String id) {
    final fromCatalog = suggestionById(id);
    if (fromCatalog != null) return fromCatalog;
    for (final s in customSuggestions) {
      if (s.id == id) return s;
    }
    return _synthesizeFallback(id);
  }

  // ──────────────────────────────────────────────────────────────
  // Custom suggestion CRUD
  // ──────────────────────────────────────────────────────────────

  /// Persist [customSuggestions] to SharedPreferences as a JSON list.
  Future<void> saveCustomSuggestions() async {
    await _prefs.setString(
      'customSuggestions',
      jsonEncode(customSuggestions.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Add a custom user-defined suggestion.
  ///
  /// Trims whitespace, enforces a max length of
  /// [SuggestionConstants.customSuggestionMaxLength], deduplicates
  /// case-insensitively against both the catalog and the user's
  /// existing customs, and caps the total count at
  /// [SuggestionConstants.customSuggestionMaxCount].
  ///
  /// On success a [Suggestion] is synthesized with a stable
  /// `custom-<hash>` id and permissive defaults (any time, any social
  /// context, hybrid activity, all moods) so it survives every filter.
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
    if (customSuggestions.any((s) => s.title.toLowerCase() == lower)) {
      return false;
    }
    if (suggestionByTitle(trimmed) != null) {
      return false; // already in the catalog
    }

    final usedIds = <String>{
      ...defaultSuggestions.map((s) => s.id),
      ...customSuggestions.map((s) => s.id),
    };
    final id = _customIdFor(trimmed, usedIds);
    customSuggestions.add(_buildCustom(trimmed, id));
    saveCustomSuggestions();
    return true;
  }

  /// Remove a custom suggestion by id or by exact title match.
  void removeCustomSuggestion(String idOrTitle) {
    final lower = idOrTitle.toLowerCase();
    final before = customSuggestions.length;
    customSuggestions.removeWhere(
      (s) => s.id == idOrTitle || s.title.toLowerCase() == lower,
    );
    if (customSuggestions.length != before) {
      saveCustomSuggestions();
    }
  }

  /// Resolve an icon for a suggestion title.
  ///
  /// Looks up the title in the catalog first; falls back to a small
  /// keyword-based heuristic for titles that aren't in the catalog
  /// (e.g. one-off display values from stale persisted state).
  /// New code should resolve via `Suggestion.iconData` directly —
  /// this shim survives because some legacy title-keyed call sites
  /// still pass titles instead of [Suggestion]s.
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
  /// `favoriteIds` and the keys used for feedback lookup are
  /// [Suggestion.id]s — Phase 3 unified all cross-reference keys.
  /// The legacy [getSuggestions] string API is a thin adapter.
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
    List<String> favoriteIds = const [],
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
          .where((s) => feedback.getActivityWeight(s.id) > 0.0)
          .toList();
    }

    // Stage 4: score by energy proximity × feedback weight.
    final scored = <_ScoredSuggestion>[];
    for (final s in pool) {
      final delta = (s.energyLevel - energyLevel).abs();
      final energyScore = 1.0 - (delta / 4.0); // 1.0 = perfect match
      final fbWeight = feedback?.getActivityWeight(s.id) ?? 1.0;
      scored.add(_ScoredSuggestion(s, energyScore * fbWeight));
    }

    // Stage 5: inject the user's custom suggestions verbatim.
    if (includeCustom) {
      for (final s in customSuggestions) {
        // Custom suggestions are permissive by construction, but still
        // honor explicit dislike feedback if present.
        if (feedback != null && feedback.getActivityWeight(s.id) <= 0.0) {
          continue;
        }
        scored.add(_ScoredSuggestion(s, 1.0));
      }
    }

    // Stage 6: favorites first, then top-by-score with intra-band shuffle.
    final favSet = favoriteIds.toSet();
    final favorites = <Suggestion>[];
    final rest = <_ScoredSuggestion>[];
    for (final entry in scored) {
      if (includeFavorites && favSet.contains(entry.suggestion.id)) {
        favorites.add(entry.suggestion);
      } else {
        rest.add(entry);
      }
    }
    rest.sort((a, b) => b.score.compareTo(a.score));

    final topBand = rest.take(count * 2).map((s) => s.suggestion).toList()
      ..shuffle(Random());

    final result = <Suggestion>[...favorites, ...topBand];
    final seen = <String>{};
    return result.where((s) => seen.add(s.id)).take(count).toList();
  }

  /// Get matching suggestion **titles** — legacy string API.
  ///
  /// `favorites` is expected to be a list of [Suggestion.id]s after
  /// Phase 3 (the migration converts older title-based favorites to
  /// ids automatically). Internally calls [getStructuredSuggestions]
  /// and projects to titles.
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
      favoriteIds: favorites,
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

  /// Generate a stable id for a custom title, with collision suffixing.
  ///
  /// Mirrors the algorithm in `MigrationService` so ids assigned during
  /// migration match ids assigned at runtime for the same title.
  String _customIdFor(String title, Set<String> usedIds) {
    final base =
        'custom-${title.hashCode.toUnsigned(32).toRadixString(16)}';
    if (!usedIds.contains(base)) return base;
    var i = 2;
    while (usedIds.contains('$base-$i')) {
      i++;
    }
    return '$base-$i';
  }

  /// Build a new custom [Suggestion] with permissive defaults.
  Suggestion _buildCustom(String title, String id) {
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
      energyLevel: SuggestionConstants.energyLevelDefault,
      durationMinutes: 30,
      weather: WeatherTolerance.any,
      tags: const ['custom'],
      isCustom: true,
    );
  }

  /// Synthesize a placeholder [Suggestion] for an id we can't resolve.
  /// Used by [resolveById] so display layers never crash on stale data.
  Suggestion _synthesizeFallback(String id) {
    return Suggestion(
      id: id,
      title: id,
      description: '',
      iconName: 'local_activity_outlined',
      activityType: ActivityType.hybrid,
      moods: const [Mood.relaxed],
      social: const [SocialContext.solo],
      energyLevel: SuggestionConstants.energyLevelDefault,
      durationMinutes: 30,
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

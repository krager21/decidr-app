import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/context_service.dart';
import 'preference_profile.dart';

/// Outcome of an attempt to save a preference profile.
enum SaveProfileResult {
  saved,

  /// Empty name.
  invalid,

  /// A profile with this name (case-insensitive) already exists.
  duplicate,

  /// The caller-supplied cap is full — upsell or explain.
  capReached,
}

/// Strongly-typed identifiers for user preferences.
///
/// Each value carries the SharedPreferences storage key. Using the enum
/// instead of raw strings catches typos at compile time and makes adding
/// a new preference a single-place change.
enum PreferenceKey {
  activityPreference('activityPreference'),
  mood('mood'),
  energyLevel('energyLevel'),
  timeOfDay('timeOfDay'),
  autoDetectTime('autoDetectTime'),
  socialContext('socialContext'),
  duration('duration'),
  useDarkMode('useDarkMode'),
  useSystemTheme('useSystemTheme'),
  enableHaptics('enableHaptics'),
  colorTheme('colorTheme'),
  weirdnessTolerance('weirdnessTolerance'),
  useWeather('useWeather'),
  useLocation('useLocation'),
  userInterests('userInterests'),
  firstDealCompleted('firstDealCompleted'),
  interestsPromptDismissed('interestsPromptDismissed');

  /// The SharedPreferences key used to persist this preference.
  final String storageKey;
  const PreferenceKey(this.storageKey);

  /// Look up an enum value by its storage key string. Returns `null` if
  /// no match is found. Used to bridge the legacy string-based API.
  static PreferenceKey? fromString(String key) {
    for (final p in PreferenceKey.values) {
      if (p.storageKey == key) return p;
    }
    return null;
  }
}

/// Model for managing user preferences with persistent storage
///
/// Handles all user settings including:
/// - Activity preferences (indoor/outdoor/hybrid)
/// - Mood and energy levels
/// - Time of day preferences
/// - Theme settings (dark mode, color themes)
/// - Haptic feedback preferences
/// - Favorite activities management
///
/// All preferences are automatically persisted to SharedPreferences.
class PreferencesModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// User's preferred activity type (Indoor, Outdoor, or Hybrid)
  String? activityPreference;

  /// User's current mood selection
  String? mood;

  /// User's energy level from 1.0 (very low) to 5.0 (very high)
  double energyLevel = 3.0;

  /// User's preferred time of day for activities
  String? timeOfDay;

  /// Whether to automatically detect time of day based on device clock
  bool autoDetectTime = true;

  /// Social context for activities (Solo, Partner, Small Group, Large Group)
  String? socialContext;

  /// Duration preference for activities (Quick, Medium, Half Day, Full Day)
  String? duration;

  /// Whether dark mode is enabled (only used if useSystemTheme is false)
  bool useDarkMode = false;

  /// Whether to follow system theme settings
  bool useSystemTheme = true;

  /// Whether haptic feedback is enabled for card interactions.
  bool enableHaptics = true;

  /// Selected color theme (rainbow, pastels, etc.). Currently dormant —
  /// kept for a possible future card-theme picker; the underlying
  /// storage migration to remove it would be more disruptive than
  /// leaving it in place.
  String colorTheme = 'rainbow';

  /// User's appetite for off-the-wall suggestions, on a 0.0 → 1.0 scale.
  ///
  ///   0.0  comfort food only — mainstream entries dominate
  ///   0.5  balanced — slightly novel sweet spot
  ///   1.0  bring on the chaos — eccentric entries dominate
  ///
  /// Multiplied into the suggestion score via a distance-based affinity
  /// (`1 − |suggestion.weirdness − tolerance|`) so the slider acts as a
  /// *target* weirdness, not a ceiling. Defaults to 0.3 — mostly
  /// comfortable with a touch of novelty.
  double weirdnessTolerance = 0.3;

  /// Whether to let live weather conditions bias the deal.
  ///
  /// When true, the card-reveal page reads from [WeatherService] and
  /// passes the current weather into the filter pipeline so outdoor
  /// suggestions get a soft penalty when it's raining, etc. When false
  /// the pipeline ignores weather entirely — no API call fires.
  ///
  /// Defaults to false (opt-in) — fetching weather requires the user
  /// to grant location permission and configure an OpenWeatherMap API
  /// key, so we never silently use it.
  bool useWeather = false;

  /// Whether to let the app use the user's location for context.
  ///
  /// Today only the weather feature consumes location, but the
  /// upcoming "nearby places" feature will also gate on this toggle.
  /// Keeping it separate from [useWeather] lets the user opt into
  /// weather without committing to other location-dependent features
  /// (and vice versa).
  ///
  /// Defaults to false (opt-in).
  bool useLocation = false;

  /// User's stable interests — values from the `Interests` constants
  /// class (e.g., 'nature', 'cooking', 'reading'). Soft-biases the
  /// score via a Jaccard overlap multiplier in the filter pipeline,
  /// so picks favor matching entries without starving the pool.
  ///
  /// Empty (the default) means "no interest signal" — the scoring
  /// term collapses to 1.0 and behavior is unchanged.
  List<String> userInterests = [];

  /// Whether the user has completed their first deal in this install.
  /// Used to gate the "tag your interests" onboarding banner so it
  /// doesn't shout at the user before they've seen what the app does.
  bool firstDealCompleted = false;

  /// Whether the user has dismissed the "tag your interests" banner.
  /// Once dismissed, the banner never reappears — they can still
  /// reach the picker via Settings → Personalization.
  bool interestsPromptDismissed = false;

  /// Saved questionnaire snapshots the user can re-apply in one tap.
  /// Persisted as JSON under `savedProfiles`. Caps are enforced by
  /// callers via [saveCurrentAsProfile]'s `maxCount` (free vs Premium).
  List<PreferenceProfile> savedProfiles = [];

  /// Lifetime count of free-tier Nearby lookups consumed. Compared
  /// against `SuggestionConstants.nearbyFreeLookupCount` by the gate.
  int nearbyFreeLookupsUsed = 0;

  /// Whether the opt-in daily deal reminder is on.
  bool dailyReminderEnabled = false;

  /// Daily reminder time as minutes past midnight (default 19:00).
  int dailyReminderMinutes = 19 * 60;

  /// Suggestion id awaiting a "did you do it?" follow-up — set by
  /// "Remind me tonight" on the settled card, cleared when the user
  /// resolves the prompt on the Decide tab.
  String? pendingReminderId;

  /// Persist the daily reminder settings. Scheduling itself lives in
  /// ReminderService; this only records the preference.
  Future<void> setDailyReminder({
    required bool enabled,
    int? minutes,
  }) async {
    dailyReminderEnabled = enabled;
    if (minutes != null) dailyReminderMinutes = minutes;
    notifyListeners();
    await _prefs.setBool('dailyReminderEnabled', dailyReminderEnabled);
    await _prefs.setInt('dailyReminderMinutes', dailyReminderMinutes);
  }

  /// Set or clear the pending "did you do it?" suggestion.
  Future<void> setPendingReminder(String? suggestionId) async {
    pendingReminderId = suggestionId;
    notifyListeners();
    if (suggestionId == null) {
      await _prefs.remove('pendingReminderId');
    } else {
      await _prefs.setString('pendingReminderId', suggestionId);
    }
  }

  /// Session-only deck override for the premium "try it for one deal"
  /// flow. Never persisted — cleared after the trial deal settles.
  String? previewDeckId;

  /// The deck the cards should actually render with right now.
  String get effectiveDeckId => previewDeckId ?? colorTheme;

  /// Apply or clear the try-on deck. In-memory only.
  void setPreviewDeck(String? deckId) {
    if (previewDeckId == deckId) return;
    previewDeckId = deckId;
    notifyListeners();
  }

  /// Consume one free Nearby lookup. Persists and notifies.
  Future<void> incrementNearbyLookups() async {
    nearbyFreeLookupsUsed++;
    notifyListeners();
    await _prefs.setInt('nearbyFreeLookupsUsed', nearbyFreeLookupsUsed);
  }

  /// List of suggestion **ids** marked as favorites by the user.
  ///
  /// Post-Phase-3, values are stable [Suggestion] ids (catalog slugs
  /// or `custom-<hash>` for user-added entries). Pre-Phase-3 the list
  /// held titles; `MigrationService` converts on first launch.
  /// Use `SuggestionsRepository.resolveById(id)` to render an id back
  /// to a display [Suggestion].
  List<String> favoriteActivities = [];

  /// Available activity type options
  final List<String> activityOptions = ['Indoor', 'Outdoor', 'Hybrid'];

  /// Available mood options
  final List<String> moodOptions = ['Relaxed', 'Productive', 'Creative', 'Social'];

  /// Available time of day options
  final List<String> timeOptions = ['Morning', 'Afternoon', 'Evening', 'Night'];

  /// Available social context options
  final List<String> socialOptions = ['Solo', 'Partner', 'Small Group', 'Large Group'];

  /// Available duration options
  final List<String> durationOptions = ['Quick (15 min)', 'Medium (1 hr)', 'Half Day', 'Full Day'];

  /// Available color-theme options (dormant — see [colorTheme]).
  final List<String> themeOptions = ['Rainbow', 'Pastels', 'Monochrome', 'Ocean', 'Sunset'];

  PreferencesModel(this._prefs);

  /// Get the effective time of day (auto-detected or manually selected)
  ///
  /// Returns the auto-detected time if autoDetectTime is enabled,
  /// otherwise returns the manually selected timeOfDay value.
  String get effectiveTimeOfDay {
    if (autoDetectTime) {
      return ContextService.getCurrentTimeOfDay();
    }
    return timeOfDay ?? ContextService.getCurrentTimeOfDay();
  }

  /// Load all user preferences from SharedPreferences
  ///
  /// Automatically migrates deprecated mood values (e.g., 'Energetic' is reset).
  /// Notifies listeners after loading is complete.
  Future<void> loadPreferences() async {
    activityPreference = _prefs.getString('activityPreference');
    // Mood is intentionally **not persisted** — we ask "what's your
    // mood today?" on each launch. Mood lives in memory for the
    // session but gets cleared whenever the app is killed and
    // reopened. Other preferences (activity, energy, weirdness, time
    // of day) keep their stickiness.
    mood = null;
    energyLevel = _prefs.getDouble('energyLevel') ?? 3.0;
    timeOfDay = _prefs.getString('timeOfDay');
    autoDetectTime = _prefs.getBool('autoDetectTime') ?? true;
    socialContext = _prefs.getString('socialContext');
    duration = _prefs.getString('duration');
    useDarkMode = _prefs.getBool('useDarkMode') ?? false;
    useSystemTheme = _prefs.getBool('useSystemTheme') ?? true;
    enableHaptics = _prefs.getBool('enableHaptics') ?? true;
    colorTheme = _prefs.getString('colorTheme') ?? 'rainbow';
    weirdnessTolerance =
        _prefs.getDouble('weirdnessTolerance')?.clamp(0.0, 1.0) ?? 0.3;
    useWeather = _prefs.getBool('useWeather') ?? false;
    useLocation = _prefs.getBool('useLocation') ?? false;
    userInterests = _prefs.getStringList('userInterests') ?? [];
    firstDealCompleted = _prefs.getBool('firstDealCompleted') ?? false;
    interestsPromptDismissed =
        _prefs.getBool('interestsPromptDismissed') ?? false;
    favoriteActivities = _prefs.getStringList('favoriteActivities') ?? [];
    savedProfiles = _decodeProfiles(_prefs.getString('savedProfiles'));
    nearbyFreeLookupsUsed = _prefs.getInt('nearbyFreeLookupsUsed') ?? 0;
    dailyReminderEnabled = _prefs.getBool('dailyReminderEnabled') ?? false;
    dailyReminderMinutes = _prefs.getInt('dailyReminderMinutes') ?? 19 * 60;
    pendingReminderId = _prefs.getString('pendingReminderId');
    notifyListeners();
  }

  /// Decode the persisted profile list, tolerating any malformed
  /// payload (partial write, downgrade) by resetting to empty rather
  /// than failing preference loading as a whole.
  static List<PreferenceProfile> _decodeProfiles(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PreferenceProfile.fromJson)
          .toList();
    } catch (e) {
      debugPrint('savedProfiles JSON malformed: $e — resetting');
      return [];
    }
  }

  Future<void> _saveProfiles() async {
    await _prefs.setString(
      'savedProfiles',
      jsonEncode(savedProfiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Snapshot the current questionnaire answers as a named profile.
  ///
  /// [maxCount] is the entitlement-dependent cap the caller resolves
  /// (free vs Premium). Names are deduplicated case-insensitively.
  Future<SaveProfileResult> saveCurrentAsProfile(
    String name, {
    required int maxCount,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return SaveProfileResult.invalid;
    final lower = trimmed.toLowerCase();
    if (savedProfiles.any((p) => p.name.toLowerCase() == lower)) {
      return SaveProfileResult.duplicate;
    }
    if (savedProfiles.length >= maxCount) {
      return SaveProfileResult.capReached;
    }
    // Timestamp ids can collide when two saves land in the same
    // millisecond (delete would then remove both) — suffix to keep
    // them unique.
    final base = 'profile-${DateTime.now().millisecondsSinceEpoch}';
    var id = base;
    var suffix = 2;
    while (savedProfiles.any((p) => p.id == id)) {
      id = '$base-${suffix++}';
    }
    savedProfiles.add(PreferenceProfile(
      id: id,
      name: trimmed,
      activityPreference: activityPreference,
      mood: mood,
      energyLevel: energyLevel,
      weirdnessTolerance: weirdnessTolerance,
      autoDetectTime: autoDetectTime,
      timeOfDay: timeOfDay,
      socialContext: socialContext,
      duration: duration,
    ));
    notifyListeners();
    await _saveProfiles();
    return SaveProfileResult.saved;
  }

  /// Apply a saved profile's answers as the current preferences.
  /// Mood is applied in-memory only (it is never persisted — see
  /// [loadPreferences]); everything else round-trips to storage.
  Future<void> applyProfile(PreferenceProfile profile) async {
    activityPreference = profile.activityPreference;
    mood = profile.mood;
    energyLevel = profile.energyLevel.clamp(1.0, 5.0);
    weirdnessTolerance = profile.weirdnessTolerance.clamp(0.0, 1.0);
    autoDetectTime = profile.autoDetectTime;
    timeOfDay = profile.timeOfDay;
    socialContext = profile.socialContext;
    duration = profile.duration;
    notifyListeners();
    await savePreferences();
  }

  /// Delete a saved profile by id. No-op for unknown ids.
  Future<void> deleteProfile(String id) async {
    final before = savedProfiles.length;
    savedProfiles.removeWhere((p) => p.id == id);
    if (savedProfiles.length == before) return;
    notifyListeners();
    await _saveProfiles();
  }
  
  /// Save all current preferences to SharedPreferences.
  ///
  /// Optional/nullable preferences are *removed* from storage when their
  /// in-memory value is null, so that calling [resetPreferences] (which
  /// flips them back to null) actually clears the persisted value
  /// instead of leaving stale data behind.
  Future<void> savePreferences() async {
    if (activityPreference != null) {
      await _prefs.setString('activityPreference', activityPreference!);
    } else {
      await _prefs.remove('activityPreference');
    }
    // Mood is deliberately not saved — see [loadPreferences] for why.
    await _prefs.setDouble('energyLevel', energyLevel);
    if (timeOfDay != null) {
      await _prefs.setString('timeOfDay', timeOfDay!);
    } else {
      await _prefs.remove('timeOfDay');
    }
    await _prefs.setBool('autoDetectTime', autoDetectTime);
    if (socialContext != null) {
      await _prefs.setString('socialContext', socialContext!);
    } else {
      await _prefs.remove('socialContext');
    }
    if (duration != null) {
      await _prefs.setString('duration', duration!);
    } else {
      await _prefs.remove('duration');
    }
    await _prefs.setBool('useDarkMode', useDarkMode);
    await _prefs.setBool('useSystemTheme', useSystemTheme);
    await _prefs.setBool('enableHaptics', enableHaptics);
    await _prefs.setString('colorTheme', colorTheme);
    await _prefs.setDouble('weirdnessTolerance', weirdnessTolerance);
    await _prefs.setBool('useWeather', useWeather);
    await _prefs.setBool('useLocation', useLocation);
    await _prefs.setStringList('userInterests', userInterests);
    await _prefs.setBool('firstDealCompleted', firstDealCompleted);
    await _prefs.setBool('interestsPromptDismissed', interestsPromptDismissed);
    await _prefs.setStringList('favoriteActivities', favoriteActivities);
  }
  
  /// Update a single preference (typed). Saves and notifies listeners.
  ///
  /// Prefer this over [updatePreference] for new code — using the enum
  /// catches typos at compile time. The exhaustive switch ensures that
  /// adding a new [PreferenceKey] surfaces a missing case as an analyzer
  /// warning.
  void setPreference(PreferenceKey key, dynamic value) {
    switch (key) {
      case PreferenceKey.activityPreference:
        activityPreference = value as String?;
        break;
      case PreferenceKey.mood:
        mood = value as String?;
        break;
      case PreferenceKey.energyLevel:
        energyLevel = value as double;
        break;
      case PreferenceKey.timeOfDay:
        timeOfDay = value as String?;
        break;
      case PreferenceKey.autoDetectTime:
        autoDetectTime = value as bool;
        break;
      case PreferenceKey.socialContext:
        socialContext = value as String?;
        break;
      case PreferenceKey.duration:
        duration = value as String?;
        break;
      case PreferenceKey.useDarkMode:
        useDarkMode = value as bool;
        break;
      case PreferenceKey.useSystemTheme:
        useSystemTheme = value as bool;
        break;
      case PreferenceKey.enableHaptics:
        enableHaptics = value as bool;
        break;
      case PreferenceKey.colorTheme:
        colorTheme = value as String;
        break;
      case PreferenceKey.weirdnessTolerance:
        weirdnessTolerance = (value as double).clamp(0.0, 1.0);
        break;
      case PreferenceKey.useWeather:
        useWeather = value as bool;
        break;
      case PreferenceKey.useLocation:
        useLocation = value as bool;
        break;
      case PreferenceKey.userInterests:
        userInterests = List<String>.from(value as Iterable);
        break;
      case PreferenceKey.firstDealCompleted:
        firstDealCompleted = value as bool;
        break;
      case PreferenceKey.interestsPromptDismissed:
        interestsPromptDismissed = value as bool;
        break;
    }
    savePreferences();
    notifyListeners();
  }

  /// Update a single preference by string key (legacy API).
  ///
  /// Routes through [setPreference] using [PreferenceKey.fromString].
  /// Unknown keys are silently ignored to preserve prior behavior.
  /// New code should use [setPreference] with [PreferenceKey] directly.
  void updatePreference(String key, dynamic value) {
    final preferenceKey = PreferenceKey.fromString(key);
    if (preferenceKey == null) return;
    setPreference(preferenceKey, value);
  }
  
  /// Toggle an activity's favorite status by [Suggestion.id].
  ///
  /// Post-Phase-3, callers pass the id of the suggestion (catalog
  /// slug or `custom-<hash>`), not its title. Adds it to favorites if
  /// not present, removes it otherwise. Saves and notifies listeners.
  ///
  /// Returns a [Future] that completes when the persist round-trip
  /// finishes. UI callers can ignore it; tests should await it so the
  /// post-toggle assertions don't race the storage write.
  Future<void> toggleFavorite(String id) async {
    if (favoriteActivities.contains(id)) {
      favoriteActivities.remove(id);
    } else {
      favoriteActivities.add(id);
    }
    notifyListeners();
    await savePreferences();
  }

  /// Whether the suggestion with the given [id] is a favorite.
  bool isFavorite(String id) {
    return favoriteActivities.contains(id);
  }

  /// Reset questionnaire preferences to default values.
  ///
  /// Clears activity preference, mood, and time of day. Resets energy
  /// level to 3.0 and weirdness tolerance to 0.3. Theme settings,
  /// favorites, history, and feedback are not affected.
  ///
  /// Returns a [Future] that completes when the cleared values are
  /// flushed to storage — important so reopen-the-app behavior matches
  /// in-memory state immediately after a reset.
  Future<void> resetPreferences() async {
    activityPreference = null;
    mood = null;
    energyLevel = 3.0;
    timeOfDay = null;
    weirdnessTolerance = 0.3;
    notifyListeners();
    await savePreferences();
  }

  /// Check if all required preferences for dealing cards are set.
  ///
  /// Returns true if activity preference and mood are selected.
  /// Time of day is optional when autoDetectTime is enabled.
  bool get arePreferencesComplete {
    return activityPreference != null &&
           mood != null &&
           (autoDetectTime || timeOfDay != null);
  }
}
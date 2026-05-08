import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/context_service.dart';

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
  weirdnessTolerance('weirdnessTolerance');

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
    mood = _prefs.getString('mood');
    // If current mood is 'Energetic', reset it since we're removing that option
    if (mood == 'Energetic') {
      mood = null;
    }
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
    favoriteActivities = _prefs.getStringList('favoriteActivities') ?? [];
    notifyListeners();
  }
  
  /// Save all current preferences to SharedPreferences
  ///
  /// Persists all non-null preference values to device storage.
  Future<void> savePreferences() async {
    if (activityPreference != null) {
      await _prefs.setString('activityPreference', activityPreference!);
    }
    if (mood != null) {
      await _prefs.setString('mood', mood!);
    }
    await _prefs.setDouble('energyLevel', energyLevel);
    if (timeOfDay != null) {
      await _prefs.setString('timeOfDay', timeOfDay!);
    }
    await _prefs.setBool('autoDetectTime', autoDetectTime);
    if (socialContext != null) {
      await _prefs.setString('socialContext', socialContext!);
    }
    if (duration != null) {
      await _prefs.setString('duration', duration!);
    }
    await _prefs.setBool('useDarkMode', useDarkMode);
    await _prefs.setBool('useSystemTheme', useSystemTheme);
    await _prefs.setBool('enableHaptics', enableHaptics);
    await _prefs.setString('colorTheme', colorTheme);
    await _prefs.setDouble('weirdnessTolerance', weirdnessTolerance);
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
  void toggleFavorite(String id) {
    if (favoriteActivities.contains(id)) {
      favoriteActivities.remove(id);
    } else {
      favoriteActivities.add(id);
    }
    savePreferences();
    notifyListeners();
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
  void resetPreferences() {
    activityPreference = null;
    mood = null;
    energyLevel = 3.0;
    timeOfDay = null;
    weirdnessTolerance = 0.3;
    savePreferences();
    notifyListeners();
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
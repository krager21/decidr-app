/// A named snapshot of the questionnaire answers — "Solo weeknight",
/// "Date night", "Rainy Sunday" — that can be re-applied in one tap
/// instead of walking the questionnaire again.
///
/// Captures the *deal inputs* only (environment, mood, energy,
/// weirdness, time, social context, duration). App-level settings like
/// theme, haptics, and consent toggles deliberately stay out: a
/// profile changes what gets dealt, never how the app behaves.
class PreferenceProfile {
  final String id;
  final String name;
  final String? activityPreference;
  final String? mood;
  final double energyLevel;
  final double weirdnessTolerance;
  final bool autoDetectTime;
  final String? timeOfDay;
  final String? socialContext;
  final String? duration;

  const PreferenceProfile({
    required this.id,
    required this.name,
    this.activityPreference,
    this.mood,
    this.energyLevel = 3.0,
    this.weirdnessTolerance = 0.3,
    this.autoDetectTime = true,
    this.timeOfDay,
    this.socialContext,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activityPreference': activityPreference,
        'mood': mood,
        'energyLevel': energyLevel,
        'weirdnessTolerance': weirdnessTolerance,
        'autoDetectTime': autoDetectTime,
        'timeOfDay': timeOfDay,
        'socialContext': socialContext,
        'duration': duration,
      };

  /// Tolerant decode: missing or wrongly-typed fields fall back to
  /// defaults so a profile written by a newer app version never
  /// crashes an older one.
  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    String? str(Object? v) => v is String ? v : null;
    double numOr(Object? v, double fallback, double lo, double hi) =>
        v is num ? v.toDouble().clamp(lo, hi) : fallback;
    return PreferenceProfile(
      id: str(json['id']) ?? 'profile-unknown',
      name: str(json['name']) ?? 'Profile',
      activityPreference: str(json['activityPreference']),
      mood: str(json['mood']),
      energyLevel: numOr(json['energyLevel'], 3.0, 1.0, 5.0),
      weirdnessTolerance: numOr(json['weirdnessTolerance'], 0.3, 0.0, 1.0),
      autoDetectTime: json['autoDetectTime'] is bool
          ? json['autoDetectTime'] as bool
          : true,
      timeOfDay: str(json['timeOfDay']),
      socialContext: str(json['socialContext']),
      duration: str(json['duration']),
    );
  }

  /// Short human summary for list subtitles, e.g.
  /// "Indoor · Relaxed · Low energy".
  String get summary {
    final parts = <String>[
      if (activityPreference != null) activityPreference!,
      if (mood != null) mood!,
      if (energyLevel <= 2.0)
        'Low energy'
      else if (energyLevel >= 4.0)
        'High energy',
    ];
    return parts.isEmpty ? 'Balanced defaults' : parts.join(' · ');
  }
}

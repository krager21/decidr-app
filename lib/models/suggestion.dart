import 'package:flutter/material.dart';

/// The type of environment an activity takes place in.
enum ActivityType {
  indoor,
  outdoor,

  /// Activities that work either indoors or outdoors.
  hybrid;

  String get label {
    switch (this) {
      case ActivityType.indoor:
        return 'Indoor';
      case ActivityType.outdoor:
        return 'Outdoor';
      case ActivityType.hybrid:
        return 'Hybrid';
    }
  }

  static ActivityType fromLabel(String label) =>
      ActivityType.values.firstWhere((e) => e.label == label);
}

/// The mood an activity suits.
enum Mood {
  relaxed,
  productive,
  creative,
  social;

  String get label {
    switch (this) {
      case Mood.relaxed:
        return 'Relaxed';
      case Mood.productive:
        return 'Productive';
      case Mood.creative:
        return 'Creative';
      case Mood.social:
        return 'Social';
    }
  }

  static Mood fromLabel(String label) =>
      Mood.values.firstWhere((e) => e.label == label);
}

/// Whether the activity is best done alone, with one other person, or in groups.
enum SocialContext {
  solo,
  partner,
  smallGroup,
  largeGroup;

  String get label {
    switch (this) {
      case SocialContext.solo:
        return 'Solo';
      case SocialContext.partner:
        return 'Partner';
      case SocialContext.smallGroup:
        return 'Small Group';
      case SocialContext.largeGroup:
        return 'Large Group';
    }
  }

  static SocialContext fromLabel(String label) =>
      SocialContext.values.firstWhere((e) => e.label == label);
}

/// Time of day when the activity makes the most sense.
enum TimeOfDayPref {
  morning,
  afternoon,
  evening,
  night;

  String get label {
    switch (this) {
      case TimeOfDayPref.morning:
        return 'Morning';
      case TimeOfDayPref.afternoon:
        return 'Afternoon';
      case TimeOfDayPref.evening:
        return 'Evening';
      case TimeOfDayPref.night:
        return 'Night';
    }
  }

  static TimeOfDayPref fromLabel(String label) =>
      TimeOfDayPref.values.firstWhere((e) => e.label == label);
}

/// How the activity tolerates weather.
enum WeatherTolerance {
  /// Works in any weather.
  any,

  /// Outdoor activity that needs dry weather.
  drySpellsOnly,

  /// Indoor-only — weather is irrelevant.
  indoorOnly;

  String get label {
    switch (this) {
      case WeatherTolerance.any:
        return 'Any';
      case WeatherTolerance.drySpellsOnly:
        return 'Dry weather only';
      case WeatherTolerance.indoorOnly:
        return 'Indoor only';
    }
  }
}

/// A structured activity suggestion.
///
/// Replaces the legacy plain-string suggestions with a rich record that
/// supports filtering, scoring, and richer presentation (icons, descriptions).
///
/// Catalog suggestions ship with the app and have stable [id]s. Custom
/// user-added suggestions get auto-generated `custom-…` IDs and conservative
/// defaults so they pass through filters.
@immutable
class Suggestion {
  /// Stable identifier (kebab-case slug for catalog items, `custom-<uuid>`
  /// for user-added entries).
  final String id;

  /// Short display name shown on cards.
  final String title;

  /// One-to-two sentence vivid description shown on the reveal card.
  final String description;

  /// Material icon name (e.g. `directions_walk`). Resolved to [IconData] at
  /// render time via [iconData] — keeps the model JSON-friendly.
  final String iconName;

  final ActivityType activityType;

  /// Moods this activity fits. Most activities suit several.
  final List<Mood> moods;

  /// Social configurations this activity supports.
  final List<SocialContext> social;

  /// Times of day when this activity makes sense. Empty list means any time.
  final List<TimeOfDayPref> timeOfDay;

  /// Energy required, on a 1.0 (very low) to 5.0 (very high) scale.
  /// Replaces the keyword-based inference in the legacy filter.
  final double energyLevel;

  /// Typical duration in minutes.
  final int durationMinutes;

  /// Weather suitability.
  final WeatherTolerance weather;

  /// Free-form descriptive tags
  /// (e.g. `screen-free`, `free`, `quick`, `physical`).
  ///
  /// Tags describe **properties** of the activity. For user-facing
  /// **categories** (music, food, fitness, etc.) use [interests] instead —
  /// see [Interests] for the canonical taxonomy.
  final List<String> tags;

  /// First-class interest categories this activity falls under.
  ///
  /// Use values from [Interests] for catalog entries. The future
  /// "I'm interested in {music, food, …}" filter will match a user's
  /// selected interests against this field. An empty list means the
  /// activity is generic (matches any interest filter).
  ///
  /// Distinct from [tags] in intent: tags describe the activity;
  /// interests categorise it for user-driven filtering and external
  /// suggestion sources (e.g. a future concert integration would
  /// produce suggestions with `interests: [Interests.music]`).
  final List<String> interests;

  /// How off-the-wall this activity is, on a 0.0 → 1.0 scale.
  ///
  /// 0.0 = mainstream, expected ("take a walk", "read a book").
  /// 0.5 = mildly unusual ("learn morse code", "make a stop-motion video").
  /// 1.0 = genuinely eccentric ("eat dinner in complete darkness",
  ///       "spend an hour pretending you're a tourist in your own town").
  ///
  /// Defaults to 0.2 so existing entries read as "slightly novel" rather
  /// than dead-mainstream — they are curated, after all.
  ///
  /// The future "weirdness slider" in preferences will map a user's
  /// tolerance against this field via a distance-based affinity: at
  /// tolerance 0 mainstream wins, at tolerance 1 weird wins.
  final double weirdness;

  /// True if user-added at runtime (not part of the shipped catalog).
  final bool isCustom;

  const Suggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.activityType,
    required this.moods,
    required this.social,
    this.timeOfDay = const [],
    required this.energyLevel,
    required this.durationMinutes,
    this.weather = WeatherTolerance.any,
    this.tags = const [],
    this.interests = const [],
    this.weirdness = 0.2,
    this.isCustom = false,
  });

  /// Resolve [iconName] to a Material [IconData]. Falls back to a generic
  /// activity icon if the name is not in the lookup table.
  IconData get iconData =>
      _materialIcons[iconName] ?? Icons.local_activity_outlined;

  Suggestion copyWith({
    String? id,
    String? title,
    String? description,
    String? iconName,
    ActivityType? activityType,
    List<Mood>? moods,
    List<SocialContext>? social,
    List<TimeOfDayPref>? timeOfDay,
    double? energyLevel,
    int? durationMinutes,
    WeatherTolerance? weather,
    List<String>? tags,
    List<String>? interests,
    double? weirdness,
    bool? isCustom,
  }) {
    return Suggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      activityType: activityType ?? this.activityType,
      moods: moods ?? this.moods,
      social: social ?? this.social,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      energyLevel: energyLevel ?? this.energyLevel,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      weather: weather ?? this.weather,
      tags: tags ?? this.tags,
      interests: interests ?? this.interests,
      weirdness: weirdness ?? this.weirdness,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'iconName': iconName,
        'activityType': activityType.name,
        'moods': moods.map((m) => m.name).toList(),
        'social': social.map((s) => s.name).toList(),
        'timeOfDay': timeOfDay.map((t) => t.name).toList(),
        'energyLevel': energyLevel,
        'durationMinutes': durationMinutes,
        'weather': weather.name,
        'tags': tags,
        'interests': interests,
        'weirdness': weirdness,
        'isCustom': isCustom,
      };

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'local_activity_outlined',
      activityType: ActivityType.values.byName(json['activityType'] as String),
      moods: (json['moods'] as List<dynamic>)
          .map((m) => Mood.values.byName(m as String))
          .toList(),
      social: (json['social'] as List<dynamic>)
          .map((s) => SocialContext.values.byName(s as String))
          .toList(),
      timeOfDay: (json['timeOfDay'] as List<dynamic>? ?? [])
          .map((t) => TimeOfDayPref.values.byName(t as String))
          .toList(),
      energyLevel: (json['energyLevel'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      weather: WeatherTolerance.values.byName(
        json['weather'] as String? ?? 'any',
      ),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((t) => t as String)
          .toList(),
      // `interests` is a Phase-5 addition. Older persisted JSON may
      // omit it — treat missing as empty list (non-breaking).
      interests: (json['interests'] as List<dynamic>? ?? [])
          .map((i) => i as String)
          .toList(),
      // `weirdness` is a Phase-5b addition; defaults to 0.2 if absent
      // so legacy JSON loads without breaking.
      weirdness: (json['weirdness'] as num?)?.toDouble() ?? 0.2,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Suggestion && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Suggestion($id: $title)';
}

/// Canonical interest categories — the taxonomy used by [Suggestion.interests].
///
/// Stable strings, not an enum, so the catalog can be edited and external
/// suggestion sources can populate this field without a code change. The
/// constants below are the single source of truth — UIs and filters
/// should reference them rather than hard-coding the strings.
///
/// Add new interests by appending to [all]. Don't rename existing ones —
/// they're persisted in the catalog.
class Interests {
  Interests._(); // not instantiable

  // Active / outdoors
  static const String nature = 'nature';
  static const String fitness = 'fitness';
  static const String sports = 'sports';
  static const String walking = 'walking';
  static const String adventure = 'adventure';

  // Creative / making
  static const String art = 'art';
  static const String music = 'music';
  static const String writing = 'writing';
  static const String photography = 'photography';
  static const String crafts = 'crafts';
  static const String creativity = 'creativity';

  // Mind / learning
  static const String reading = 'reading';
  static const String learning = 'learning';
  static const String mindfulness = 'mindfulness';

  // Food & home
  static const String food = 'food';
  static const String cooking = 'cooking';
  static const String home = 'home';
  static const String gardening = 'gardening';

  // People / community
  static const String social = 'social';
  static const String connection = 'connection';
  static const String community = 'community';
  static const String family = 'family';

  // Self & lifestyle
  static const String wellness = 'wellness';
  static const String productivity = 'productivity';
  static const String games = 'games';
  static const String tech = 'tech';
  static const String exploration = 'exploration';
  static const String culture = 'culture';

  /// All canonical interest values, useful for UI pickers and validation.
  ///
  /// Order roughly groups related interests so a future picker can show
  /// them in sensible sections.
  static const List<String> all = [
    nature, fitness, sports, walking, adventure,
    art, music, writing, photography, crafts, creativity,
    reading, learning, mindfulness,
    food, cooking, home, gardening,
    social, connection, community, family,
    wellness, productivity, games, tech, exploration, culture,
  ];
}

/// Lookup table mapping icon name strings to Material [IconData].
///
/// Keeping this private and append-only avoids issues with const IconData
/// tree-shaking. Add new entries here as new suggestions reference them.
const Map<String, IconData> _materialIcons = {
  'directions_walk': Icons.directions_walk,
  'directions_run': Icons.directions_run,
  'directions_bike': Icons.directions_bike,
  'menu_book': Icons.menu_book,
  'auto_stories': Icons.auto_stories,
  'movie': Icons.movie,
  'music_note': Icons.music_note,
  'headphones': Icons.headphones,
  'mic': Icons.mic,
  'palette': Icons.palette,
  'brush': Icons.brush,
  'edit': Icons.edit,
  'create': Icons.create,
  'photo_camera': Icons.photo_camera,
  'self_improvement': Icons.self_improvement,
  'spa': Icons.spa,
  'bedtime': Icons.bedtime,
  'bathtub': Icons.bathtub,
  'local_cafe': Icons.local_cafe,
  'restaurant': Icons.restaurant,
  'restaurant_menu': Icons.restaurant_menu,
  'cake': Icons.cake,
  'cookie': Icons.cookie,
  'fitness_center': Icons.fitness_center,
  'sports_basketball': Icons.sports_basketball,
  'sports_tennis': Icons.sports_tennis,
  'sports_soccer': Icons.sports_soccer,
  'pool': Icons.pool,
  'hiking': Icons.hiking,
  'kayaking': Icons.kayaking,
  'park': Icons.park,
  'forest': Icons.forest,
  'beach_access': Icons.beach_access,
  'wb_sunny': Icons.wb_sunny,
  'nightlight': Icons.nightlight,
  'cloud': Icons.cloud,
  'pets': Icons.pets,
  'home': Icons.home,
  'cleaning_services': Icons.cleaning_services,
  'build': Icons.build,
  'yard': Icons.yard,
  'grass': Icons.grass,
  'eco': Icons.eco,
  'shopping_basket': Icons.shopping_basket,
  'volunteer_activism': Icons.volunteer_activism,
  'celebration': Icons.celebration,
  'group': Icons.group,
  'people': Icons.people,
  'forum': Icons.forum,
  'phone': Icons.phone,
  'video_call': Icons.video_call,
  'chat': Icons.chat,
  'mail': Icons.mail,
  'card_giftcard': Icons.card_giftcard,
  'school': Icons.school,
  'language': Icons.language,
  'computer': Icons.computer,
  'devices': Icons.devices,
  'work': Icons.work,
  'attach_money': Icons.attach_money,
  'savings': Icons.savings,
  'list_alt': Icons.list_alt,
  'checklist': Icons.checklist,
  'lightbulb': Icons.lightbulb,
  'flag': Icons.flag,
  'extension': Icons.extension,
  'gamepad': Icons.gamepad,
  'piano': Icons.piano,
  'theater_comedy': Icons.theater_comedy,
  'museum': Icons.museum,
  'local_florist': Icons.local_florist,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'local_activity_outlined': Icons.local_activity_outlined,
  // Phase 4 additions
  'shower': Icons.shower,
  'newspaper': Icons.newspaper,
  'explore': Icons.explore,
  'emoji_events': Icons.emoji_events,
  'videocam': Icons.videocam,
  'track_changes': Icons.track_changes,
  'waves': Icons.waves,
  'iron': Icons.iron,
};

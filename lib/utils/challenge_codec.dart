import 'dart:convert';

import '../models/suggestion.dart';

/// A shareable "same hand" challenge: the deal inputs plus a shuffle
/// seed, so a friend opening the link gets dealt the exact same three
/// cards (against the same catalog version), plus the sender's pick
/// for comparison.
///
/// Encoded as URL-safe base64 JSON in the `c` query parameter of the
/// web app's `/deal` route.
class ChallengePayload {
  final ActivityType activityType;
  final Mood mood;
  final TimeOfDayPref timeOfDay;
  final double energyLevel;
  final double weirdnessTolerance;
  final int seed;

  /// The sender's chosen suggestion id — shown as "they drew X".
  final String chosenId;

  const ChallengePayload({
    required this.activityType,
    required this.mood,
    required this.timeOfDay,
    required this.energyLevel,
    required this.weirdnessTolerance,
    required this.seed,
    required this.chosenId,
  });

  String encode() {
    final json = jsonEncode({
      'v': 1,
      'a': activityType.name,
      'm': mood.name,
      't': timeOfDay.name,
      'e': energyLevel,
      'w': weirdnessTolerance,
      's': seed,
      'c': chosenId,
    });
    return base64UrlEncode(utf8.encode(json));
  }

  /// Decode a challenge string. Returns null for anything malformed —
  /// a bad link should degrade to a normal open, never crash.
  static ChallengePayload? decode(String encoded) {
    try {
      final json =
          jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (json is! Map<String, dynamic>) return null;
      if (json['v'] != 1) return null;
      return ChallengePayload(
        activityType: ActivityType.values.byName(json['a'] as String),
        mood: Mood.values.byName(json['m'] as String),
        timeOfDay: TimeOfDayPref.values.byName(json['t'] as String),
        energyLevel: (json['e'] as num).toDouble().clamp(1.0, 5.0),
        weirdnessTolerance:
            (json['w'] as num).toDouble().clamp(0.0, 1.0),
        seed: json['s'] as int,
        chosenId: json['c'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// The full shareable web link for this challenge.
  String get shareUrl =>
      'https://krager21.github.io/decidr-app/#/deal?c=${encode()}';
}

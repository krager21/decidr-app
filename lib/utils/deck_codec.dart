import 'dart:convert';

import '../models/suggestion.dart';

/// Portable text encoding for a user's custom card deck, so decks can
/// travel over any share sheet / chat and be imported by pasting.
///
/// Format: `decidr-deck:v1:<base64url json>` where the JSON is a list
/// of `{t: title, a: activityType, e: energy, d: minutes}`.
const String _prefix = 'decidr-deck:v1:';

/// One card in a portable deck.
typedef PortableCard = ({
  String title,
  ActivityType activityType,
  double energyLevel,
  int durationMinutes,
});

String encodeCustomDeck(List<Suggestion> customs) {
  final payload = jsonEncode([
    for (final s in customs)
      {
        't': s.title,
        'a': s.activityType.name,
        'e': s.energyLevel,
        'd': s.durationMinutes,
      },
  ]);
  return '$_prefix${base64UrlEncode(utf8.encode(payload))}';
}

/// Decode a shared deck string (whitespace-tolerant — chat apps love
/// wrapping pasted text). Returns null when the string isn't a deck;
/// individual malformed entries are skipped rather than failing the
/// whole import.
List<PortableCard>? decodeCustomDeck(String input) {
  final compact = input.trim().replaceAll(RegExp(r'\s'), '');
  if (!compact.startsWith(_prefix)) return null;
  try {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(compact.substring(_prefix.length))),
    );
    if (decoded is! List) return null;
    final cards = <PortableCard>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final title = entry['t'];
      if (title is! String || title.trim().isEmpty) continue;
      ActivityType type;
      try {
        type = ActivityType.values.byName(entry['a'] as String);
      } catch (_) {
        type = ActivityType.hybrid;
      }
      cards.add((
        title: title.trim(),
        activityType: type,
        energyLevel:
            ((entry['e'] as num?)?.toDouble() ?? 3.0).clamp(1.0, 5.0),
        durationMinutes: (entry['d'] as num?)?.toInt() ?? 30,
      ));
    }
    return cards;
  } catch (_) {
    return null;
  }
}

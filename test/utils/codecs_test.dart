import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/suggestion.dart';
import 'package:decidr_app/models/suggestions_repository.dart';
import 'package:decidr_app/utils/challenge_codec.dart';
import 'package:decidr_app/utils/deck_codec.dart';

void main() {
  group('ChallengePayload', () {
    const payload = ChallengePayload(
      activityType: ActivityType.indoor,
      mood: Mood.relaxed,
      timeOfDay: TimeOfDayPref.evening,
      energyLevel: 2.5,
      weirdnessTolerance: 0.4,
      seed: 12345,
      chosenId: 'read-a-book',
    );

    test('round-trips through encode/decode', () {
      final decoded = ChallengePayload.decode(payload.encode())!;
      expect(decoded.activityType, ActivityType.indoor);
      expect(decoded.mood, Mood.relaxed);
      expect(decoded.timeOfDay, TimeOfDayPref.evening);
      expect(decoded.energyLevel, 2.5);
      expect(decoded.weirdnessTolerance, 0.4);
      expect(decoded.seed, 12345);
      expect(decoded.chosenId, 'read-a-book');
    });

    test('decode rejects garbage instead of throwing', () {
      expect(ChallengePayload.decode('not-base64!!'), isNull);
      expect(ChallengePayload.decode(''), isNull);
      expect(ChallengePayload.decode('aGVsbG8='), isNull); // "hello"
    });

    test('shareUrl embeds the payload on the /deal route', () {
      expect(payload.shareUrl, contains('#/deal?c='));
    });

    test('the same seed deals the same hand', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SuggestionsRepository(prefs);

      List<String> deal() => repo
          .getStructuredSuggestions(
            activityType: payload.activityType,
            mood: payload.mood,
            timeOfDay: payload.timeOfDay,
            energyLevel: payload.energyLevel,
            weirdnessTolerance: payload.weirdnessTolerance,
            includeCustom: false,
            includeFavorites: false,
            count: 3,
            shuffleSeed: payload.seed,
          )
          .map((s) => s.id)
          .toList();

      expect(deal(), deal(), reason: 'seeded shuffle must be deterministic');
    });
  });

  group('deck codec', () {
    test('round-trips custom cards with details', () async {
      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = SuggestionsRepository(sharedPrefs);
      repo.addCustomSuggestionChecked(
        'Go bouldering',
        activityType: ActivityType.outdoor,
        energyLevel: 4.5,
        durationMinutes: 90,
      );
      repo.addCustomSuggestionChecked('Sort the photo library');

      final encoded = encodeCustomDeck(repo.customSuggestions);
      final decoded = decodeCustomDeck(encoded)!;

      expect(decoded, hasLength(2));
      expect(decoded.first.title, 'Go bouldering');
      expect(decoded.first.activityType, ActivityType.outdoor);
      expect(decoded.first.energyLevel, 4.5);
      expect(decoded.first.durationMinutes, 90);
    });

    test('tolerates whitespace wrapping from chat apps', () async {
      SharedPreferences.setMockInitialValues({});
      final sharedPrefs = await SharedPreferences.getInstance();
      final repo = SuggestionsRepository(sharedPrefs);
      repo.addCustomSuggestionChecked('Pottery');
      final encoded = encodeCustomDeck(repo.customSuggestions);
      final wrapped =
          '  ${encoded.substring(0, 30)}\n${encoded.substring(30)}  ';
      expect(decodeCustomDeck(wrapped), hasLength(1));
    });

    test('rejects non-deck text', () {
      expect(decodeCustomDeck('hello there'), isNull);
      expect(decodeCustomDeck('decidr-deck:v1:!!!'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decidr_app/models/preference_profile.dart';
import 'package:decidr_app/models/preferences_model.dart';

Future<PreferencesModel> freshModel({Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final model = PreferencesModel(prefs);
  await model.loadPreferences();
  return model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferenceProfile JSON', () {
    test('round-trips all fields', () {
      const profile = PreferenceProfile(
        id: 'profile-1',
        name: 'Date night',
        activityPreference: 'Outdoor',
        mood: 'Social',
        energyLevel: 4.0,
        weirdnessTolerance: 0.7,
        autoDetectTime: false,
        timeOfDay: 'Evening',
        socialContext: 'Partner',
        duration: 'Half Day',
      );

      final decoded = PreferenceProfile.fromJson(profile.toJson());

      expect(decoded.id, 'profile-1');
      expect(decoded.name, 'Date night');
      expect(decoded.activityPreference, 'Outdoor');
      expect(decoded.mood, 'Social');
      expect(decoded.energyLevel, 4.0);
      expect(decoded.weirdnessTolerance, 0.7);
      expect(decoded.autoDetectTime, isFalse);
      expect(decoded.timeOfDay, 'Evening');
      expect(decoded.socialContext, 'Partner');
      expect(decoded.duration, 'Half Day');
    });

    test('tolerates missing and mistyped fields', () {
      final decoded = PreferenceProfile.fromJson({
        'name': 42, // wrong type
        'energyLevel': 'high', // wrong type
        'autoDetectTime': 'yes', // wrong type
      });

      expect(decoded.name, 'Profile');
      expect(decoded.energyLevel, 3.0);
      expect(decoded.autoDetectTime, isTrue);
      expect(decoded.activityPreference, isNull);
    });

    test('clamps out-of-range numeric values', () {
      final decoded = PreferenceProfile.fromJson({
        'id': 'p',
        'name': 'n',
        'energyLevel': 99,
        'weirdnessTolerance': -3,
      });

      expect(decoded.energyLevel, 5.0);
      expect(decoded.weirdnessTolerance, 0.0);
    });
  });

  group('PreferencesModel profiles', () {
    test('save, persist, and reload a profile', () async {
      final model = await freshModel();
      model.activityPreference = 'Indoor';
      model.mood = 'Relaxed';
      model.energyLevel = 2.0;

      final result =
          await model.saveCurrentAsProfile('Cozy night', maxCount: 2);
      expect(result, SaveProfileResult.saved);
      expect(model.savedProfiles, hasLength(1));

      // Reload from the same storage — the profile survives.
      final prefs = await SharedPreferences.getInstance();
      final reloaded = PreferencesModel(prefs);
      await reloaded.loadPreferences();
      expect(reloaded.savedProfiles, hasLength(1));
      expect(reloaded.savedProfiles.first.name, 'Cozy night');
      expect(reloaded.savedProfiles.first.activityPreference, 'Indoor');
      expect(reloaded.savedProfiles.first.mood, 'Relaxed');
    });

    test('rejects empty and duplicate names', () async {
      final model = await freshModel();
      expect(await model.saveCurrentAsProfile('  ', maxCount: 5),
          SaveProfileResult.invalid);
      expect(await model.saveCurrentAsProfile('Solo', maxCount: 5),
          SaveProfileResult.saved);
      expect(await model.saveCurrentAsProfile('solo', maxCount: 5),
          SaveProfileResult.duplicate);
    });

    test('enforces the caller-supplied cap', () async {
      final model = await freshModel();
      expect(await model.saveCurrentAsProfile('One', maxCount: 2),
          SaveProfileResult.saved);
      expect(await model.saveCurrentAsProfile('Two', maxCount: 2),
          SaveProfileResult.saved);
      expect(await model.saveCurrentAsProfile('Three', maxCount: 2),
          SaveProfileResult.capReached);
      // Premium ceiling admits it.
      expect(await model.saveCurrentAsProfile('Three', maxCount: 10),
          SaveProfileResult.saved);
    });

    test('applyProfile sets answers including in-memory mood', () async {
      final model = await freshModel();
      const profile = PreferenceProfile(
        id: 'p1',
        name: 'Adventure',
        activityPreference: 'Outdoor',
        mood: 'Creative',
        energyLevel: 5.0,
        weirdnessTolerance: 1.0,
        autoDetectTime: false,
        timeOfDay: 'Morning',
        socialContext: 'Solo',
        duration: 'Full Day',
      );

      await model.applyProfile(profile);

      expect(model.activityPreference, 'Outdoor');
      expect(model.mood, 'Creative');
      expect(model.energyLevel, 5.0);
      expect(model.weirdnessTolerance, 1.0);
      expect(model.autoDetectTime, isFalse);
      expect(model.timeOfDay, 'Morning');
      expect(model.socialContext, 'Solo');
      expect(model.duration, 'Full Day');
      expect(model.arePreferencesComplete, isTrue);

      // Mood is session-only: a reload clears it but keeps the rest.
      final prefs = await SharedPreferences.getInstance();
      final reloaded = PreferencesModel(prefs);
      await reloaded.loadPreferences();
      expect(reloaded.mood, isNull);
      expect(reloaded.activityPreference, 'Outdoor');
    });

    test('deleteProfile removes and persists', () async {
      final model = await freshModel();
      await model.saveCurrentAsProfile('Keep', maxCount: 5);
      await model.saveCurrentAsProfile('Drop', maxCount: 5);
      final dropId = model.savedProfiles
          .firstWhere((p) => p.name == 'Drop')
          .id;

      await model.deleteProfile(dropId);

      expect(model.savedProfiles.map((p) => p.name), ['Keep']);
      final prefs = await SharedPreferences.getInstance();
      final reloaded = PreferencesModel(prefs);
      await reloaded.loadPreferences();
      expect(reloaded.savedProfiles.map((p) => p.name), ['Keep']);
    });

    test('malformed persisted payload resets to empty', () async {
      final model = await freshModel(seed: {
        'savedProfiles': '{not json',
      });
      expect(model.savedProfiles, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decidr_app/models/preferences_model.dart';

/// Unit tests for PreferencesModel
///
/// Tests cover:
/// - Loading preferences from storage
/// - Saving preferences to storage
/// - Updating individual preferences
/// - Favorite activity management
/// - Preference reset functionality
/// - Migration of deprecated values
void main() {
  group('PreferencesModel', () {
    late PreferencesModel model;

    setUp(() async {
      // Initialize with empty preferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      model = PreferencesModel(prefs);
    });

    test('should have default values on initialization', () {
      expect(model.activityPreference, isNull);
      expect(model.mood, isNull);
      expect(model.energyLevel, 3.0);
      expect(model.timeOfDay, isNull);
      expect(model.useDarkMode, false);
      expect(model.useSystemTheme, true);
      expect(model.enableHaptics, true);
      expect(model.colorTheme, 'rainbow');
      expect(model.favoriteActivities, isEmpty);
    });

    test('should load preferences from storage', () async {
      // Setup mock data
      SharedPreferences.setMockInitialValues({
        'activityPreference': 'Indoor',
        'mood': 'Relaxed',
        'energyLevel': 4.0,
        'timeOfDay': 'Evening',
        'useDarkMode': true,
        'useSystemTheme': false,
        'enableHaptics': false,
        'colorTheme': 'ocean',
        'favoriteActivities': ['Reading', 'Walking'],
      });

      final prefs = await SharedPreferences.getInstance();
      final loadedModel = PreferencesModel(prefs);
      await loadedModel.loadPreferences();

      expect(loadedModel.activityPreference, 'Indoor');
      // Mood is intentionally not persisted; loadPreferences clears it
      // even if a value is in storage (legacy data is ignored).
      expect(loadedModel.mood, isNull);
      expect(loadedModel.energyLevel, 4.0);
      expect(loadedModel.timeOfDay, 'Evening');
      expect(loadedModel.useDarkMode, true);
      expect(loadedModel.useSystemTheme, false);
      expect(loadedModel.enableHaptics, false);
      expect(loadedModel.colorTheme, 'ocean');
      expect(loadedModel.favoriteActivities, ['Reading', 'Walking']);
    });

    test('mood always loads as null (intentionally not persisted)', () async {
      // Mood is wiped on each launch so the user is asked
      // "what's your mood today?" fresh every time. This subsumes the
      // older "deprecated Energetic mood is reset" test.
      SharedPreferences.setMockInitialValues({
        'mood': 'Productive',
      });

      final prefs = await SharedPreferences.getInstance();
      final loadedModel = PreferencesModel(prefs);
      await loadedModel.loadPreferences();

      expect(loadedModel.mood, isNull);
    });

    test('should save preferences to storage', () async {
      model.activityPreference = 'Outdoor';
      model.mood = 'Productive';
      model.energyLevel = 5.0;
      model.timeOfDay = 'Morning';

      await model.savePreferences();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activityPreference'), 'Outdoor');
      // Mood is intentionally NOT persisted, so it never lands in
      // storage even when the in-memory value is set.
      expect(prefs.getString('mood'), isNull);
      expect(prefs.getDouble('energyLevel'), 5.0);
      expect(prefs.getString('timeOfDay'), 'Morning');
    });

    test('should update single preference and save', () async {
      model.updatePreference('activityPreference', 'Indoor');

      expect(model.activityPreference, 'Indoor');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activityPreference'), 'Indoor');
    });

    test('should update energy level preference', () async {
      model.updatePreference('energyLevel', 2.5);

      expect(model.energyLevel, 2.5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('energyLevel'), 2.5);
    });

    test('should toggle favorite activities on', () async {
      expect(model.favoriteActivities, isEmpty);
      expect(model.isFavorite('Reading'), false);

      await model.toggleFavorite('Reading');

      expect(model.favoriteActivities, contains('Reading'));
      expect(model.isFavorite('Reading'), true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favoriteActivities'), contains('Reading'));
    });

    test('should toggle favorite activities off', () async {
      model.favoriteActivities.add('Walking');
      await model.savePreferences();

      expect(model.isFavorite('Walking'), true);

      await model.toggleFavorite('Walking');

      expect(model.favoriteActivities, isNot(contains('Walking')));
      expect(model.isFavorite('Walking'), false);
    });

    test('should manage multiple favorites', () async {
      await model.toggleFavorite('Reading');
      await model.toggleFavorite('Walking');
      await model.toggleFavorite('Cooking');

      expect(model.favoriteActivities.length, 3);
      expect(model.isFavorite('Reading'), true);
      expect(model.isFavorite('Walking'), true);
      expect(model.isFavorite('Cooking'), true);
    });

    test('should reset preferences to defaults', () async {
      model.activityPreference = 'Indoor';
      model.mood = 'Relaxed';
      model.energyLevel = 4.0;
      model.timeOfDay = 'Evening';
      await model.savePreferences();

      await model.resetPreferences();

      expect(model.activityPreference, isNull);
      expect(model.mood, isNull);
      expect(model.energyLevel, 3.0);
      expect(model.timeOfDay, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activityPreference'), isNull);
      expect(prefs.getString('mood'), isNull);
      expect(prefs.getDouble('energyLevel'), 3.0);
    });

    test('should not reset theme settings and favorites on reset', () async {
      model.useDarkMode = true;
      model.colorTheme = 'sunset';
      model.favoriteActivities.add('Reading');
      await model.savePreferences();

      await model.resetPreferences();

      expect(model.useDarkMode, true);
      expect(model.colorTheme, 'sunset');
      expect(model.favoriteActivities, contains('Reading'));
    });

    test('should report preferences incomplete when missing values', () {
      model.activityPreference = 'Indoor';
      model.mood = 'Relaxed';
      // With autoDetectTime=false, timeOfDay must be set explicitly,
      // so leaving it null leaves preferences incomplete.
      model.autoDetectTime = false;
      // timeOfDay is null

      expect(model.arePreferencesComplete, false);
    });

    test('arePreferencesComplete treats time as optional when auto-detect is on', () {
      model.activityPreference = 'Indoor';
      model.mood = 'Relaxed';
      model.autoDetectTime = true;
      // timeOfDay is null but auto-detect fills it in at read time.

      expect(model.arePreferencesComplete, true);
    });

    test('should report preferences complete when all required values set', () {
      model.activityPreference = 'Outdoor';
      model.mood = 'Creative';
      model.timeOfDay = 'Afternoon';

      expect(model.arePreferencesComplete, true);
    });

    test('should notify listeners when preferences update', () {
      int listenerCallCount = 0;
      model.addListener(() {
        listenerCallCount++;
      });

      model.updatePreference('mood', 'Social');

      expect(listenerCallCount, 1);
    });

    test('should notify listeners when toggling favorites', () async {
      int listenerCallCount = 0;
      model.addListener(() {
        listenerCallCount++;
      });

      await model.toggleFavorite('Yoga');

      expect(listenerCallCount, 1);
    });

    test('should notify listeners when resetting preferences', () async {
      int listenerCallCount = 0;
      model.addListener(() {
        listenerCallCount++;
      });

      await model.resetPreferences();

      expect(listenerCallCount, 1);
    });
  });

  group('PreferencesModel predefined options', () {
    late PreferencesModel model;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      model = PreferencesModel(prefs);
    });

    test('should have correct activity options', () {
      expect(model.activityOptions, ['Indoor', 'Outdoor', 'Hybrid']);
      expect(model.activityOptions.length, 3);
    });

    test('should have correct mood options', () {
      expect(model.moodOptions, ['Relaxed', 'Productive', 'Creative', 'Social']);
      expect(model.moodOptions.length, 4);
    });

    test('should have correct time options', () {
      expect(model.timeOptions, ['Morning', 'Afternoon', 'Evening', 'Night']);
      expect(model.timeOptions.length, 4);
    });

    test('should have correct theme options', () {
      expect(model.themeOptions, ['Rainbow', 'Pastels', 'Monochrome', 'Ocean', 'Sunset']);
      expect(model.themeOptions.length, 5);
    });
  });
}

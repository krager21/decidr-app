/// Application-wide constants for the Decidr app
library;

import 'package:flutter/material.dart';

/// Constants related to the spinning wheel
class WheelConstants {
  WheelConstants._(); // Private constructor to prevent instantiation

  // Wheel dimensions
  static const double wheelSize = 300.0;
  static const double wheelShadowSize = 310.0;
  static const double centerKnobSize = 40.0;
  static const double centerKnobInnerSize = 15.0;
  static const double pointerSize = 40.0;

  // Spin animation parameters
  static const int minSpinRotations = 4;
  static const int maxSpinRotations = 6;
  static const Duration minSpinDuration = Duration(seconds: 4);
  static const Duration maxSpinDuration = Duration(seconds: 6);
  static const Duration snapDuration = Duration(milliseconds: 300);

  // Wheel rendering
  static const double iconRadiusRatio = 0.65;
  static const double iconSize = 22.0;
  static const double segmentBorderWidth = 3.0;
  static const double outerRingWidth = 5.0;

  // Gesture parameters
  static const double minVelocityForMomentum = 1.0;
  static const double velocityMultiplier = 2.0;
  static const double velocityDurationFactor = 0.5;

  // Haptic feedback
  static const Duration hapticDelayHeavy = Duration(milliseconds: 100);
  static const Duration hapticDelayMedium = Duration(milliseconds: 70);
}

/// Constants for suggestions and filtering
class SuggestionConstants {
  SuggestionConstants._();

  // Suggestion counts
  static const int minSuggestionsCount = 8;
  static const int maxSuggestionsCount = 12;
  static const int defaultSuggestionsCount = 8;

  // Filtering parameters
  static const double popularActivityBoostFactor = 0.3;
  static const int minFilteredSuggestionsCount = 5;

  // Energy level ranges
  static const double energyLevelMin = 1.0;
  static const double energyLevelMax = 5.0;
  static const double energyLevelDefault = 3.0;
  static const int energyLevelDivisions = 4;

  // Energy thresholds for labeling
  static const double energyVeryLowThreshold = 1.5;
  static const double energyLowThreshold = 2.5;
  static const double energyMediumThreshold = 3.5;
  static const double energyHighThreshold = 4.5;

  // Custom suggestions
  /// Maximum length for a user-supplied custom suggestion.
  /// Mirrored by the input field's `maxLength` in the UI.
  static const int customSuggestionMaxLength = 50;

  /// Maximum number of custom suggestions a user can save.
  static const int customSuggestionMaxCount = 100;
}

/// Constants for UI elements
class UIConstants {
  UIConstants._();

  // Padding and spacing
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  static const double defaultSpacing = 8.0;
  static const double largeSpacing = 16.0;
  static const double extraLargeSpacing = 24.0;

  // Border radius
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 30.0;
  static const double chipBorderRadius = 20.0;

  // Icon sizes
  static const double smallIconSize = 18.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 48.0;
  static const double extraLargeIconSize = 64.0;
  static const double avatarIconSize = 48.0;
  static const double profileAvatarSize = 80.0;

  // Elevation
  static const double cardElevation = 2.0;
  static const double elevatedCardElevation = 4.0;
  static const double dialogElevation = 5.0;

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Button sizes
  static const Size minButtonSize = Size(200, 56);
  static const EdgeInsets spinButtonPadding = EdgeInsets.symmetric(horizontal: 32, vertical: 16);
}

/// Constants for persistence and storage
class StorageConstants {
  StorageConstants._();

  // SharedPreferences keys
  static const String keyActivityPreference = 'activityPreference';
  static const String keyMood = 'mood';
  static const String keyEnergyLevel = 'energyLevel';
  static const String keyTimeOfDay = 'timeOfDay';
  static const String keyUseDarkMode = 'useDarkMode';
  static const String keyUseSystemTheme = 'useSystemTheme';
  static const String keyEnableHaptics = 'enableHaptics';
  static const String keyColorTheme = 'colorTheme';
  static const String keyFavoriteActivities = 'favoriteActivities';
  static const String keyActivityHistory = 'activityHistory';
  static const String keyCustomSuggestions = 'customSuggestions';

  // Debounce durations
  static const Duration saveDebounceDuration = Duration(milliseconds: 500);
}

/// Application metadata constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Decidr';
  static const String appVersion = '2.0.0';
  static const String appLegalese = '© 2025 Decidr App';
  static const String appDescription =
      'Decidr helps you make decisions with a fun spin of the wheel! '
      'Get personalized suggestions based on your preferences and mood.';
  static const String appEnhancedFeatures =
      'Enhanced with Material 3 design, dynamic themes, and personalized suggestions.';
}

/// Route name constants
class RouteConstants {
  RouteConstants._();

  static const String questionnaire = '/questionnaire';
  static const String settings = '/settings';
}

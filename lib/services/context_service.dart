import 'package:flutter/material.dart';

/// Service for auto-detecting contextual information like time of day
///
/// Provides automatic detection of time-based preferences to reduce
/// user friction in the questionnaire.
class ContextService {
  /// Get the current time of day category based on device time
  ///
  /// Returns:
  /// - 'Morning': 5:00 AM - 11:59 AM
  /// - 'Afternoon': 12:00 PM - 4:59 PM
  /// - 'Evening': 5:00 PM - 8:59 PM
  /// - 'Night': 9:00 PM - 4:59 AM
  static String getCurrentTimeOfDay() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening';
    } else {
      return 'Night';
    }
  }

  /// Get an appropriate icon for the current time of day
  ///
  /// Returns a Material icon that visually represents the time period.
  static IconData getTimeIcon() {
    final time = getCurrentTimeOfDay();
    switch (time) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Afternoon':
        return Icons.wb_twilight;
      case 'Evening':
        return Icons.nights_stay;
      default:
        return Icons.dark_mode;
    }
  }
}

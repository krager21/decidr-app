import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for tracking user feedback on activity suggestions
///
/// Tracks rejections and dislikes to improve future suggestions by:
/// - Reducing frequency of recently rejected activities
/// - Completely excluding disliked activities
/// - Applying time-based decay to rejections
class FeedbackModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// Map of activity name to list of rejection timestamps
  Map<String, List<DateTime>> _rejections = {};

  /// Set of activities the user has explicitly disliked
  Set<String> _dislikes = {};

  FeedbackModel(this._prefs) {
    _loadFeedback();
  }

  /// Get all rejected activities
  Map<String, List<DateTime>> get rejections => _rejections;

  /// Get all disliked activities
  Set<String> get dislikes => _dislikes;

  /// Record a "not right now" rejection for an activity
  ///
  /// Keeps only the last 5 rejections per activity for memory efficiency.
  void rejectActivity(String activity) {
    _rejections[activity] ??= [];
    _rejections[activity]!.add(DateTime.now());

    // Keep only last 5 rejections per activity
    if (_rejections[activity]!.length > 5) {
      _rejections[activity]!.removeAt(0);
    }

    _saveFeedback();
    notifyListeners();
    debugPrint('Rejected activity: $activity');
  }

  /// Mark an activity as disliked (permanently excluded)
  void dislikeActivity(String activity) {
    _dislikes.add(activity);
    _saveFeedback();
    notifyListeners();
    debugPrint('Disliked activity: $activity');
  }

  /// Clear all feedback for a specific activity
  void clearFeedback(String activity) {
    _rejections.remove(activity);
    _dislikes.remove(activity);
    _saveFeedback();
    notifyListeners();
    debugPrint('Cleared feedback for: $activity');
  }

  /// Clear all feedback data
  void clearAllFeedback() {
    _rejections.clear();
    _dislikes.clear();
    _saveFeedback();
    notifyListeners();
    debugPrint('Cleared all feedback');
  }

  /// Get weight multiplier for an activity (0.0 to 1.0)
  ///
  /// Returns:
  /// - 0.0 for disliked activities (completely excluded)
  /// - 0.1-1.0 for rejected activities based on recency and frequency
  /// - 1.0 for activities with no negative feedback
  double getActivityWeight(String activity) {
    // Disliked activities get 0 weight (completely excluded)
    if (_dislikes.contains(activity)) {
      return 0.0;
    }

    // Calculate recency-weighted rejection score
    final rejectionList = _rejections[activity] ?? [];
    if (rejectionList.isEmpty) {
      return 1.0;
    }

    double penalty = 0.0;
    final now = DateTime.now();

    for (final rejection in rejectionList) {
      final daysSince = now.difference(rejection).inDays;

      // Rejections decay over 30 days
      if (daysSince < 1) {
        penalty += 0.3; // Same day: heavy penalty
      } else if (daysSince < 7) {
        penalty += 0.2; // This week: medium penalty
      } else if (daysSince < 30) {
        penalty += 0.1; // This month: light penalty
      }
      // Older than 30 days: ignored
    }

    // Ensure weight stays in valid range (0.1 minimum to still appear occasionally)
    return (1.0 - penalty).clamp(0.1, 1.0);
  }

  /// Check if an activity is disliked
  bool isDisliked(String activity) {
    return _dislikes.contains(activity);
  }

  /// Get count of rejections for an activity in the last 30 days
  int getRecentRejectionsCount(String activity) {
    final rejectionList = _rejections[activity] ?? [];
    final now = DateTime.now();
    return rejectionList
        .where((rejection) => now.difference(rejection).inDays < 30)
        .length;
  }

  /// Load feedback data from SharedPreferences
  Future<void> _loadFeedback() async {
    try {
      // Load rejections
      final rejectionsJson = _prefs.getString('activity_rejections');
      if (rejectionsJson != null) {
        final Map<String, dynamic> decoded = json.decode(rejectionsJson);
        _rejections = decoded.map((key, value) {
          final timestamps = (value as List<dynamic>)
              .map((ts) => DateTime.parse(ts as String))
              .toList();
          return MapEntry(key, timestamps);
        });
      }

      // Load dislikes
      final dislikesList = _prefs.getStringList('activity_dislikes');
      if (dislikesList != null) {
        _dislikes = Set<String>.from(dislikesList);
      }

      debugPrint('Loaded feedback: ${_rejections.length} rejected, ${_dislikes.length} disliked');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading feedback: $e');
    }
  }

  /// Save feedback data to SharedPreferences
  Future<void> _saveFeedback() async {
    try {
      // Save rejections
      final rejectionsMap = _rejections.map((key, value) {
        final timestamps = value.map((dt) => dt.toIso8601String()).toList();
        return MapEntry(key, timestamps);
      });
      await _prefs.setString('activity_rejections', json.encode(rejectionsMap));

      // Save dislikes
      await _prefs.setStringList('activity_dislikes', _dislikes.toList());

      debugPrint('Saved feedback data');
    } catch (e) {
      debugPrint('Error saving feedback: $e');
    }
  }
}
